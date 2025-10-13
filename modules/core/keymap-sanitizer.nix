{ config, lib, ... }:
# Ensures a valid console keymap; fixes builds where "(unset)" sneaks in
let
  key = (config.console.keyMap or "");
  lower = lib.toLower key;
  invalid = builtins.elem lower [ "(unset)" "unset" "n/a" "-" "" ];
in {
  config = lib.mkIf invalid {
    console.keyMap = lib.mkForce "us";
  };
}
