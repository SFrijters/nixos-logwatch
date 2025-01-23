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
      customServices
      extraFixup
      ;
  };

  logwatch = pkgs.callPackage ../packages/logwatch.nix { inherit packageConfig; };
in
{
  options.services.logwatch = {
    enable = lib.mkEnableOption "logwatch";

    startAt = lib.mkOption {
      default = "*-*-* 4:00:00";
      type = with types; either singleLineStr (listOf singleLineStr);
      example = [
        "daily"
        "*-*-* 12:00:00"
      ];
      description = "When to run";
    };
    persistent = lib.mkOption {
      default = true;
      type = types.bool;
      example = false;
      description = ''
        Takes a boolean argument. If true, the time when the service
        unit was last triggered is stored on disk. When the timer is
        activated, the service unit is triggered immediately if it
        would have been triggered at least once during the time when
        the timer was inactive. Such triggering is nonetheless
        subject to the delay imposed by RandomizedDelaySec=. This is
        useful to catch up on missed runs of the service when the
        system was powered down.
      '';
    };
    randomizedDelaySec = lib.mkOption {
      default = "0m";
      type = types.singleLineStr;
      example = "12h";
      description = ''
        Add a randomized delay before each logwatch run.
        The delay will be chosen between zero and this value.
        This value must be a time span in the format specified by
        {manpage}`systemd.time(7)`
      '';
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
      type = types.singleLineStr;
      description = "Recipient of the reports";
    };
    mailfrom = lib.mkOption {
      default = "Logwatch";
      type = types.singleLineStr;
      description = "Name of the sender of the reports";
    };
    range = lib.mkOption {
      default = "Yesterday";
      type = types.singleLineStr;
      description = "Time range to digest (use logwatch --range Help for details)";
    };
    detail = lib.mkOption {
      default = "Low";
      type = types.singleLineStr;
      description = "Detail level of the analysis";
    };
    services = lib.mkOption {
      default = [ "All" ];
      type = types.listOf types.singleLineStr;
      description = "Which services to digest";
    };
    customServices = lib.mkOption {
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
    environment.systemPackages = [ logwatch ];
    systemd.services.logwatch = {
      description = "Digests the system logs";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = ''${lib.getExe logwatch} --output mail'';
        PrivateTmp = true;
      };
    };

    systemd.timers.logwatch = {
      description = "Periodically digests the system logs";
      wantedBy = [ "timers.target" ];
      after = [ "network.target" ];
      timerConfig = {
        OnCalendar = if builtins.isString cfg.startAt then [ cfg.startAt ] else cfg.startAt;
        Persistent = cfg.persistent;
        RandomizedDelaySec = cfg.randomizedDelaySec;
      };
    };
  };
}
