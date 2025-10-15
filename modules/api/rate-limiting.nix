{ config, lib, pkgs, ... }:

# API Rate Limiting Module
# Prevents abuse and brute-force attacks
# Learned from: Pulse security architecture
# Part of Design Ethos - Security (Pillar 2)

let
  cfg = config.hypervisor.api.rateLimiting;
  
in {
  options.hypervisor.api.rateLimiting = {
    enable = lib.mkEnableOption "API rate limiting";
    
    general = lib.mkOption {
      type = lib.types.submodule {
        options = {
          requestsPerMinute = lib.mkOption {
            type = lib.types.int;
            default = 500;
            description = "Maximum requests per minute per IP for general endpoints";
          };
          
          burstSize = lib.mkOption {
            type = lib.types.int;
            default = 100;
            description = "Burst size for traffic spikes";
          };
        };
      };
      default = {
        requestsPerMinute = 500;
        burstSize = 100;
      };
      description = "General API rate limits";
    };
    
    authentication = lib.mkOption {
      type = lib.types.submodule {
        options = {
          attemptsPerMinute = lib.mkOption {
            type = lib.types.int;
            default = 10;
            description = "Maximum authentication attempts per minute per IP";
          };
          
          lockoutDuration = lib.mkOption {
            type = lib.types.str;
            default = "15m";
            description = "Lockout duration after max attempts exceeded";
          };
          
          maxFailedAttempts = lib.mkOption {
            type = lib.types.int;
            default = 5;
            description = "Failed attempts before account lockout";
          };
        };
      };
      default = {
        attemptsPerMinute = 10;
        lockoutDuration = "15m";
        maxFailedAttempts = 5;
      };
      description = "Authentication-specific rate limits";
    };
    
    csrfProtection = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable CSRF protection for state-changing operations";
    };
    
    securityHeaders = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable security headers (CSP, X-Frame-Options, etc.)";
    };
    
    auditLog = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Log all authentication and rate-limit events";
    };
  };
  
  config = lib.mkIf cfg.enable {
    # Install rate limiting middleware
    environment.systemPackages = [
      pkgs.redis  # For rate limit storage
      
      (pkgs.writeShellScriptBin "hv-rate-limit-check" ''
        #!/usr/bin/env bash
        # Check if IP is rate limited
        # Usage: hv-rate-limit-check <ip> <endpoint_type>
        
        IP=$1
        ENDPOINT_TYPE=''${2:-general}
        
        STATE_DIR="/var/lib/hypervisor/rate-limits"
        mkdir -p "$STATE_DIR"
        
        RATE_FILE="$STATE_DIR/$IP.$ENDPOINT_TYPE"
        CURRENT_TIME=$(date +%s)
        
        # Rate limits
        GENERAL_LIMIT=${toString cfg.general.requestsPerMinute}
        AUTH_LIMIT=${toString cfg.authentication.attemptsPerMinute}
        
        # Select limit based on endpoint
        case "$ENDPOINT_TYPE" in
          auth|authentication)
            LIMIT=$AUTH_LIMIT
            WINDOW=60
            ;;
          *)
            LIMIT=$GENERAL_LIMIT
            WINDOW=60
            ;;
        esac
        
        # Check current count
        if [ -f "$RATE_FILE" ]; then
          read -r LAST_TIME COUNT < "$RATE_FILE"
          
          # Check if window expired
          if [ $((CURRENT_TIME - LAST_TIME)) -gt $WINDOW ]; then
            # Reset counter
            echo "$CURRENT_TIME 1" > "$RATE_FILE"
            exit 0
          else
            # Increment counter
            NEW_COUNT=$((COUNT + 1))
            
            if [ $NEW_COUNT -gt $LIMIT ]; then
              echo "Rate limit exceeded: $NEW_COUNT/$LIMIT requests" >&2
              
              ${lib.optionalString cfg.auditLog ''
              logger -t hypervisor-api -p auth.warn "Rate limit exceeded for $IP on $ENDPOINT_TYPE endpoint"
              ''}
              
              exit 1
            else
              echo "$LAST_TIME $NEW_COUNT" > "$RATE_FILE"
              exit 0
            fi
          fi
        else
          # First request
          echo "$CURRENT_TIME 1" > "$RATE_FILE"
          exit 0
        fi
      '')
    ];
    
    # Nginx rate limiting configuration (if nginx is used)
    services.nginx = lib.mkIf (config.services.nginx.enable or false) {
      appendHttpConfig = ''
        # Rate limiting zones
        limit_req_zone $binary_remote_addr zone=api_general:10m rate=${toString cfg.general.requestsPerMinute}r/m;
        limit_req_zone $binary_remote_addr zone=api_auth:10m rate=${toString cfg.authentication.attemptsPerMinute}r/m;
      '';
    };
    
    # Configuration file
    environment.etc."hypervisor/rate-limits.json" = {
      text = builtins.toJSON {
        version = "1.0";
        rate_limiting = {
          enabled = true;
          
          general = {
            requests_per_minute = cfg.general.requestsPerMinute;
            burst_size = cfg.general.burstSize;
          };
          
          authentication = {
            attempts_per_minute = cfg.authentication.attemptsPerMinute;
            lockout_duration = cfg.authentication.lockoutDuration;
            max_failed_attempts = cfg.authentication.maxFailedAttempts;
          };
          
          csrf_protection = cfg.csrfProtection;
          security_headers = cfg.securityHeaders;
          audit_log = cfg.auditLog;
        };
        
        security_headers = lib.mkIf cfg.securityHeaders {
          "X-Frame-Options" = "DENY";
          "X-Content-Type-Options" = "nosniff";
          "X-XSS-Protection" = "1; mode=block";
          "Referrer-Policy" = "strict-origin-when-cross-origin";
          "Content-Security-Policy" = "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline';";
        };
      };
      
      mode = "0644";
    };
  };
}
