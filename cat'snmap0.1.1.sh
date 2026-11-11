#!/usr/bin/env bash
# fix.sh - clean up the catnmap wrapper: rename, drop dead var, fix -A/-sV dup, add README
set -euo pipefail

cd "$(dirname "$0")"

src="cat'snmap0.1.1.sh"
dst="catnmap"

# BSD sed needs -i '', GNU sed needs -i. Pick whichever this system is.
if sed --version >/dev/null 2>&1; then
  sedi() { sed -i -e "$@"; }
else
  sedi() { sed -i '' -e "$@"; }
fi

# 1. rename
if [[ -f $src && ! -f $dst ]]; then
  mv "$src" "$dst"
  echo "[+] renamed -> $dst"
elif [[ -f $dst ]]; then
  echo "[=] $dst already exists, skipping rename"
else
  echo "[!] $src not found" >&2
  exit 1
fi

# 2. header: version + filename reference
sedi 's|^# Cat.s Nmap 2\.0 |.*|# catnmap 2.0 | © AC Kondo 1999-2026|' "$dst" 2>/dev/null || true
sedi 's|^# Cat'"'"'s Nmap 2\.0 |.*|# catnmap 2.0 | (c) AC Kondo 1999-2026|' "$dst"
sedi 's|^Cat'"'"'s Nmap 2\.0$|catnmap 2.0|' "$dst"
sedi 's|^Usage: catnmap HOST|Usage: catnmap HOST|' "$dst"

# 3. drop the dead variable
sedi "s| out='' mode=''| out=''|" "$dst"

# 4. suppress -sV when -A already implies it
sedi 's|((sv)) && cmd+=(-sV)|((sv \&\& !agg)) \&\& cmd+=(-sV)|' "$dst"

# 5. README
cat > README.md <<'EOF'
# catnmap

Thin, safe wrapper around `nmap`. Validates input, builds the argv properly, and
always writes `.nmap` / `.gnmap` / `.xml` so results never live only in scrollback.

## Install

```sh
brew install nmap
chmod +x catnmap
