#!/usr/bin/env bash
# Install cfa — https://github.com/eanp/cfa
#
#   curl -fsSL https://raw.githubusercontent.com/eanp/cfa/main/install.sh | bash
#
# Environment:
#   CFA_INSTALL_DIR  where to put the `cfa` binary (default: ~/.local/bin)
#   CFA_REF          git tag or branch to install (default: latest release, else main)
set -euo pipefail

REPO="eanp/cfa"
DIR="${CFA_INSTALL_DIR:-$HOME/.local/bin}"
REF="${CFA_REF:-}"

fetch() { # fetch <url> [out]
  if command -v curl >/dev/null 2>&1; then
    if [ -n "${2-}" ]; then curl -fsSL "$1" -o "$2"; else curl -fsSL "$1"; fi
  elif command -v wget >/dev/null 2>&1; then
    if [ -n "${2-}" ]; then wget -qO "$2" "$1"; else wget -qO- "$1"; fi
  else
    echo "install.sh: need curl or wget" >&2
    exit 1
  fi
}

if [ -z "$REF" ]; then
  REF=$(fetch "https://api.github.com/repos/$REPO/releases/latest" 2>/dev/null |
    sed -n 's/.*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1 || true)
  REF=${REF:-main}
fi

tmp=$(mktemp "${TMPDIR:-/tmp}/cfa.XXXXXX")
trap 'rm -f "$tmp"' EXIT
fetch "https://raw.githubusercontent.com/$REPO/$REF/bin/cfa" "$tmp"
head -n1 "$tmp" | grep -q '^#!/usr/bin/env bash' || { echo "install.sh: download looks wrong" >&2; exit 1; }

mkdir -p "$DIR"
chmod 755 "$tmp"
mv -f "$tmp" "$DIR/cfa"
trap - EXIT

echo "Installed $("$DIR/cfa" --version) to $DIR/cfa"
case ":$PATH:" in
  *":$DIR:"*) ;;
  *) echo "Note: $DIR is not on your PATH. Add: export PATH=\"$DIR:\$PATH\"" ;;
esac

shell=$(basename "${SHELL:-bash}")
# shellcheck disable=SC2088,SC2016 # literal text shown to the user
case "$shell" in
  zsh) rc='~/.zshrc'; line='eval "$(cfa init zsh)"' ;;
  fish) rc='~/.config/fish/config.fish'; line='cfa init fish | source' ;;
  *) rc='~/.bashrc'; line='eval "$(cfa init bash)"' ;;
esac
cat <<EOF

Next steps:
  1. Add the shell integration to $rc:
       $line
  2. Open a new terminal, then:
       cfa import <name> wrangler   # adopt your current wrangler login, or
       cfa login <name> wrangler    # log in to another account
  3. cfa doctor
EOF
