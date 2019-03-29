# Proposal for self-updating nix `src` expressions:

## Sample expressions:

Simple, revision-based update:

```
mkDerivation rec {
	inhert (src.meta) version;
	name = "opam2nix-${version}";
	src = fetch {
		type = "github";
		owner = "timbertson";
		repo = "opam2nix";
		rev = "v1.2.3";
		sha256 = "abcd1234xxxxxxxxxx";
		meta = {
			version = "1.2.3";
			update = { current, version }:
				# returns a nix expression which replaces the argument to `fetch`. It
				# does not populate sha256, that's done by whoever calls `update`.
				{
					rev = "v${version}";
					meta = current.meta // { inhert version; };
				};
		};
	};
}
```

Basic flow:

inputs = { version: 1234 };
json="$(nix-impure "$(nix-prefetch-src '<nixpkgs>' -A myPkg.src.meta.update --argstr version "1.2.4")")"
json['meta'] = { version = 1234; }
nix-splice-expr --merge-arg-to 'fetchSrc' "$(cat json)" path/to/pkg.nix

`fetch-latest` update using a local repo:
```
		meta = {
			branch = "master";
			update = { current, git }:
				{
					rev = evalScript ''
						cd ../
						${git}/bin/git rev-parse ${current.meta.branch}
					'';
				};
		};
```

fetch the latest release from github
```
		meta = {
			branch = "master";
			update = { evalScript, curl, jq }:
				{
					rev = evalScript (with current.meta; ''
						${curl}/bin/curl -sSL "https://api.github.com/repos/${owner}/releases/latest" | ${jq}/bin/jq '.tag_name'
					'');
				};
		};
```

User-interactive (e.g. you could build a picker)
```
		meta = {
			branch = "version";
			update = { evalScript, current }:
				{
					rev = evalScript (with current.meta; ''
						echo -n "Pick a new version: " >&2
						read v
						echo "" >&2
						echo "$v"
					'');
				};
		};
```

### How it works:

Rules for splicing in the updated values:

`update` must return a plain attrset.

Values must either be simple values or calls to `evalScript` (which will produce a derivation with some sort of marker so we can tell these from regular derivations).

Attributes are merged, but in a way that leaves untouched values alone in the source code.

e.g. if merging `meta` with `{version = "1.2.3"; }`, the source expression for meta.update must be untouched, since it's a function and we can't pretty-print that.

This allows `meta.update` to reference some shared function which is useful for updating a large number of packages with the same logic.

**Question**: is that possible with existing nix parsers?

# `evalScript`

Can't be pure, would work somewhat like `updateScript` attribute in nixpkgs. It writes a script, which then gets impurely run to get the actual value.

# Initialization:

nix-prefetch-any should take the same arguments as the generic `fetch` function, and print out valid nix source to be copy-pasted.

It should also support some convenient shorthands, and asking for more information. e.g.:

```
$ nix-prefetch-any init 'https://github.com/timbertson/opam2nix'
# This specification is partial, please enter the remaining attributes...
# - rev: v1.2.3
# Fetching v1.2.3 ...
src = fetch {
	# generated `fetch` arguments
};
```

```
$ nix-prefetch-any init -o pkg.nix 'https://github.com/timbertson/opam2nix' --ref v1.2.3
$ nix-prefetch-any init -o pkg.nix 'github:timbertson/opam2nix#v1.2.3'
$ nix-prefetch-any init -o pkg.nix --type github --owner timbertson --name opam2nix --rev v1.2.3
```

# How do we reference a `src` expression?

Has to be via attribute path rather than just a file, since it needs to be evaluated expression.

We could still support importing from a file directly, if the file can be evaluated with a simple `pkgs.callPackage`.

# Questions:

- How does the sha256 actually get populated? Can we hardcode an implicit evalScript which will work for every fetch type?

- This supports most of nix-update-source functionality, what about niv/nix-path?

	niv prefers all sources in a single place, which could still be supported, you'd just need to specify the attribute path of the derivation / src you wanted to change.


