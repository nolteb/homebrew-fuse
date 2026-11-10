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
  depends_on "pkgconf" => :build

  def install
    pc = Pathname("/usr/local/lib/pkgconfig/fuse.pc")
    dylib = Pathname("/usr/local/lib/libfuse.2.dylib")
    unless pc.exist? && dylib.exist?
      raise "macFUSE not found (#{pc} / #{dylib} missing). " \
            "Install it first: brew install --cask macfuse"
    end

    # Brew sandboxes build subprocesses and they cannot read /usr/local, so
    # stage macFUSE's libfuse headers and dylib into the build directory and
    # point pkg-config at the staged copies. The installed binary keeps the
    # dylib's absolute install name (/usr/local/lib/libfuse.2.dylib), which
    # resolves at runtime because macFUSE is a prerequisite.
    staged = Pathname("macfuse")
    (staged/"fuse").mkpath
    (staged/"lib").mkpath
    (staged/"pkgconfig").mkpath
    Dir["/usr/local/include/fuse/*.h"].each do |header|
      cp header, staged/"fuse"/File.basename(header)
    end
    cp dylib, staged/"lib"/"libfuse.2.dylib"
    ln_sf "libfuse.2.dylib", staged/"lib"/"libfuse.dylib"
    (staged/"pkgconfig"/"fuse.pc").write <<~PC
      prefix=#{staged.expand_path}
      Name: fuse
      Description: Filesystem in Userspace (macFUSE, staged)
      Version: #{pc.read[/^Version: (.+)$/, 1].to_s.strip}
      Libs: -L${prefix}/lib -lfuse -pthread
      Cflags: -I${prefix}/fuse -D_FILE_OFFSET_BITS=64
    PC

    ENV["PKG_CONFIG_PATH"] = (staged/"pkgconfig").to_s
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
