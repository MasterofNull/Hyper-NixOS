{ config, lib, ... }:
# Ensures a valid console keymap; fixes builds where "(unset)" sneaks in
{
  config = let
    key = (config.console.keyMap or "");
    lower = lib.toLower key;
    invalid = builtins.elem lower [ "(unset)" "unset" "n/a" "-" "" ];
  in lib.mkIf invalid {
    console.keyMap = lib.mkForce "us";
  };
}
