{
  description = "Hypervisor Suite - bootable NixOS with VM menu";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in {
        packages.iso = pkgs.nixos ({ config, pkgs, ... }: {
          imports = [ ./configuration/configuration.nix ];
        }).config.system.build.isoImage;
        defaultPackage = self.packages.${system}.iso;
      });
}
