let
  pkgs = import <nixpkgs> { };
in
with pkgs;
mkShell {
  buildInputs = [
    pandoc
    zip
    nixpkgs-fmt
    shellcheck
  ];
}
