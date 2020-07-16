let
  pkgs = import <nixpkgs> {};

in 
  with pkgs;
  stdenv.mkDerivation {
    pname = "fbrs-blog";
    version = "latest";
    src = ./.;

    buildInputs = [ pandoc ];

    buildPhase = ''
      ./make build
    '';

    installPhase = ''
      cp -R public $out
    '';
  }
