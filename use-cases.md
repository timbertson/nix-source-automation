# Large, out-of-tree package collection

Real life example: opam2nix-packages. This is a full set of opam packages, but isn't part of `nixpkgs`.

Current state: users need to copy the whole `nix/release/` folder from a checkout which includes default.nix plus multiple JSON files in order to reference these pacakges. I used to embed them all in a single `release.nix` but that required templating to update 3 files in slightly different ways on every commit.

Requirements:

 - Users should be able to opt in to a specific version with a simple oneline nix expression
 - Users should be able to update their pinned version to `master` easily.

# Self-contained source code

Example: git-wip. A simple script mainly for the author's personal use, not intending to upstream into nixpkgs.

Requirements:

 - Should be easy to build the software from a checkout
 - Should be possible to import this nix expression into a larger "dotfiles"-like repo / expression

# Out-of-tree software which ditributes its own nix expressions

Example: gup.

Superset of "Self-contained source code", with additional requirements:

 - Should be possible to use the same `.nix` file between the repo and the corresponding location in nixpkgs without having to make modifications.
 - Should be possible to update the self-contained nix expression, test, then copy into `nixpkgs` for an upstream PR.

# Easy maintenance of third-party software

Example: TODO

Requirements:

 - should be easy to update to a newer tagged revision / tarball
 - should be possible to automate updates
