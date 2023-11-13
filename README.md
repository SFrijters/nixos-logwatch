# nixos-logwatch

This flake provides a NixOS module for [logwatch](https://sourceforge.net/projects/logwatch/).

It probably does not cover all use cases, as it has been lifted out of my personal configuration.
Any suggestions or PR are welcome!

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
  journalCtlEntries = [
    { name = "sshd"; }
    { name = "postfix"; output = "short"; }
    { name = "sudo"; unit = "session*"; }
  ]
};
```

Available options:
* `enable`: Whether to enable the service.
* `mailto`: Recipient of the reports.
* `range`: Time range to digest (use logwatch --range Help for details).
* `detail`: Detail level of the analysis.
* `service`: Which services to digest.
* `startAt`: When to run.
* `journalCtlEntries`: What to watch (see below).

## Advanced usage

The option `services.logwatch.journalCtlEntries` contains attribute sets with the following name-value-pairs:

* `name`: The name of the journalctl service that is watched.
* `title` (optional): The title of the section in the report.
* `output` (optional): Forwarded to the `--output` flag of journalctl. Defaults to `cat`.
* `unit` (optional): Forwarded to the `--unit` flake of journalctl. Defaults to `${name}.service`.
* `script` (optional): If the service does not have a script available in the logwatch package, you can provide your own here.

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
services.logwatch.journalCtlEntries = [
  {
    name = "nix-gc";
    title = "Nix garbage collection";
    script = "${lib.getExe logwatch-nix-gc-script}";
  }
  ...
];
```

Some useful / example scripts are provided as packages in this flake.
