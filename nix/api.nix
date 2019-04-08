{ pkgs, lib, stdenv, fetchFromGitHub, fetchurl, fetchgit }:
with lib;
let
	_nixpkgs = pkgs;
	utils = rec {
		# sub-tools implemented in their own nix files
		nixImpure = pkgs.callPackage ./nixImpure.nix {};
		importDrv = pkgs.callPackage ./importDrv.nix {};
		exportLocalGit = pkgs.callPackage ./exportLocalGit.nix { inherit nixImpure; };
		overrideSrc = pkgs.callPackage ./overrideSrc.nix { inherit importDrv; };
		unpackArchive = pkgs.callPackage ./unpackArchive.nix {};
	};

	# exposed for testing
	internals = with api; rec {
		overlaysOfJson = json: overlaysOfNodes (nodesOfJson json);

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
				nix = "${src}/${attrs.nix or "default.nix"}";

				defaultCall = { pkgs, path }: pkgs.callPackage path {};
				callImpl = attrs.call or defaultCall;

				callWith = args: overrideSrc {
					inherit src;
					drv = callImpl args;
					version = attrs.version or (fetchArgs.ref or null);
				};
				drv = callWith { pkgs = _nixpkgs; path = nix; };
				overlay = (self: super:
					let
						impl = callWith { pkgs = self; path = nix; };
						addition = implAttrset node impl;
					in
					recursiveUpdateUntil (path: l: r: isDerivation l) super addition
				);
				node = { inherit name attrs src nix overlay drv; };
			in
			node
		;

		nodesOfJson = mapAttrs makeNode;

		nodesOfJsonList = jsons:
			lib.foldr (a: b: a // b) {} (map nodesOfJson jsons);
	};

	api = with internals; with utils; utils // (rec {
		inherit internals;

		fetchers = {
			github = fetchFromGitHub;
			url = fetchurl;
			git = fetchgit;
			git-local = exportLocalGit;
			path = ({ path }: path);
		};

		importJsonSrc = path:
			let attrs = if isAttrs path
				then path
				else builtins.trace "Importing ${path}" (importJSON path);
			in
			assert attrs.wrangle.apiversion == 1; attrs.sources;

		importFrom = {
			path ? null,
			sources ? null,
			extend ? null,
		}:
		let
			jsonList = map importJsonSrc (
				if sources != null then sources else (
					if path == null
						then (abort "path or sources required")
						else (
							let
								p = builtins.toString path;
								candidates = [
									"${p}/wrangle.json"
									"${p}/wrangle-local.json"
								];
								present = filter builtins.pathExists candidates;
							in
							if (length present == 0)
								then lib.warn "No files found in candidates:\n - ${concatStringsSep "\n - " candidates}" present
								else present
						)
				)
			);
			jsonSources = lib.foldr (a: b: a // b) {} jsonList;
			jsonExtended = if extend == null then jsonSources else (
				recursiveUpdate jsonSources (extend jsonSources)
			);
		in
		nodesOfJson jsonExtended;

		overlaysOfNodes = nodes:
			map (node: node.overlay) (attrValues nodes);

		pkgs = {
			path ? null,
			sources ? null,
			nixpkgs ? null,
			overlays ? [],
			extend ? null,
		}:
		# TODO: any special treatment for wrangle itself?
		let
			nodes = importFrom { inherit path sources extend; };
			nixpkgsPath =
				if nixpkgs != null then nixpkgs else (
					# if not specified use the "nixpkgs" entry,
					# falling back to the version of nixpkgs used at import time
					if (nodes ? nixpkgs)
						then builtins.trace "Using nixpkgs: ${nodes.nixpkgs.nix}" nodes.nixpkgs.nix
						else _nixpkgs.path
				);
		in
		import nixpkgsPath {
			overlays = overlays ++ (overlaysOfNodes nodes);
		};

		overlays = args: overlaysOfNodes (importFrom args);

		derivations = args: mapAttrs (name: node: node.drv) (importFrom args);
	});
in api
