check:
	nix-instantiate --show-trace --option restrict-eval true -I .. all.nix -K
