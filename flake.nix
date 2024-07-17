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
        packages = rec {
          default = logwatch;
          logwatch = pkgs.callPackage ./packages/logwatch.nix {};
          nix-gc-script = pkgs.callPackage ./packages/logwatch-scripts/nix-gc.nix {};
          nixos-upgrade-script = pkgs.callPackage ./packages/logwatch-scripts/nixos-upgrade.nix {};
        };

        checks.default = pkgs.nixosTest {
          name = "logwatch-module-test";

          nodes.server = { ... }: {

            imports = [
              self.nixosModules.logwatch
            ];

            environment.systemPackages = [
              pkgs.mailutils
            ];

            services = {
              logwatch.enable = true;
              postfix.enable = true;
            };
          };

          testScript = ''
            import time
            start_all()
            server.wait_for_unit("default.target")
            # Force restart of logwatch so it sends a mail
            server.systemctl("restart logwatch")
            # VMs on CI runners can be kind of slow, delay here
            time.sleep(3)
            # Get all mails for root and check if the expected subject is there
            mail = server.succeed("mail -p")
            print(mail)
            if "Subject: Logwatch for server" not in mail:
                raise
          '';
        };

        formatter = pkgs.nixfmt-rfc-style;
      }
    ) //
    {
      nixosModules = {
        logwatch = import ./modules/logwatch.nix;
      };
    };
}
