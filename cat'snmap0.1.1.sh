#!/usr/bin/env bash
# catnmap 0.1.1 | (c) AC Kondo 1999-2026
# Real nmap wrapper: parallel, service/version detection, -oA output.
set -u

usage() {
  cat <<'EOF'
catnmap 0.1.1
Usage: catnmap HOST [options]

  -p PORTS     ports (80,443,8000-8010) or -p- for all
  -t 0-5       timing template (default 4)
  -T N         alias for -t
  -sV          service/version detection
  -O           OS detection (needs root)
  -A           aggressive: -sV -O -sC --traceroute (needs root)
  -U           UDP top 50 (needs root)
  -S           ping sweep only (-sn)
  --top N      scan N most common ports
  -6           IPv6
  -n           no DNS resolution
  -q           print open ports only
  -o NAME      output prefix (default: scans/<host>_<stamp>)

  Output is always written as .nmap / .gnmap / .xml via -oA.
EOF
}

command -v nmap >/dev/null 2>&1 || { echo 'Error: nmap not installed (brew install nmap).' >&2; exit 1; }
(($#)) || { usage; exit 2; }

host=$1; shift
[[ $host != -* && -n $host ]] || { echo 'Invalid host' >&2; exit 2; }

ports='' timing=4 family='' quiet=0 nodns=0 out=''
sv=0 os=0 agg=0 udp=0 sweep=0 top=''

while (($#)); do
  case $1 in
    -p) [[ $# -ge 2 ]] || { usage; exit 2; }; ports=$2; shift 2 ;;
    -t|-T) [[ $# -ge 2 ]] || { usage; exit 2; }; timing=$2; shift 2 ;;
    -sV) sv=1; shift ;;
    -O) os=1; shift ;;
    -A) agg=1; shift ;;
    -U) udp=1; shift ;;
    -S) sweep=1; shift ;;
    --top) [[ $# -ge 2 ]] || { usage; exit 2; }; top=$2; shift 2 ;;
    -6) family=-6; shift ;;
    -n) nodns=1; shift ;;
    -q) quiet=1; shift ;;
    -o) [[ $# -ge 2 ]] || { usage; exit 2; }; out=$2; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 2 ;;
  esac
done

[[ $timing =~ ^[0-5]$ ]] || { echo 'Timing must be 0-5' >&2; exit 2; }
[[ -z $top || $top =~ ^[0-9]+$ ]] || { echo '--top needs a number' >&2; exit 2; }
if [[ -n $ports ]]; then
  [[ $ports == - ]] || [[ $ports =~ ^[0-9]+([-,][0-9]+)*$ ]] || { echo 'Invalid port spec' >&2; exit 2; }
fi

if (( os || agg || udp )) && [[ $(id -u) -ne 0 ]]; then
  echo '[!] -O / -A / -U need root - re-run with sudo.' >&2
  exit 1
fi

stamp=$(date +%Y%m%d-%H%M%S)
safe=${host//[.:\/ ]/_}
[[ -n $out ]] || out="scans/${safe}_${stamp}"
mkdir -p "$(dirname "$out")"

cmd=(nmap -T"$timing" --reason -oA "$out")
((nodns)) && cmd+=(-n)
[[ -n $family ]] && cmd+=("$family")
((sv && !agg)) && cmd+=(-sV)
((os)) && cmd+=(-O --osscan-guess)
((agg)) && cmd+=(-A)
((udp)) && cmd+=(-sU --top-ports 50)
((sweep)) && cmd+=(-sn)
[[ -n $top ]] && cmd+=(--top-ports "$top")
[[ -n $ports ]] && cmd+=(-p "$ports")
((quiet)) && cmd+=(--open)
cmd+=("$host")

((quiet)) || printf '[*] %s\n[*] results -> %s.{nmap,gnmap,xml}\n\n' "${cmd[*]}" "$out"

if ((quiet)); then
  "${cmd[@]}" | grep -E '^[0-9]+/(tcp|udp)'
  rc=${PIPESTATUS[0]}
else
  "${cmd[@]}"
  rc=$?
fi

printf '\n[*] done (exit %d)\n' "$rc"
exit "$rc"
