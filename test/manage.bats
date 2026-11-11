#!/usr/bin/env bats
load test_helper

@test "import moves the default cert and replaces it with a symlink" {
  mkdir -p "$HOME/.cloudflared"
  mkcert "$HOME/.cloudflared/cert.pem" imp0001
  run "$CFA" import work
  [ "$status" -eq 0 ]
  [ "$(readlink "$HOME/.cloudflared/cert.pem")" = "$STORE/work/cert.pem" ]
  [ "$(mode "$STORE/work/cert.pem")" = 600 ]
  run "$CFA" import again
  [ "$status" -eq 1 ]
  [[ "$output" == *"already managed"* ]]
}

@test "import --copy from another path leaves the source alone" {
  mkcert "$WORK/x.pem" imp0002
  run "$CFA" import other "$WORK/x.pem" --copy
  [ "$status" -eq 0 ]
  [ -f "$WORK/x.pem" ]
  [ -f "$STORE/other/cert.pem" ]
  # first account becomes the default
  [ "$(readlink "$HOME/.cloudflared/cert.pem")" = "$STORE/other/cert.pem" ]
}

@test "import rejects files that are not certs" {
  echo junk > "$WORK/junk.pem"
  run "$CFA" import bad "$WORK/junk.pem"
  [ "$status" -eq 1 ]
  [ ! -e "$STORE/bad" ]
}

@test "list shows accounts, ids, default and current" {
  login work aaaa1111
  login personal bbbb2222
  run "$CFA" list
  [ "$status" -eq 0 ]
  [[ "${lines[1]}" == "  personal"*"bbbb2222"*"cloudflared"* ]]
  [[ "${lines[2]}" == "* work"*"aaaa1111"*"cloudflared"*"yes" ]]
  CFA_ACCOUNT=personal run "$CFA" list
  [[ "${lines[1]}" == "* personal"* ]]
}

@test "list --json" {
  login work aaaa1111
  run "$CFA" list --json
  [ "$status" -eq 0 ]
  [ "$output" = '[{"name":"work","account_id":"aaaa1111","credentials":["cloudflared"],"default":true,"current":true}]' ]
}

@test "list with no accounts" {
  run "$CFA" list
  [ "$status" -eq 0 ]
  [[ "$output" == *"No accounts yet"* ]]
}

@test "remove deletes the account and the default link" {
  login work aaaa1111
  run "$CFA" remove work -y
  [ "$status" -eq 0 ]
  [ ! -e "$STORE/work" ]
  [ ! -L "$HOME/.cloudflared/cert.pem" ]
}

@test "remove refuses accounts holding tunnel credentials unless --force" {
  login work aaaa1111
  echo '{}' > "$STORE/work/abc.json"
  run "$CFA" remove work -y
  [ "$status" -eq 1 ]
  [ -d "$STORE/work" ]
  run "$CFA" remove work -y --force
  [ "$status" -eq 0 ]
}

@test "remove of unknown account" {
  run "$CFA" remove nope -y
  [ "$status" -eq 4 ]
}

@test "rename moves the account, relinks default and node mappings" {
  login work aaaa1111
  "$CFA" -q map node 22 work
  run "$CFA" rename work job
  [ "$status" -eq 0 ]
  [ -f "$STORE/job/cert.pem" ]
  [ "$(readlink "$HOME/.cloudflared/cert.pem")" = "$STORE/job/cert.pem" ]
  grep -q '^node.22=job$' "$STORE/config"
}

@test "rename refuses to clobber" {
  login a aaaa
  login b bbbb
  run "$CFA" rename a b
  [ "$status" -eq 5 ]
}

@test "default shows, sets and unsets" {
  login work aaaa1111
  login personal bbbb2222
  run "$CFA" default
  [ "$output" = work ]
  "$CFA" -q default personal
  [ "$(readlink "$HOME/.cloudflared/cert.pem")" = "$STORE/personal/cert.pem" ]
  "$CFA" -q default --unset
  [ ! -e "$HOME/.cloudflared/cert.pem" ]
  run "$CFA" default
  [ "$status" -eq 1 ]
}

@test "default refuses to overwrite an unmanaged cert" {
  login work aaaa1111
  rm "$HOME/.cloudflared/cert.pem"
  mkcert "$HOME/.cloudflared/cert.pem" real
  run "$CFA" default work
  [ "$status" -eq 1 ]
  [[ "$output" == *"cfa import"* ]]
  [ ! -L "$HOME/.cloudflared/cert.pem" ]
}

@test "path and whoami never print the API token" {
  login work aaaa1111
  run "$CFA" path work
  [ "$output" = "$STORE/work" ]
  run "$CFA" whoami
  [ "$status" -eq 0 ]
  [[ "$output" == *"aaaa1111"* ]]
  [[ "$output" == *"selected by default"* ]]
  [[ "$output" != *SECRET* ]]
  run "$CFA" list --json
  [[ "$output" != *SECRET* ]]
}

@test "map node set, list, unset; requires existing account" {
  login work aaaa1111
  run "$CFA" map node 22 missing
  [ "$status" -eq 4 ]
  "$CFA" -q map node 22 work
  run "$CFA" map list
  [ "$output" = "node 22 → work" ]
  "$CFA" -q map node 22 --unset
  run "$CFA" map list
  [ -z "$output" ]
  run "$CFA" map node abc work
  [ "$status" -eq 2 ]
}

@test "doctor passes on a healthy setup" {
  login work aaaa1111
  run "$CFA" doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"no problems"* ]]
}

@test "doctor reports problems" {
  login work aaaa1111
  chmod 644 "$STORE/work/cert.pem"
  mkdir -p "$STORE/broken"
  echo junk > "$STORE/broken/cert.pem"
  printf 'origincert: /x/cert.pem\n' > "$HOME/.cloudflared/config.yml"
  run "$CFA" doctor
  [ "$status" -eq 1 ]
  [[ "$output" == *"cert mode 644"* ]]
  [[ "$output" == *"broken: cloudflared cert can't be decoded"* ]]
  [[ "$output" == *"origincert:"* ]]
}

@test "unknown command and help" {
  run "$CFA" frobnicate
  [ "$status" -eq 2 ]
  run "$CFA" help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Selection order"* ]]
  run "$CFA" --version
  [[ "$output" == "cfa "* ]]
}
