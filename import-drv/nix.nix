{ pkgs ? import <nixpkgs> {}}:
with pkgs;

# nix revision with support for string-context introspection
pkgs.nixUnstable.overrideAttrs (o: { src = fetchFromGitHub {
	owner = "nixos";
	repo = "nix";
	rev = "7a7ec2229834aa294b3e09df7f514b7134287ec2";
	sha256 = null;
}; })
