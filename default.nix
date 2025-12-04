final: prev: {
  logwatch = final.callPackage ./packages/logwatch.nix { };

  logwatch-scripts = final.lib.makeScope final.newScope (self: {
    passthrough = self.callPackage ./packages/logwatch-scripts/passthrough.nix { };
    nix-gc = self.callPackage ./packages/logwatch-scripts/nix-gc.nix { };
    nixos-upgrade = self.callPackage ./packages/logwatch-scripts/nixos-upgrade.nix { };
  });

  nix-gc-script = final.lib.warn "Attribute nix-gc-script is deprecated, use logwatch-scripts.nix-gc instead" final.logwatch-scripts.nix-gc;
  nixos-upgrade-script = final.lib.warn "Attribute nixos-upgrade-script is deprecated, use logwatch-scripts.nixos-upgrade instead" final.logwatch-scripts.nixos-upgrade;
  passthrough-script = final.lib.warn "Attribute passthrough-script is deprecated, use logwatch-scripts.passthrough instead" final.logwatch-scripts.passthrough;
}
