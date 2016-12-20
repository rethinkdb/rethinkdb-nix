with import ./prelude.nix;
with { inherit (import ./build.nix) rethinkdbBuildInputs; };
rec {
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

  versionFile = mkSimpleDerivation {
    name = "rethinkdb-version";
    env.src = <rethinkdb>;
    buildInputs = [ pkgs.git ];
    buildCommand = ''
      cd $src
      echo -n $(bash scripts/gen-version.sh) > $out
    '';
  };

  depInfo = dep: let
    source = readFile (toPath "${<rethinkdb>}/mk/support/pkg/${dep}.sh");
    find = var: let go = source: val:
      let group = match "(.*?)\n *${var}=\"?([^\"\n]*)\"?\n.*" source;
      in if group == null then val else go (head group) (elemAt group 1);
    in go source null;
    rawUrl = find "src_url";
  in rec {
    version = replace "/-patched.*/" "" (find "version");
    url = if rawUrl == null then null
      else replace "\\$\\{?version([^}]*})?" version rawUrl;
    sha1 = find "src_url_sha1";
    varName = replace "-" "_" dep;
    name = dep;
  };

  mkFetch = fetch_list: let
    depInfos = map (dep: depInfo dep) fetchList;
  in mkSimpleDerivation (rec {
    name = "rethinkdb-dependencies-src";
    buildCommand = "set -x\n mkdir $out\n" +
      concatStringsSep "\n"
        (map (info: "cp -r --no-preserve=all ${"$"}${info.varName}/* $out/") depInfos);
    buildInputs = [ <rethinkdb> ];
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
            # ln -s $src $out/external/.cache/''${src#*-}
            src="${info.url}"
            curl "$src" > $out/external/.cache/''${src##*/}
            # TODO: check sha1
          '';
          env.__noChroot = true;
        } else mkSimpleDerivation {
          name = "rethinkdb-fetch-${dep}-${info.version}";
          buildCommand = ''
            cp -r $rethinkdb/* .
            chmod -R u+w .
            ./configure --fetch jemalloc --fetch ${dep}
            make fetch-${dep}
            mkdir -p $out/external
            cp -r external/${dep}_* $out/external/
          '';
          buildInputs = rethinkdbBuildInputs ++ [ reCC ];
          env = {
            __noChroot = true;
            rethinkdb = unsafeDiscardStringContext (toString <rethinkdb>);
          }; 
        })
      ) depInfos));
  });

  fetchList = ["v8" "jemalloc" "admin-deps" ];
  fetchInfos = map (dep: depInfo dep) fetchList;

  fetchDependencies = mkFetch fetchList;


  sourcePrep = mkSimpleDerivation rec {
    name = "rethinkdb-${env.version}";
    buildCommand = ''

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
      ./configure --fetch jemalloc
      ${make} dist-dir DIST_DIR=$out
      ${unpatchScripts "$out"}
    '';
    env = {
      version = unsafeDiscardStringContext (readFile versionFile);
      __noChroot = true;
      src = <rethinkdb>;
      inherit fetchDependencies;
    };
    buildInputs = with pkgs; rethinkdbBuildInputs ++ [ git cacert nix unzip ];
  };

  sourceTgz = mkSimpleDerivation rec {
    name = "rethinkdb-${env.src.version}-source";
    env.src = sourcePrep;
    buildInputs = [ pkgs.gnutar ];
    buildCommand = ''
      mkdir $out
      cd $src
      tar --transform 's|^.|rethinkdb-${env.src.version}|' -zcf $out/rethinkdb-${env.src.version}.tgz ./
      mkdir $out/nix-support
      echo file source-dist $out/rethinkdb-${env.src.version}.tgz > $out/nix-support/hydra-build-products
    '';
  };
}
