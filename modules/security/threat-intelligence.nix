# Threat Intelligence Integration
# Integrates external threat feeds and internal intelligence

{ config, lib, pkgs, ... }:

let
  inherit (lib) mkOption mkEnableOption mkIf mkDefault mkForce mkMerge types;
  cfg = config.hypervisor.security.threatIntelligence;
  
  # Threat intelligence sources
  threatFeeds = {
    # IP reputation feeds
    emergingThreats = {
      name = "Emerging Threats";
      url = "https://rules.emergingthreats.net/fwrules/emerging-Block-IPs.txt";
      type = "ip-list";
      updateInterval = "6h";
    };
    
    alienvault = {
      name = "AlienVault OTX";
      url = "https://reputation.alienvault.com/reputation.generic";
      type = "ip-reputation";
      updateInterval = "12h";
    };
    
    # Domain reputation
    malwareDomains = {
      name = "Malware Domain List";
      url = "https://www.malwaredomainlist.com/hostslist/hosts.txt";
      type = "domain-list";
      updateInterval = "24h";
    };
    
    phishtank = {
      name = "PhishTank";
      url = "http://data.phishtank.com/data/online-valid.json";
      type = "phishing-urls";
      updateInterval = "1h";
      requiresApiKey = true;
    };
    
    # File hashes
    malwareBazaar = {
      name = "MalwareBazaar";
      url = "https://bazaar.abuse.ch/export/txt/sha256/recent/";
      type = "hash-list";
      updateInterval = "1h";
    };
    
    # CVE database
    nvd = {
      name = "NVD CVE Feed";
      url = "https://nvd.nist.gov/feeds/json/cve/1.1/nvdcve-1.1-recent.json.gz";
      type = "vulnerability-db";
      updateInterval = "6h";
    };
  };
  
  # Intelligence correlation engine
  correlationEngine = pkgs.writeScriptBin "threat-intel-correlator" ''
    #!${pkgs.python3}/bin/python3
    
    import json
    import logging
    import sqlite3
    from datetime import datetime, timedelta
    from pathlib import Path
    
    logging.basicConfig(level=logging.INFO)
    logger = logging.getLogger('threat-intel')
    
    class ThreatIntelligence:
        def __init__(self):
            self.db_path = "/var/lib/hypervisor/threat-intel/intel.db"
            self.init_database()
            
        def init_database(self):
            """Initialize threat intelligence database"""
            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()
            
            # IP reputation table
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS ip_reputation (
                    ip TEXT PRIMARY KEY,
                    reputation_score INTEGER,
                    categories TEXT,
                    last_seen TIMESTAMP,
                    source TEXT
                )
            ''')
            
            # Domain reputation table
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS domain_reputation (
                    domain TEXT PRIMARY KEY,
                    risk_level TEXT,
                    categories TEXT,
                    last_updated TIMESTAMP,
                    source TEXT
                )
            ''')
            
            # Hash database
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS file_hashes (
                    hash TEXT PRIMARY KEY,
                    hash_type TEXT,
                    malware_family TEXT,
                    first_seen TIMESTAMP,
                    source TEXT
                )
            ''')
            
            # CVE database
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS vulnerabilities (
                    cve_id TEXT PRIMARY KEY,
                    severity TEXT,
                    description TEXT,
                    affected_software TEXT,
                    published_date TIMESTAMP
                )
            ''')
            
            # Threat indicators
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS indicators (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    indicator_type TEXT,
                    indicator_value TEXT,
                    confidence INTEGER,
                    first_seen TIMESTAMP,
                    last_seen TIMESTAMP,
                    times_seen INTEGER DEFAULT 1,
                    tags TEXT
                )
            ''')
            
            conn.commit()
            conn.close()
            
        def check_ip_reputation(self, ip):
            """Check IP reputation against threat intelligence"""
            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()
            
            cursor.execute(
                "SELECT reputation_score, categories, source FROM ip_reputation WHERE ip = ?",
                (ip,)
            )
            result = cursor.fetchone()
            conn.close()
            
            if result:
                score, categories, source = result
                return {
                    'malicious': score > 70,
                    'score': score,
                    'categories': json.loads(categories),
                    'source': source
                }
            return {'malicious': False, 'score': 0}
            
        def check_domain(self, domain):
            """Check domain reputation"""
            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()
            
            cursor.execute(
                "SELECT risk_level, categories FROM domain_reputation WHERE domain = ?",
                (domain,)
            )
            result = cursor.fetchone()
            conn.close()
            
            if result:
                risk_level, categories = result
                return {
                    'malicious': risk_level in ['high', 'critical'],
                    'risk_level': risk_level,
                    'categories': json.loads(categories)
                }
            return {'malicious': False, 'risk_level': 'unknown'}
            
        def check_file_hash(self, file_hash):
            """Check if file hash is known malware"""
            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()
            
            cursor.execute(
                "SELECT malware_family, source FROM file_hashes WHERE hash = ?",
                (file_hash.lower(),)
            )
            result = cursor.fetchone()
            conn.close()
            
            if result:
                malware_family, source = result
                return {
                    'malicious': True,
                    'malware_family': malware_family,
                    'source': source
                }
            return {'malicious': False}
            
        def add_indicator(self, indicator_type, value, confidence=50, tags=None):
            """Add a new threat indicator"""
            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()
            
            # Check if indicator exists
            cursor.execute(
                "SELECT id, times_seen FROM indicators WHERE indicator_type = ? AND indicator_value = ?",
                (indicator_type, value)
            )
            existing = cursor.fetchone()
            
            if existing:
                # Update existing indicator
                cursor.execute(
                    "UPDATE indicators SET last_seen = ?, times_seen = ? WHERE id = ?",
                    (datetime.now(), existing[1] + 1, existing[0])
                )
            else:
                # Insert new indicator
                cursor.execute(
                    "INSERT INTO indicators (indicator_type, indicator_value, confidence, first_seen, last_seen, tags) VALUES (?, ?, ?, ?, ?, ?)",
                    (indicator_type, value, confidence, datetime.now(), datetime.now(), json.dumps(tags or []))
                )
            
            conn.commit()
            conn.close()
            
        def get_threat_context(self, indicator_type, value):
            """Get full context for a threat indicator"""
            context = {
                'indicator_type': indicator_type,
                'value': value,
                'verdict': 'unknown',
                'confidence': 0,
                'details': {}
            }
            
            if indicator_type == 'ip':
                rep = self.check_ip_reputation(value)
                context['verdict'] = 'malicious' if rep['malicious'] else 'clean'
                context['confidence'] = rep.get('score', 0)
                context['details'] = rep
                
            elif indicator_type == 'domain':
                rep = self.check_domain(value)
                context['verdict'] = 'malicious' if rep['malicious'] else 'clean'
                context['confidence'] = 80 if rep['malicious'] else 20
                context['details'] = rep
                
            elif indicator_type == 'hash':
                rep = self.check_file_hash(value)
                context['verdict'] = 'malicious' if rep['malicious'] else 'unknown'
                context['confidence'] = 95 if rep['malicious'] else 0
                context['details'] = rep
            
            # Check internal indicators
            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()
            cursor.execute(
                "SELECT confidence, times_seen, tags FROM indicators WHERE indicator_type = ? AND indicator_value = ?",
                (indicator_type, value)
            )
            internal = cursor.fetchone()
            conn.close()
            
            if internal:
                context['internal_confidence'] = internal[0]
                context['times_seen'] = internal[1]
                context['tags'] = json.loads(internal[2])
            
            return context
    
    # Initialize and run
    intel = ThreatIntelligence()
    logger.info("Threat intelligence correlator initialized")
  '';
  
  # Feed updater
  feedUpdater = pkgs.writeScriptBin "update-threat-feeds" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    
    INTEL_DIR="/var/lib/hypervisor/threat-intel"
    mkdir -p "$INTEL_DIR"/{feeds,cache}
    
    log() {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
        logger -t threat-feeds "$*"
    }
    
    # Update IP reputation feeds
    update_ip_feeds() {
        log "Updating IP reputation feeds"
        
        # Emerging Threats
        if curl -s -o "$INTEL_DIR/feeds/emerging-threats-ips.txt" \
            "https://rules.emergingthreats.net/fwrules/emerging-Block-IPs.txt"; then
            log "Updated Emerging Threats IP list"
        fi
        
        # Process and import to database
        python3 <<EOF
    import sqlite3
    import re
    from datetime import datetime
    
    conn = sqlite3.connect("$INTEL_DIR/intel.db")
    cursor = conn.cursor()
    
    with open("$INTEL_DIR/feeds/emerging-threats-ips.txt") as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith('#'):
                # Simple IP regex
                if re.match(r'^\d+\.\d+\.\d+\.\d+$', line):
                    cursor.execute(
                        "INSERT OR REPLACE INTO ip_reputation (ip, reputation_score, categories, last_seen, source) VALUES (?, ?, ?, ?, ?)",
                        (line, 90, '["malware", "botnet"]', datetime.now(), 'emerging-threats')
                    )
    
    conn.commit()
    conn.close()
    EOF
    }
    
    # Update domain feeds
    update_domain_feeds() {
        log "Updating domain reputation feeds"
        
        # Malware domains
        if curl -s -o "$INTEL_DIR/feeds/malware-domains.txt" \
            "https://www.malwaredomainlist.com/hostslist/hosts.txt"; then
            log "Updated malware domain list"
        fi
    }
    
    # Update hash feeds
    update_hash_feeds() {
        log "Updating file hash feeds"
        
        # MalwareBazaar
        if curl -s -o "$INTEL_DIR/feeds/malware-hashes.txt" \
            "https://bazaar.abuse.ch/export/txt/sha256/recent/"; then
            log "Updated MalwareBazaar hash list"
        fi
    }
    
    # Update CVE database
    update_cve_feeds() {
        log "Updating CVE database"
        
        # NVD feed
        if curl -s -o "$INTEL_DIR/feeds/nvd-recent.json.gz" \
            "https://nvd.nist.gov/feeds/json/cve/1.1/nvdcve-1.1-recent.json.gz"; then
            gunzip -f "$INTEL_DIR/feeds/nvd-recent.json.gz"
            log "Updated NVD CVE feed"
        fi
    }
    
    # Main update process
    main() {
        log "Starting threat intelligence feed update"
        
        update_ip_feeds
        update_domain_feeds
        update_hash_feeds
        update_cve_feeds
        
        # Update feed metadata
        echo "{\"last_update\": \"$(date -Iseconds)\"}" > "$INTEL_DIR/feeds/metadata.json"
        
        log "Threat intelligence feed update completed"
        
        # Notify detection engine
        systemctl reload hypervisor-threat-detector || true
    }
    
    main
  '';

in {
  options.hypervisor.security.threatIntelligence = {
    enable = mkEnableOption "threat intelligence integration";
    
    enabledFeeds = mkOption {
      type = types.listOf types.str;
      default = [ "emergingThreats" "malwareDomains" "malwareBazaar" ];
      description = "List of enabled threat intelligence feeds";
    };
    
    customFeeds = mkOption {
      type = types.attrsOf types.attrs;
      default = {};
      description = "Custom threat intelligence feeds";
    };
    
    updateInterval = mkOption {
      type = types.str;
      default = "6h";
      description = "How often to update threat feeds";
    };
    
    enableCorrelation = mkOption {
      type = types.bool;
      default = true;
      description = "Enable cross-source correlation";
    };
    
    sharing = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable threat intelligence sharing";
      };
      
      partners = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Trusted partners for intelligence sharing";
      };
      
      anonymize = mkOption {
        type = types.bool;
        default = true;
        description = "Anonymize shared intelligence";
      };
    };
    
    api = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable threat intelligence API";
      };
      
      port = mkOption {
        type = types.int;
        default = 8089;
        description = "API port";
      };
      
      authentication = mkOption {
        type = types.enum [ "none" "apikey" "mtls" ];
        default = "apikey";
        description = "API authentication method";
      };
    };
  };
  
  config = lib.mkIf cfg.enable {
    # Threat intelligence services
    systemd.services."hypervisor-threat-intel" = {
      description = "Threat Intelligence Correlation Engine";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      
      serviceConfig = {
        Type = "simple";
        ExecStart = "${correlationEngine}/bin/threat-intel-correlator";
        Restart = "always";
        
        # Security
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ReadWritePaths = [ "/var/lib/hypervisor/threat-intel" ];
      };
    };
    
    # Feed update timer
    systemd.timers."hypervisor-threat-feeds" = {
      description = "Update threat intelligence feeds";
      wantedBy = [ "timers.target" ];
      
      timerConfig = {
        OnCalendar = cfg.updateInterval;
        Persistent = true;
        RandomizedDelaySec = "30m";
      };
    };
    
    systemd.services."hypervisor-threat-feeds" = {
      description = "Update threat intelligence feeds";
      
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${feedUpdater}/bin/update-threat-feeds";
        
        # Network access needed
        PrivateNetwork = false;
      };
    };
    
    # API service
    systemd.services."hypervisor-threat-api" = mkIf cfg.api.enable {
      description = "Threat Intelligence API";
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.python3}/bin/python3 -m http.server ${toString cfg.api.port}";
        WorkingDirectory = "/var/lib/hypervisor/threat-intel";
        Restart = "always";
        
        # Security
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ReadOnlyPaths = [ "/var/lib/hypervisor/threat-intel" ];
      };
    };
    
    # Create directories
    systemd.tmpfiles.rules = [
      "d /var/lib/hypervisor/threat-intel 0750 root root - -"
      "d /var/lib/hypervisor/threat-intel/feeds 0750 root root - -"
      "d /var/lib/hypervisor/threat-intel/cache 0750 root root - -"
    ];
    
    # Install packages
    environment.systemPackages = [
      correlationEngine
      feedUpdater
    ];
  };
}