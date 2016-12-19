rec {
  inherit (builtins)
    toFile readFile concatStringsSep unsafeDiscardStringContext
    listToAttrs match head tail toJSON toPath elemAt getAttr length
    trace genList isString fromJSON getEnv concatLists toString
    isAttrs hasAttr attrNames;
  foldl = builtins.foldl'; #'
  tracing = x: trace x x;
  for = xs: f: map f xs;
  pkgs = import <nixpkgs> {};

  replace = pattern: replacement: string:
    let group = match "(.*)(${pattern})(.*)" string;
    in if group == null then string else
      replace pattern replacement (elemAt group 0)
      + (if isString replacement then replacement
         else replacement (genList (i: elemAt group (i + 2)) (length group - 3)))
      + elemAt group (length group - 1);

  split = string:
    if string == "" then [] else
    let group = tracing (match "([^ ]*) +(.*)" string);
    in if group == null then [string]
    else [(head group)] ++ split (elemAt group 1);

  make = "make -j $NIX_BUILD_CORES";

  mkStdBuilder = script: toFile "builder.sh" ("source $stdenv/setup\n" + script);

  reCC = pkgs.ccacheWrapper.override {
    extraConfig = ''
      export CCACHE_COMPRESS=1
      export CCACHE_DIR=/home/nix/ccache # chown root:build, chmod 770
      export CCACHE_UMASK=007
      export CCACHE_COMPILERCHECK=none
      export CCACHE_MAXSIZE=100G 
    '';
  };

  mkSimpleDerivation = {
    name,
    buildCommand,
    system ? builtins.currentSystem,
    env ? {},
    buildInputs ? [],
    useDefaultBuildInputs ? true
  }: derivation (env // {
    inherit system name;
    builder = "${pkgs.bash}/bin/bash";
    buildInputs =  buildInputs ++ (if useDefaultBuildInputs
      then with pkgs; [coreutils findutils gnugrep gnused bash patchShebangs gnumake gnutar bzip2 binutils gawk]
      else []);
    args = [ (toFile "builder.sh" (unsafeDiscardStringContext ''
      set -eu
      for pkg in $buildInputs; do
        test ! -d $pkg/bin || export PATH="$pkg/bin:$PATH"
        test ! -d $pkg/lib || export LIBRARY_PATH="$pkg/lib:''${LIBRARY_PATH:-}"
        test ! -d $pkg/include || export C_INCLUDE_PATH="$pkg/include:''${C_INCLUDE_PATH:-}"
        test ! -d $pkg/include || export CPLUS_INCLUDE_PATH="$pkg/include:''${CPLUS_INCLUDE_PATH:-}"
      done
      test ! -v LIBRARY_PATH || export LIBRARY_PATH=''${LIBRARY_PATH%:}
      test ! -v INCLUDE_PATH || export C_INCLUDE_PATH=''${C_INCLUDE_PATH%:}
      test ! -v INCLUDE_PATH || export CPLUS_INCLUDE_PATH=''${CPLUS_INCLUDE_PATH%:}
      ${buildCommand}
    '')) ];
  });

  patchShebangs = mkSimpleDerivation {
    useDefaultBuildInputs = false;
    buildInputs = with pkgs; [coreutils findutils gnugrep gnused bash];
    name = "patch-shebangs";
    buildCommand = ''
      mkdir -p $out/bin
      cat > $out/bin/patchShebangs << EOF
      #!$bash/bin/bash
      echo "ARGS: \$*"
      set -e
      header() { echo "\$@"; }
      stopNest() { :; }
      PATH="$findutils/bin:\$PATH"
      . $patchShebangs
      fixupOutputHooks= 
      patchShebangs "\$@"
      EOF
      chmod +x $out/bin/patchShebangs
    '';
    env = {
      patchShebangs = <nixpkgs/pkgs/build-support/setup-hooks/patch-shebangs.sh>;
      bash = pkgs.bash;
      findutils = pkgs.findutils;
    };
  };
}
