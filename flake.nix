{
  description = "Logwatch for NixOS";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs";

  outputs = { self, nixpkgs, ... }:
    {
      nixosModules = {
        logwatch = import ./logwatch.nix;
      };
    };
}

