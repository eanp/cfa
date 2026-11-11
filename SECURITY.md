# Security policy

## Reporting a vulnerability

Please **don't** open a public issue. Use GitHub's private reporting:
**Security → Report a vulnerability** on this repository.

You'll get a reply within 7 days. Please include the cfa version (`cfa --version`), your
OS and shell, and steps to reproduce.

## Scope

cfa stores wrangler OAuth logins, Cloudflare API tokens and `cloudflared` origin
certificates. Things we treat as security bugs:

- a credential being printed, logged, or written with permissions wider than `0600`
- a credential being lost or overwritten during `login` / `import` / `rename` / `remove`
- a `.cfa-account` file (e.g. from a cloned repo) making cfa read or expose a file outside
  the account store, or execute code
- cfa selecting a different account than the one shown by `cfa current`, or silently
  falling back to another account

Out of scope: attackers who can already run code as your user (they can read the store
directly). By design, the selected account's API token is exported into your shell's
environment, so programs you run in that shell can read it.

## Supported versions

Only the latest release receives fixes.
