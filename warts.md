# Things that aren't ideal (about source code management) in nixpkgs as it stands:

## nix expressions inside source code are awkward

e.g. if I keep a repo at https://example.org/repo.git. Master commit is `aaaaaaaa`, and the previous commit is `9999999`.

The default.nix _inside_ that commit has no good way of referencing itself, it can only reference `HEAD^`

Also, every time you regenerate `default.nix` to point to the current `HEAD` commit, it creates changes to be committed even if they're not meaningful.

### Workarounds:

 - use a relative path like `./`

But that's not ideal for development, since it acts differently to a git export and caching needs to managed explicitly (via `filterSource`).
It also doesn't allow the `.nix` file to be copied / moved.

 -  code specific support for injecting "the source for myself". This is used in `opam2nix` - e.g. `import opam2nixSrc { srcJson = "${opam2nixSrc}/src.json"; };`

 - switch based on whether the current path is already in the store, e.g.:

```
isStorePath = x: lib.isStorePath (builtins.toString x);
src = if isStorePath ../. then ../. else (nix-update-source.fetch ./release/src.json).src;
```
This is ugly and repetitive boulerplate, and might be confusing.

 - A final workaround is used in `nix-pin`, which explicitly overrides `src` for every imported package, replacing it with a `git-export` of the current HEAD (or a `stash`, if there are working changes). That relies on having an opinionated program importing the source though.

## `src` fetchers should support `meta` and other passthru attributes

Use case: keeping the canonical `version` value where it belongs, annotating the src with information on how to fetch updates.

## There's no unified interface for fetchers

Each fetcher takes a similar set of arguments, but the various prefetch scripts are scattered and inconsistent.

(This also prevents `passthru` being supported consistently)

## Overlays are powerful, but hard to distribute

They require getting files onto the local machine before they can be used, or explicitly reimporting `<nixpkgs>` in each expression that needs an overlay.
Seems like this should be improved by flakes.

