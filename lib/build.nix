with (import ./prelude.nix);
with { inherit (import ./source.nix) sourcePrep fetchList fetchDependencies; };
rec {
  buildDeps = buildDepsWith pkgs.gcc builtins.currentSystem;
  buildDepsWith = cc: system: pkgs.stdenv.mkDerivation (rec {
    name = "rethinkdb-deps-build-debug-${cc.name}-${system}";
    inherit system;
    rethinkdb = unsafeDiscardStringContext (toString <rethinkdb>);
    buildInputs = with pkgs; [
      cc
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
    builder = mkStdBuilder ''
      cp -r $rethinkdb/* .
      chmod -R u+w .
      for x in $deps; do
        cp -r ''${!x}/* .
        chmod -R u+w .
      done
      patchShebangs . > /dev/null
      ./configure --fetch jemalloc
      ${make} fetch
      patchShebangs external > /dev/null
      ${make} support
      mkdir -p $out/build/
      cp -r build/external $out/build/
    '';
    deps = fetchList;

    # TODO: should eventually not need this
    __noChroot = true;
  } // listToAttrs (for fetchList (dep:
      { name = dep; value = getAttr dep fetchDependencies; })));

  debugBuild = debugBuildWith pkgs.gcc (tracing builtins.currentSystem);
  debugBuildWith = cc: system: pkgs.stdenv.mkDerivation rec {
    name = "rethinkdb-${src.version}-build-debug-${cc.name}-${system}";
    inherit system;
    src = sourcePrep;
    deps = buildDepsWith pkgs.gcc system;
    buildInputs = with pkgs; [
      cc
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
    builder = mkStdBuilder ''
      cp -r $src/* .
      chmod -R u+w .
      cp -r $deps/* .
      chmod -R u+w .
      patchShebangs .      
      ./configure
      cp -r $deps/* .
      ${make} DEBUG=1 ALLOW_WARNINGS=1 # TODO: disallow warnings
      mkdir -p$out/build/debug
      cp build/debug/rethinkdb{,-unittest} $out/build/debug
    '';
  };

  matrixBuilds =
    listToAttrs (for (with pkgs; [ gcc48 gcc49 gcc5 gcc6 ]) (cc:
      concatLists (for [ "x86_64-linux" "i686-linux" ] (system:
        { name = "debugBuild-${cc.name}-${system}";
          value = debugBuildWith cc system; })))); 
}
