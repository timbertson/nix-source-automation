{ lib, fetchFromGitHub, fetchurl, fetchgit }:
let
	knownFetchers = {
		inherit fetchFromGitHub fetchurl fetchgit;
	};
	makeNode = attrs:
		let
			source = (builtins.getAttr atts.source[0] knownFetchers) (attrs.source[1]);
			# TODO: import from derivation
			importPath = "${source}/(attrs.importPath or "nix/"
			call = callWith callPackage
		in
		{ inherit source; version; call; overlay; }
	;
	loadWrap = fn: path:
		let
			contents = lib.importJSON path;
		in
		;
	load = loadWrap (x: x);
in
{ inherit load; loadWrap; }
