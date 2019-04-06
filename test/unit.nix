with import <nixpkgs> {};
with builtins;
with lib;
with (callPackage ../nix/default.nix {}).wrangle;
with internals;
let
	eq = msg: a: b: [
		"${msg}: ${toJSON a} != ${toJSON b}" (a == b)
	];
	versionSrc = {
		source = ["github" {
			"owner" = "timbertson";
			"repo" = "version";
			"rev" = "version-0.13.1";
			"sha256" = "056l8m0xxl1h7x4fd1hf754w8q4sibpqnwgnbk5af5i66399az61";
		}];
		importPath = "nix/";
	};

	versionNoImport = {
		source = ["github" {
			"owner" = "timbertson";
			"repo" = "version";
			"rev" = "version-0.13.1";
			"sha256" = "056l8m0xxl1h7x4fd1hf754w8q4sibpqnwgnbk5af5i66399az61";
		}];
	};

	fakeNixpkgs = {
		wrangle = { apiversion = 1; };
		sources = {
			nixpkgs = {
				source = [ "path" { path = (toString ./.); } ];
				importPath = "fakeNixpkgs.nix";
			};
		};
	};

	checks = [
		(eq "implAttrset with no explicit path"
			(implAttrset { attrs = {}; name = "foo"; } 1)
			{ foo = 1; })

		(eq "implAttrset with multiple paths"
			(implAttrset { attrs = { attrPaths = ["foo" "bar.baz"]; }; } 1)
			{ foo = 1; bar = { baz = 1; }; })

		["implPath is path" (isString (makeNode "name" versionSrc).importPath)]
		["importPath defaults to default.nix" (hasSuffix "/default.nix" (makeNode "name" versionNoImport).importPath)]
		["importPath is modifiable" (hasSuffix "/foo.nix" (makeNode "name" (versionSrc // {importPath = "foo.nix";})).importPath)]
		["src is derivation" (isDerivation (makeNode "name" versionSrc).src)]
		(eq "passthru name" (makeNode "name" versionSrc).name "name")
		(eq "passthru attrs" (makeNode "name" versionSrc).attrs versionSrc)
		["overlay is valid"
			(isDerivation ((makeNode "pythonPackages.versionOverride" versionSrc).overlay
				{inherit callPackage;} # self
				{} # super
			).pythonPackages.versionOverride)]
		(eq "uses nixpkgs entry" (pkgs { paths = [ fakeNixpkgs ]; }) "fake nixpkgs!")
	];
	failures = concatMap (test:
		if elemAt test 1 then [] else [(elemAt test 0)]
	) checks;
in
if (length failures) == 0 then "OK" else abort (lib.concatStringsSep "\n" failures)