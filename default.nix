final: prev: {
  logwatch = final.callPackage ./packages/logwatch.nix { };
  nix-gc-script = final.callPackage ./packages/logwatch-scripts/nix-gc.nix { };
  nixos-upgrade-script = final.callPackage ./packages/logwatch-scripts/nixos-upgrade.nix { };
}
