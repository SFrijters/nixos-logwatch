{ pkgs, ...}:

pkgs.writeShellApplication {
  name = "logwatch-nixos-upgrade";
  text = ''
    package_update_regex="^  */nix/store"
    keep_output_regex="updating lock file|updated input|github:NixOS/nixpkgs|will be built|will be fetched|^  /nix/store|switching to system configuration|NixOS Upgrade.|error: builder for"
    error_regex="error: builder for|Failed to start"

    last=

    while IFS= read -r line; do
        if [[ "''${line}" =~ ''${package_update_regex} ]]; then
            # shellcheck disable=SC2001
            package_name="$(echo "''${line}" | sed 's| */nix/store/[^\-]*-||')"
            printf "%s " "''${package_name}"
            last=package
        elif [[ "''${line}" =~ ''${keep_output_regex} ]]; then
            if [ "''${last}" = package ]; then
                printf "\n"
            fi
            if [[ "''${line}" =~ ''${error_regex} ]]; then
                echo
                echo "ERROR: ''${line}"
                echo
            else
                echo "''${line}"
            fi
            last=
        fi
    done
  '';
}
