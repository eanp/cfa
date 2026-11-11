#!/usr/bin/env bats
load test_helper

@test "login stores the cert, hardens permissions, becomes default" {
  run env FAKE_CF_ACCOUNT=aaaa1111 "$CFA" login work cloudflared
  [ "$status" -eq 0 ]
  [ -f "$STORE/work/cert.pem" ]
  [ "$(mode "$STORE/work/cert.pem")" = 600 ]
  [ "$(mode "$STORE/work")" = 700 ]
  [ "$(mode "$STORE")" = 700 ]
  [ "$(readlink "$HOME/.cloudflared/cert.pem")" = "$STORE/work/cert.pem" ]
  [ "$(cat "$STORE/work/account_id")" = aaaa1111 ]
  [[ "$output" == *"default account"* ]]
}

@test "second login keeps the first account as default" {
  login work aaaa1111
  login personal bbbb2222
  [ -f "$STORE/personal/cert.pem" ]
  [ "$(readlink "$HOME/.cloudflared/cert.pem")" = "$STORE/work/cert.pem" ]
  ! ls "$HOME/.cloudflared/".cert.pem.cfa-backup.* 2>/dev/null
}

@test "login preserves an unmanaged cert.pem" {
  mkdir -p "$HOME/.cloudflared"
  mkcert "$HOME/.cloudflared/cert.pem" original0
  login work aaaa1111
  [ ! -L "$HOME/.cloudflared/cert.pem" ]
  grep -q 'ARGO TUNNEL TOKEN' "$HOME/.cloudflared/cert.pem"
  run "$CFA" import old
  [ "$status" -eq 0 ]
  [ "$(cat "$STORE/old/account_id")" = original0 ]
}

@test "failed login restores the previous cert and stores nothing" {
  login work aaaa1111
  run env FAKE_CF_FAIL=1 "$CFA" login personal cloudflared
  [ "$status" -eq 6 ]
  [ ! -e "$STORE/personal" ]
  [ "$(readlink "$HOME/.cloudflared/cert.pem")" = "$STORE/work/cert.pem" ]
  [ ! -d "$STORE/.lock" ]
}

@test "login that writes then fails keeps the new cert aside" {
  login work aaaa1111
  run env FAKE_CF_FAIL_AFTER_WRITE=1 FAKE_CF_ACCOUNT=cccc "$CFA" login personal cloudflared
  [ "$status" -eq 6 ]
  [ "$(readlink "$HOME/.cloudflared/cert.pem")" = "$STORE/work/cert.pem" ]
  ls "$HOME/.cloudflared/"cert.pem.cfa-unsaved.*
}

@test "login hides TUNNEL_ORIGIN_CERT from cloudflared" {
  TUNNEL_ORIGIN_CERT=/somewhere/else.pem login work aaaa1111
  [ "$(cat "$HOME/.fake-login-env")" = "<unset>" ]
}

@test "login refuses an existing name, --force replaces and keeps tunnel creds" {
  login work aaaa1111
  echo '{}' > "$STORE/work/1234.json"
  run env FAKE_CF_ACCOUNT=dddd "$CFA" login work cloudflared
  [ "$status" -eq 5 ]
  run env FAKE_CF_ACCOUNT=dddd "$CFA" login work cloudflared --force
  [ "$status" -eq 0 ]
  [ "$(cat "$STORE/work/account_id")" = dddd ]
  [ -f "$STORE/work/1234.json" ]
}

@test "login rejects invalid names" {
  for n in ../x Work default none -x 'a b' "$(printf 'a%.0s' $(seq 1 33))"; do
    run "$CFA" login "$n"
    [ "$status" -eq 2 ]
  done
}

@test "login warns when the same Cloudflare account is added twice" {
  login work aaaa1111
  run env FAKE_CF_ACCOUNT=aaaa1111 "$CFA" login work2 cloudflared
  [ "$status" -eq 0 ]
  [[ "$output" == *"same Cloudflare account as 'work'"* ]]
}

@test "login respects the lock" {
  mkdir -p "$STORE/.lock"
  run env FAKE_CF_ACCOUNT=a "$CFA" login work cloudflared
  [ "$status" -eq 1 ]
  [[ "$output" == *"in progress"* ]]
}

@test "login without cloudflared fails clearly" {
  run env CFA_CLOUDFLARED=/nonexistent "$CFA" login work cloudflared
  [ "$status" -eq 6 ]
}

@test "login passes extra args to cloudflared after --" {
  cat > "$BATS_TEST_TMPDIR/cf" <<EOF
#!/usr/bin/env bash
echo "\$@" > "$HOME/args"
exec "$FIX/bin/cloudflared" "\$@"
EOF
  chmod +x "$BATS_TEST_TMPDIR/cf"
  CFA_CLOUDFLARED="$BATS_TEST_TMPDIR/cf" "$CFA" -q login gov cloudflared -- --fedramp
  [ "$(cat "$HOME/args")" = "tunnel login --fedramp" ]
}
