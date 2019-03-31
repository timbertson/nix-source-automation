{ lib, importDrv ? (assert "importDrv required to override .drv files"; null) }:
{ src, drv }:
let
	drvAttrs = if lib.isAttrs drv then drv else (importDrv drv); # if not an attrset, assume a .drv path
	override = attrs: if attrs ? overrideAttrs then attrs.overrideAttrs else lib.overrideDerivation attrs;
in
	override drvAttrs (o: { inherit src; })
