{ pkgs ? import <nixpkgs> {},
  pullRequests ? <pull-requests> }:
let
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
      rethinkdb = {
        type = "git";
        value = "git://github.com/${repo} ${branch} 1";
        emailresponsible = false;
      };
      rethinkdb-nix = metajob.inputs.rethinkdb-nix;
      nixpkgs = metajob.inputs.nixpkgs;
    };
  } // attrs;

  metajob = builtins.fromJSON (builtins.readFile <rethinkdb-nix/generate-jobs/metajob.json>);
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

  prSpecs = builtins.listToAttrs (map (pr: {
    name = "${toString pr.number}-${pr.user.login}";
    value = jobset {
      repo = pr.head.repo.full_name or "${pr.user.login}/rethinkdb";
      branch = pr.head.ref;
      checkinterval = 600;
      attrs = {
        description = "[${pr.milestone.title or "unassigned"}] ${pr.title}";

	# TODO: doesn't work. Maybe use 0 or 1 instead of true/false?
	# enabled = if pr.head == null then false else true;
      };
    };
  }) (builtins.fromJSON (builtins.unsafeDiscardStringContext (builtins.readFile pullRequests))));

  specs = mainSpecs // prSpecs // { ".jobsets" = metajob; };

in {
  jobsets = pkgs.writeText "jobsets.json" (builtins.toJSON specs);
}
