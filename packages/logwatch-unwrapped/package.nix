{
  stdenvNoCC,
  lib,
  fetchgit,
  makeWrapper,
  versionCheckHook,
  perl,
  perlPackages,
  gnugrep,
  net-tools,
  gzip,
  bzip2,
  xz,
}:
let
  # For unstable versions: set rev not-null, for stable versions: set tag not-null
  rev = "9fab253d061ac1e68f019c31ef1d29fdcef38cd8";
  tag = null;
  date = "2026-03-14";
  hash = "sha256-m9sjgYi7OO+e/klnz2Q10Hxcucv/KO08O3A2HXbrdr4=";
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

    runHook postInstall
  '';

  postFixup = ''
    substituteInPlace $out/bin/logwatch \
      --replace-fail "/usr/share"    "$out/usr/share"     \
      --replace-fail '"/etc/logwatch"' "\$ENV{'NIX_LOGWATCH_CONF_PATH'} ? \$ENV{'NIX_LOGWATCH_CONF_PATH'} : \"$out/etc/logwatch\"" \
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
          net-tools
          gzip
          bzip2
          xz
        ]
      }" \
      --set pathto_ifconfig "${lib.getExe' net-tools "ifconfig"}"
  '';

  nativeInstallCheckInputs = [ versionCheckHook ];
  versionCheckProgramArg = [ "--version" ];
  doInstallCheck = true;

  __structuredAttrs = true;

  meta = {
    description = "A customizable log analysis system";
    longDescription = ''
      A customizable log analysis system. Logwatch parses through your system's logs and creates a report analyzing areas that you specify.
      Logwatch is easy to use and will work right out of the package on most systems.
    '';
    homepage = "https://sourceforge.net/projects/logwatch/";
    maintainers = with lib.maintainers; [ sfrijters ];
    license = with lib.licenses; [ mit ];
    mainProgram = "logwatch";
  };
}
