let
  pkgs = import <nixpkgs> {};

in
  with pkgs;
  stdenv.mkDerivation {
    pname = "fbrs-blog";

    version = "latest";

    src = builtins.path {
      name = "source";
      path = ./.;
    };

    buildInputs = [ pandoc ];

    phases = [ "unpackPhase" "buildPhase" "installPhase" ];

    buildPhase = ''
       mkdir -p ./public
      ./build.sh
    '';

    installPhase = ''
      cp -R public $out
    '';
  }
