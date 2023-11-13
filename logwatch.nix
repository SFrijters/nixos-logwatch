{ lib, pkgs, config, ... }:
let
  # Inspiration from https://git.lamsade.dauphine.fr/tamby/nixos-router/-/blob/master/pkgs/logwatch.nix
  #                  https://sourceforge.net/p/logwatch/discussion/1115929/thread/99b02722/
  cfg = config.services.logwatch;
  types = lib.types;

  logwatch = let
    mkJournalCtlEntry = { name, title ? null, output ? "cat", unit ? null, script ? null}:
      "echo -e '" + lib.optionalString (title != null) ''
        Title = "${title}"\n
      '' + ''
        LogFile =\nLogFile = logwatch-null\n*JournalCtl = "--output=${output} --unit=${if unit != null then unit else "${name}.service"}"\n' > $out/etc/logwatch/conf/services/${name}.conf
      '' + lib.optionalString (script != null) ''
        cp ${script} $out/etc/logwatch/scripts/services/${name}
      '';

  in pkgs.stdenvNoCC.mkDerivation {
    name = "logwatch";
    version = "unstable-2023-10-25";

    src = pkgs.fetchgit {
      url = "https://git.code.sf.net/p/logwatch/git";
      rev = "f811f4d8a2b46dcbef8f900618f59a4211d7a1d0";
      hash = "sha256-dkv4osfB3BqFaS9VitAuR9199QNxlsLiyXAi/1zG6GY=";
    };

    nativeBuildInputs = [
      pkgs.makeWrapper
    ];

    patchPhase = ''
      substituteInPlace install_logwatch.sh \
        --replace "/usr/share"      "$out/usr/share"          \
        --replace "/etc/logwatch"   "$out/etc/logwatch"       \
        --replace "/usr/bin/perl"   "${pkgs.perl}/bin/perl"   \
        --replace " perl "          " ${pkgs.perl}/bin/perl " \
        --replace "/usr/sbin"       "$out/bin"                \
        --replace "install -m 0755 -d \$TEMPDIR" ":"
    '';

    buildPhase = "";

    installPhase = ''
      mkdir -p $out/bin
      sh install_logwatch.sh

      # Null log necessary to be able to use journalctl
      echo -e "LogFile = logwatch-null.log" > $out/etc/logwatch/conf/logfiles/logwatch-null.conf
    '' + (lib.concatMapStrings mkJournalCtlEntry cfg.journalCtlEntries);

    postFixup = ''
      substituteInPlace $out/bin/logwatch \
        --replace "/usr/share"    "$out/usr/share"        \
        --replace "/etc/logwatch" "$out/etc/logwatch"     \
        --replace "/usr/bin/perl" "${pkgs.perl}/bin/perl" \
        --replace "/var/cache"    "/tmp"

      substituteInPlace $out/usr/share/logwatch/default.conf/logwatch.conf \
        --replace "/usr/sbin/sendmail"  "${pkgs.postfix}/bin/sendmail" \
        --replace "/var/cache"          "/tmp"

      # Enable runtime stats
      substituteInPlace $out/usr/share/logwatch/default.conf/services/zz-runtime.conf \
        --replace '#$show_uptime = 0' '$show_uptime = 1'

      # Do not show unmatched entries; getting all messages from journalctl unit 'session*' contains a lot more stuff than only sudo
      substituteInPlace $out/usr/share/logwatch/scripts/services/sudo \
        --replace "if (keys %OtherList) {" "if (0) {"

      wrapProgram $out/bin/logwatch \
        --prefix PERL5LIB : "${with pkgs.perlPackages; makePerlPath [ DateManip HTMLParser SysCPU SysMemInfo ]}" \
        --prefix PATH : "${lib.makeBinPath [ pkgs.nettools pkgs.gzip pkgs.bzip2 pkgs.xz ]}" \
        --set pathto_ifconfig  "${pkgs.nettools}/bin/ifconfig"
    '';
  };

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
        default = [];
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
