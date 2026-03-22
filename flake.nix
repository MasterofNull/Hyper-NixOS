{
  description = "Hyper-NixOS: Production-ready NixOS hypervisor with zero-trust security and enterprise automation";
  
  # Enable experimental features for flakes and nix-command
  nixConfig = {
    experimental-features = [ "nix-command" "flakes" ];
  };
  
  inputs = {
    # Flexible channel system - defaults to latest stable
    # Override with: nix build --override-input nixpkgs github:NixOS/nixpkgs/nixos-unstable
    # Or switch permanently with: ./scripts/switch-channel.sh

    # Default: Latest stable release (currently 25.05)
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";

    # Alternative channels (available for override):
    # - nixos-unstable: github:NixOS/nixpkgs/nixos-unstable (bleeding edge)
    # - nixos-25.05: github:NixOS/nixpkgs/nixos-25.05 (current stable)
    # - nixos-24.11: github:NixOS/nixpkgs/nixos-24.11 (previous stable)
    # - nixos-24.05: github:NixOS/nixpkgs/nixos-24.05 (older stable)

    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs = inputs@{ self, nixpkgs, flake-utils }:
    let lib = nixpkgs.lib;
    in flake-utils.lib.eachDefaultSystem (system:
      let pkgs = import nixpkgs {
            inherit system;
            # Allow unfree if user enables; keeps default permissive off
            config = { allowUnfree = false; };
          };
          # Build ISO using nixosSystem for proper module evaluation
          isoSystem = nixpkgs.lib.nixosSystem {
            inherit system;
            modules = [
              ./configuration.nix
              # ISO-specific configuration
              ({ config, pkgs, lib, modulesPath, ... }: {
                imports = [ (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix") ];
                # Ensure the ISO is bootable
                isoImage.makeEfiBootable = true;
                isoImage.makeUsbBootable = true;
              })
            ];
          };
      in {
        packages = {
          iso = isoSystem.config.system.build.isoImage;
          default = isoSystem.config.system.build.isoImage;
        };
        apps = {
          system-installer = {
            type = "app";
            program = lib.getExe (pkgs.writeShellScriptBin "hypervisor-system-installer" ''
              # Ensure git is in PATH for flake operations
              export PATH="${pkgs.git}/bin:$PATH"
              exec ${pkgs.bash}/bin/bash ${./scripts/system_installer.sh} "$@"
            '');
            meta = {
              description = "Interactive system installer for Hyper-NixOS";
              mainProgram = "hypervisor-system-installer";
            };
          };
          rebuild-helper = {
            type = "app";
            program = lib.getExe (pkgs.writeShellScriptBin "hypervisor-rebuild" ''
              # Ensure git is in PATH for flake operations
              export PATH="${pkgs.git}/bin:$PATH"
              exec ${pkgs.bash}/bin/bash ${./scripts/rebuild_helper.sh} "$@"
            '');
            meta = {
              description = "Helper script for rebuilding Hyper-NixOS configuration";
              mainProgram = "hypervisor-rebuild";
            };
          };
          default = self.apps.${system}.system-installer;
        };
      }
    ) // {
      nixosConfigurations = {
        # Template configurations for flake check validation
        # Replace with actual hardware-configuration.nix when deploying
        hypervisor-x86_64 = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./configuration.nix
            # Placeholder filesystem for template validation
            ({ lib, ... }: {
              fileSystems."/" = lib.mkDefault {
                device = "/dev/disk/by-label/nixos";
                fsType = "ext4";
              };
              boot.loader.grub.device = lib.mkDefault "/dev/sda";
            })
          ];
        };
        hypervisor-aarch64 = nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          modules = [
            ./configuration.nix
            # Placeholder filesystem for template validation
            ({ lib, ... }: {
              fileSystems."/" = lib.mkDefault {
                device = "/dev/disk/by-label/nixos";
                fsType = "ext4";
              };
              boot.loader.grub.device = lib.mkDefault "/dev/sda";
            })
          ];
        };
      };
    };
}
