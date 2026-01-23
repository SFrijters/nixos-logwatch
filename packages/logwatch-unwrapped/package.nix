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
  rev = "125b7f019a0e15b0b796f11ce9a64e0a33535ee6";
  tag = null;
  date = "2026-01-22";
  hash = "sha256-OIpzTqjkDYnPAusOUTFSnU+BCAeLEsQkYTJJnNGjhg8=";
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

  meta.mainProgram = "logwatch";
}
