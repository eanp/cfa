# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Fixed

- The shell hook falls back to `cfa` on `PATH` when the binary recorded by `cfa init`
  no longer exists (e.g. after switching from `install.sh` to Homebrew in an open shell).

## [0.1.0] - 2026-11-12

### Added

- Fix test assertions on bash 3.2/fish; clearer doctor message
- One store per Cloudflare account holding any of: a **wrangler OAuth login**, a
  **Cloudflare API token**, a **cloudflared tunnel cert**.
- `cfa login <name> <wrangler|token|cloudflared>`, `import`, `logout` (revokes wrangler
  OAuth), `list`, `account-id`, `remove`, `rename`.
- Account selection per command (`exec`), per shell (`use`), per directory (`pin`,
  `.cfa-account`), by nvm Node version (`map node`), and machine-wide (`default`, which
  links wrangler's global login and `~/.cloudflared/cert.pem`).
- Shell hook exports `CLOUDFLARE_ACCOUNT_ID`, `CLOUDFLARE_API_TOKEN` and
  `TUNNEL_ORIGIN_CERT`; a `wrangler` shell function selects the OAuth login. Fails closed
  when the selected account is missing or lacks a login.
- `cfa each` to run a command once per account.
- `current`, `whoami`, `path`, `doctor` for inspection.
- Shell integration for zsh, bash and fish (`cfa init`) with completions.
- Installer script, Makefile, Homebrew formula template.

[Unreleased]: https://github.com/eanp/cfa/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/eanp/cfa/releases/tag/v0.1.0
