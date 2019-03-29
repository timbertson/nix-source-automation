{ pkgs ? import <nixpkgs> {}}:
with pkgs;
with callPackage ../nix/default.nix {};
let
in
{
	impure = nixImpure { name = "testing"; } ''
		touch $out;
		ls -l $out
	'' ;
	
	importDrv = { drvPath }: importDrv drvPath;

	exportGit = { commit ? null, ref ? null, unpack ? false, workingChanges ? false }:
		exportGit { inherit commit ref unpack workingChanges; dir = ../.; };

	gup = callPackage ./gup-readme.nix {};
}
