{
  description = "Logwatch for NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        packages = rec {
          default = logwatch;
          logwatch = pkgs.callPackage ./packages/logwatch.nix { };
          nix-gc-script = pkgs.callPackage ./packages/logwatch-scripts/nix-gc.nix { };
          nixos-upgrade-script = pkgs.callPackage ./packages/logwatch-scripts/nixos-upgrade.nix { };
        };

        checks.default = pkgs.nixosTest {
          name = "logwatch-module-test";

          nodes.server =
            { ... }:
            {

              imports = [ self.nixosModules.logwatch ];

              environment.systemPackages = [ pkgs.mailutils ];

              services = {
                logwatch.enable = true;
                postfix.enable = true;
              };

              virtualisation.diskSize = 128; # MB
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
                raise Exception("Missing text 'Subject: Logwatch for server' in output of 'mail -p'")
            if "unstable" not in "${self.packages.${system}.logwatch.version}":
                if "Logwatch ${self.packages.${system}.logwatch.version}" not in mail:
                    raise Exception("Missing text 'Logwatch ${
                      self.packages.${system}.logwatch.version
                    } in output of 'mail -p'")
            else:
                if "Logwatch ${self.packages.${system}.logwatch.src.rev}" not in mail:
                    raise Exception("Missing text 'Logwatch ${
                      self.packages.${system}.logwatch.src.rev
                    } in output of 'mail -p'")
          '';
        };

        formatter = pkgs.nixfmt-rfc-style;
      }
    )
    // {
      nixosModules = {
        logwatch = import ./modules/logwatch.nix;
      };
    };
}
