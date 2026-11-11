<div align="center">

# cfa

**Pakai beberapa akun Cloudflare dengan `wrangler` dan `cloudflared` — per project, per shell, atau per perintah.**

[![CI](https://github.com/eanp/cfa/actions/workflows/ci.yml/badge.svg)](https://github.com/eanp/cfa/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/eanp/cfa)](https://github.com/eanp/cfa/releases/latest)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
![Shell: bash 3.2+](https://img.shields.io/badge/bash-3.2%2B-4EAA25)
![Shells: zsh · bash · fish](https://img.shields.io/badge/shells-zsh%20·%20bash%20·%20fish-555)

[English](README.md) · [Bahasa Indonesia](README.id.md)

</div>

```console
$ cfa login acme wrangler       # login browser dengan user Cloudflare milik acme
$ cfa login globex wrangler     # login browser dengan user lain

$ cd ~/clients/acme && cfa pin acme
$ npx wrangler deploy           # → akun acme
$ cd ~/clients/globex && cfa pin globex
$ npx wrangler deploy           # → akun globex

$ cfa exec acme -- npm run deploy
```

## Kenapa

`wrangler login` hanya menyimpan **satu** sesi OAuth (dan `cloudflared tunnel login` satu
sertifikat) per mesin. Kalau kamu pegang beberapa klien atau vendor — masing-masing dengan
akun Cloudflare dan email login sendiri — ujung-ujungnya `wrangler logout` / `wrangler login`
terus seharian, atau malah deploy ke akun yang salah.

`cfa` menyimpan satu login per akun dan memilih yang benar secara otomatis:

- **per folder** — file `.cfa-account` mengikat project ke satu akun
- **per shell** — `cfa use globex` hanya berlaku di terminal itu
- **per perintah** — `cfa exec acme -- npm run deploy`
- **seluruh mesin** — `cfa default acme`, juga dipakai IDE, cron, dll.

Ada tiga jenis kredensial, dan ketiganya bisa disimpan di bawah satu nama akun:

| Jenis | Dibuat dengan | Dipakai oleh |
|-------|---------------|--------------|
| `wrangler` | `cfa login <nama> wrangler` (OAuth di browser) | wrangler |
| `token` | `cfa login <nama> token` (tempel API token Cloudflare) | wrangler, CI, script |
| `cloudflared` | `cfa login <nama> cloudflared` (cert tunnel) | cloudflared |

Satu script Bash, tanpa dependency, dan `wrangler` / `cloudflared` biasa tetap jalan.

## Instalasi

**Homebrew** (macOS / Linux)

```sh
brew install eanp/tap/cfa
```

**Script** (dipasang ke `~/.local/bin`)

```sh
curl -fsSL https://raw.githubusercontent.com/eanp/cfa/main/install.sh | bash
```

**Dari source**

```sh
git clone https://github.com/eanp/cfa && cd cfa && make install PREFIX=~/.local
```

Lalu aktifkan integrasi shell (dibutuhkan untuk `cfa use`, pin folder, dan prompt):

```sh
# ~/.zshrc
eval "$(cfa init zsh)"
# ~/.bashrc
eval "$(cfa init bash)"
# ~/.config/fish/config.fish
cfa init fish | source
```

Butuh `bash` ≥ 3.2 (bawaan macOS sudah cukup). `wrangler` dan/atau
[`cloudflared`](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/)
hanya dibutuhkan untuk login. Jalankan `cfa doctor` untuk mengecek setup.

## Mulai cepat

```sh
# Sudah login wrangler? Adopsi login itu, tidak perlu login ulang.
cfa import acme wrangler

# Tambah akun lain (browser terbuka — login dengan email yang *lain*).
cfa login globex wrangler

# Pin project.
cd ~/clients/acme   && cfa pin acme
cd ~/clients/globex && cfa pin globex

cfa list
#   NAME               ACCOUNT ID                        CREDENTIALS                DEFAULT
#   acme               3f1c0e9d…                         wrangler                   yes
# * globex             7b40aa21…                         wrangler
```

## Pilih OAuth atau API token

| | `wrangler` (OAuth) | `token` (API token) |
|---|---|---|
| Setup | login browser | bikin token di dashboard ([template "Edit Cloudflare Workers"](https://dash.cloudflare.com/profile/api-tokens)) |
| `wrangler …` diketik di shell | ✓ | ✓ |
| `npm run deploy`, `npx wrangler`, `pnpm wrangler` di folder yang di-pin | ✓ untuk akun **default**; akun lain pakai `cfa exec` (lihat bawah) | ✓ di mana saja |
| CI / script | `cfa exec` | ✓ |
| Kedaluwarsa | di-refresh otomatis | sesuai yang kamu atur |

**Kenapa beda?** wrangler hanya bisa diarahkan ke login OAuth lain lewat `XDG_CONFIG_HOME`,
dan variabel itu tidak bisa diganti untuk seluruh shell tanpa memengaruhi tool lain. Jadi
hook menambahkan shell function `wrangler` kecil yang men-set-nya khusus untuk wrangler,
dan `cfa exec` men-set-nya untuk satu pohon perintah. Tool yang menjalankan wrangler
*sendiri* (`npm run`, `npx`) melewati shell function itu — untuk kasus ini cfa tetap
meng-export `CLOUDFLARE_ACCOUNT_ID`, sehingga wrangler **gagal, bukan deploy ke akun yang salah**.

> **Tips:** kalau kamu lebih sering deploy lewat `npm run …`, beri akun non-default sebuah
> API token: `cfa login globex token`. Satu nama bisa punya keduanya.

## Pemakaian

| Perintah | Fungsi |
|----------|--------|
| `cfa login <nama> <wrangler\|token\|cloudflared>` | Login dan simpan sebagai `<nama>`. `--account-id` kalau satu login bisa melihat beberapa akun. Login global yang ada tidak pernah ditimpa. |
| `cfa import <nama> [wrangler\|cloudflared] [path]` | Adopsi login wrangler global atau `cert.pem` yang sudah ada. |
| `cfa logout <nama> [wrangler\|token\|cloudflared]` | Cabut/hapus kredensial (token OAuth wrangler di-revoke di server). |
| `cfa list [--json]` | Daftar akun; `*` menandai akun yang terpilih di sini. |
| `cfa use <nama\|none\|--clear>` | Pilih akun **hanya untuk shell ini**. |
| `cfa pin [<nama>]` / `cfa unpin` | Tulis/hapus `.cfa-account` di folder saat ini. |
| `cfa default [<nama>\|--unset]` | Default seluruh mesin: login wrangler global dan `~/.cloudflared/cert.pem` jadi link ke akun ini. |
| `cfa exec [<nama>] -- <cmd>` | Jalankan satu perintah (beserta semua yang dijalankannya) dengan akun tertentu. |
| `cfa each -- <cmd>` | Jalankan perintah sekali per akun, mis. `cfa each -- wrangler whoami`. |
| `cfa current [--name]` | Akun mana yang terpilih, dan kenapa. |
| `cfa whoami [<nama>]` | Account ID dan kredensial yang tersimpan. Tidak pernah menampilkan rahasia. |
| `cfa account-id <nama> [<id>]` | Lihat atau set account ID Cloudflare. |
| `cfa rename <lama> <baru>` · `cfa remove <nama>` | Kelola akun. |
| `cfa map node <mayor> <nama>` | Opsional: pilih akun berdasarkan versi Node nvm yang aktif. |
| `cfa doctor` | Cek permission, default, hook, dan setting yang bentrok. |
| `cfa init <shell>` · `cfa completion <shell>` | Integrasi shell / completion saja. |

### Akun mana yang menang?

```
cfa exec <nama>   >   cfa use <nama>   >   .cfa-account   >   cfa map node   >   cfa default
 (satu perintah)       (shell ini)        (folder terdekat)   (versi nvm)        (mesin)
```

Kredensial yang kamu set sendiri — `CLOUDFLARE_API_TOKEN` / `CLOUDFLARE_ACCOUNT_ID` dari
direnv atau CI, atau `TUNNEL_ORIGIN_CERT` — selalu menang atas cfa.

cfa bersifat fail-closed: kalau pin menyebut akun yang tidak ada, atau akun tidak punya
login wrangler, tool-nya diberi account ID / path cert yang tidak mungkin berhasil — tidak
pernah kredensial akun lain.

### Yang di-export hook

| Variable | Kapan |
|----------|-------|
| `CLOUDFLARE_ACCOUNT_ID` | selalu, untuk akun yang terpilih |
| `CLOUDFLARE_API_TOKEN` | kalau akun punya `token` (lebih diutamakan dari OAuth) |
| `TUNNEL_ORIGIN_CERT` | selalu (`cloudflared` error kalau akun tidak punya cert) |
| `_CFA_NAME` | nama yang terpilih, untuk prompt |

Tampilkan di prompt:

```zsh
RPROMPT='${_CFA_NAME:+☁ $_CFA_NAME}'      # zsh (butuh: setopt prompt_subst)
```

```sh
PS1='${_CFA_NAME:+[☁ $_CFA_NAME] }'"$PS1"  # bash
```

Tidak mau shell function `wrangler`? Set `CFA_NO_WRANGLER_WRAPPER=1` sebelum `cfa init`.

### Tunnel (`cloudflared`)

`cfa login <nama> cloudflared` menyimpan cert tunnel di bawah akun. Karena hook mengarahkan
`TUNNEL_ORIGIN_CERT` ke sana, `cloudflared tunnel create` menulis JSON kredensial tunnel ke
folder akun yang sama. Untuk tunnel yang dijalankan launchd/systemd, rujuk file-nya secara
eksplisit di `config.yml` tunnel itu (`origincert: /Users/kamu/.config/cfa/acme/cert.pem` — lihat `cfa path acme`), atau pakai
[tunnel berbasis token](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/get-started/create-remote-tunnel/).

## Cara kerja

```
~/.config/cfa/                                (0700)
├── default                                   nama akun default
├── acme/
│   ├── account_id
│   ├── xdg/.wrangler/config/default.toml     login OAuth wrangler (0600)
│   ├── token                                 API token (0600, opsional)
│   └── cert.pem                              cert cloudflared (0600, opsional)
└── globex/
    └── …

~/Library/Preferences/.wrangler/config/default.toml ──▶ acme/xdg/…   (cfa default)
~/.cloudflared/cert.pem                              ──▶ acme/cert.pem
```

(Di Linux, login global wrangler ada di `~/.config/.wrangler/config/default.toml`.)

- `cfa login <nama> wrangler` menjalankan `wrangler login` dengan `XDG_CONFIG_HOME` diarahkan
  ke folder sementara, jadi login kamu yang sekarang tidak tersentuh, lalu menyimpannya di
  bawah akun. Account ID dibaca dari `wrangler whoami`.
- wrangler me-refresh token OAuth dengan menulis ulang file config-nya; penulisan itu mengikuti
  symlink, jadi token hasil refresh masuk ke file milik akunnya.
- Hook shell me-resolve ulang akun sebelum setiap prompt (dan saat `cd` di zsh/fish) tanpa
  menjalankan proses apa pun — sekitar setengah milidetik.

## FAQ

<details>
<summary><b>Dua akun saya pakai email login yang sama.</b></summary>

Kalau begitu kamu tidak butuh switcher untuk wrangler: satu login bisa mengakses kedua akun.
Set `account_id` di `wrangler.toml`/`wrangler.jsonc` tiap project. cfa untuk akun yang ada di
balik login yang **berbeda**.
</details>

<details>
<summary><b>Kenapa tidak mengikat akun ke versi Node (nvm)?</b></summary>

Login wrangler disimpan di luar instalasi Node, jadi semua versi Node berbagi login yang sama,
dan cloudflared tidak ada hubungannya dengan Node. Pin per folder lebih cocok. Kalau tetap mau:
`cfa map node 22 acme` (pin dan `cfa use` tetap lebih diutamakan).
</details>

<details>
<summary><b>Saya punya folder <code>~/.wrangler</code>.</b></summary>

Itu lokasi lama wrangler; selama folder itu ada, wrangler mengabaikan `XDG_CONFIG_HOME`,
sehingga OAuth per akun tidak bisa jalan. Jalankan `cfa import <nama> wrangler`, lalu hapus
`~/.wrangler`. `cfa doctor` melaporkan kondisi ini.
</details>

<details>
<summary><b>Perlu commit <code>.cfa-account</code>?</b></summary>

Hanya kalau semua orang di project memakai nama akun yang sama. Kalau tidak, masukkan ke
`.gitignore`. Isinya cuma nama; repo jahat paling jauh hanya bisa memilih salah satu akun
*milikmu* yang sudah ada, dan `cfa current` selalu menunjukkan asal pilihannya.
</details>

<details>
<summary><b>Windows?</b></summary>

Pakai WSL. PowerShell native tidak didukung.
</details>

<details>
<summary><b>Cara uninstall?</b></summary>

Jalankan `cfa default --unset` (menghapus link global), hapus baris `cfa init` dari rc shell,
lalu `rm "$(command -v cfa)"`. Login kamu tetap ada di `~/.config/cfa/` — copy salah satunya
kembali ke path config wrangler kalau mau jadi login biasa lagi.
</details>

## Keamanan

Kredensial disimpan dengan mode `0600` di folder `0700` dan tidak pernah ditampilkan. API
token sebuah akun di-export ke environment shell selama akun itu terpilih (sama seperti
direnv atau CI). cfa sendiri tidak melakukan koneksi jaringan; `login`/`logout` menjalankan
wrangler atau cloudflared. Lihat [SECURITY.md](SECURITY.md) untuk melaporkan celah keamanan.

## Kontribusi

Laporan bug, ide, dan PR sangat diterima — lihat [CONTRIBUTING.md](CONTRIBUTING.md).
Test memakai binary `wrangler` dan `cloudflared` palsu, jadi tidak perlu akun Cloudflare.

## Lisensi

[MIT](LICENSE). Tidak berafiliasi dengan Cloudflare, Inc.
