class Ext4fuseMac < Formula
  desc "Read-only ext4 FUSE driver for macOS, built against macFUSE's libfuse"
  homepage "https://github.com/gerard/ext4fuse"
  url "https://github.com/gerard/ext4fuse/archive/refs/tags/v0.1.3.tar.gz"
  sha256 "550f1e152c4de7d4ea517ee1c708f57bfebb0856281c508511419db45aa3ca9f"
  license "GPL-2.0-only"

  # homebrew-core's ext4fuse is Linux-only ("on macOS, requires closed-source
  # macFUSE"). macFUSE ships the libfuse 2.x userspace in /usr/local, which is
  # what this formula compiles against.
  depends_on :macos
  # macFUSE is a cask; cask dependencies in formulae are unreliable, so we
  # check for its /usr/local libfuse at build time (see install).
  depends_on "pkgconf" => :build

  def install
    pkgconfig = "/usr/local/lib/pkgconfig/fuse.pc"
    unless File.exist?(pkgconfig)
      raise "macFUSE not found (#{pkgconfig} missing). " \
            "Install it first: brew install --cask macfuse"
    end
    ENV["PKG_CONFIG_PATH"] = "/usr/local/lib/pkgconfig"
    system "make"
    bin.install "ext4fuse"
  end

  test do
    # --version prints "Version: <string>" and exits 1 by design
    assert_match "Version:", shell_output("#{bin}/ext4fuse --version 2>&1", 1)

    # The superblock check must run and reject a non-ext4 image
    (testpath/"mnt").mkpath
    (testpath/"test.img").write "\0" * 4096
    output = shell_output(
      "#{bin}/ext4fuse #{testpath/"test.img"} #{testpath/"mnt"} 2>&1", 1
    )
    assert_match "Partition doesn't contain EXT4 filesystem", output
  end
end
