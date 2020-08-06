let
  pkgs = import <nixpkgs> { };
  netlify-cli = (import ./node/default.nix { inherit pkgs; }).netlify-cli;
in
with pkgs;
mkShell {
  buildInputs = [
    netlify-cli
    pandoc
    zip
    nixpkgs-fmt
    shellcheck
    coreutils
    nodejs
    entr
  ];
}
