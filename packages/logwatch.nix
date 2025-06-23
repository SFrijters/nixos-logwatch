{
  stdenvNoCC,
  lib,
  fetchgit,
  makeWrapper,
  writeText,
  versionCheckHook,
  perl,
  perlPackages,
  postfix,
  gnugrep,
  nettools,
  gzip,
  bzip2,
  xz,
  packageConfig ? null,
}:
let
  mkCustomService =
    {
      name,
      title ? null,
      output ? "cat",
      unit ? null,
      script ? null,
      preIgnore ? null,
      ...
    }:
    ''
      echo Adding JournalCtl entry '${name}'
    ''
    + "echo -e '"
    + lib.optionalString (title != null) ''
      Title = "${title}"\n
    ''
    + ''
      LogFile =\nLogFile = none\n*JournalCtl = "--output=${output} --unit=${
        if unit != null then unit else "${name}.service"
      }"\n${
        if preIgnore != null then "Pre_Ignore = \"${preIgnore}\"\n" else ""
      }' > $out/etc/logwatch/conf/services/${name}.conf
    ''
    + lib.optionalString (script != null) ''
      cp ${script} $out/etc/logwatch/scripts/services/${name}
    '';

  confFile = writeText "logwatch.conf" (mkConf packageConfig);

  mkConf =
    c:
    ''
      TmpDir = /tmp
      mailer = "${lib.getExe' postfix "sendmail"} -t"
      Archives = ${if c.archives or true then "Yes" else "No"}
      MailTo = ${c.mailto or "root"}
      MailFrom = ${c.mailfrom or "Logwatch"}
      Range = ${c.range or "Yesterday"}
      Detail = ${c.detail or "Low"}
    ''
    + lib.concatMapStrings (s: "Service = ${s}\n") (c.services or [ "All" ]);

  # For unstable versions: set rev not-null, for stable versions: set tag not-null
  rev = "36eb45fbb7071d6eccca9a125108c88acd88404c";
  tag = null;
  date = "2025-06-23";
  hash = "sha256-sSemDyjSD6aAmYVuhMAubvNbCCH8rgX8QcYOGsrwpnU=";
in
stdenvNoCC.mkDerivation {
  pname = "logwatch";
  version =
    assert tag == null || rev == null;
    if tag != null then tag else "unstable-${date}";

  src = fetchgit {
    inherit hash rev tag;
    url = "https://git.code.sf.net/p/logwatch/git";
  };

  strictDeps = true;

  nativeBuildInputs = [ makeWrapper ];

  patches = [
    # Add patch for pre_ignore with LogFile = none (i.e. JournalCtl)
    ./pre_ignore.patch
  ];

  postPatch =
    ''
      # Fix paths
      substituteInPlace install_logwatch.sh \
        --replace-fail "/usr/share"      "$out/usr/share"       \
        --replace-fail "/etc/logwatch"   "$out/etc/logwatch"    \
        --replace-fail "/usr/bin/perl"   "${lib.getExe perl}"   \
        --replace-fail " perl "          " ${lib.getExe perl} " \
        --replace-fail "/usr/sbin"       "$out/bin"             \
        --replace-fail "install -m 0755 -d \$TEMPDIR" ":"
    ''
    + lib.optionalString (tag == null) ''
      # Set version
      sed -i -e "s|^Version:.*|Version: ${rev}|" logwatch.spec
      sed -i \
        -e "s|^my \$Version = '.*';|my \$Version = '${rev}';|" \
        -e "s|^my \$VDate = '.*';|my \$VDate = '${date}';|" \
        -e "s|released \$VDate|unstable-\$VDate|" \
        scripts/logwatch.pl
    '';

  dontConfigure = true;
  dontBuild = true;

  installPhase =
    ''
      mkdir -p $out/bin
      sh install_logwatch.sh
      cp ${confFile} $out/usr/share/logwatch/default.conf/logwatch.conf
    ''
    + (lib.concatMapStrings mkCustomService packageConfig.customServices or [ ]);

  postFixup =
    ''
      substituteInPlace $out/bin/logwatch \
        --replace-fail "/usr/share"    "$out/usr/share"     \
        --replace-fail "/etc/logwatch" "$out/etc/logwatch"  \
        --replace-fail "/usr/bin/perl" "${lib.getExe perl}" \
        --replace-fail "/var/cache"    "/tmp"

      wrapProgram $out/bin/logwatch \
        --prefix PERL5LIB : "${
          with perlPackages;
          makePerlPath [
            DateManip
            HTMLParser
            SysCPU
            SysMemInfo
          ]
        }" \
        --prefix PATH : "${
          lib.makeBinPath [
            gnugrep
            nettools
            gzip
            bzip2
            xz
          ]
        }" \
        --set pathto_ifconfig "${lib.getExe' nettools "ifconfig"}"
    ''
    + (lib.concatMapStrings (cs: cs.extraFixup or "") (packageConfig.customServices or [ ]))
    + packageConfig.extraFixup or "";

  nativeInstallCheckInputs = [ versionCheckHook ];
  versionCheckProgramArg = [ "--version" ];
  doInstallCheck = true;

  meta.mainProgram = "logwatch";
}
