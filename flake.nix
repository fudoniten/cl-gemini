{
  description = "Common Lisp Gemini server.";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-22.05";
    utils.url = "github:numtide/flake-utils";
    lisp-repo.url = "git+https://fudo.dev/public/lisp-repository.git";
    cl-gemini = {
      url = "git+https://fudo.dev/informis/cl-gemini.git";
      flake = false;
    };
  };

  outputs = { nixpkgs, lisp-repo, cl-gemini, utils, ... }:
    utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        lispPackages = pkgs.lispPackages // lisp-repo.packages."${system}";
      in {
        packages = rec {
          cl-gemini = pkgs.callPackage ./package.nix { inherit lispPackages; };
          cl-gemini-launcher =
            pkgs.callPackage ./launcher.nix { inherit lispPackages cl-gemini; };
          default = cl-gemini;
        };
      }) // {
        nixosModules = rec {
          cl-gemini = import ./module.nix;
          default = cl-gemini;
        };
      };
}
