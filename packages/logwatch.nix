{
  stdenvNoCC,
  lib,
  fetchgit,
  makeWrapper,
  perl,
  perlPackages,
  postfix,
  nettools,
  gzip,
  bzip2,
  xz,
  journalCtlEntries ? [ ],
  removeScripts ? [ ],
}:
let
  mkJournalCtlEntry =
    {
      name,
      title ? null,
      output ? "cat",
      unit ? null,
      script ? null,
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
      }"\n' > $out/etc/logwatch/conf/services/${name}.conf
    ''
    + lib.optionalString (script != null) ''
      cp ${script} $out/etc/logwatch/scripts/services/${name}
    '';

  # For unstable versions: set rev not-null, for stable versions: set tag not-null
  rev = "607f7295353157c1600f56f07395b852cec2a97b";
  tag = null;
  date = "2024-12-23";
  hash = "sha256-YkHqeDm3fVA0MdkeLqbBdtsdYN+42NIB3lvtGK22wvQ=";
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

  nativeBuildInputs = [ makeWrapper ];

  patchPhase =
    ''
      runHook prePatch

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
        scripts/logwatch.pl
    ''
    + ''
      runHook postPatch
    '';

  dontConfigure = true;
  dontBuild = true;

  installPhase =
    ''
      mkdir -p $out/bin
      sh install_logwatch.sh
    ''
    + (lib.concatMapStrings mkJournalCtlEntry journalCtlEntries);

  postFixup =
    ''
      substituteInPlace $out/bin/logwatch \
        --replace-fail "/usr/share"    "$out/usr/share"     \
        --replace-fail "/etc/logwatch" "$out/etc/logwatch"  \
        --replace-fail "/usr/bin/perl" "${lib.getExe perl}" \
        --replace-fail "/var/cache"    "/tmp"

      {
          echo "TmpDir = /tmp/logwatch";
          echo "mailer = \"${lib.getExe' postfix "sendmail"} -t\"";
          echo "MailFrom = Logwatch"
      } >> $out/usr/share/logwatch/default.conf/logwatch.conf

      # Enable runtime stats
      substituteInPlace $out/usr/share/logwatch/default.conf/services/zz-runtime.conf \
        --replace-fail '#$show_uptime = 0' '$show_uptime = 1'

      # Do not show unmatched entries; getting all messages from journalctl unit 'session*' contains a lot more stuff than only sudo
      substituteInPlace $out/usr/share/logwatch/scripts/services/sudo \
        --replace-fail "if (keys %OtherList) {" "if (0) {"

    ''
    + (lib.concatMapStrings (
      f: "rm $out/usr/share/logwatch/default.conf/services/${f}.conf;"
    ) removeScripts)
    + ''

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
            nettools
            gzip
            bzip2
            xz
          ]
        }" \
        --set pathto_ifconfig  "${lib.getExe' nettools "ifconfig"}"
    '';
}
