#!/usr/bin/env bats
# Runs the generated hooks inside real shells.
load test_helper

setup_accounts() {
  login work aaaa1111
  login personal bbbb2222
  mkdir -p "$WORK/pinned/sub"
  echo personal > "$WORK/pinned/.cfa-account"
}

# in_sh <shell> <script> — shell is bash or zsh
in_sh() {
  local sh=$1
  shift
  case "$sh" in
  zsh) zsh -f -c "eval \"\$(\"$CFA\" init zsh)\"; $*" ;;
    bash) bash --norc --noprofile -c "eval \"\$(\"$CFA\" init bash)\"; $*" ;;
  esac
}

check_shell() {
  local sh=$1
  setup_accounts

  # default at startup
  run in_sh "$sh" 'echo "$TUNNEL_ORIGIN_CERT|$_CFA_NAME|$_CFA_HOOK"'
  [ "$output" = "$STORE/work/cert.pem|work|$sh" ]

  # cfa use changes this shell only, --clear restores
  run in_sh "$sh" 'cfa use personal 2>/dev/null; echo "$TUNNEL_ORIGIN_CERT"; cfa use --clear 2>/dev/null; echo "$TUNNEL_ORIGIN_CERT"'
  [ "${lines[0]}" = "$STORE/personal/cert.pem" ]
  [ "${lines[1]}" = "$STORE/work/cert.pem" ]

  # use none -> unset (cloudflared falls back to its default path)
  run in_sh "$sh" 'cfa use none 2>/dev/null; echo "[${TUNNEL_ORIGIN_CERT-}]"'
  [ "$output" = "[]" ]

  # failing use keeps state and propagates the exit code
  run in_sh "$sh" 'cfa use ghost 2>/dev/null; echo "rc=$? $TUNNEL_ORIGIN_CERT"'
  [ "$output" = "rc=4 $STORE/work/cert.pem" ]

  # directory pin
  run in_sh "$sh" "cd '$WORK/pinned/sub'; _cfa_sync; echo \"\$TUNNEL_ORIGIN_CERT\"; cd '$WORK'; _cfa_sync; echo \"\$TUNNEL_ORIGIN_CERT\""
  [ "${lines[0]}" = "$STORE/personal/cert.pem" ]
  [ "${lines[1]}" = "$STORE/work/cert.pem" ]

  # external value is respected
  run in_sh "$sh" 'export TUNNEL_ORIGIN_CERT=/ext.pem; _cfa_sync; echo "$TUNNEL_ORIGIN_CERT|$_CFA_NAME"'
  [ "$output" = "/ext.pem|work" ]

  # missing account -> non-existent path, never a fallback to another account
  mkdir -p "$WORK/ghost" && echo ghost > "$WORK/ghost/.cfa-account"
  run in_sh "$sh" "cd '$WORK/ghost'; _cfa_sync; echo \"\$TUNNEL_ORIGIN_CERT|\$_CFA_NAME\""
  [ "$output" = "$STORE/ghost/cert.pem|ghost?" ]

  # nvm mapping follows NVM_BIN
  "$CFA" -q map node 25 personal
  run in_sh "$sh" "NVM_BIN=\$HOME/.nvm/versions/node/v25.0.0/bin; _cfa_sync; echo \"\$TUNNEL_ORIGIN_CERT\""
  [ "$output" = "$STORE/personal/cert.pem" ]

  # cloudflared sees the selected cert
  run in_sh "$sh" "cd '$WORK/pinned'; _cfa_sync; cloudflared tunnel list"
  [ "$output" = "cert=$STORE/personal/cert.pem" ]
}

@test "bash hook" {
  check_shell bash
}

@test "zsh hook" {
  command -v zsh >/dev/null || skip "zsh not installed"
  check_shell zsh
}

@test "zsh chpwd hook updates on cd within one command line" {
  command -v zsh >/dev/null || skip "zsh not installed"
  setup_accounts
  run in_sh zsh "cd '$WORK/pinned' && echo \"\$TUNNEL_ORIGIN_CERT\""
  [ "$output" = "$STORE/personal/cert.pem" ]
}

@test "bash hook does not duplicate PROMPT_COMMAND" {
  setup_accounts
  run bash --norc --noprofile -c "PROMPT_COMMAND='echo hi'; eval \"\$('$CFA' init bash)\"; eval \"\$('$CFA' init bash)\"; echo \"\$PROMPT_COMMAND\""
  [ "$output" = "_cfa_sync;echo hi" ]
}

@test "fish hook" {
  command -v fish >/dev/null || skip "fish not installed"
  setup_accounts
  f() { fish --no-config -c "$CFA init fish | source; $1"; }
  run f 'echo "$TUNNEL_ORIGIN_CERT|$_CFA_NAME"'
  [ "$output" = "$STORE/work/cert.pem|work" ]
  # fish doesn't apply a function call's 2>/dev/null to command substitutions inside it,
  # so drop the shell's stderr as a whole (inside the function: `run` merges stderr).
  fq() { f "$1" 2>/dev/null; }
  run fq 'cfa use personal; echo $TUNNEL_ORIGIN_CERT; cfa use --clear; echo $TUNNEL_ORIGIN_CERT'
  [ "${lines[0]}" = "$STORE/personal/cert.pem" ]
  [ "${lines[1]}" = "$STORE/work/cert.pem" ]
  run f "cd '$WORK/pinned/sub'; echo \$TUNNEL_ORIGIN_CERT"
  [ "$output" = "$STORE/personal/cert.pem" ]
  run f 'set -gx TUNNEL_ORIGIN_CERT /ext.pem; _cfa_sync; echo "$TUNNEL_ORIGIN_CERT|$_CFA_NAME"'
  [ "$output" = "/ext.pem|work" ]
  "$CFA" -q map node 25 personal
  run f "set -gx NVM_BIN \$HOME/.nvm/versions/node/v25.0.0/bin; _cfa_sync; echo \$TUNNEL_ORIGIN_CERT"
  [ "$output" = "$STORE/personal/cert.pem" ]
}

@test "generated code is syntactically valid" {
  "$CFA" init bash | bash -n
  "$CFA" completion bash | bash -n
  if command -v zsh >/dev/null; then
    "$CFA" init zsh | zsh -n
    "$CFA" completion zsh | zsh -n
  fi
  if command -v fish >/dev/null; then
    "$CFA" init fish | fish -n
    "$CFA" completion fish | fish -n
  fi
}

@test "bash completion offers commands and account names" {
  setup_accounts
  run bash --norc --noprofile -c "eval \"\$('$CFA' init bash)\"; COMP_WORDS=(cfa us); COMP_CWORD=1; _cfa; echo \"\${COMPREPLY[*]}\"; COMP_WORDS=(cfa use ''); COMP_CWORD=2; _cfa; echo \"\${COMPREPLY[*]}\""
  [ "${lines[0]}" = "use" ]
  [ "${lines[1]}" = "personal work none --clear" ]
}

setup_wrangler_accounts() {
  FAKE_WR_ACCOUNTS=$A1 "$CFA" -q login acme wrangler       # default
  printf 'TOKEN-ci-xyz123\n' | "$CFA" -q login ci token --account-id "$C3"
  FAKE_CF_ACCOUNT=$B2 "$CFA" -q login tun cloudflared
  mkdir -p "$WORK/acme" "$WORK/ci" "$WORK/tun" "$WORK/ghost"
  echo acme > "$WORK/acme/.cfa-account"
  echo ci > "$WORK/ci/.cfa-account"
  echo tun > "$WORK/tun/.cfa-account"
  echo ghost > "$WORK/ghost/.cfa-account"
}

check_wrangler_shell() {
  local sh=$1
  setup_wrangler_accounts
  local show='echo "${CLOUDFLARE_API_TOKEN-<unset>}|${CLOUDFLARE_ACCOUNT_ID-<unset>}|${_CFA_WRANGLER_XDG-<unset>}"'

  # OAuth account: account id + XDG for the wrapper, no token
  run in_sh "$sh" "cd '$WORK/acme'; _cfa_sync; $show; wrangler deploy"
  [ "${lines[0]}" = "<unset>|$A1|$STORE/acme/xdg" ]
  [ "${lines[1]}" = "token=<unset> account=$A1 xdg=$STORE/acme/xdg" ]

  # token account, then back to OAuth: token is removed again
  run in_sh "$sh" "cd '$WORK/ci'; _cfa_sync; $show; wrangler deploy; cd '$WORK/acme'; _cfa_sync; $show"
  [ "${lines[0]}" = "TOKEN-ci-xyz123|$C3|<unset>" ]
  [ "${lines[1]}" = "token=TOKEN-ci-xyz123 account=$C3 xdg=<unset>" ]
  [ "${lines[2]}" = "<unset>|$A1|$STORE/acme/xdg" ]

  # cloudflared-only account: wrangler is pinned to its account ID (fails closed)
  run in_sh "$sh" "cd '$WORK/tun'; _cfa_sync; $show"
  [ "$output" = "<unset>|$B2|<unset>" ]

  # missing account: placeholder ID, never another account
  run in_sh "$sh" "cd '$WORK/ghost'; _cfa_sync; $show"
  [ "$output" = "<unset>|cfa-no-account-id|<unset>" ]

  # externally set credentials (direnv/CI) are left alone
  run in_sh "$sh" "export CLOUDFLARE_API_TOKEN=from-direnv; cd '$WORK/ci'; _cfa_sync; $show"
  [ "$output" = "from-direnv|<unset>|<unset>" ]
  run in_sh "$sh" "export CLOUDFLARE_ACCOUNT_ID=$B2; cd '$WORK/acme'; _cfa_sync; $show"
  [ "$output" = "<unset>|$B2|<unset>" ]

  # cfa use none: nothing exported; plain wrangler uses its global (default) login
  run in_sh "$sh" "cd '$WORK/acme'; cfa use none 2>/dev/null; $show"
  [ "$output" = "<unset>|<unset>|<unset>" ]

  # opting out of the wrapper
  run "$sh" -c "CFA_NO_WRANGLER_WRAPPER=1; export CFA_NO_WRANGLER_WRAPPER; eval \"\$('$CFA' init $sh)\"; type wrangler"
  [[ "$output" != *function* ]] || false
}

@test "bash hook: wrangler" {
  check_wrangler_shell bash
}

@test "zsh hook: wrangler" {
  command -v zsh >/dev/null || skip "zsh not installed"
  check_wrangler_shell zsh
}

@test "fish hook: wrangler" {
  command -v fish >/dev/null || skip "fish not installed"
  setup_wrangler_accounts
  f() { fish --no-config -c "$CFA init fish | source; $1"; }
  local show='echo "$CLOUDFLARE_API_TOKEN|$CLOUDFLARE_ACCOUNT_ID|$_CFA_WRANGLER_XDG"'
  run f "cd '$WORK/acme'; $show; wrangler deploy"
  [ "${lines[0]}" = "|$A1|$STORE/acme/xdg" ]
  [ "${lines[1]}" = "token=<unset> account=$A1 xdg=$STORE/acme/xdg" ]
  run f "cd '$WORK/ci'; $show; cd '$WORK/acme'; $show"
  [ "${lines[0]}" = "TOKEN-ci-xyz123|$C3|" ]
  [ "${lines[1]}" = "|$A1|$STORE/acme/xdg" ]
  run f "cd '$WORK/ghost'; $show"
  [ "$output" = "|cfa-no-account-id|" ]
  run f "set -gx CLOUDFLARE_API_TOKEN from-direnv; cd '$WORK/ci'; _cfa_sync; $show"
  [ "$output" = "from-direnv||" ]
}
