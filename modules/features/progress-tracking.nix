{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.hypervisor.education.progressTracking;

  # Progress tracking CLI tool
  progressTracker = pkgs.writeScriptBin "hv-track-progress" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    PROGRESS_DB="${cfg.database}"
    SQLITE="${pkgs.sqlite}/bin/sqlite3"

    # Ensure database directory exists
    ensure_db_dir() {
      mkdir -p "$(dirname "$PROGRESS_DB")"
      chmod 755 "$(dirname "$PROGRESS_DB")"
    }

    # Initialize database
    init_db() {
      ensure_db_dir

      $SQLITE "$PROGRESS_DB" <<'SQL'
        CREATE TABLE IF NOT EXISTS progress (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user TEXT NOT NULL,
          category TEXT NOT NULL,
          item TEXT NOT NULL,
          completed BOOLEAN DEFAULT 1,
          timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
          UNIQUE(user, category, item)
        );

        CREATE TABLE IF NOT EXISTS achievements (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user TEXT NOT NULL,
          achievement TEXT NOT NULL,
          level INTEGER DEFAULT 1,
          unlocked_at DATETIME DEFAULT CURRENT_TIMESTAMP,
          UNIQUE(user, achievement)
        );

        CREATE TABLE IF NOT EXISTS learning_paths (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user TEXT NOT NULL,
          path_name TEXT NOT NULL,
          level INTEGER DEFAULT 1,
          started_at DATETIME DEFAULT CURRENT_TIMESTAMP,
          completed_at DATETIME,
          UNIQUE(user, path_name)
        );

        CREATE INDEX IF NOT EXISTS idx_progress_user ON progress(user);
        CREATE INDEX IF NOT EXISTS idx_progress_category ON progress(category);
        CREATE INDEX IF NOT EXISTS idx_achievements_user ON achievements(user);
SQL

      echo "✓ Progress tracking database initialized"
    }

    # Record progress
    record_progress() {
      local user="$1"
      local category="$2"
      local item="$3"

      ensure_db_dir

      # Insert or replace progress
      $SQLITE "$PROGRESS_DB" <<SQL
        INSERT OR REPLACE INTO progress (user, category, item, completed, timestamp)
        VALUES ('$user', '$category', '$item', 1, datetime('now'));
SQL

      echo "✓ Progress recorded: $category/$item"

      # Check for achievements
      check_achievements "$user"
    }

    # Show user progress
    show_progress() {
      local user="$1"
      local limit="''${2:-20}"

      if [ ! -f "$PROGRESS_DB" ]; then
        echo "No progress recorded yet. Start learning!"
        return
      fi

      echo "Recent Progress for $user:"
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

      $SQLITE -header -column "$PROGRESS_DB" <<SQL
        SELECT
          category as Category,
          item as Item,
          strftime('%Y-%m-%d %H:%M', timestamp) as Completed
        FROM progress
        WHERE user='$user'
        ORDER BY timestamp DESC
        LIMIT $limit;
SQL
    }

    # Show statistics
    show_stats() {
      local user="$1"

      if [ ! -f "$PROGRESS_DB" ]; then
        echo "No progress recorded yet."
        return
      fi

      echo "Progress Statistics for $user"
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo ""

      # Total progress
      local total=$($SQLITE "$PROGRESS_DB" \
        "SELECT COUNT(*) FROM progress WHERE user='$user';")
      echo "Total items completed: $total"
      echo ""

      # By category
      echo "By Category:"
      $SQLITE -column "$PROGRESS_DB" <<SQL
        SELECT
          category as Category,
          COUNT(*) as Completed
        FROM progress
        WHERE user='$user'
        GROUP BY category
        ORDER BY COUNT(*) DESC;
SQL

      echo ""

      # Achievements
      local achievement_count=$($SQLITE "$PROGRESS_DB" \
        "SELECT COUNT(*) FROM achievements WHERE user='$user';")

      if [ "$achievement_count" -gt 0 ]; then
        echo "🏆 Achievements Unlocked: $achievement_count"
        $SQLITE -column "$PROGRESS_DB" <<SQL
          SELECT
            achievement as Achievement,
            level as Level,
            strftime('%Y-%m-%d', unlocked_at) as Unlocked
          FROM achievements
          WHERE user='$user'
          ORDER BY unlocked_at DESC;
SQL
      else
        echo "🏆 Achievements: 0 (keep learning!)"
      fi
    }

    # Check and award achievements
    check_achievements() {
      local user="$1"

      # Count total completed items
      local total=$($SQLITE "$PROGRESS_DB" \
        "SELECT COUNT(*) FROM progress WHERE user='$user';")

      # Award achievements based on milestones
      if [ "$total" -ge 10 ]; then
        award_achievement "$user" "Novice Navigator" 1
      fi

      if [ "$total" -ge 25 ]; then
        award_achievement "$user" "Competent Curator" 2
      fi

      if [ "$total" -ge 50 ]; then
        award_achievement "$user" "Advanced Architect" 3
      fi

      if [ "$total" -ge 100 ]; then
        award_achievement "$user" "Master Virtualist" 4
      fi

      # Category-specific achievements
      local networking=$($SQLITE "$PROGRESS_DB" \
        "SELECT COUNT(*) FROM progress WHERE user='$user' AND category='networking';")

      if [ "$networking" -ge 5 ]; then
        award_achievement "$user" "Network Ninja" 1
      fi

      local security=$($SQLITE "$PROGRESS_DB" \
        "SELECT COUNT(*) FROM progress WHERE user='$user' AND category='security';")

      if [ "$security" -ge 5 ]; then
        award_achievement "$user" "Security Specialist" 1
      fi

      local vm_mgmt=$($SQLITE "$PROGRESS_DB" \
        "SELECT COUNT(*) FROM progress WHERE user='$user' AND category='vm-management';")

      if [ "$vm_mgmt" -ge 10 ]; then
        award_achievement "$user" "VM Virtuoso" 1
      fi
    }

    # Award achievement
    award_achievement() {
      local user="$1"
      local achievement="$2"
      local level="$3"

      # Check if already awarded
      local exists=$($SQLITE "$PROGRESS_DB" \
        "SELECT COUNT(*) FROM achievements WHERE user='$user' AND achievement='$achievement';")

      if [ "$exists" -eq 0 ]; then
        $SQLITE "$PROGRESS_DB" <<SQL
          INSERT INTO achievements (user, achievement, level)
          VALUES ('$user', '$achievement', $level);
SQL
        echo ""
        echo "🎉 Achievement Unlocked: $achievement!"
        echo ""
      fi
    }

    # List all achievements
    list_achievements() {
      cat <<'EOF'
Available Achievements:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

General Progress:
  🏅 Novice Navigator      - Complete 10 items
  🌟 Competent Curator     - Complete 25 items
  🚀 Advanced Architect    - Complete 50 items
  💎 Master Virtualist     - Complete 100 items

Category-Specific:
  🔧 Network Ninja         - Complete 5 networking tasks
  🔒 Security Specialist   - Complete 5 security tasks
  📦 VM Virtuoso           - Complete 10 VM management tasks
  💾 Storage Sage          - Complete 5 storage tasks
  📊 Monitoring Master     - Complete 5 monitoring tasks

Special:
  🎓 Learning Path Completionist - Finish a learning path
  🏆 First Boot Champion   - Complete first boot wizard
  ⚡ Speed Learner         - Complete 10 items in one day

EOF
    }

    # Start learning path
    start_path() {
      local user="$1"
      local path_name="$2"

      $SQLITE "$PROGRESS_DB" <<SQL
        INSERT OR IGNORE INTO learning_paths (user, path_name)
        VALUES ('$user', '$path_name');
SQL

      echo "✓ Started learning path: $path_name"
    }

    # Complete learning path
    complete_path() {
      local user="$1"
      local path_name="$2"

      $SQLITE "$PROGRESS_DB" <<SQL
        UPDATE learning_paths
        SET completed_at = datetime('now')
        WHERE user='$user' AND path_name='$path_name';
SQL

      echo "🎉 Completed learning path: $path_name"
      award_achievement "$user" "Learning Path Completionist" 1
    }

    # Export progress
    export_progress() {
      local user="$1"
      local output_file="''${2:-progress-export-$(date +%Y%m%d).json}"

      if [ ! -f "$PROGRESS_DB" ]; then
        echo "No progress to export"
        return 1
      fi

      # Export to JSON
      {
        echo "{"
        echo "  \"user\": \"$user\","
        echo "  \"exported_at\": \"$(date -Iseconds)\","
        echo "  \"progress\": ["

        $SQLITE -json "$PROGRESS_DB" \
          "SELECT category, item, timestamp FROM progress WHERE user='$user';" | \
          sed 's/^/    /'

        echo "  ],"
        echo "  \"achievements\": ["

        $SQLITE -json "$PROGRESS_DB" \
          "SELECT achievement, level, unlocked_at FROM achievements WHERE user='$user';" | \
          sed 's/^/    /'

        echo "  ]"
        echo "}"
      } > "$output_file"

      echo "✓ Progress exported to: $output_file"
    }

    # Main command dispatcher
    case "''${1:-help}" in
      init)
        init_db
        ;;

      record)
        if [ $# -lt 4 ]; then
          echo "Usage: hv-track-progress record USER CATEGORY ITEM"
          exit 1
        fi
        record_progress "$2" "$3" "$4"
        ;;

      show)
        user="''${2:-$USER}"
        limit="''${3:-20}"
        show_progress "$user" "$limit"
        ;;

      stats)
        user="''${2:-$USER}"
        show_stats "$user"
        ;;

      achievements)
        list_achievements
        ;;

      start-path)
        if [ $# -lt 3 ]; then
          echo "Usage: hv-track-progress start-path USER PATH_NAME"
          exit 1
        fi
        start_path "$2" "$3"
        ;;

      complete-path)
        if [ $# -lt 3 ]; then
          echo "Usage: hv-track-progress complete-path USER PATH_NAME"
          exit 1
        fi
        complete_path "$2" "$3"
        ;;

      export)
        user="''${2:-$USER}"
        output="''${3:-}"
        export_progress "$user" "$output"
        ;;

      help|--help|-h)
        cat <<'EOF'
hv-track-progress - Track your Hyper-NixOS learning journey

Usage:
  hv-track-progress COMMAND [OPTIONS]

Commands:
  init                     Initialize progress tracking database
  record USER CAT ITEM     Record completed item
  show [USER] [LIMIT]      Show recent progress (default: 20)
  stats [USER]             Show statistics and achievements
  achievements             List all available achievements
  start-path USER PATH     Start a learning path
  complete-path USER PATH  Mark learning path as complete
  export [USER] [FILE]     Export progress to JSON
  help                     Show this help

Examples:
  hv-track-progress record alice networking configured-bridge
  hv-track-progress show alice
  hv-track-progress stats alice
  hv-track-progress achievements
  hv-track-progress export alice progress.json

EOF
        ;;

      *)
        echo "Unknown command: $1"
        echo "Run 'hv-track-progress help' for usage"
        exit 1
        ;;
    esac
  '';

in {
  options.hypervisor.education.progressTracking = {
    enable = mkEnableOption "user progress tracking system";

    database = mkOption {
      type = types.path;
      default = "/var/lib/hypervisor/progress.db";
      description = "Path to progress tracking database";
    };

    autoInitialize = mkOption {
      type = types.bool;
      default = true;
      description = "Automatically initialize database on activation";
    };

    enableWebDashboard = mkOption {
      type = types.bool;
      default = false;
      description = "Enable web-based progress dashboard";
    };
  };

  config = mkIf cfg.enable {
    # Install progress tracker
    environment.systemPackages = [
      progressTracker
      pkgs.sqlite
    ];

    # Create data directory
    systemd.tmpfiles.rules = [
      "d /var/lib/hypervisor 0755 root root -"
    ];

    # Initialize database on activation
    system.activationScripts.initProgressTracking = mkIf cfg.autoInitialize ''
      if [ ! -f ${cfg.database} ]; then
        echo "Initializing progress tracking database..."
        ${progressTracker}/bin/hv-track-progress init
      fi
    '';

    # Shell integration
    environment.interactiveShellInit = ''
      # Alias for convenience
      alias progress='hv-track-progress show $USER'
      alias my-progress='hv-track-progress stats $USER'
      alias my-achievements='hv-track-progress stats $USER | grep -A20 "🏆"'
    '';

    # Documentation
    environment.etc."hypervisor/docs/progress-tracking.txt".text = ''
      ╔═══════════════════════════════════════════════════════════════╗
      ║               Progress Tracking System                         ║
      ╚═══════════════════════════════════════════════════════════════╝

      Your learning journey is automatically tracked!

      VIEW YOUR PROGRESS
      ──────────────────
      hv-track-progress show       # Recent activity
      hv-track-progress stats      # Full statistics
      progress                     # Quick alias

      ACHIEVEMENTS
      ────────────
      Earn achievements as you learn:
      • Complete 10 items → Novice Navigator
      • Complete 25 items → Competent Curator
      • Complete 50 items → Advanced Architect
      • Complete 100 items → Master Virtualist

      Category achievements for networking, security, VMs, and more!

      Run: hv-track-progress achievements

      EXPORT YOUR PROGRESS
      ────────────────────
      hv-track-progress export $USER my-progress.json

      LEARNING PATHS
      ──────────────
      Follow structured learning paths to build skills systematically.
      Progress is automatically tracked as you complete tutorials.

      See: /usr/share/doc/hypervisor/LEARNING_PATH.md
    '';
  };
}
