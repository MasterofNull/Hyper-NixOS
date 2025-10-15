{ config, lib, pkgs, ... }:

# Database Tools Module
# Provides PostgreSQL, Redis, SQLite, and other database services

let
  cfg = config.hypervisor.features.databaseTools;
in
{
  options.hypervisor.features.databaseTools = {
    enable = lib.mkEnableOption "database services and tools";
    
    postgresql = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable PostgreSQL database server";
      };
      
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.postgresql_15;
        description = "PostgreSQL package to use";
      };
      
      enableBackup = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable automatic PostgreSQL backups";
      };
    };
    
    redis = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Redis in-memory data store";
      };
      
      port = lib.mkOption {
        type = lib.types.port;
        default = 6379;
        description = "Redis port";
      };
    };
    
    mysql = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable MySQL/MariaDB database server";
      };
      
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.mariadb;
        description = "MySQL/MariaDB package to use";
      };
    };
    
    sqlite = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install SQLite tools";
    };
    
    tools = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install database management tools";
    };
  };
  
  config = lib.mkIf cfg.enable {
    # PostgreSQL
    services.postgresql = lib.mkIf cfg.postgresql.enable {
      enable = true;
      package = cfg.postgresql.package;
      enableTCPIP = true;
      
      # Authentication configuration
      authentication = pkgs.lib.mkOverride 10 ''
        # TYPE  DATABASE        USER            ADDRESS                 METHOD
        local   all             all                                     trust
        host    all             all             127.0.0.1/32            md5
        host    all             all             ::1/128                 md5
      '';
      
      # Initial databases
      ensureDatabases = [ "hypervisor" ];
      ensureUsers = [
        {
          name = "hypervisor";
          ensureDBOwnership = true;
        }
      ];
    };
    
    # PostgreSQL backup
    services.postgresqlBackup = lib.mkIf (cfg.postgresql.enable && cfg.postgresql.enableBackup) {
      enable = true;
      databases = [ "hypervisor" ];
      startAt = "*-*-* 02:00:00";  # Daily at 2 AM
      location = "/var/backup/postgresql";
      compression = "zstd";
    };
    
    # Redis
    services.redis.servers.hypervisor = lib.mkIf cfg.redis.enable {
      enable = true;
      port = cfg.redis.port;
      bind = "127.0.0.1";
      
      # Persistence
      save = [
        [ 900 1 ]    # After 900 sec (15 min) if at least 1 key changed
        [ 300 10 ]   # After 300 sec (5 min) if at least 10 keys changed
        [ 60 10000 ] # After 60 sec if at least 10000 keys changed
      ];
      
      settings = {
        maxmemory = "256mb";
        maxmemory-policy = "allkeys-lru";
        appendonly = true;
        appendfsync = "everysec";
      };
    };
    
    # MySQL/MariaDB
    services.mysql = lib.mkIf cfg.mysql.enable {
      enable = true;
      package = cfg.mysql.package;
      
      # Initial databases
      ensureDatabases = [ "hypervisor" ];
      ensureUsers = [
        {
          name = "hypervisor";
          ensurePermissions = {
            "hypervisor.*" = "ALL PRIVILEGES";
          };
        }
      ];
    };
    
    # Database management tools
    environment.systemPackages = with pkgs; [
      # PostgreSQL tools
    ] ++ lib.optionals cfg.postgresql.enable [
      cfg.postgresql.package
      pkgs.pgcli          # Modern PostgreSQL CLI
      pkgs.pgadmin4       # PostgreSQL GUI admin
    ] ++ lib.optionals cfg.redis.enable [
      pkgs.redis
      pkgs.redis-tui      # Terminal UI for Redis
    ] ++ lib.optionals cfg.mysql.enable [
      cfg.mysql.package
      pkgs.mycli          # Modern MySQL CLI
    ] ++ lib.optionals cfg.sqlite [
      pkgs.sqlite
      pkgs.sqlite-interactive
      pkgs.litecli        # Modern SQLite CLI
    ] ++ lib.optionals cfg.tools [
      # Generic database tools
      pkgs.dbeaver        # Universal database tool
      pkgs.sqlitebrowser  # SQLite browser
      pkgs.dbmate         # Database migration tool
      pkgs.flyway         # Database migration tool
    ];
    
    # Firewall configuration
    networking.firewall.allowedTCPPorts = lib.optionals cfg.postgresql.enable [ 5432 ]
      ++ lib.optionals cfg.redis.enable [ cfg.redis.port ]
      ++ lib.optionals cfg.mysql.enable [ 3306 ];
    
    # Backup directory
    systemd.tmpfiles.rules = [
      "d /var/backup/postgresql 0750 postgres postgres - -"
      "d /var/backup/redis 0750 redis redis - -"
      "d /var/backup/mysql 0750 mysql mysql - -"
    ];
    
    # Feature status file
    environment.etc."hypervisor/features/database-tools.conf".text = ''
      # Database Tools Configuration
      FEATURE_NAME="database-tools"
      FEATURE_STATUS="enabled"
      FEATURE_VERSION="1.0.0"
      
      POSTGRESQL_ENABLED="${if cfg.postgresql.enable then "yes" else "no"}"
      REDIS_ENABLED="${if cfg.redis.enable then "yes" else "no"}"
      MYSQL_ENABLED="${if cfg.mysql.enable then "yes" else "no"}"
      SQLITE_ENABLED="${if cfg.sqlite then "yes" else "no"}"
      
      ${lib.optionalString cfg.postgresql.enable ''
        POSTGRESQL_VERSION="${cfg.postgresql.package.version}"
        POSTGRESQL_PORT="5432"
      ''}
      
      ${lib.optionalString cfg.redis.enable ''
        REDIS_PORT="${toString cfg.redis.port}"
      ''}
    '';
    
    # Database management scripts
    environment.systemPackages = [
      (pkgs.writeScriptBin "db-status" ''
        #!${pkgs.bash}/bin/bash
        echo "Database Services Status"
        echo "========================"
        
        ${lib.optionalString cfg.postgresql.enable ''
          echo -n "PostgreSQL: "
          if systemctl is-active --quiet postgresql; then
            echo "✓ Running (port 5432)"
            echo "  Version: ${cfg.postgresql.package.version}"
            sudo -u postgres psql -c "SELECT version();" | head -3
          else
            echo "✗ Not running"
          fi
          echo ""
        ''}
        
        ${lib.optionalString cfg.redis.enable ''
          echo -n "Redis: "
          if systemctl is-active --quiet redis-hypervisor; then
            echo "✓ Running (port ${toString cfg.redis.port})"
            ${pkgs.redis}/bin/redis-cli ping
          else
            echo "✗ Not running"
          fi
          echo ""
        ''}
        
        ${lib.optionalString cfg.mysql.enable ''
          echo -n "MySQL/MariaDB: "
          if systemctl is-active --quiet mysql; then
            echo "✓ Running (port 3306)"
            mysql -V
          else
            echo "✗ Not running"
          fi
          echo ""
        ''}
      '')
      
      (pkgs.writeScriptBin "db-backup" ''
        #!${pkgs.bash}/bin/bash
        echo "Creating database backups..."
        
        ${lib.optionalString cfg.postgresql.enable ''
          echo "Backing up PostgreSQL..."
          sudo -u postgres pg_dumpall | gzip > /var/backup/postgresql/all-$(date +%Y%m%d-%H%M%S).sql.gz
          echo "  ✓ PostgreSQL backup complete"
        ''}
        
        ${lib.optionalString cfg.redis.enable ''
          echo "Backing up Redis..."
          ${pkgs.redis}/bin/redis-cli SAVE
          cp /var/lib/redis-hypervisor/dump.rdb /var/backup/redis/dump-$(date +%Y%m%d-%H%M%S).rdb
          echo "  ✓ Redis backup complete"
        ''}
        
        ${lib.optionalString cfg.mysql.enable ''
          echo "Backing up MySQL..."
          mysqldump --all-databases | gzip > /var/backup/mysql/all-$(date +%Y%m%d-%H%M%S).sql.gz
          echo "  ✓ MySQL backup complete"
        ''}
        
        echo "All backups complete!"
      '')
    ];
  };
}
