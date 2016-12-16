let
  pkgs = import <nixpkgs> {};

  jobset = { branch, job ? "test-commit", attrs ? {}, repo ? "rethinkdb/rethinkdb", checkinterval ? 0 }: {
    enabled = 1;
    hidden = false;
    description = "Build and test ${branch}";
    nixexprinput = "rethinkdb-nix";
    nixexprpath = "${job}.nix";
    checkinterval = checkinterval;
    schedulingshares = 100;
    enableemail = true;
    emailoverride = "";
    keepnr = 10;
    inputs = {
      nixpkgs = {
        type = "path";
        value = metajob.inputs.nixpkgs.value;
        emailresponsible = false;
      };
      rethinkdb = {
        type = "git";
        value = "git://github.com/${repo} ${branch} 1";
        emailresponsible = false;
      };
      rethinkdb-nix = {
        type = "path";
        value = "/home/atnnn/code/rethinkdb-nix";
        emailresponsible = false;
      };
    };
  } // attrs;

  metajobOrig = builtins.fromJSON (builtins.readFile <declInput/generate-jobs/metajob.json>);
  metajob = metajobOrig // {
    inputs = metajobOrig.inputs // {
      prs = metajobOrig.inputs.prs // {
        type = "sysbuild";
	value = "listPullRequests:json";
      };
    };
  };

  mainBranches = ["next" "v2.3.x"];

  mainSpecs = builtins.foldl' (a: b: a // b) {} (map (branch: {
    "${branch}" = jobset {
      inherit branch;
      checkinterval = 600;
    };
    "daily-${branch}" = jobset {
      inherit branch;
      job = "daily";
      checkinterval = 86400; # 1 day
      attrs = {
        description = "Daily build of ${branch}";
      	schedulingshares = 1;
      	keepnr = 30;
      };
    };
  } ) mainBranches);

  pullRequests = pkgs.stdenv.mkDerivation {
    name = "rethinkdb-pull-requests-${toString builtins.currentTime}.json";
    curl = pkgs.curl;
    builder = builtins.toFile "builder.sh" ''
      $curl/bin/curl -q "https://api.github.com/repos/rethinkdb/rethinkdb/pulls?state=open&sort=updated" > $out;
    '';
    __noChroot = true;
    preferLocalBuild = true;
  };

  prSpecs = builtins.listToAttrs (map (pr: {
    name = "PR${toString pr.number}-${pr.user.login}";
    value = jobset {
      repo = pr.head.repo.full_name or "${pr.user.login}/rethinkdb";
      branch = pr.head.ref;
      checkinterval = 600;
      attrs = { description = pr.title; enabled = if pr.head == null then 0 else 1; };
    };
  }) (builtins.fromJSON (builtins.unsafeDiscardStringContext (builtins.readFile pullRequests))));

  specs = mainSpecs // prSpecs // { ".jobsets" = metajob; };

in {
  jobsets = pkgs.writeText "jobsets.json" (builtins.toJSON specs);
}
