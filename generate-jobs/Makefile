check:
	F=`mktemp`; \
	curl "https://api.github.com/repos/rethinkdb/rethinkdb/pulls" > "$$F"; \
	nix-instantiate -I rethinkdb-nix=.. --arg pullRequests "$$F" release.nix --show-trace
