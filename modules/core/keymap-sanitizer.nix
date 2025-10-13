{ config, lib, ... }:
# Ensures a valid console keymap; fixes builds where "(unset)" sneaks in
{
  config = lib.mkIf (let
    key = (config.console.keyMap or "");
    lower = lib.toLower key;
  in builtins.elem lower [ "(unset)" "unset" "n/a" "-" "" ]) {
    console.keyMap = lib.mkForce "us";
  };
}
