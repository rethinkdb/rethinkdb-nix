let
  pkgs = import <nixpkgs> {};

  specs = {
    next = {
      enabled = 1;
      hidden = false;
      description = "Build and test next";
      nixexprinput = "rethinkdb-nix";
      nixexprpath = "release.nix";
      checkinterval = 0;
      schedulingshares = 100;
      enableemail = true;
      emailoverride = "";
      keepnr = 10;
      inputs = {
        nixpkgs = {
	  type = "path";
	  value = "/nix/var/nix/profiles/per-user/root/channels/nixos/nixpkgs";
	  emailresponsible = false;
	};
	rethinkdb = {
	  type = "git";
	  value = "git://github.com/rethinkdb/rethinkdb next 1";
	  emailresponsible = false;
	};
	rethinkdb-nix = {
	  type = "path";
	  value = "/home/atnnn/code/rethinkdb-nix";
	  emailresponsible = false;
	};
      };
    };
  };

  writeText = pkgs.writeText;

  # writeText = name: text: derivation {
  #   inherit name text;
  #   system = builtins.currentSystem;
  #   builder = "${pkgs.bash}/bin/bash";
  #   args = [ ( builtins.toFile "builder.sh" ''
  #     echo "$text" > $out
  #   '' ) ];
  # };
in {
  jobsets = writeText "jobsets.json" (builtins.toJSON specs);
}
