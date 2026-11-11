# Records assets/demo.gif for the README with https://github.com/charmbracelet/vhs
#   vhs assets/demo.tape
# Uses the fake wrangler from the test suite in a throwaway HOME — no real accounts.
Output assets/demo.gif
Set Shell zsh
Set FontSize 18
Set Width 1100
Set Height 600
Set TypingSpeed 45ms
Set Theme "Catppuccin Mocha"

Hide
Type `export HOME=$(mktemp -d) PATH="$PWD/bin:$PATH" CFA_WRANGLER=$PWD/test/fixtures/bin/wrangler CFA_NONINTERACTIVE=1` Enter
Type `eval "$(cfa init zsh)"; mkdir -p ~/clients/acme ~/clients/globex; PROMPT='%~ ${_CFA_NAME:+☁ $_CFA_NAME }❯ '; setopt prompt_subst; clear` Enter
Show

Type "FAKE_WR_ACCOUNTS=3f1c0e9d5b2a4c6e8f0a1b2c3d4e5f60 cfa login acme wrangler" Enter
Sleep 1.5s
Type "FAKE_WR_ACCOUNTS=7b40aa21c3d4e5f60718293a4b5c6d7e cfa login globex wrangler" Enter
Sleep 1.5s
Type "cd ~/clients/acme && cfa pin acme" Enter
Sleep 1s
Type "cd ~/clients/globex && cfa pin globex" Enter
Sleep 1s
Type "wrangler deploy" Enter
Sleep 1.5s
Type "cd ~/clients/acme && wrangler deploy" Enter
Sleep 1.5s
Type "cfa list" Enter
Sleep 3s
