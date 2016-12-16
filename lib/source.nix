with import ./prelude.nix;
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

  versionFile = pkgs.stdenv.mkDerivation {
    name = "rethinkdb-version";
    src = <rethinkdb>;
    buildInputs = [ pkgs.git ];
    builder = mkStdBuilder ''
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
  in rec {
    version = replace "/-patched.*/" "" (find "version");
    url = replace "\\$\\{?version([^}]*})?" version (find "src_url");
    sha1 = find "src_url_sha1";
  };

  stripForFetching = dep: src: pkgs.stdenv.mkDerivation {
    # TODO
  };

  mkFetch = fetch_list: pkgs.stdenv.mkDerivation (rec {
    name = "rethinkdb-dependencies-src";
    builder = mkStdBuilder ("mkdir $out\n" +
      concatStringsSep "\n"
        (map (dep: "cp -r --no-preserve=all ${"$"}${dep}/* $out/") fetch_list));
    buildInputs = [ <rethinkdb> ];
  } // listToAttrs (map (dep: let info = depInfo dep; in {
    name = dep;
    value = if info.url != null
      then pkgs.stdenv.mkDerivation {
        name = "rethinkdb-fetch-${dep}-${info.version}";
	# TODO: doesn't work on hydra?
        # src = pkgs.fetchurl {
        #   url = info.url;
        #   sha1 = info.sha1;
        # };
	buildInputs = [ pkgs.curl pkgs.coreutils ];
        builder = mkStdBuilder ''
          mkdir -p $out/external/.cache
          # ln -s $src $out/external/.cache/''${src#*-}
	  src="${info.url}"
	  curl "$src" > $out/external/.cache/''${src##*/}
	  # TODO: check sha1
        '';
	__noChroot = true;
      } else pkgs.stdenv.mkDerivation {
	name = "rethinkdb-fetch-${dep}-${info.version}";
	src = stripForFetching dep <rethinkdb>;
	builder = mkStdBuilder ''
	  ${src.fetch}
	  mkdir $out
	  cp -r external/${dep}_* $out/
	'';
      };
  }) fetch_list));

  fetchList = ["v8" "jemalloc"];

  fetchDependencies = mkFetch fetchList;


  sourcePrep = pkgs.stdenv.mkDerivation rec {
    name = "rethinkdb-${version}";
    version = unsafeDiscardStringContext (readFile versionFile);
    builder = mkStdBuilder ''

      # TODO: https://github.com/NixOS/nixpkgs/issues/13744
      export SSL_CERT_FILE=$cacert/etc/ssl/certs/ca-bundle.crt

      mkdir rethinkdb
      cp -r $src/* rethinkdb/
      chmod -R u+w rethinkdb
      cd rethinkdb

      # TODO: move upstream
      sed -i 's/reset-dist-dir: FORCE | web-assets/reset-dist-dir: FORCE/' mk/packaging.mk
      sed -i 's/install: build/install:/' packaging/debian/rules

      echo "${version}" > VERSION.OVERRIDE
      cp -r --no-preserve=all $fetchDependencies/* .
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
      unzip
    ];
  };

  sourceTgz = pkgs.stdenv.mkDerivation rec {
    name = "rethinkdb-${src.version}-source";
    src = sourcePrep;
    buildInputs = [ pkgs.gnutar ];
    builder = mkStdBuilder ''
      mkdir $out
      cd $src
      tar --transform 's|^.|rethinkdb-${src.version}|' -zcf $out/rethinkdb-${src.version}.tgz ./
      mkdir $out/nix-support
      echo file source-dist $out/rethinkdb-${src.version}.tgz > $out/nix-support/hydra-build-products
    '';
  };
}
