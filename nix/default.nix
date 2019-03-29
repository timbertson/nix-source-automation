{ pkgs ? import <nixpkgs> {}}:
with pkgs;
rec {
	nixImpure = callPackage ./nixImpure.nix {};
	importDrv = callPackage ./importDrv.nix {};
	exportGit = callPackage ./exportGit.nix { inherit nixImpure; };
	overrideSrc = callPackage ./overrideSrc.nix { inherit importDrv; };
	overlayPath = callPackage ./overlayPath.nix {};
}
