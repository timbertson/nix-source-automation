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
				version = attrs.version or (fetchArgs.ref or null);

				defaultCall = { pkgs, path }: pkgs.callPackage path {};
				callImpl = attrs.call or defaultCall;

				callWith = args: overrideSrc {
					inherit src version;
					drv = callImpl args;
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
		# TODO: merge `sources` but keep toplevel self / pkgs?
		nodesOfJson jsonExtended;

		overlaysOfNodes = nodes:
			map (node: node.overlay) (attrValues nodes);

		pkgsOfNodes = nodes: {
			overlays ? [],
			extend ? null,
			importArgs ? {},
		}:
		import _nixpkgs.path ({
			overlays = overlays ++ (overlaysOfNodes nodes);
		} // importArgs);

		pkgs = {
			path ? null,
			sources ? null,

			overlays ? [],
			extend ? null,
			importArgs ? {},
		}:
		pkgsOfNodes (importFrom { inherit path sources extend; }) {
			inherit overlays extend importArgs;
		}

		overlays = args: overlaysOfNodes (importFrom args);

		derivations = args: mapAttrs (name: node: node.drv) (importFrom args);

		callPackage = arg:
			let
				argValue = if isPath arg then import arg else arg;
				attrs = if isFunction argValue
					then assert isPath arg; { drv = argValue; nix = argValue; path = arg; }
					else argValue;
			in ({
				path ? null,
				sources ? null,

				nix ? path,

				overlays ? [],
				extend ? null,
				importArgs ? {},
			} callArgs:
				let
					nodes = importFrom { inherit path source extend; };
					pkgs = pkgsOfNodes nodes {inherit overlay extend importArgs; };
					base = pkgs.callPackage nix callArgs;
					overridden = if nodes ? self then
						overrideSrc {
							inherit (nodes.self) src version;
							drv = base;
						} else base;
				in
				overridden
			) attrs
	});
in api
