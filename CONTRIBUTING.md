# Contributing to cfa

Thanks for helping! Issues and pull requests are welcome in English or Bahasa Indonesia.

## Development setup

You need `bash`, [`bats-core`](https://github.com/bats-core/bats-core) and
[`shellcheck`](https://www.shellcheck.net/). `zsh` and `fish` are optional but let the
shell-hook tests run. You do **not** need wrangler, cloudflared or a Cloudflare account —
tests use fake `wrangler` and `cloudflared` binaries in `test/fixtures/bin/` that mimic
the real config paths and outputs.

```sh
# macOS
brew install bats-core shellcheck fish
# Debian/Ubuntu
sudo apt-get install bats shellcheck zsh fish

make check        # shellcheck + bats
make test         # bats only
bats test/resolve.bats -f 'pin'   # a subset
```

Run the CLI from your checkout with `./bin/cfa`. To try your changes in a real shell
without touching your accounts:

```sh
export HOME=$(mktemp -d) CFA_WRANGLER=$PWD/test/fixtures/bin/wrangler \
       CFA_CLOUDFLARED=$PWD/test/fixtures/bin/cloudflared
eval "$(./bin/cfa init zsh)"
FAKE_WR_ACCOUNTS=0123456789abcdef0123456789abcdef cfa login demo wrangler
```

## Layout

```
bin/cfa                 the whole tool (single file, bash 3.2+)
test/*.bats             tests; test_helper.bash isolates HOME per test
test/fixtures/          fake wrangler + cloudflared, cert generator
install.sh              curl | bash installer
packaging/homebrew/     formula template for the tap
```

`bin/cfa` contains code blocks (`CFA_SH_CORE`, `CFA_SH_HOOK`, `CFA_SH_WRANGLER`) that are
executed by cfa itself and/or printed by `cfa init` into the user's zsh/bash. Code in those blocks
must run in both shells: no arrays, no `[[ ]]`, no bash-only expansions. The fish hook is a
separate port in `init_fish` — keep the two behaviourally identical (the tests in
`test/shell.bats` check both).

## Rules of thumb

- Keep it a single dependency-free script that runs on macOS's `/bin/bash` 3.2.
- Never print secrets (API tokens, OAuth tokens, the token inside `cert.pem`); only IDs.
- When wrangler/cloudflared behaviour matters, check their source and mirror it in the
  fakes under `test/fixtures/bin/`, citing the version you checked.
- Fail closed: if the selected account is missing, cloudflared must fail rather than use
  another account.
- Add or update a test for every behaviour change. Update both `README.md` and
  `README.id.md` when user-facing behaviour changes, and add a line to `CHANGELOG.md`.
- Commit messages: short imperative subject (`Add cfa each`), body explains why.

## Releasing (maintainers)

1. Bump `CFA_VERSION` in `bin/cfa`, move `Unreleased` in `CHANGELOG.md` under the new version.
2. `git tag vX.Y.Z && git push --tags` — the release workflow checks the version, runs the
   tests and publishes a GitHub release.
3. Update `url` and `sha256` in the tap's formula (template: `packaging/homebrew/cfa.rb`).
