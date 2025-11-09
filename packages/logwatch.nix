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
  net-tools,
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
    let
      mailer = if (c.mailer or "") != "" then c.mailer else (lib.getExe' postfix "sendmail") + " -t";
    in
    ''
      TmpDir = /tmp
      mailer = ${mailer}
      Archives = ${if c.archives or true then "Yes" else "No"}
      MailTo = ${c.mailto or "root"}
      MailFrom = ${c.mailfrom or "Logwatch"}
      Range = ${c.range or "Yesterday"}
      Detail = ${c.detail or "Low"}
    ''
    + lib.concatMapStrings (s: "Service = ${s}\n") (c.services or [ "All" ]);

  # For unstable versions: set rev not-null, for stable versions: set tag not-null
  rev = "fd1cb9c93eeb2fd364adff1c68ac8d9276a8d2ca";
  tag = null;
  date = "2025-11-02";
  hash = "sha256-5InufdLEjs0GnTZM2e5TlhvtsG5q2GPsNIQvtgEGN1c=";
in
stdenvNoCC.mkDerivation {
  pname = "logwatch";
  version =
    assert tag == null || rev == null;
    if tag != null then tag else "unstable-${date}";

  __structuredAttrs = true;

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

  postPatch = ''
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

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    sh install_logwatch.sh
    cp ${confFile} $out/usr/share/logwatch/default.conf/logwatch.conf
  ''
  + (lib.concatMapStrings mkCustomService packageConfig.customServices or [ ])
  + ''
    runHook postInstall
  '';

  postFixup = ''
    substituteInPlace $out/bin/logwatch \
      --replace-fail "/usr/share"    "$out/usr/share"     \
      --replace-fail "/etc/logwatch" "$out/etc/logwatch"  \
      --replace-fail "/usr/bin/perl" "${lib.getExe perl}" \
      --replace-fail "/var/cache"    "/tmp"

    wrapProgram $out/bin/logwatch \
      --prefix PERL5LIB : "${
        with perlPackages;
        makePerlPath (
          [
            DateManip
            HTMLParser
            SysCPU
            SysMemInfo
          ]
          ++ packageConfig.extraPerl5Lib or [ ]
        )
      }" \
      --prefix PATH : "${
        lib.makeBinPath (
          [
            gnugrep
            net-tools
            gzip
            bzip2
            xz
          ]
          ++ packageConfig.extraPath or [ ]
        )
      }" \
      --set pathto_ifconfig "${lib.getExe' net-tools "ifconfig"}"
  ''
  + (lib.concatMapStrings (cs: cs.extraFixup or "") (packageConfig.customServices or [ ]))
  + packageConfig.extraFixup or "";

  nativeInstallCheckInputs = [ versionCheckHook ];
  versionCheckProgramArg = [ "--version" ];
  doInstallCheck = true;

  meta.mainProgram = "logwatch";
}
