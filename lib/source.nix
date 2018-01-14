{ lib, rethinkdb }:
with lib;

rec {
  rawSource = rethinkdb;

  rethinkdbBuildInputsCC = cc: with pkgs; let
    protobuf' = protobuf.override { stdenv = overrideCC stdenv cc; }; in [ 
       protobuf' # protobuf'.lib
       python27Full
       zlib zlib.dev
       openssl.dev openssl.out
       boost.dev
       curl curl.out curl.dev
       binutils binutils-unwrapped
    ];
  rethinkdbBuildInputs = rethinkdbBuildInputsCC pkgs.stdenv.cc;

  scripts = concatStringsSep " " [
    "configure" "drivers/convert_protofile" "scripts/gen-version.sh"
    "mk/support/pkg/pkg.sh" "test/run" "external/v8_*/build/gyp/gyp"
  ];
  patchScripts = ''
    for script in ${scripts}; do
      if [[ -e $script ]]; then
        cp $script $script.orig
        patchShebangs $script
      fi
    done
  '';
  unpatchScripts = dest: ''
    for script in ${scripts}; do
      test ! -e $script.orig || cp $script.orig ${dest}/$script
    done
  '';

  versionFile = mkSimpleDerivation {
    name = "rethinkdb-version";
    env.src = rethinkdb;
    buildInputs = [ pkgs.git ];
    buildCommand = ''
      cd $src
      echo -n $(bash scripts/gen-version.sh) > $out
    '';
  };

  depInfo = dep: let
    source = readFile (toPath "${rawSource}/mk/support/pkg/${dep}.sh");
    find = var: let go = source: val:
      let group = match "(.*?)\n *${var}=\"?([^\"\n]*)\"?\n.*" source;
      in if group == null then val else go (head group) (elemAt group 1);
    in go source null;
    rawUrl = find "src_url";
    substVersion = version: groups: replaceStrings [(elemAt groups 0)] [(elemAt groups 1)] version;
  in rec {
    version = replace "/-patched.*/" "" (find "version");
    url = if rawUrl == null then null
      else replace "\\$\\{?version([^}]*})?" version
           (replace "\\$\\{version//([^/]+)/([^}]*)}" (substVersion version) rawUrl);
    sha1 = find "src_url_sha1";
    varName = replace "-" "_" dep;
    name = dep;
  };

  alwaysFetch = "--fetch jemalloc --fetch coffee-script --fetch browserify";
    
  mkFetch = fetch_list: let
    depInfos = map (dep: depInfo dep) fetch_list;
  in mkSimpleDerivation (rec {
    name = "rethinkdb-dependencies-src";
    buildCommand = "set -x\n mkdir $out\n" +
      concatStringsSep "\n"
        (map (info: "cp -r --no-preserve=all ${"$"}${info.varName}/* $out/") depInfos);
    buildInputs = [ rawSource ];
    env = listToAttrs (concatLists (map (info: let
        dep = info.name;
        bothNames = val: [ { name = dep; value = val; } { name = info.varName; value = val; } ];
      in bothNames (if info.url != null
        then mkSimpleDerivation {
          name = "rethinkdb-fetch-${dep}-${info.version}";
          # TODO: doesn't work on hydra?
          # src = pkgs.fetchurl {
          #   url = info.url;
          #   sha1 = info.sha1;
          # };
          buildInputs = [ pkgs.curl pkgs.coreutils ];
          buildCommand = ''
            mkdir -p $out/external/.cache 
            # TODO: ln -s $src $out/external/.cache/''${src#*-}
            src="${info.url}"
            curl -L "$src" > $out/external/.cache/''${src##*/}
            # TODO: check sha1
          '';
          env.__noChroot = true;
        } else mkSimpleDerivation {
          name = "rethinkdb-fetch-${dep}-${info.version}";
          buildCommand = ''
            cp -r $rethinkdb/* .
            chmod -R u+w .
            ./configure --fetch ${dep} ${alwaysFetch}
            make fetch-${dep}
            mkdir -p $out/external
            cp -r external/${dep}_* $out/external/
          '';
          buildInputs = rethinkdbBuildInputs ++ [ reCC pkgs.nodejs ];
          env = {
            __noChroot = true;
            rethinkdb = unsafeDiscardStringContext (toString rawSource);
          }; 
        })
      ) depInfos));
  });

  fetchList = [ "v8" "jemalloc" "admin-deps" "browserify" "coffee-script" "bluebird" ];
  fetchInfos = map (dep: depInfo dep) fetchList;

  fetchDependencies = mkFetch fetchList;

  sourcePrep = mkSimpleDerivation rec {
    name = "rethinkdb-${env.version}";
    buildCommand = ''
      export HOME=$TEMP # needed by gulp dependency v8-flags

      # TODO: https://github.com/NixOS/nixpkgs/issues/13744
      export SSL_CERT_FILE=$cacert/etc/ssl/certs/ca-bundle.crt

      mkdir rethinkdb
      cp -r $src/* rethinkdb/
      chmod -R u+w rethinkdb
      cd rethinkdb

      # TODO: move upstream
      sed -i 's/reset-dist-dir: FORCE | web-assets/reset-dist-dir: FORCE/' mk/packaging.mk
      sed -i 's/install: build/install:/' packaging/debian/rules

      echo "${env.version}" > VERSION.OVERRIDE
      cp -r --no-preserve=all $fetchDependencies/* .
      ${patchScripts}
      ./configure ${alwaysFetch}
      ${make} dist-dir DIST_DIR=$out
      ${unpatchScripts "$out"}
    '';
    env = {
      version = unsafeDiscardStringContext (readFile versionFile);
      __noChroot = true;
      src = rawSource;
      inherit fetchDependencies;
      cacert = pkgs.cacert;
    };
    buildInputs = with pkgs; rethinkdbBuildInputs ++ [ git nix unzip reCC nodejs ];
  };

  sourceTgz = mkSimpleDerivation rec {
    name = "rethinkdb-${env.src.version}-source";
    env.src = sourcePrep;
    buildInputs = [ pkgs.gnutar ];
    buildCommand = ''
      mkdir $out
      cd $src
      tar --transform 's|^.|rethinkdb-${env.src.version}|' --owner rethinkdb --group rethinkdb --mode ug+w -zcf $out/rethinkdb-${env.src.version}.tgz ./
      mkdir $out/nix-support
      echo file source-dist $out/rethinkdb-${env.src.version}.tgz > $out/nix-support/hydra-build-products
    '';
  };
}
