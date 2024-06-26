{
  description = "Common Lisp Gemini server.";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-23.11";
    utils.url = "github:numtide/flake-utils";
    lisp-repo.url = "github:fudoniten/nix-lisp-packages";
    cl-gemini = {
      url = "github:fudoniten/cl-gemini";
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
          cl-gemini =
            import ./module.nix { inherit (lisp-repo.lib) lispSourceRegistry; };
          default = cl-gemini;
        };
      };
}
