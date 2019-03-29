{ lib, importDrv ? (assert "importDrv required to override .drv files"; null) }:
{ src, drv }:
	# TODO: use overrideAttributes if possible
	let setSrc = (o: { inherit src; }); in
	if drv ? overrideAttrs
		then drv.overrideAttrs setSrc
		else lib.overrideDerivation (importDrv drv) setSrc
