with import <nixpkgs> {};
with builtins;
with lib;
let api = (callPackage ../nix/api.nix {}); internal = api.internal; in
let
	wrangleHeader = { apiversion = 1; };
	addHeader = j: j // { wrangle = wrangleHeader; };
	eq = msg: a: b: [
		"${msg}: ${toJSON a} != ${toJSON b}" (a == b)
	];

	versionSrc = import samplePackage/versionSrc.nix;

	version = addHeader {
		sources = {
			version = versionSrc;
		};
	};

	versionNoImport = {
		source = ["github" {
			"owner" = "timbertson";
			"repo" = "version";
			"rev" = "version-0.13.1";
			"sha256" = "056l8m0xxl1h7x4fd1hf754w8q4sibpqnwgnbk5af5i66399az61";
		}];
	};

	fakeNixpkgs = addHeader {
		sources = {
			nixpkgs = {
				source = [ "path" { path = (toString ./.); } ];
				nix = "fakeNixpkgs.nix";
			};
		};
	};

	checks = [
		(eq "implAttrset with no explicit path"
			(internal.implAttrset { attrs = {}; name = "foo"; } 1)
			{ foo = 1; })

		(eq "implAttrset with multiple paths"
			(internal.implAttrset { attrs = { attrPaths = ["foo" "bar.baz"]; }; } 1)
			{ foo = 1; bar = { baz = 1; }; })

		["implPath is path" (isString (internal.makeImport "name" versionSrc).nix)]

		["nix defaults to default.nix" (hasSuffix "/default.nix" (internal.makeImport "name" versionNoImport).nix)]

		["nix is modifiable" (hasSuffix "/foo.nix" (internal.makeImport "name" (versionSrc // {nix = "foo.nix";})).nix)]

		["src is derivation" (isDerivation (internal.makeImport "name" versionSrc).src)]

		(eq "passthru name" (internal.makeImport "name" versionSrc).name "name")

		(eq "passthru attrs" (internal.makeImport "name" versionSrc).attrs versionSrc)

		["overlay is valid"
			(isDerivation ((internal.makeImport "pythonPackages.versionOverride" versionSrc).overlay
				{inherit callPackage;} # self
				{} # super
			).pythonPackages.versionOverride)]

		["makes derivations" (isDerivation (api.derivations { sources = [ version ]; }).version)]

		(eq "allows overriding of individual package invocations" "injected" (api.derivations {
			sources = [ version ];
			extend = nodes: {
				version = {
					call = { pkgs, path }: ((pkgs.callPackage path {}).overrideAttrs (o: {
						passthru = { extra = "injected"; };
					}));
				};
			};
		}).version.extra)

		(eq "callpackage works with just a path" ./samplePackage/upstream-src
			(api.callPackage ./samplePackage).src)

		(eq "callpackage works with a path which is an attrset of args" "attr!"
			(api.callPackage ./samplePackage/attrs.nix).custom)

		(eq "callpackage works with an attrset and no `self`" ./samplePackage/upstream-src (
			api.callPackage {
				sources = [ version ];
				nix = ({ pkgs, version }: pkgs.callPackage ./samplePackage/default.nix {});
			}
		).src)

		(eq "callpackage overrides src if `self` is given" ./samplePackage/local-src (
			api.callPackage {
				sources = [ version (addHeader {
					self = { source = [ "path" { path = ./samplePackage/local-src; } ]; };
				})];
				nix = ({ pkgs, version }: pkgs.callPackage ./samplePackage/default.nix {});
			}
		).src)

	];
	failures = concatMap (test:
		if elemAt test 1 then [] else [(elemAt test 0)]
	) checks;
in
if (length failures) == 0 then "OK" else abort (lib.concatStringsSep "\n" failures)
