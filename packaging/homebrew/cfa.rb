# Template for the Homebrew tap (github.com/eanp/homebrew-tap → Formula/cfa.rb).
# On each release, update `url` and `sha256`:
#   curl -fsSL https://github.com/eanp/cfa/archive/refs/tags/vX.Y.Z.tar.gz | shasum -a 256
class Cfa < Formula
  desc "Use several Cloudflare accounts with wrangler and cloudflared"
  homepage "https://github.com/eanp/cfa"
  url "https://github.com/eanp/cfa/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "REPLACE_WITH_SHA256_OF_THE_RELEASE_TARBALL"
  license "MIT"
  head "https://github.com/eanp/cfa.git", branch: "main"

  def install
    bin.install "bin/cfa"
    generate_completions_from_executable(bin/"cfa", "completion")
  end

  def caveats
    <<~EOS
      Enable the shell integration (needed for `cfa use` and directory pins):
        zsh:  echo 'eval "$(cfa init zsh)"' >> ~/.zshrc
        bash: echo 'eval "$(cfa init bash)"' >> ~/.bashrc
        fish: echo 'cfa init fish | source' >> ~/.config/fish/config.fish

      Log in with wrangler (npm i -g wrangler) and/or cloudflared:
        cfa login <name> wrangler
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/cfa --version")
    ENV["HOME"] = testpath
    assert_match "No accounts yet", shell_output("#{bin}/cfa list 2>&1")
    assert_match "Selection order", shell_output("#{bin}/cfa help")
  end
end
