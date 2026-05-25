# typed: false
# frozen_string_literal: true

class Adshield < Formula
  desc "System-level ad blocker CLI tool"
  homepage "https://github.com/USER/adshield"
  url "https://github.com/USER/adshield/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "UPDATE_WITH_REAL_SHA256_AFTER_RELEASE"
  license "MIT"
  head "https://github.com/USER/adshield.git", branch: "main"

  depends_on "python@3"

  def install
    bin.install "adshield"
    (share/"adshield").install "sources.json"
  end

  def caveats
    <<~EOS
      AdShield modifies your system hosts file and must be run with sudo:

        sudo adshield activate     # Enable ad blocking
        sudo adshield deactivate   # Disable ad blocking
        sudo adshield update       # Update blocklists

      Your configuration is stored in:
        ~/.adshield/

      Default blocklist sources are installed to:
        #{share}/adshield/sources.json

      To set up automatic weekly updates, run the installer:
        sudo bash "$(brew --prefix)/share/adshield/install.sh"
    EOS
  end

  test do
    assert_match(/\d+\.\d+\.\d+/, shell_output("#{bin}/adshield --version"))
  end
end
