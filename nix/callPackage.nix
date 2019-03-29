let
	pkgs = import <nixpkgs> {};
	lib = pkgs.lib;
	mergeNone = pkgs: [];
in
{ rootScope ? pkgs, merge ? mergeNone, attrs ? {}, path }:
let
	scope = lib.foldr (a: b: a // b) rootScope (merge pkgs);
in
	# pkgs.callPackage path {}
lib.callPackageWith scope path attrs

