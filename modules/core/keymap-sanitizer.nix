{ lib, ... }:
# Keep console keymap deterministic during evaluation. The previous sanitizer
# inspected `config.console.keyMap` while defining it, which caused infinite
# recursion during flake checks.
{
  config.console.keyMap = lib.mkDefault "us";
}
