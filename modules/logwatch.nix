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

  packageConfig = {
    inherit (cfg)
      archives
      mailto
      mailfrom
      range
      detail
      services
      journalctlEntries
      extraFixup
      ;
  };

  logwatch = pkgs.callPackage ../packages/logwatch.nix { inherit packageConfig; };

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
    startAt = lib.mkOption {
      default = "*-*-* 4:00:00";
      type = types.str;
      description = "When to run";
    };
    archives = lib.mkOption {
      default = true;
      type = types.bool;
      description = ''
        Use archives?  If set to 'Yes', the archives of logfiles
        (i.e. /var/log/messages.1 or /var/log/messages.1.gz) will
        be searched in addition to the /var/log/messages file.
      '';
    };
    mailto = lib.mkOption {
      default = "root";
      type = types.str;
      description = "Recipient of the reports";
    };
    mailfrom = lib.mkOption {
      default = "Logwatch";
      type = types.str;
      description = "Name of the sender of the reports";
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
    services = lib.mkOption {
      default = [ "All" ];
      type = types.listOf types.str;
      description = "Which services to digest";
    };
    journalctlEntries = lib.mkOption {
      default = [ ];
      type = types.listOf types.attrs;
      description = "What to watch";
    };
    extraFixup = lib.mkOption {
      default = "";
      type = types.str;
      description = "Arbitrary customization commands, added to the end of the fixupPhase";
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
        ExecStart = ''${logwatchWithTemp}/bin/logwatch --output mail'';
        PrivateTmp = true;
      };
    };
  };
}
