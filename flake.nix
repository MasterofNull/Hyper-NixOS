{
  description = "Hyper-NixOS: Production-ready NixOS hypervisor with zero-trust security and enterprise automation";
  
  # Enable experimental features for flakes and nix-command
  nixConfig = {
    experimental-features = [ "nix-command" "flakes" ];
  };
  
  inputs = {
    # Track latest NixOS; pin via flake.lock for reproducibility
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
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
      in {
        packages.iso = pkgs.nixos ({ config, pkgs, ... }: {
          imports = [ ./configuration.nix ];
        }).config.system.build.isoImage;
        apps.system-installer = {
          type = "app";
          program = lib.getExe (pkgs.writeShellScriptBin "hypervisor-system-installer" ''
            # Ensure git is in PATH for flake operations
            export PATH="${pkgs.git}/bin:$PATH"
            exec ${pkgs.bash}/bin/bash ${./scripts/system_installer.sh} "$@"
          '');
        };
        apps.rebuild-helper = {
          type = "app";
          program = lib.getExe (pkgs.writeShellScriptBin "hypervisor-rebuild" ''
            # Ensure git is in PATH for flake operations
            export PATH="${pkgs.git}/bin:$PATH"
            exec ${pkgs.bash}/bin/bash ${./scripts/rebuild_helper.sh} "$@"
          '');
        };
        defaultPackage = self.packages.${system}.iso;
        defaultApp = self.apps.${system}.system-installer;
      }
    ) // {
      nixosConfigurations = {
        hypervisor-x86_64 = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [ ./configuration.nix ];
        };
        hypervisor-aarch64 = nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          modules = [ ./configuration.nix ];
        };
      };
    };
}
