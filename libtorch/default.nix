{ pkgs, ... }:
with pkgs;

let
  mkUrl = build: os: let url = "https://download.pytorch.org/libtorch/"; in
    if os == "linux"
    then "${url}${build}/libtorch-cxx11-abi-shared-with-deps-${libtorch_version}%2B${build}.zip"
    else if os == "macos" && build == "cpu" then "${url}cpu/libtorch-macos-${libtorch_version}.zip"
    else throw "bad build config";

  fetcher = build: os: let
    json =  "libtorch-${build}-${os}";
    name =  "libtorch-${build}-${os}-${libtorch_version}.zip";
    sha256 = lib.strings.removeSuffix "\n" (builtins.readFile (./sha + "/${json}"));
    url = mkUrl build os;
  in pkgs.fetchurl {inherit url sha256; inherit name; };

  libtorch-cpu-macos   = fetcher "cpu"   "macos";
  libtorch-cpu-linux   = fetcher "cpu"   "linux";
  libtorch-cu102-linux = fetcher "cu102" "linux";
  libtorch-cu113-linux = fetcher "cu113" "linux";

  libtorch_version = "1.13.1";
  libcxx-for-libtorch = if stdenv.hostPlatform.system == "x86_64-darwin" then libcxx else stdenv.cc.cc.lib;
  libmklml = opts: callPackage ./mklml.nix ({} // opts);
  callCpu = opts: callPackage ./generic.nix ({libcxx = libcxx-for-libtorch;} // opts);
  callGpu = opts: callPackage ./generic.nix ({libcxx = libcxx-for-libtorch;} // opts);
  matchSys = sys: (pkgs.lib.tail (pkgs.lib.splitString "-" stdenv.hostPlatform.system)) == [sys];
  isDarwin = matchSys "darwin";
  isLinux = matchSys "linux";
in
{
  libmklml = libmklml { useIomp5 = true; inherit lib;};
  libmklml_without_iomp5 = libmklml { useIomp5 = false; inherit lib;};

  libtorch_cpu = callCpu {
    version = libtorch_version;
    buildtype = "cpu";
    mkSrc = buildtype:
      if isLinux then libtorch-cpu-linux
      else if isDarwin then libtorch-cpu-macos
      else throw "missing url for platform ${stdenv.hostPlatform.system}";
  };
} // lib.optionalAttrs (stdenv.hostPlatform.system == "x86_64-linux") {
  libtorch_cudatoolkit_11_3 = callGpu {
    version = "cu113-${libtorch_version}";
    buildtype = "cu113";
    mkSrc = buildtype:
      if stdenv.hostPlatform.system == "x86_64-linux" then libtorch-cu113-linux
      else throw "missing url for platform ${stdenv.hostPlatform.system}";
  };
  libtorch_cudatoolkit_10_2 = callGpu {
    version = "cu102-${libtorch_version}";
    buildtype = "cu102";
    mkSrc = buildtype:
      if stdenv.hostPlatform.system == "x86_64-linux" then libtorch-cu102-linux
      else throw "missing url for platform ${stdenv.hostPlatform.system}";
  };
}
