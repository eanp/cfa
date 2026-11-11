# shellcheck shell=bash
# mkcert <file> <accountID> [zoneID] — write a cloudflared-style origin cert.
mkcert() {
  local json b64
  json=$(printf '{"zoneID":"%s","accountID":"%s","apiToken":"SECRET-TOKEN-DO-NOT-PRINT","endpoint":""}' \
    "${3:-zone000000000000000000000000000000}" "$2")
  b64=$(printf '%s' "$json" | base64 | tr -d '\n' | fold -w 64)
  {
    echo '-----BEGIN ARGO TUNNEL TOKEN-----'
    printf '%s\n' "$b64"
    echo '-----END ARGO TUNNEL TOKEN-----'
  } > "$1"
}
