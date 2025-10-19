# VM Limits Presets for Hyper-NixOS
# Pre-configured templates for different deployment scenarios
#
# Usage: Include in configuration.nix or reference during setup wizard

{
  # Preset 1: Personal Workstation / Developer Laptop
  # Use case: Single user, development and testing
  personal = {
    global = {
      maxTotalVMs = 20;
      maxRunningVMs = 10;
      maxVMsPerHour = 5;
    };
    perUser = {
      enable = false;  # Not needed for single-user systems
      maxVMsPerUser = 20;
      maxRunningVMsPerUser = 10;
    };
    storage = {
      maxDiskPerVM = 200;      # GB
      maxTotalStorage = 1000;  # GB
      maxSnapshotsPerVM = 5;
    };
    enforcement = {
      blockExcessCreation = true;
      notifyOnApproach = true;
      adminOverride = true;
    };
  };

  # Preset 2: Small Team Server
  # Use case: 3-5 users, shared development/testing environment
  smallTeam = {
    global = {
      maxTotalVMs = 50;
      maxRunningVMs = 25;
      maxVMsPerHour = 10;
    };
    perUser = {
      enable = true;
      maxVMsPerUser = 15;
      maxRunningVMsPerUser = 8;
    };
    storage = {
      maxDiskPerVM = 300;
      maxTotalStorage = 2000;
      maxSnapshotsPerVM = 8;
    };
    enforcement = {
      blockExcessCreation = true;
      notifyOnApproach = true;
      adminOverride = true;
    };
  };

  # Preset 3: Medium Organization
  # Use case: 10-20 users, departmental server
  mediumOrg = {
    global = {
      maxTotalVMs = 100;
      maxRunningVMs = 50;
      maxVMsPerHour = 15;
    };
    perUser = {
      enable = true;
      maxVMsPerUser = 20;
      maxRunningVMsPerUser = 10;
    };
    storage = {
      maxDiskPerVM = 500;
      maxTotalStorage = 5000;
      maxSnapshotsPerVM = 10;
    };
    enforcement = {
      blockExcessCreation = true;
      notifyOnApproach = true;
      adminOverride = true;
    };
  };

  # Preset 4: Large Enterprise
  # Use case: 50+ users, production environment
  enterprise = {
    global = {
      maxTotalVMs = 500;
      maxRunningVMs = 250;
      maxVMsPerHour = 30;
    };
    perUser = {
      enable = true;
      maxVMsPerUser = 30;
      maxRunningVMsPerUser = 15;
    };
    storage = {
      maxDiskPerVM = 1000;
      maxTotalStorage = 20000;
      maxSnapshotsPerVM = 15;
    };
    enforcement = {
      blockExcessCreation = true;
      notifyOnApproach = true;
      adminOverride = true;
    };
  };

  # Preset 5: Cloud/Hosting Provider
  # Use case: Multi-tenant hosting, strict resource control
  hosting = {
    global = {
      maxTotalVMs = 1000;
      maxRunningVMs = 500;
      maxVMsPerHour = 50;
    };
    perUser = {
      enable = true;
      maxVMsPerUser = 50;
      maxRunningVMsPerUser = 25;
    };
    storage = {
      maxDiskPerVM = 2000;
      maxTotalStorage = 50000;
      maxSnapshotsPerVM = 20;
    };
    enforcement = {
      blockExcessCreation = true;
      notifyOnApproach = true;
      adminOverride = true;
    };
  };

  # Preset 6: Education/Training Lab
  # Use case: Many users, temporary VMs, frequent turnover
  education = {
    global = {
      maxTotalVMs = 200;
      maxRunningVMs = 100;
      maxVMsPerHour = 25;  # High burst for lab sessions
    };
    perUser = {
      enable = true;
      maxVMsPerUser = 10;  # Limited per student
      maxRunningVMsPerUser = 5;
    };
    storage = {
      maxDiskPerVM = 100;  # Smaller VMs for training
      maxTotalStorage = 3000;
      maxSnapshotsPerVM = 3;  # Minimal snapshots
    };
    enforcement = {
      blockExcessCreation = true;
      notifyOnApproach = true;
      adminOverride = true;
    };
  };

  # Preset 7: Testing/CI Environment
  # Use case: Automated testing, high VM churn
  testing = {
    global = {
      maxTotalVMs = 150;
      maxRunningVMs = 75;
      maxVMsPerHour = 50;  # Very high for CI pipelines
    };
    perUser = {
      enable = true;
      maxVMsPerUser = 50;  # CI users need more
      maxRunningVMsPerUser = 25;
    };
    storage = {
      maxDiskPerVM = 200;
      maxTotalStorage = 4000;
      maxSnapshotsPerVM = 5;
    };
    enforcement = {
      blockExcessCreation = false;  # Warning mode for CI
      notifyOnApproach = true;
      adminOverride = true;
    };
  };

  # Preset 8: Minimal/Resource-Constrained
  # Use case: Low-end hardware, single user
  minimal = {
    global = {
      maxTotalVMs = 10;
      maxRunningVMs = 5;
      maxVMsPerHour = 3;
    };
    perUser = {
      enable = false;
      maxVMsPerUser = 10;
      maxRunningVMsPerUser = 5;
    };
    storage = {
      maxDiskPerVM = 100;
      maxTotalStorage = 500;
      maxSnapshotsPerVM = 3;
    };
    enforcement = {
      blockExcessCreation = true;
      notifyOnApproach = true;
      adminOverride = true;
    };
  };

  # Preset 9: Custom (Template for manual configuration)
  custom = {
    global = {
      maxTotalVMs = 100;      # Adjust based on your needs
      maxRunningVMs = 50;     # Typically 50% of total
      maxVMsPerHour = 10;     # Prevent rapid creation
    };
    perUser = {
      enable = true;          # Enable for multi-user systems
      maxVMsPerUser = 20;
      maxRunningVMsPerUser = 10;
    };
    storage = {
      maxDiskPerVM = 500;
      maxTotalStorage = 5000;
      maxSnapshotsPerVM = 10;
    };
    enforcement = {
      blockExcessCreation = true;
      notifyOnApproach = true;
      adminOverride = true;
    };
  };
}
