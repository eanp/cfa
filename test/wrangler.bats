#!/usr/bin/env bats
load test_helper

@test "wrangler login: stored per account, ID detected, becomes default" {
  run env FAKE_WR_ACCOUNTS=$A1 CLOUDFLARE_API_TOKEN=ambient "$CFA" login acme wrangler
  [ "$status" -eq 0 ]
  [[ "$output" == *"saved wrangler login for 'acme' ($A1)"* ]] || false
  [ -f "$STORE/acme/xdg/.wrangler/config/default.toml" ]
  [ "$(mode "$STORE/acme/xdg/.wrangler/config/default.toml")" = 600 ]
  [ "$(cat "$STORE/acme/account_id")" = "$A1" ]
  [ "$(cat "$STORE/default")" = acme ]
  # global wrangler login now points at acme
  [ "$(readlink "$WCFG")" = "$STORE/acme/xdg/.wrangler/config/default.toml" ]
  # wrangler ran with a scratch XDG dir and without the ambient token
  [[ "$(cat "$HOME/.fake-wrangler-login-env")" == "$STORE/acme/.xdg-login."*"|<unset>" ]] || false
}

@test "wrangler login never touches an existing global login" {
  mkdir -p "$(dirname "$WCFG")"
  printf 'refresh_token = "MINE"\n' > "$WCFG"
  login_wr acme "$A1"
  [ ! -L "$WCFG" ]
  grep -q MINE "$WCFG"
  run "$CFA" default acme
  [ "$status" -eq 1 ]
  [[ "$output" == *"cfa import <name> wrangler"* ]] || false
}

@test "second wrangler account keeps the first as default" {
  login_wr acme "$A1"
  login_wr globex "$B2"
  [ "$(cat "$STORE/default")" = acme ]
  [ "$(readlink "$WCFG")" = "$STORE/acme/xdg/.wrangler/config/default.toml" ]
  "$CFA" -q default globex
  [ "$(readlink "$WCFG")" = "$STORE/globex/xdg/.wrangler/config/default.toml" ]
}

@test "token refreshes written through the default symlink land in the account" {
  login_wr acme "$A1"
  printf 'refreshed = true\n' >> "$WCFG"
  grep -q refreshed "$STORE/acme/xdg/.wrangler/config/default.toml"
  [ -L "$WCFG" ]
}

@test "failed wrangler login leaves nothing behind" {
  login_wr acme "$A1"
  run env FAKE_WR_FAIL=1 "$CFA" login globex wrangler
  [ "$status" -eq 6 ]
  [ ! -e "$STORE/globex" ]
  [ "$(readlink "$WCFG")" = "$STORE/acme/xdg/.wrangler/config/default.toml" ]
  run env FAKE_WR_FAIL=1 "$CFA" login acme wrangler --force
  [ "$status" -eq 6 ]
  [ -f "$STORE/acme/xdg/.wrangler/config/default.toml" ]
}

@test "wrangler login with several visible accounts needs an explicit ID" {
  run env FAKE_WR_ACCOUNTS="$A1,$B2" "$CFA" login acme wrangler
  [ "$status" -eq 0 ]
  [[ "$output" == *"cfa account-id acme"* ]] || false
  [ ! -f "$STORE/acme/account_id" ]
  run "$CFA" doctor
  [[ "$output" == *"acme: unknown account ID"* ]] || false
  "$CFA" -q account-id acme "$B2"
  [ "$(cat "$STORE/acme/account_id")" = "$B2" ]
  run "$CFA" account-id acme nothex
  [ "$status" -eq 2 ]
  FAKE_WR_ACCOUNTS="$A1,$B2" "$CFA" -q login globex wrangler --account-id "$A1"
  [ "$(cat "$STORE/globex/account_id")" = "$A1" ]
}

@test "wrangler login refuses when legacy ~/.wrangler exists" {
  mkdir -p "$HOME/.wrangler/config"
  run env FAKE_WR_ACCOUNTS=$A1 "$CFA" login acme wrangler
  [ "$status" -eq 1 ]
  [[ "$output" == *"cfa import <name> wrangler"* ]] || false
}

@test "import wrangler adopts the global login and links it back" {
  FAKE_WR_ACCOUNTS=$A1 "$CFA_WRANGLER" login >/dev/null
  [ -f "$WCFG" ] && [ ! -L "$WCFG" ]
  run "$CFA" import acme wrangler
  [ "$status" -eq 0 ]
  [ "$(cat "$STORE/acme/account_id")" = "$A1" ]
  [ "$(readlink "$WCFG")" = "$STORE/acme/xdg/.wrangler/config/default.toml" ]
  run "$CFA" import other wrangler
  [ "$status" -eq 1 ]
  [[ "$output" == *"already managed"* ]] || false
}

@test "token login reads stdin, detects the ID, stores 0600" {
  run sh -c "printf 'tok-ABCDEFGH\n' | FAKE_WR_ACCOUNTS=$C3 '$CFA' login ci token"
  [ "$status" -eq 0 ]
  [ "$(cat "$STORE/ci/token")" = tok-ABCDEFGH ]
  [ "$(mode "$STORE/ci/token")" = 600 ]
  [ "$(cat "$STORE/ci/account_id")" = "$C3" ]
  [[ "$output" != *ABCDEFGH* ]] || false
}

@test "token login: ambiguous ID fails cleanly, --account-id works" {
  run sh -c "printf 'tok-1\n' | FAKE_WR_ACCOUNTS=$A1,$B2 '$CFA' login ci token"
  [ "$status" -eq 1 ]
  [ ! -e "$STORE/ci" ]
  run sh -c "printf 'tok-1\n' | '$CFA' login ci token --account-id $B2"
  [ "$status" -eq 0 ]
  [ "$(cat "$STORE/ci/account_id")" = "$B2" ]
  run sh -c "printf '' | '$CFA' login ci2 token --account-id $B2"
  [ "$status" -eq 2 ]
}

@test "one name refuses credentials from two different Cloudflare accounts" {
  login_wr acme "$A1"
  run env FAKE_CF_ACCOUNT=$B2 "$CFA" login acme cloudflared
  [ "$status" -eq 1 ]
  [[ "$output" == *"is Cloudflare account $A1"* ]] || false
  [ ! -f "$STORE/acme/cert.pem" ]
  FAKE_CF_ACCOUNT=$A1 "$CFA" -q login acme cloudflared
  [ -f "$STORE/acme/cert.pem" ]
  run "$CFA" list --json
  [[ "$output" == *'"credentials":["wrangler","cloudflared"]'* ]] || false
}

@test "exec: OAuth account gets XDG_CONFIG_HOME, token account gets the token" {
  login_wr acme "$A1"
  login_tok ci "$C3"
  run "$CFA" exec acme -- wrangler deploy
  [ "$output" = "token=<unset> account=$A1 xdg=$STORE/acme/xdg" ]
  run "$CFA" exec ci -- wrangler deploy
  [ "$output" = "token=TOKEN-ci-xyz123 account=$C3 xdg=<unset>" ]
}

@test "exec overrides ambient credentials" {
  login_wr acme "$A1"
  CLOUDFLARE_API_TOKEN=ambient CLOUDFLARE_ACCOUNT_ID=$B2 CLOUDFLARE_API_KEY=k run "$CFA" exec acme -- sh -c 'echo "${CLOUDFLARE_API_TOKEN-unset} $CLOUDFLARE_ACCOUNT_ID ${CLOUDFLARE_API_KEY-unset}"'
  [ "$output" = "unset $A1 unset" ]
}

@test "exec for a cloudflared-only account still pins wrangler to that account" {
  login cf "$A1"
  run "$CFA" exec cf -- wrangler deploy
  [ "$output" = "token=<unset> account=$A1 xdg=<unset>" ]
}

@test "each runs per account with the right credentials" {
  login_wr acme "$A1"
  login_tok ci "$C3"
  run "$CFA" each -- wrangler whoami-ish
  [[ "$output" == *"==> acme"*"account=$A1 xdg=$STORE/acme/xdg"*"==> ci"*"token=TOKEN-ci-xyz123 account=$C3"* ]] || false
}

@test "logout wrangler revokes and unlinks the default" {
  login_wr acme "$A1"
  login_tok acme "$A1"
  run "$CFA" logout acme wrangler
  [ "$status" -eq 0 ]
  [[ "$output" == *"revoked"* ]] || false
  [ ! -e "$STORE/acme/xdg" ]
  [ ! -L "$WCFG" ] && [ ! -e "$WCFG" ]
  [ -f "$STORE/acme/token" ]
  run "$CFA" logout acme token
  [[ "$output" == *"has no credentials left"* ]] || false
  [ ! -e "$STORE/acme" ]
  [ ! -f "$STORE/default" ]
}

@test "default for an account without OAuth removes the managed wrangler link" {
  login_wr acme "$A1"
  login cf "$B2"
  "$CFA" -q default cf
  [ ! -e "$WCFG" ] && [ ! -L "$WCFG" ]
  [ "$(readlink "$HOME/.cloudflared/cert.pem")" = "$STORE/cf/cert.pem" ]
  "$CFA" -q default acme
  [ "$(readlink "$WCFG")" = "$STORE/acme/xdg/.wrangler/config/default.toml" ]
  [ ! -e "$HOME/.cloudflared/cert.pem" ]
}

@test "whoami and list show credentials but never secrets" {
  login_wr acme "$A1"
  login_tok acme "$A1"
  run "$CFA" whoami acme
  [[ "$output" == *"OAuth login (access token expires 2030-01-01"* ]] || false
  [[ "$output" == *"+ API token (takes precedence)"* ]] || false
  [[ "$output" != *SECRET* ]] || false
  [[ "$output" != *TOKEN-acme* ]] || false
  run "$CFA" list
  [[ "${lines[1]}" == "* acme"*"$A1"*"wrangler,token"*"yes" ]] || false
  run "$CFA" list --json
  [[ "$output" != *TOKEN-acme* ]] || false
}

@test "doctor flags legacy ~/.wrangler and unmanaged global logins" {
  login_wr acme "$A1"
  "$CFA" -q default --unset
  mkdir -p "$(dirname "$WCFG")"
  printf 'refresh_token = "x"\n' > "$WCFG"
  run "$CFA" doctor
  [[ "$output" == *"not managed by cfa (adopt it: cfa import <name> wrangler)"* ]] || false
  mkdir -p "$HOME/.wrangler"
  run "$CFA" doctor
  [[ "$output" == *".wrangler exists"* ]] || false
}

@test "login without a kind is an error when not interactive" {
  run "$CFA" login acme
  [ "$status" -eq 2 ]
  [[ "$output" == *"wrangler|token|cloudflared"* ]] || false
}

@test "doctor explains when the default isn't active for wrangler" {
  mkdir -p "$(dirname "$WCFG")"
  printf 'refresh_token = "old"\n' > "$WCFG"
  login_wr it "$A1"
  run "$CFA" doctor
  [ "$status" -eq 1 ]
  [[ "$output" == *"default 'it' is not active for wrangler"* ]] || false
  [[ "$output" == *"then: cfa default it"* ]] || false
  # after dropping the old login, setting the default links it
  rm "$WCFG"
  "$CFA" -q default it
  [ "$(readlink "$WCFG")" = "$STORE/it/xdg/.wrangler/config/default.toml" ]
  run "$CFA" doctor
  [[ "$output" != *"not active"* ]] || false
}
