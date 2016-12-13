with (with builtins; {
  inherit toFile readFile concatStringsSep unsafeDiscardStringContext
    listToAttrs match head tail toJSON toPath elemAt getAttr length
    trace genList isString;
  foldl = foldl'; #'
  tracing = x: trace x x;
});
let
  pkgs = import <nixpkgs> {}; 

  mkBuilder = script: toFile "builder.sh" ("source $stdenv/setup\n" + script);

  scripts = concatStringsSep " " [
    "configure" "drivers/convert_protofile" "scripts/gen-version.sh"
    "mk/support/pkg/pkg.sh" "test/run" "external/v8_*/build/gyp/gyp"
  ];
  patchScripts = ''
    for script in ${scripts}; do
      cp $script $script.orig
      patchShebangs $script
    done
  '';
  unpatchScripts = dest: ''
    for script in ${scripts}; do
      test ! -e $script.orig || cp $script.orig ${dest}/$script
    done
  '';
  make = "make -j $NIX_BUILD_CORES -l $NIX_BUILD_CORES";

  skip_tests = [
    # known failures (TODO: fix upstream)
    # "unit.RDBBtree"
    "unit.UtilsTest"
    "unit.RDBProtocol"
    "unit.RDBBtree"
    # Slow tests
    "unit.DiskBackedQueue"
  ];
  skip_tests_filter =
      concatStringsSep " " (map (t: "'!" + t + "'") skip_tests);

  versionFile = pkgs.stdenv.mkDerivation {
    name = "rethinkdb-version";
    src = <rethinkdb>;
    buildInputs = [ pkgs.git ];
    builder = mkBuilder ''
      cd $src
      echo -n $(bash scripts/gen-version.sh) > $out
    '';
  };

  replace = pattern: replacement: string:
    let group = match "(.*)(${pattern})(.*)" string;
    in if group == null then string else
      replace pattern replacement (elemAt group 0)
      + (if isString replacement then replacement
         else replacement (genList (i: elemAt group (i + 2)) (length group - 3)))
      + elemAt group (length group - 1);

  depInfo = dep: let
    source = readFile (toPath "${<rethinkdb>}/mk/support/pkg/${dep}.sh");
    find = var: let go = source: val:
      let group = match "(.*?)\n *${var}=([^\n]*)\n.*" source;
      in if group == null then val else go (head group) (elemAt group 1);
    in go source null;
  in rec {
    version = replace "/-patched.*/" "" (find "version");
    url = replace "\\$\\{?version([^}]*})?" version (find "src_url");
    sha1 = find "src_url_sha1";
  };

  mkFetch = fetch_list: pkgs.stdenv.mkDerivation (rec {
    name = "rethinkdb-dependencies-src";
    builder = mkBuilder ("mkdir $out\n" +
      concatStringsSep "\n"
        (map (dep: "cp -rv --no-preserve=all ${"$"}${dep}/* $out/") fetch_list));
    buildInputs = [ <rethinkdb> ];
  } // listToAttrs (map (dep: let info = depInfo dep; in {
    name = dep;
    value = pkgs.stdenv.mkDerivation {
      name = "rethinkdb-fetch-${dep}-${info.version}";
      src = pkgs.fetchurl {
        url = info.url;
        sha1 = info.sha1;
      };
      builder = mkBuilder ''
        mkdir -p $out/external/.cache
        ln -s $src $out/external/.cache/''${src#*-}
      '';
    };
  }) fetch_list));

  fetchList = ["v8" "jemalloc"];

in rec {

  #test = pkgs.stdenv.mkDerivation {
  #  name = "test";
  #  builder = toFile "builder.sh" ". $stdenv/setup; cat <<__end\n${toJSON (depInfo "v8")}\n__end";
  #};

  fetchDependencies = mkFetch fetchList;

  sourcePrep = pkgs.stdenv.mkDerivation rec {
    name = "rethinkdb-${version}";
    version = unsafeDiscardStringContext (readFile versionFile);
    builder = mkBuilder ''
      # TODO: https://github.com/NixOS/nixpkgs/issues/13744
      export SSL_CERT_FILE=$cacert/etc/ssl/certs/ca-bundle.crt
      cp -r $src rethinkdb
      chmod -R u+w rethinkdb
      cd rethinkdb
      echo "${version}" > VERSION.OVERRIDE
      cp -rv --no-preserve=all $fetchDependencies/* .
      ${patchScripts}
      ./configure --fetch jemalloc
      ${make} dist-dir DIST_DIR=$out
      ${unpatchScripts "$out"}
    '';
    __noChroot = true;
    src = <rethinkdb>;
    inherit fetchDependencies;
    buildInputs = with pkgs; [
      protobuf
      python
      nodejs
      nodePackages.coffee-script
      nodePackages.browserify
      zlib
      openssl
      curl
      boost
      git
      cacert
      nix
    ];
  };

  fastTests = pkgs.stdenv.mkDerivation rec {
    name = "rethinkdb-fast-tests-results-${src.version}";
    src = sourcePrep;
    buildInputs = with pkgs; [
      protobuf
      python27Full
      nodejs
      nodePackages.coffee-script
      nodePackages.browserify
      zlib
      openssl
      boost
      curl
    ];
    builder = mkBuilder ''
      cp -rv --no-preserve=all $src/* .
      ./configure
      ${make} DEBUG=1
      test/run -j $NIX_BUILD_CORES '!long' ${skip_tests_filter} || :
      test -e test/results/*/test_results.html
      cp test/results/* $out
      echo report test_results $out/*/test_results.html > $out/nix-support/hydra-build-products
    '';
  };
}
