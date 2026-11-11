<div align="center">

# cfa

**Use several Cloudflare accounts with `wrangler` and `cloudflared` — per project, per shell, or per command.**

[![CI](https://github.com/eanp/cfa/actions/workflows/ci.yml/badge.svg)](https://github.com/eanp/cfa/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
![Shell: bash 3.2+](https://img.shields.io/badge/bash-3.2%2B-4EAA25)
![Shells: zsh · bash · fish](https://img.shields.io/badge/shells-zsh%20·%20bash%20·%20fish-555)

[English](README.md) · [Bahasa Indonesia](README.id.md)

</div>

```console
$ cfa login acme wrangler       # browser login with acme's Cloudflare user
$ cfa login globex wrangler     # browser login with another user

$ cd ~/clients/acme && cfa pin acme
$ npx wrangler deploy           # → acme's account
$ cd ~/clients/globex && cfa pin globex
$ npx wrangler deploy           # → globex's account

$ cfa exec acme -- npm run deploy
```

## Why

`wrangler login` keeps **one** OAuth session (and `cloudflared tunnel login` one
certificate) per machine. If you work for several clients or vendors — each with its own
Cloudflare account and login email — you end up running `wrangler logout` / `wrangler
login` all day, or deploying to the wrong account.

`cfa` keeps one login per account and selects the right one automatically:

- **per directory** — a `.cfa-account` file pins a project to an account
- **per shell** — `cfa use globex` affects only the current terminal
- **per command** — `cfa exec acme -- npm run deploy`
- **machine-wide** — `cfa default acme`, also used by your IDE, cron, etc.

It handles three kinds of credentials, all of which can live under one account name:

| Kind | Created with | Used by |
|------|--------------|---------|
| `wrangler` | `cfa login <name> wrangler` (OAuth in the browser) | wrangler |
| `token` | `cfa login <name> token` (paste a Cloudflare API token) | wrangler, CI, scripts |
| `cloudflared` | `cfa login <name> cloudflared` (tunnel cert) | cloudflared |

Single Bash script, no dependencies, plain `wrangler` / `cloudflared` keep working.

## Install

**Homebrew** (macOS / Linux)

```sh
brew install eanp/tap/cfa
```

**Script** (installs to `~/.local/bin`)

```sh
curl -fsSL https://raw.githubusercontent.com/eanp/cfa/main/install.sh | bash
```

**From source**

```sh
git clone https://github.com/eanp/cfa && cd cfa && make install PREFIX=~/.local
```

Then enable the shell integration (needed for `cfa use`, directory pins and prompts):

```sh
# ~/.zshrc
eval "$(cfa init zsh)"
# ~/.bashrc
eval "$(cfa init bash)"
# ~/.config/fish/config.fish
cfa init fish | source
```

Requires `bash` ≥ 3.2 (the macOS default works). `wrangler` and/or
[`cloudflared`](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/)
are only needed to log in. Run `cfa doctor` to check your setup.

## Quick start

```sh
# Already logged in to wrangler? Adopt that login instead of logging in again.
cfa import acme wrangler

# Add the other account (opens the browser — sign in with the *other* email).
cfa login globex wrangler

# Pin projects.
cd ~/clients/acme   && cfa pin acme
cd ~/clients/globex && cfa pin globex

cfa list
#   NAME               ACCOUNT ID                        CREDENTIALS                DEFAULT
#   acme               3f1c0e9d…                         wrangler                   yes
# * globex             7b40aa21…                         wrangler
```

## Choosing OAuth or an API token

| | `wrangler` (OAuth) | `token` (API token) |
|---|---|---|
| Setup | browser login | create a token in the dashboard ([template "Edit Cloudflare Workers"](https://dash.cloudflare.com/profile/api-tokens)) |
| `wrangler …` typed in your shell | ✓ | ✓ |
| `npm run deploy`, `npx wrangler`, `pnpm wrangler` in a pinned dir | ✓ for the **default** account; for others use `cfa exec` (see below) | ✓ everywhere |
| CI / scripts | `cfa exec` | ✓ |
| Expires | refreshed automatically | when you decide |

**Why the difference?** wrangler can only be pointed at another OAuth login through
`XDG_CONFIG_HOME`, which can't be changed for a whole shell without affecting other
tools. So the hook adds a small `wrangler` shell function that sets it just for wrangler,
and `cfa exec` sets it for one command tree. Tools that launch their *own* wrangler
(`npm run`, `npx`) bypass the shell function — for those, cfa still exports
`CLOUDFLARE_ACCOUNT_ID`, so wrangler **fails instead of deploying to the wrong account**.

> **Tip:** if you mostly deploy through `npm run …`, give the non-default accounts an
> API token: `cfa login globex token`. One name can hold both.

## Usage

| Command | What it does |
|---------|--------------|
| `cfa login <name> <wrangler\|token\|cloudflared>` | Log in and save under `<name>`. `--account-id` when a login can see several accounts. Existing global logins are never overwritten. |
| `cfa import <name> [wrangler\|cloudflared] [path]` | Adopt your existing global wrangler login or `cert.pem`. |
| `cfa logout <name> [wrangler\|token\|cloudflared]` | Revoke/remove credentials (the wrangler OAuth token is revoked server-side). |
| `cfa list [--json]` | List accounts; `*` marks the one selected here. |
| `cfa use <name\|none\|--clear>` | Select an account for **this shell only**. |
| `cfa pin [<name>]` / `cfa unpin` | Write/remove `.cfa-account` in the current directory. |
| `cfa default [<name>\|--unset]` | Machine-wide default: your global wrangler login and `~/.cloudflared/cert.pem` become links to it. |
| `cfa exec [<name>] -- <cmd>` | Run one command (and everything it starts) with an account. |
| `cfa each -- <cmd>` | Run a command once per account, e.g. `cfa each -- wrangler whoami`. |
| `cfa current [--name]` | Which account is selected, and why. |
| `cfa whoami [<name>]` | Account ID and stored credentials. Never prints secrets. |
| `cfa account-id <name> [<id>]` | Show or set the Cloudflare account ID. |
| `cfa rename <old> <new>` · `cfa remove <name>` | Manage accounts. |
| `cfa map node <major> <name>` | Optional: pick an account by active nvm Node version. |
| `cfa doctor` | Check permissions, defaults, hook and conflicting settings. |
| `cfa init <shell>` · `cfa completion <shell>` | Shell integration / completions only. |

### Which account wins?

```
cfa exec <name>   >   cfa use <name>   >   .cfa-account   >   cfa map node   >   cfa default
 (one command)        (this shell)        (nearest dir)       (nvm version)       (machine)
```

Credentials you set yourself — `CLOUDFLARE_API_TOKEN` / `CLOUDFLARE_ACCOUNT_ID` from
direnv or CI, or `TUNNEL_ORIGIN_CERT` — always win over cfa.

cfa fails closed: if a pin names an account that doesn't exist, or an account has no
wrangler login, the tools get an account ID / cert path that can't work, never another
account's credentials.

### What the hook exports

| Variable | When |
|----------|------|
| `CLOUDFLARE_ACCOUNT_ID` | always, for the selected account |
| `CLOUDFLARE_API_TOKEN` | if the account has a `token` (it takes precedence over OAuth) |
| `TUNNEL_ORIGIN_CERT` | always (`cloudflared` errors if the account has no cert) |
| `_CFA_NAME` | the selected name, for your prompt |

Show it in your prompt:

```zsh
RPROMPT='${_CFA_NAME:+☁ $_CFA_NAME}'      # zsh (needs: setopt prompt_subst)
```

```sh
PS1='${_CFA_NAME:+[☁ $_CFA_NAME] }'"$PS1"  # bash
```

Don't want the `wrangler` shell function? Set `CFA_NO_WRANGLER_WRAPPER=1` before `cfa init`.

### Tunnels (`cloudflared`)

`cfa login <name> cloudflared` stores the tunnel cert under the account. Because the hook
points `TUNNEL_ORIGIN_CERT` at it, `cloudflared tunnel create` writes the tunnel's
credentials JSON into the same account directory. For tunnels run by launchd/systemd,
reference the files explicitly in that tunnel's `config.yml`
(`origincert: /Users/you/.config/cfa/acme/cert.pem` — see `cfa path acme`), or use
[token-based tunnels](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/get-started/create-remote-tunnel/).

## How it works

```
~/.config/cfa/                                (0700)
├── default                                   name of the default account
├── acme/
│   ├── account_id
│   ├── xdg/.wrangler/config/default.toml     wrangler OAuth login (0600)
│   ├── token                                 API token (0600, optional)
│   └── cert.pem                              cloudflared cert (0600, optional)
└── globex/
    └── …

~/Library/Preferences/.wrangler/config/default.toml ──▶ acme/xdg/…   (cfa default)
~/.cloudflared/cert.pem                              ──▶ acme/cert.pem
```

(On Linux wrangler's global login is `~/.config/.wrangler/config/default.toml`.)

- `cfa login <name> wrangler` runs `wrangler login` with `XDG_CONFIG_HOME` pointed at a
  scratch directory, so your current login is untouched, then files it under the account.
  The account ID is read from `wrangler whoami`.
- wrangler refreshes OAuth tokens by rewriting its config file; it follows symlinks, so the
  refreshed token lands in the account's own file.
- The shell hook re-resolves the account before every prompt (and on `cd` in zsh/fish)
  without spawning processes — about half a millisecond.

## FAQ

<details>
<summary><b>My two accounts use the same login email.</b></summary>

Then you don't need a switcher for wrangler: one login can reach both accounts. Set
`account_id` in each project's `wrangler.toml`/`wrangler.jsonc`. cfa is for accounts
behind **different** logins.
</details>

<details>
<summary><b>Why not tie the account to the Node version (nvm)?</b></summary>

wrangler's login lives outside the Node installation, so every Node version shares it, and
cloudflared has nothing to do with Node. Directory pins fit better. If you still want it:
`cfa map node 22 acme` (pins and `cfa use` still take precedence).
</details>

<details>
<summary><b>I have a <code>~/.wrangler</code> directory.</b></summary>

That's wrangler's legacy location; while it exists wrangler ignores `XDG_CONFIG_HOME`, so
per-account OAuth can't work. Run `cfa import <name> wrangler`, then remove `~/.wrangler`.
`cfa doctor` reports this.
</details>

<details>
<summary><b>Should I commit <code>.cfa-account</code>?</b></summary>

Only if everyone on the project uses the same account names. Otherwise add it to
`.gitignore`. It holds just a name; a hostile repo can at most select one of *your*
existing accounts, and `cfa current` always shows where the selection came from.
</details>

<details>
<summary><b>Windows?</b></summary>

Use WSL. Native PowerShell isn't supported.
</details>

<details>
<summary><b>How do I uninstall?</b></summary>

Run `cfa default --unset` (removes the global links), remove the `cfa init` line from your
shell rc, then `rm "$(command -v cfa)"`. Your logins stay in `~/.config/cfa/` — copy one
back to wrangler's config path if you want it as your plain login again.
</details>

## Security

Credentials are stored `0600` in a `0700` directory and are never printed. An account's API
token is exported to your shell's environment while that account is selected (the same
as direnv or CI would). cfa makes no network calls itself; `login`/`logout` run wrangler or
cloudflared. See [SECURITY.md](SECURITY.md) to report a vulnerability.

## Contributing

Bug reports, ideas and PRs are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md).
Tests use fake `wrangler` and `cloudflared` binaries, so you don't need a Cloudflare account.

## License

[MIT](LICENSE). Not affiliated with Cloudflare, Inc.
