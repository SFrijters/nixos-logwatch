# Changelog

NOTE: This changelog only covers changes to the flake, not to the upstream logwatch.

## 7.14

* logwatch and its configuration have been separated: the unwrapped package `logwatch-unwrapped` is provided as an argument to the package `logwatch`, which additionally takes extra configuration arguments and combines it into a wrapped derivation.
* Breaking change: the customization option `extraFixup` has been removed. If you need to tweak the logwatch package directly, override the `logwatch-unwrapped` package in the usual way; if you need to tweak a service file, use `customServices.extraFixup`. A new `customServices.extraConfig` option is also available.
* Breaking change: the overlay now provides a scope `logwatch-scripts`, inside of which the scripts can be found. The old derivation paths are deprecated.

## 7.12

* Breaking change: the module option `journalCtlEntries` has been renamed to `customServices`.
* Extra customization options `persistent`, `randomizedDelaySec`, `archives`, `mailfrom` and `extraFixup` are available, see [README.md](README.md) for their use. Also, individual custom services now accept the `extraFixup` attribute.
* Runtime stats are no longer enabled by default because it was a hardcoded hack. If you want the old behaviour, add

```bash
  substituteInPlace $out/usr/share/logwatch/default.conf/services/zz-runtime.conf \
    --replace-fail '#$show_uptime = 0' '$show_uptime = 1'
```

  to `extraFixup`.

* Enabling sudo as a service will now be more spammy by default, because working around it was a hardcoded hack. If you want the old behaviour, add

```bash
   substituteInPlace $out/usr/share/logwatch/scripts/services/sudo \
     --replace-fail "if (keys %OtherList) {" "if (0) {"
```

  to the `extraFixup` attribute of the `sudo` service.
