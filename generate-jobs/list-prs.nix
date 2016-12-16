let
  pkgs = import <nixpkgs> {};
in { json = pkgs.stdenv.mkDerivation {
  name = "rethinkdb-pull-requests.json";
  curl = pkgs.curl;
  now = <now>;
  builder = builtins.toFile "builder.sh" ''
    $curl/bin/curl "https://api.github.com/repos/rethinkdb/rethinkdb/pulls?state=open&sort=updated" > $out;
  '';
  __noChroot = true;
  preferLocalBuild = true;
}; }


