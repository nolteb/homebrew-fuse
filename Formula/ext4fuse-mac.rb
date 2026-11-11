class Ext4fuseMac < Formula
  desc "Read-only ext4 FUSE driver for macOS, built against macFUSE's libfuse"
  homepage "https://github.com/gerard/ext4fuse"
  url "https://github.com/gerard/ext4fuse/archive/refs/tags/v0.1.3.tar.gz"
  sha256 "550f1e152c4de7d4ea517ee1c708f57bfebb0856281c508511419db45aa3ca9f"
  license "GPL-2.0-only"

  # homebrew-core's ext4fuse is Linux-only ("on macOS, requires closed-source
  # macFUSE"). macFUSE ships the libfuse 2.x userspace in /usr/local, which is
  # what this formula compiles against.
  depends_on "pkgconf" => :build
  depends_on :macos

  # Fix a 2010 argument-parsing bug: e4f_opt_proc stripped every
  # -o option before fuse_main, so options like allow_other never
  # reached the macFUSE mount helper (mounts were root-only).
  # Patch submitted upstream in spirit; upstream is unmaintained.
  patch :DATA

  def install
    pc = Pathname("/usr/local/lib/pkgconfig/fuse.pc")
    dylib = Pathname("/usr/local/lib/libfuse.2.dylib")
    if !pc.exist? || !dylib.exist?
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

__END__
--- a/fuse-main.c
+++ b/fuse-main.c
@@ -46,9 +46,17 @@
 
 static struct e4f {
     char *disk;
+    char *mountpoint;
     char *logfile;
 } e4f;
 
+/* Options forwarded to fuse_main (e.g. "-o", "allow_other"). The stock
+ * parser stripped every option, so macFUSE's mount helper never saw
+ * allow_other and the mount was root-only. */
+#define E4F_MAX_OPTS 64
+static char *e4f_opt_args[E4F_MAX_OPTS];
+static int e4f_opt_count = 0;
+
 static struct fuse_opt e4f_opts[] = {
     { "logfile=%s", offsetof(struct e4f, logfile), 0 },
     FUSE_OPT_END
@@ -62,13 +70,17 @@
 
     switch (key) {
     case FUSE_OPT_KEY_OPT:
-        return 1;
+        if (e4f_opt_count < E4F_MAX_OPTS) {
+            e4f_opt_args[e4f_opt_count++] = strdup(arg);
+        }
+        return 1; /* consumed here; forwarded manually below */
     case FUSE_OPT_KEY_NONOPT:
         if (!e4f.disk) {
             e4f.disk = strdup(arg);
-            return 0;
+        } else if (!e4f.mountpoint) {
+            e4f.mountpoint = strdup(arg);
         }
-        return 1;
+        return 1; /* consumed here */
     default:
         fprintf(stderr, "internal error\n");
         abort();
@@ -87,7 +99,6 @@
     DEBUG("Segmentation Fault.  Starting backtrace:");
     size = backtrace(array, 10);
     strings = backtrace_symbols(array, size);
-
     for (i = 0; i < size; i++)
         DEBUG("%s", strings[i]);
     DEBUG("========================================");
@@ -98,7 +109,10 @@
 int main(int argc, char *argv[])
 {
     int res;
+    int i;
     struct fuse_args args = FUSE_ARGS_INIT(argc, argv);
+    char *fuse_argv[E4F_MAX_OPTS + 2];
+    int fuse_argc = 0;
 
     if (signal(SIGSEGV, signal_handle_sigsegv) == SIG_ERR) {
         fprintf(stderr, "Failed to initialize signals\n");
@@ -107,15 +121,16 @@
 
     // Default options
     e4f.disk = NULL;
+    e4f.mountpoint = NULL;
     e4f.logfile = DEFAULT_LOG_FILE;
 
     if (fuse_opt_parse(&args, &e4f, e4f_opts, e4f_opt_proc) == -1) {
         return EXIT_FAILURE;
     }
 
-    if (!e4f.disk) {
+    if (!e4f.disk || !e4f.mountpoint) {
         fprintf(stderr, "Version: %s\n", EXT4FUSE_VERSION);
-        fprintf(stderr, "Usage: %s <disk> <mountpoint>\n", argv[0]);
+        fprintf(stderr, "Usage: %s <disk> <mountpoint> [fuse options]\n", argv[0]);
         exit(1);
     }
 
@@ -133,7 +148,7 @@
     off_t disk_magic_offset = BOOT_SECTOR_SIZE + offsetof(struct ext4_super_block, s_magic);
     uint16_t disk_magic;
     if (disk_read(disk_magic_offset, sizeof(disk_magic), &disk_magic) < 0) {
-        fprintf(stderr, "Failed to read disk: %s\n",  e4f.disk);
+        fprintf(stderr, "Failed to read disk: %s\n", e4f.disk);
         return EXIT_FAILURE;
     }
 
@@ -142,10 +157,22 @@
         return EXIT_FAILURE;
     }
 
-    res = fuse_main(args.argc, args.argv, &e4f_ops, NULL);
+    /* Standard libfuse invocation: [prog, mountpoint, forwarded options].
+     * The mountpoint is the single positional arg; options like
+     * "-o allow_other" reach the macFUSE mount helper intact. */
+    fuse_argv[fuse_argc++] = argv[0];
+    fuse_argv[fuse_argc++] = e4f.mountpoint;
+    for (i = 0; i < e4f_opt_count; i++) {
+        fuse_argv[fuse_argc++] = e4f_opt_args[i];
+    }
 
+    res = fuse_main(fuse_argc, fuse_argv, &e4f_ops, NULL);
+
     fuse_opt_free_args(&args);
     free(e4f.disk);
+    free(e4f.mountpoint);
+    for (i = 0; i < e4f_opt_count; i++)
+        free(e4f_opt_args[i]);
 
     return res;
-}   
+}
