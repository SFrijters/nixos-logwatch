{
  lib,
  writeTextDir,
  runCommandLocal,
  symlinkJoin,
  makeWrapper,
  perlPackages,
  logwatch-unwrapped,
  extraConfig ? null,
  customServices ? [ ],
  extraPath ? [ ],
  extraPerl5Lib ? [ ],
}:
let
  unwrapped = logwatch-unwrapped;

  mkCustomService =
    {
      name,
      title ? null,
      output ? "cat",
      unit ? null,
      script ? null,
      preIgnore ? null,
      extraConfig ? "",
      extraFixup ? "",
    }:
    let
      serviceConf = writeTextDir "conf/services/${name}.conf" ''
        ${lib.optionalString (title != null) ''Title = "${title}"''}
        LogFile =
        LogFile = none
        *JournalCtl = "--output=${output} --unit=${if unit != null then unit else "${name}.service"}"
        ${lib.optionalString (preIgnore != null) ''Pre_Ignore = "${preIgnore}"''}
        ${extraConfig}
      '';
      serviceScript = runCommandLocal "logwatch-service-${name}-script" { } ''
        mkdir -p $out/scripts/services
        cp ${
          if (script != null) then script else "${unwrapped}/usr/share/logwatch/scripts/services/${name}"
        } $out/scripts/services/${name}

        eval ${extraFixup}
      '';
    in
    symlinkJoin {
      name = "logwatch-service-${name}";
      paths = [
        serviceConf
        serviceScript
      ];
    };

  mkConfFile =
    config:
    writeTextDir "conf/logwatch.conf" (
      ''
        TmpDir = /tmp
      ''
      + lib.optionalString (config != null) ''
        ${lib.optionalString (config.mailer != null) ''mailer = ${config.mailer}''}
        ${lib.optionalString (config.archives != null)
          ''Archives = ${if config.archives then "Yes" else "No"}''
        }
        ${lib.optionalString (config.mailto != null) ''MailTo = ${config.mailto}''}
        ${lib.optionalString (config.mailfrom != null) ''MailFrom = ${config.mailfrom}''}
        ${lib.optionalString (config.range != null) ''Range = ${config.range}''}
        ${lib.optionalString (config.detail != null) ''Detail = ${config.detail}''}
      ''
      + lib.concatMapStrings (s: "Service = ${s}\n") (config.services or [ ])
    );

  customConfig = symlinkJoin {
    name = "logwatch-config";
    paths = [
      (map mkCustomService customServices)
      (mkConfFile extraConfig)
    ];
  };

  wrapper =
    runCommandLocal "${unwrapped.name}-wrapped"
      {
        nativeBuildInputs = [ makeWrapper ];

        passthru = {
          inherit unwrapped;
        };

        meta.mainProgram = "logwatch";
      }
      ''
        makeWrapper ${unwrapped}/bin/logwatch $out/bin/logwatch \
          --prefix PERL5LIB : "${perlPackages.makePerlPath extraPerl5Lib}" \
          --prefix PATH : "${lib.makeBinPath extraPath}" \
          --set NIX_LOGWATCH_CONF_PATH ${customConfig}
      '';
in
wrapper
