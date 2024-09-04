{ writeShellApplication }:

writeShellApplication {
  name = "logwatch-nix-gc";
  text = ''
    cat - | grep -i "store paths deleted"
  '';
}
