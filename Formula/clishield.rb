# typed: false
# frozen_string_literal: true

class Adshield < Formula
  desc "System-level ad blocker CLI tool"
  homepage "https://github.com/USER/clishield"
  url "https://github.com/USER/clishield/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "UPDATE_WITH_REAL_SHA256_AFTER_RELEASE"
  license "MIT"
  head "https://github.com/USER/clishield.git", branch: "main"

  depends_on "python@3"

  def install
    bin.install "clishield"
    (share/"clishield").install "sources.json"
  end

  def caveats
    <<~EOS
      CliShield modifies your system hosts file and must be run with sudo:

        sudo clishield activate     # Enable ad blocking
        sudo clishield deactivate   # Disable ad blocking
        sudo clishield update       # Update blocklists

      Your configuration is stored in:
        ~/.clishield/

      Default blocklist sources are installed to:
        #{share}/clishield/sources.json

      To set up automatic weekly updates, run the installer:
        sudo bash "$(brew --prefix)/share/clishield/install.sh"
    EOS
  end

  test do
    assert_match(/\d+\.\d+\.\d+/, shell_output("#{bin}/clishield --version"))
  end
end
