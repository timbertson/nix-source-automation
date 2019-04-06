{ pkgs, lib, stdenv, fetchFromGitHub, fetchurl, fetchgit,
	overrideSrc, exportLocalGit, unpackArchive }:
with lib;
let
	_nixpkgs = pkgs;
	# exposed for testing
	internals = with api; rec {
		overlaysOfJson = json: overlaysOfNodes (nodesOfJson json);

		importJsonSrc = path:
			if isAttrs path
				then warn "path is an attrset, this should only be used for testing" path
				else builtins.trace "Importing ${path}" (importJSON path);

		implAttrset = node: impl:
		let
			paths = map (splitString ".") (node.attrs.attrPaths or [node.name]);
			attrs = map (path: setAttrByPath path impl) paths;
		in
		foldr recursiveUpdate {} attrs;

		makeNode = name: attrs:
			let
				fetcher = elemAt attrs.source 0;
				fetchArgs = elemAt attrs.source 1;
				fetched = if builtins.hasAttr fetcher fetchers
					then (builtins.getAttr fetcher fetchers) fetchArgs
					else abort "Unknown fetcher: ${fetcher}"
				;
				src = if (attrs.unpack or false) then (unpackArchive fetched) else fetched;
				importPath = "${src}/${attrs.importPath or "default.nix"}";
				callWith = callPackage: args: overrideSrc {
					inherit src;
					drv = callPackage importPath args;
					version = attrs.version or (fetchArgs.ref or null);
				};
				overlay = (self: super:
					let
						impl = callWith self.callPackage {};
						addition = implAttrset node impl;
					in
					recursiveUpdateUntil (path: l: r: isDerivation l) super addition
				);
				node = { inherit name attrs src importPath overlay callWith; };
			in
			node
		;
		nodesOfJson = json:
			assert json.wrangle.apiversion == 1;
			mapAttrs makeNode json.sources;

		nodesOfJsonList = jsons:
			lib.foldr (a: b: a // b) {} (map nodesOfJson jsons);

		overlaysOfNodes = nodes:
			map (node: node.overlay) (attrValues nodes);
	};

	api = with internals; rec {
		inherit internals;

		fetchers = {
			github = fetchFromGitHub;
			url = fetchurl;
			git = fetchgit;
			git-local = exportLocalGit;
			path = ({ path }: path);
		};

		importFrom = {
			basePath ? null,
			paths ? null,
		}:
		nodesOfJsonList (
			if paths != null then paths else (
				if basePath == null
					then (abort "basePath or paths required")
					else map importJsonSrc (
						let
							p = builtins.toString basePath;
							candidates = [
								"${p}/wrangle.json"
								"${p}/wrangle-local.json"
							];
							present = filter builtins.pathExists candidates;
						in
						if (length present == 0)
							then abort "No files found in candidates:\n - ${concatStringsSep "\n - " candidates}"
							else present
					)
			)
		);

		overlays = {
			basePath ? null,
			paths ? null,
		}: overlaysOfNodes (importFrom { inherit basePath paths; });

		pkgs = {
			basePath ? null,
			paths ? null,
			nixpkgs ? null,
			overlays ? [],
		}:
		# TODO: any special treatment for wrangle itself?
		let
			nodes = importFrom { inherit basePath paths; };
			nixpkgsPath =
				if nixpkgs != null then nixpkgs else (
					# if not specified use the "nixpkgs" entry,
					# falling back to the version of nixpkgs used at import time
					if (nodes ? nixpkgs)
						then builtins.trace "Using nixpkgs: ${nodes.nixpkgs.importPath}" nodes.nixpkgs.importPath
						else _nixpkgs.path
				);
		in
		import nixpkgsPath {
			overlays = overlays ++ (overlaysOfNodes nodes);
		};

		call = { basePath ? null, paths ? null, callPackage ? _nixpkgs.callPackage, name }: args:
			let
				nodes = importFrom { inherit basePath paths; };
			in
			(builtins.getAttr name nodes).callWith callPackage args;
	};
in api
