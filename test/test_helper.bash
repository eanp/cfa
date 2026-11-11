# shellcheck shell=bash
ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
CFA="$ROOT/bin/cfa"
FIX="$ROOT/test/fixtures"
# shellcheck source=fixtures/mkcert.sh
. "$FIX/mkcert.sh"

# 32-hex Cloudflare account IDs
A1=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
B2=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
C3=cccccccccccccccccccccccccccccccc
export A1 B2 C3

setup() {
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME"
  unset CFA_HOME CFA_ACCOUNT TUNNEL_ORIGIN_CERT _CFA_EXPORTED _CFA_HOOK NVM_BIN CFA_NO_DIR \
    CLOUDFLARE_API_TOKEN CLOUDFLARE_ACCOUNT_ID CLOUDFLARE_API_KEY CLOUDFLARE_EMAIL \
    CF_API_TOKEN CF_ACCOUNT_ID XDG_CONFIG_HOME _CFA_TOKEN_FP _CFA_ACCOUNT_ID _CFA_WRANGLER_XDG
  export NO_COLOR=1 CFA_NONINTERACTIVE=1
  export CFA_CLOUDFLARED="$FIX/bin/cloudflared"
  export CFA_WRANGLER="$FIX/bin/wrangler"
  export PATH="$ROOT/bin:$FIX/bin:$PATH"
  # Work in a directory with no .cfa-account above it.
  export WORK="$BATS_TEST_TMPDIR/work"
  mkdir -p "$WORK"
  cd "$WORK" || return 1
  # CI: run cfa (and the hook tests) under a specific bash, e.g. macOS /bin/bash 3.2
  if [ -n "${CFA_TEST_BASH-}" ]; then
    mkdir -p "$BATS_TEST_TMPDIR/shim"
    ln -sf "$CFA_TEST_BASH" "$BATS_TEST_TMPDIR/shim/bash"
    export PATH="$BATS_TEST_TMPDIR/shim:$PATH"
  fi
  export STORE="$HOME/.config/cfa"
  if [ "$(uname -s)" = Darwin ]; then
    export WCFG="$HOME/Library/Preferences/.wrangler/config/default.toml"
  else
    export WCFG="$HOME/.config/.wrangler/config/default.toml"
  fi
}

# login <name> <accountID>  — cloudflared login
login() {
  FAKE_CF_ACCOUNT=$2 "$CFA" -q login "$1" cloudflared
}

# login_wr <name> <accountID>  — wrangler OAuth login
login_wr() {
  FAKE_WR_ACCOUNTS=$2 "$CFA" -q login "$1" wrangler
}

# login_tok <name> <accountID>  — API token
login_tok() {
  printf 'TOKEN-%s-xyz123\n' "$1" | FAKE_WR_ACCOUNTS=$2 "$CFA" -q login "$1" token
}

mode() { stat -c %a "$1" 2>/dev/null || stat -f %Lp "$1"; }
