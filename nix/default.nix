{ stdenv, callPackage }:
stdenv.mkDerivation rec {
	src = (callPackage ./api.nix {}).exportLocalGit { path = ../.; ref="HEAD"; unpack = true; };
	name="nix-source-automation";
	passthru = {
		api = import "${src}/nix/api.nix";
	};
	buildCommand = "touch $out";
}
