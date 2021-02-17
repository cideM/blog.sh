let
  sources = import ./nix/sources.nix;
  pkgs = import sources.nixpkgs { };
  netlify-cli = (import ./node/default.nix { inherit pkgs; }).netlify-cli;
  serve = (import ./node/default.nix { inherit pkgs; }).serve;
in
pkgs.mkShell {
  buildInputs = with pkgs; [
    netlify-cli
    serve
    pandoc
    zip
    nixpkgs-fmt
    shellcheck
    shfmt
    nodePackages.node2nix
    coreutils
    nodejs
    entr
  ];
}
