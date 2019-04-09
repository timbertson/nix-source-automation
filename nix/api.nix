{ pkgs, lib, stdenv, fetchFromGitHub, fetchurl, fetchgit }:
with lib;
let
	_nixpkgs = pkgs;
	utils = rec {
		# sub-tools implemented in their own nix files
		nixImpure = _nixpkgs.callPackage ./nixImpure.nix {};
		importDrv = _nixpkgs.callPackage ./importDrv.nix {};
		exportLocalGit = _nixpkgs.callPackage ./exportLocalGit.nix { inherit nixImpure; };
		overrideSrc = _nixpkgs.callPackage ./overrideSrc.nix { inherit importDrv; };
		unpackArchive = _nixpkgs.callPackage ./unpackArchive.nix {};
	};

	# exposed for testing
	internal = with api; rec {
		implAttrset = node: impl:
		let
			paths = map (splitString ".") (node.attrs.attrPaths or [node.name]);
			attrs = map (path: setAttrByPath path impl) paths;
		in
		foldr recursiveUpdate {} attrs;

		makeImport = name: attrs:
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
				node = { inherit name attrs src version nix overlay drv; };
			in
			node
		;

		importsOfJson = json: mapAttrs makeImport json;
	};

	api = with internal; with utils; utils // (rec {
		inherit internal;

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
			assert attrs.wrangle.apiversion == 1; attrs;

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
			jsonSources = lib.foldr recursiveUpdate { sources = {}; } jsonList;
			jsonExtended = if extend == null then jsonSources else (
				# extend only acts on `sources`, not the full attrset
				recursiveUpdate jsonSources ({ sources = extend jsonSources.sources; })
			);
			result = jsonExtended // {
				sources = importsOfJson jsonExtended.sources;
			};
		in
		# map `sources` into imports instead of plain attrs
		jsonExtended // {
			sources = importsOfJson jsonExtended.sources;
		};

		overlaysOfImport = imports:
			map (node: node.overlay) (attrValues imports.sources);

		pkgsOfImport = imports: {
			overlays ? [],
			extend ? null,
			importArgs ? {},
		}:
		import _nixpkgs.path ({
			overlays = overlays ++ (overlaysOfImport imports);
		} // importArgs);

		pkgs = {
			path ? null,
			sources ? null,

			overlays ? [],
			extend ? null,
			importArgs ? {},
		}:
		pkgsOfImport (importFrom { inherit path sources extend; }) {
			inherit overlays extend importArgs;
		};

		overlays = args: overlaysOfImport (importFrom args);

		derivations = args: mapAttrs (name: node: node.drv) (importFrom args).sources;

		callPackage = arg:
			let
				isPath = p: builtins.typeOf p == "path";
				argValue = if isPath arg then import arg else arg;
				attrs = if isFunction argValue
					then assert isPath arg; { nix = argValue; path = arg; }
					else argValue;
			in ({
				# callPackage args
				nix,
				args ? {},

				# importFrom args
				path ? null,
				sources ? null,

				# pkgsOfImport args
				overlays ? [],
				extend ? null,
				importArgs ? {},
			}:
				let
					imports = importFrom { inherit path sources extend; };
					pkgs = pkgsOfImport imports {inherit overlays extend importArgs; };
					base = pkgs.callPackage nix args;
					overridden = if imports ? self then
						let self = makeImport null imports.self; in
						overrideSrc {
							inherit (self) src version;
							drv = base;
						} else base;
				in
				overridden
			) attrs;

	});
in api
