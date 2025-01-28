# Changelog

NOTE: This changelog only covers changes to the flake, not to the upstream logwatch.

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
