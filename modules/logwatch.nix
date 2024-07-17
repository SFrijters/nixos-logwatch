{
  lib,
  pkgs,
  config,
  ...
}:
let
  # Inspiration from https://git.lamsade.dauphine.fr/tamby/nixos-router/-/blob/master/pkgs/logwatch.nix
  #                  https://sourceforge.net/p/logwatch/discussion/1115929/thread/99b02722/
  cfg = config.services.logwatch;
  types = lib.types;

  logwatch = pkgs.callPackage ../packages/logwatch.nix { journalCtlEntries = cfg.journalCtlEntries; };

  logwatchWithTemp = pkgs.writeShellApplication {
    name = "logwatch";

    runtimeInputs = [ logwatch ];

    text = ''
      __logwatch_pre() {
        rm -rf /tmp/logwatch
        mkdir -p /tmp/logwatch
        echo " " > /var/log/logwatch-null.log
      }

      __logwatch_post() {
        rm -rf /tmp/logwatch
        rm -f /var/log/logwatch-null.log
      }

      trap __logwatch_post EXIT

      __logwatch_pre
      ${logwatch}/bin/logwatch "$@"
    '';
  };
in
{
  options.services.logwatch = {
    enable = lib.mkEnableOption "logwatch";
    mailto = lib.mkOption {
      default = "root";
      type = types.str;
      description = "Recipient of the reports";
    };
    range = lib.mkOption {
      default = "Yesterday";
      type = types.str;
      description = "Time range to digest (use logwatch --range Help for details)";
    };
    detail = lib.mkOption {
      default = "Low";
      type = types.str;
      description = "Detail level of the analysis";
    };
    service = lib.mkOption {
      default = "All";
      type = types.str;
      description = "Which services to digest";
    };
    startAt = lib.mkOption {
      default = "*-*-* 4:00:00";
      type = types.str;
      description = "When to run";
    };
    journalCtlEntries = lib.mkOption {
      default = [ ];
      type = types.listOf types.attrs;
      description = "What to watch";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ logwatchWithTemp ];
    systemd.services.logwatch = {
      description = "Digests the system logs";
      wantedBy = [ ];
      after = [ "network.target" ];
      startAt = "${cfg.startAt}";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = ''${logwatchWithTemp}/bin/logwatch --archives --range "${cfg.range}" --detail "${cfg.detail}" --service "${cfg.service}" --mailto "${cfg.mailto}"'';
        PrivateTmp = true;
      };
    };
  };
}
