#!/usr/bin/env bats
load test_helper

setup_accounts() {
  login work aaaa1111      # becomes default
  login personal bbbb2222
  login client cccc3333
}

@test "default is used when nothing else is set" {
  setup_accounts
  run "$CFA" current
  [ "$output" = "work  (source: default)" ]
}

@test "node mapping beats default" {
  setup_accounts
  "$CFA" -q map node 25 client
  NVM_BIN="$HOME/.nvm/versions/node/v25.1.0/bin" run "$CFA" current --name
  [ "$output" = client ]
  NVM_BIN="$HOME/.nvm/versions/node/v22.3.0/bin" run "$CFA" current --name
  [ "$output" = work ]
}

@test ".cfa-account in a parent dir beats node mapping" {
  setup_accounts
  "$CFA" -q map node 25 client
  mkdir -p "$WORK/proj/sub/deep"
  printf 'personal\n' > "$WORK/proj/.cfa-account"
  cd "$WORK/proj/sub/deep"
  NVM_BIN="$HOME/.nvm/versions/node/v25.1.0/bin" run "$CFA" current
  [ "$output" = "personal  (source: pin $WORK/proj/.cfa-account)" ]
  CFA_NO_DIR=1 NVM_BIN="$HOME/.nvm/versions/node/v25.1.0/bin" run "$CFA" current --name
  [ "$output" = client ]
}

@test ".cfa-account tolerates CRLF and trailing spaces" {
  setup_accounts
  printf 'client \r\n' > .cfa-account
  run "$CFA" current --name
  [ "$output" = client ]
}

@test "CFA_ACCOUNT beats a pin" {
  setup_accounts
  echo personal > .cfa-account
  CFA_ACCOUNT=client run "$CFA" current --name
  [ "$output" = client ]
}

@test "cfa use none disables selection" {
  setup_accounts
  CFA_ACCOUNT=none run "$CFA" current
  [ "$status" -eq 1 ]
  [[ "$output" == "none"* ]] || false
}

@test "external TUNNEL_ORIGIN_CERT is reported, not overridden" {
  setup_accounts
  TUNNEL_ORIGIN_CERT=/etc/x.pem run "$CFA" current
  [ "${lines[0]}" = "work  (source: default)" ]
  [ "${lines[1]}" = "  cloudflared: external TUNNEL_ORIGIN_CERT=/etc/x.pem" ]
  CLOUDFLARE_API_TOKEN=xyz run "$CFA" current
  [ "${lines[1]}" = "  wrangler: external CLOUDFLARE_API_TOKEN/CLOUDFLARE_ACCOUNT_ID" ]
}

@test "a pin naming a missing account is flagged" {
  setup_accounts
  echo ghost > .cfa-account
  run "$CFA" current
  [ "$status" -eq 4 ]
  [[ "$output" == *"does not exist"* ]] || false
  run "$CFA" exec -- true
  [ "$status" -eq 4 ]
}

@test "a pin with a malicious name cannot escape the store" {
  setup_accounts
  echo '../../../etc' > .cfa-account
  run "$CFA" path
  [ "$status" -eq 2 ]
}

@test "pin and unpin" {
  setup_accounts
  run "$CFA" pin client
  [ "$status" -eq 0 ]
  [ "$(cat .cfa-account)" = client ]
  run "$CFA" pin ghost
  [ "$status" -eq 4 ]
  "$CFA" -q unpin
  [ ! -e .cfa-account ]
  run "$CFA" unpin
  [ "$status" -eq 1 ]
}

@test "exec sets the env for one command and propagates exit codes" {
  setup_accounts
  run "$CFA" exec personal -- cloudflared tunnel list
  [ "$output" = "cert=$STORE/personal/cert.pem" ]
  run "$CFA" exec personal -- sh -c 'echo "$CFA_ACCOUNT"; exit 7'
  [ "$status" -eq 7 ]
  [ "$output" = personal ]
  run "$CFA" exec -- cloudflared tunnel list
  [ "$output" = "cert=$STORE/work/cert.pem" ]
  run "$CFA" exec ghost -- true
  [ "$status" -eq 4 ]
}

@test "each runs once per account" {
  setup_accounts
  run "$CFA" each -- cloudflared tunnel list
  [ "$status" -eq 0 ]
  [[ "$output" == *"==> client"*"cert=$STORE/client/cert.pem"*"==> personal"*"==> work"* ]] || false
  run "$CFA" each -- false
  [ "$status" -eq 1 ]
}

@test "use without the shell hook explains and exits 3" {
  setup_accounts
  run "$CFA" use personal
  [ "$status" -eq 3 ]
  [[ "$output" == *"cfa init"* ]] || false
}

@test "use --print emits shell code" {
  setup_accounts
  run "$CFA" -q use --print personal
  [ "$output" = "export CFA_ACCOUNT='personal'" ]
  run "$CFA" -q use --print --shell fish personal
  [ "$output" = "set -gx CFA_ACCOUNT 'personal'" ]
  run "$CFA" -q use --print --clear
  [ "$output" = "unset CFA_ACCOUNT" ]
  run "$CFA" -q use --print none
  [ "$output" = "export CFA_ACCOUNT='none'" ]
  run "$CFA" use --print ghost
  [ "$status" -eq 4 ]
}

@test "a custom CFA_HOME is honoured everywhere" {
  export CFA_HOME="$BATS_TEST_TMPDIR/store"
  login work aaaa1111
  [ -f "$CFA_HOME/work/cert.pem" ]
  run "$CFA" current --name
  [ "$output" = work ]
}
