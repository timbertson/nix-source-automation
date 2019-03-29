{ nix, runCommand, lib }:

# Takes a nix derivation path (must be in the store), and
# converts it to a derivation expression.
# Note that the result is not a `stdenv.mkDerivation` with
# all the helpers that entails (like overrideAttrs), but
# is a low-level call to `derivation`
#
# TODO: this likely doesn't suppot multi-output drvs, we'd
# need more smarts around `outputs`.
drvPath:
	let
		# TODO: this introduces import-from-derivation, is there some
		# way to shift this to eval time?
		jsonFile =
			assert (lib.isStorePath drvPath);
			runCommand "drv.json" {} ''
			${nix}/bin/nix show-derivation ${toString drvPath} > "$out"
		'';

		drvJson = lib.importJSON jsonFile;

		# The JSON has a single toplevel key of the .drv path
		rawDrv = lib.getAttr (toString drvPath) drvJson;

		outputs = lib.attrNames rawDrv.outputs;

		filteredEnv = lib.filterAttrs (k: v:
			!(lib.elem k outputs)
		) rawDrv.env;

		# Assume there's always a `builder` string,
		# and attach all the original derivation's to it:
		builderWithCtx = with lib;
		let
			getAllAttrs = src: attrs: map (name: getAttr name src) attrs;
			importInputs = attrs:
				concatLists (
					mapAttrsToList
						# each attr is an attrset with key = path-to-drv and value = list of outputs (attributes)
						(name: outputs: getAllAttrs (import name) outputs)
						attrs
				);
			addContextFrom = orig: dest:
				lib.warn ("Adding context from: ${orig} to ${dest}")
				(lib.addContextFrom orig dest);
		in
		foldr addContextFrom filteredEnv.builder ((importInputs rawDrv.inputDrvs) ++ (builtins.map builtins.storePath rawDrv.inputSrcs));

		drvAttrs = filteredEnv // {
			inherit outputs;
			inherit (rawDrv) args;
			builder = builderWithCtx;
		};
	in
	lib.warn "outputs isList = ${if (lib.isList rawDrv.env.outputs) then "true" else "false"}" (
	lib.warn "outputs = ${toString (rawDrv.env.outputs)}" (
	lib.warn "jsonFile = ${jsonFile}" (
	lib.warn "rawDrv = ${toString (lib.attrNames rawDrv)}" (
	lib.warn "importedDrv = ${toString (lib.attrNames (import drvPath))}" (
	# lib.warn "getContext importedDrv = ${toString (builtins.toJSON (builtins.getContext (import drvPath).drvPath))}" (
	derivation drvAttrs
	# )
	)
	)
	)
	)
	)
