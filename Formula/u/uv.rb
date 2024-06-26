class Uv < Formula
  desc "Extremely fast Python package installer and resolver, written in Rust"
  homepage "https://github.com/astral-sh/uv"
  url "https://github.com/astral-sh/uv/archive/refs/tags/0.1.38.tar.gz"
  sha256 "4dc144df5ee64c2c02a55d4115af09815ee1ef5d364662694fae7f9f085e94fa"
  license any_of: ["Apache-2.0", "MIT"]
  head "https://github.com/astral-sh/uv.git", branch: "main"

  bottle do
    sha256 cellar: :any,                 arm64_sonoma:   "a4458c848c3626656fa9d8ff25ffc13733e759f57a8703b35a8d65654959c0ee"
    sha256 cellar: :any,                 arm64_ventura:  "33985309235fa216916be43968a3f27dfb79cccc96a5aeec1b972e4b5b2c6031"
    sha256 cellar: :any,                 arm64_monterey: "588fa09a6817b6d3e5a3e14af978162806ab7d39dde76a8c81f1745d114f4371"
    sha256 cellar: :any,                 sonoma:         "139d4d52af9a30fcf7ea12d4301fe92316ed66bcec9c6e6622a1da2d01ba97a4"
    sha256 cellar: :any,                 ventura:        "360fe08efae8cbac4a014d0ec76ba066bbc730bdb45038d906302ed10eca4f91"
    sha256 cellar: :any,                 monterey:       "8f0a31ac0ececba051b02dd9994f3c467104a7d826e971246ae86079fc314abc"
    sha256 cellar: :any_skip_relocation, x86_64_linux:   "c7ee5956cf60d5800519b6fde18f46a8c4850937de622fbb026416be6417694e"
  end

  depends_on "pkg-config" => :build
  depends_on "rust" => :build
  depends_on "libgit2"
  depends_on "openssl@3"

  uses_from_macos "python" => :test

  on_linux do
    # On macOS, bzip2-sys will use the bundled lib as it cannot find the system or brew lib.
    # We only ship bzip2.pc on Linux which bzip2-sys needs to find library.
    depends_on "bzip2"
  end

  def install
    ENV["LIBGIT2_NO_VENDOR"] = "1"

    # Ensure that the `openssl` crate picks up the intended library.
    ENV["OPENSSL_DIR"] = Formula["openssl@3"].opt_prefix
    ENV["OPENSSL_NO_VENDOR"] = "1"

    system "cargo", "install", "--no-default-features", *std_cargo_args(path: "crates/uv")
    generate_completions_from_executable(bin/"uv", "generate-shell-completion")
  end

  def check_binary_linkage(binary, library)
    binary.dynamically_linked_libraries.any? do |dll|
      next false unless dll.start_with?(HOMEBREW_PREFIX.to_s)

      File.realpath(dll) == File.realpath(library)
    end
  end

  test do
    (testpath/"requirements.in").write <<~EOS
      requests
    EOS

    compiled = shell_output("#{bin}/uv pip compile -q requirements.in")
    assert_match "This file was autogenerated by uv", compiled
    assert_match "# via requests", compiled

    [
      Formula["libgit2"].opt_lib/shared_library("libgit2"),
      Formula["openssl@3"].opt_lib/shared_library("libssl"),
      Formula["openssl@3"].opt_lib/shared_library("libcrypto"),
    ].each do |library|
      assert check_binary_linkage(bin/"uv", library),
             "No linkage with #{library.basename}! Cargo is likely using a vendored version."
    end
  end
end
