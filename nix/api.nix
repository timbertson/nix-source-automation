{ pkgs ? import <nixpkgs> {}}:
with pkgs;
rec {
	nixImpure = callPackage ./nixImpure.nix {};
	importDrv = callPackage ./importDrv.nix {};
	exportLocalGit = callPackage ./exportLocalGit.nix { inherit nixImpure; };
	overrideSrc = callPackage ./overrideSrc.nix { inherit importDrv; };
	wrangle = callPackage ./wrangle.nix {inherit overrideSrc exportLocalGit unpackArchive;};
	unpackArchive = callPackage ./unpackArchive.nix {};
}
