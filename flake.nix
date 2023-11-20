{
  description = "Logwatch for NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = nixpkgs.legacyPackages.${system}; in
      {
        packages = {
          logwatch = pkgs.callPackage ./packages/logwatch.nix {};
          nix-gc-script = pkgs.callPackage ./packages/logwatch-scripts/nix-gc.nix {};
          nixos-upgrade-script = pkgs.callPackage ./packages/logwatch-scripts/nixos-upgrade.nix {};
        };

      }
    ) //
    {
      nixosModules = {
        logwatch = import ./modules/logwatch.nix;
      };
    };
}
