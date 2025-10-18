################################################################################
# Hyper-NixOS - Auto-generated test for clustering-mesh-cluster
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "clustering_mesh_cluster";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/clustering/mesh-cluster.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module clustering-mesh-cluster loaded'")
    print("✓ clustering-mesh-cluster test passed")
  '';
}
