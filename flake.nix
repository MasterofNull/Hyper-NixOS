{
  description = "Hypervisor Suite - bootable NixOS with VM menu";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = inputs@{ self, nixpkgs, flake-utils }:
    let
      lib = nixpkgs.lib;
    in
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in {
        # Bootable ISO image that embeds this configuration
        packages.iso = pkgs.nixos ({ config, pkgs, ... }: {
          imports = [ ./configuration/configuration.nix ];
        }).config.system.build.isoImage;

        # Convenience apps for bootstrap and rebuild helper
        apps.bootstrap = {
          type = "app";
          program = lib.getExe (pkgs.writeShellScriptBin "hypervisor-bootstrap" ''
            exec ${pkgs.bash}/bin/bash ${./scripts/bootstrap_nixos.sh} "$@"
          '');
        };

        apps.rebuild-helper = {
          type = "app";
          program = lib.getExe (pkgs.writeShellScriptBin "hypervisor-rebuild" ''
            exec ${pkgs.bash}/bin/bash ${./scripts/rebuild_helper.sh} "$@"
          '');
        };

        defaultPackage = self.packages.${system}.iso;
        defaultApp = self.apps.${system}.bootstrap;
      }
    ) // {
      # Host configurations for common architectures; the bootstrap selects the right one
      nixosConfigurations = {
        hypervisor-x86_64 = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [ ./configuration/configuration.nix ];
        };
        hypervisor-aarch64 = nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          modules = [ ./configuration/configuration.nix ];
        };
      };
    };
}
