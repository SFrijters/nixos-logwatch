# nixos-logwatch

[![nix flake check](https://github.com/SFrijters/nixos-logwatch/actions/workflows/nix-flake-check.yml/badge.svg)](https://github.com/SFrijters/nixos-logwatch/actions/workflows/nix-flake-check.yml)

This flake provides a NixOS module for [logwatch](https://sourceforge.net/projects/logwatch/).

It probably does not cover all use cases, as it has been lifted out of my personal configuration.
Any suggestions or PR are welcome!

The `master` branch of this repository packages [tagged logwatch releases](https://sourceforge.net/p/logwatch/git/ci/7.13/tree/) (currently 7.13), while the `unstable` branch will be updated more regularly following the [logwatch master branch](https://sourceforge.net/p/logwatch/git/ci/master/tree/).

## Basic usage

In your flake.nix: add this flake to your inputs:

```nix
inputs = {
  ...
  nixos-logwatch = {
    url = "github:SFrijters/nixos-logwatch";
    inputs.nixpkgs.follows = "nixpkgs";  # It's probably best to follow your existing nixpkgs
  };
};
```

and add `nixos-logwatch.nixosModules.logwatch` to your modules.

In your configuration.nix:

```nix
services.logwatch = {
  enable = true;
  range = "since 24 hours ago for those hours";
  customServices = [
    { name = "sshd"; }
    { name = "postfix"; output = "short"; }
    { name = "sudo"; unit = "session*"; }
  ];
};
```

Available options:

* Service options:
  * `enable`: Whether to enable the service.
  * `startAt`: When to run. Defaults to `"*-*-* 4:00:00"`.
  * `persistent`: Run the service to catch up if a trigger moment has been missed. Defaults to `true`.
  * `randomizedDelaySec`: Randomized delay on top of the `startAt` time(s). Defaults to `"0m"`.

* Logwatch options:
  * `mailer`: Which mailer command to use. Defaults to using postfix.
  * `archives`: Use archived log files too. Defaults to `true`.
  * `mailto`: Recipient of the reports. Defaults to `"root"`.
  * `mailfrom`: Name of the sender of the reports. Defaults to `"Logwatch"`.
  * `range`: Date range: Yesterday, Today, All, Help where help will describe additional options. Defaults to `"Yesterday"`.
  * `detail`: Report Detail Level - High, Med, Low or any #. Defaults to `"Low"`.
  * `services`: Which services to digest, by name. Defaults to `[ "All" ]`.
  * `customServices`: See below.
  * `extraFixup`: Arbitrary customization commands, added to the end of the fixupPhase.
  * `extraPath`: List of packages to be added to PATH for logwatch, in case any (custom) modules need them. Defaults to the empty list.
  * `extraPerl5Lib`: List of packages to be added to the PERL5LIB path for logwatch, in case any (custom) modules need them. Defaults to the empty list.

## Advanced usage

The option `services.logwatch.customServices` contains attribute sets with the following name-value-pairs:

* `name`: The name of the journalctl service that is watched.
* `title` (optional): The title of the section in the report.
* `output` (optional): Forwarded to the `--output` flag of journalctl. Defaults to `cat`.
* `unit` (optional): Forwarded to the `--unit` flake of journalctl. Defaults to `${name}.service`.
* `script` (optional): If the service does not have a script available in the logwatch package, you can provide your own here.
* `preIgnore` (optional): Adds the Pre_Ignore setting to the config. Value should be a `grep -E` compatible regex.
* `extraFixup` (optional): Extra commands to run to fix up the logwatch package, e.g. tweak existing scripts.

Example:

```nix
logwatch-nix-gc-script = pkgs.writeShellApplication {
  name = "logwatch-nix-gc";
  text = ''
    cat - | grep -i "store paths deleted"
  '';
};
```

```nix
services.logwatch.customServices = [
  {
    name = "nix-gc";
    title = "Nix garbage collection";
    script = "${lib.getExe logwatch-nix-gc-script}";
  }
  ...
];
```

Some useful / example scripts are provided as packages in this flake.

If you are an advanced user, you can also get inspiration from the `check` in the flake.
