let
  pkgs = import <nixpkgs> { };
  netlify-cli = (import ./node/default.nix { inherit pkgs; }).netlify-cli;
  serve = (import ./node/default.nix { inherit pkgs; }).serve;
in
with pkgs;
mkShell {
  buildInputs = [
    netlify-cli
    serve
    pandoc
    zip
    nixpkgs-fmt
    shellcheck
    nodePackages.node2nix
    coreutils
    nodejs
    entr
  ];
}
