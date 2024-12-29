{
  description = "Logwatch for NixOS";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs";

  outputs =
    {
      self,
      nixpkgs,
      ...
    }:
    let
      forAllSystems =
        function:
        nixpkgs.lib.genAttrs [
          "x86_64-linux"
          "aarch64-linux"
          "x86_64-darwin"
          "aarch64-darwin"
        ] (system: function nixpkgs.legacyPackages.${system});
    in
    {
      nixosModules.logwatch = import ./modules/logwatch.nix;

      overlays.default = import ./.;

      packages = forAllSystems (pkgs: rec {
        default = logwatch;
        logwatch = pkgs.callPackage ./packages/logwatch.nix { };
        passthrough-script = pkgs.callPackage ./packages/logwatch-scripts/passthrough.nix { };
        nix-gc-script = pkgs.callPackage ./packages/logwatch-scripts/nix-gc.nix { };
        nixos-upgrade-script = pkgs.callPackage ./packages/logwatch-scripts/nixos-upgrade.nix { };
      });

      checks = forAllSystems (pkgs: {
        default = pkgs.nixosTest {
          name = "logwatch-module-test";

          nodes.server =
            { ... }:
            {

              imports = [ self.nixosModules.logwatch ];

              environment.systemPackages = [ pkgs.mailutils ];

              services = {
                postfix.enable = true;
                logwatch = {
                  enable = true;
                  range = "since 24 hours ago for those hours";
                  services = [
                    "All"
                    "-zz-network"
                  ];
                  customServices = [
                    {
                      name = "postfix";
                      output = "short";
                    }
                  ];
                  extraFixup = ''
                    # Enable runtime stats
                    substituteInPlace $out/usr/share/logwatch/default.conf/services/zz-runtime.conf \
                      --replace-fail '#$show_uptime = 0' '$show_uptime = 1'
                  '';
                };
              };

              virtualisation.diskSize = 128; # MB
            };

          testScript =
            let
              inherit (pkgs) system;
            in
            ''
              import time
              start_all()
              server.wait_for_unit("default.target")

              # Force restart of logwatch so it sends a mail
              server.systemctl("restart logwatch")
              # VMs on CI runners can be kind of slow, delay here
              time.sleep(3)

              # Get all mails for root and check if the expected data is there
              mail = server.succeed("mail -p")
              print(mail)
              if "Subject: Logwatch for server" not in mail:
                  raise Exception("Missing text 'Subject: Logwatch for server' in output of 'mail -p'")
              if "unstable" not in "${self.packages.${pkgs.system}.logwatch.version}":
                  if "Logwatch ${self.packages.${pkgs.system}.logwatch.version}" not in mail:
                      raise Exception("Missing text 'Logwatch ${
                        self.packages.${pkgs.system}.logwatch.version
                      } in output of 'mail -p'")
              else:
                  if "Logwatch ${self.packages.${pkgs.system}.logwatch.src.rev}" not in mail:
                      raise Exception("Missing text 'Logwatch ${
                        self.packages.${pkgs.system}.logwatch.src.rev
                      } in output of 'mail -p'")

              if "Network statistics" in mail:
                  raise Exception("Network statistics should have been disabled in 'services'")

              if "Uptime" not in mail:
                  raise Exception("Uptime should have been enabled in 'extraFixup'")

              # Clean mailbox
              server.succeed("echo 'd *' | mail -N")

              # Force restart of logwatch to re-analyze to logs
              # It should now include a delivered mail in the Postfix output
              server.systemctl("restart logwatch")
              # VMs on CI runners can be kind of slow, delay here
              time.sleep(3)

              # Get all mails for root and check if the expected data is there
              mail = server.succeed("mail -p")
              print(mail)
              if "1   Delivered" not in mail:
                  raise Exception("Missing test '1   Delivered' in output of 'mail -p', should have been enabled in 'customServices'")

              text = server.succeed("logwatch --output stdout")
              print(text)
              if "2   Delivered" not in text:
                  raise Exception("Missing test '2   Delivered' in output of 'logwatch --output stdout'")

              # Ensure we didn't send email along with the stdout
              text = server.succeed("logwatch --output stdout")
              print(text)
              if "2   Delivered" not in text:
                  raise Exception("Missing test '2   Delivered' in output of 'logwatch --output stdout'")
            '';
        };
      });

      formatter = forAllSystems (pkgs: pkgs.nixfmt-rfc-style);
    };
}
