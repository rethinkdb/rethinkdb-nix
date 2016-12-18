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

  mkStdBuilder = script: toFile "builder.sh" ("source $stdenv/setup\n" + script);

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

}
