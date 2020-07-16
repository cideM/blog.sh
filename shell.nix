let
  pkgs = import <nixpkgs> { };
  blog = import ./default.nix;
in
with pkgs;
mkShell {
  inherit blog;
  buildInputs = [
    pandoc
    zip
    nixpkgs-fmt
    shellcheck
  ];
}
