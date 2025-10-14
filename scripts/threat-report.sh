#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154,SC1091
#
# Comprehensive Threat Reporting System
# Generates detailed security reports and analytics
#
# Copyright (c) 2025 Hyper-NixOS Contributors
# License: MIT
#

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

# Report configuration
readonly REPORT_DIR="/var/lib/hypervisor/reports"
readonly THREAT_DB="/var/lib/hypervisor/threats/threat.db"
readonly INTEL_DB="/var/lib/hypervisor/threat-intel/intel.db"

# Time periods
readonly HOUR=$((60 * 60))
readonly DAY=$((24 * HOUR))
readonly WEEK=$((7 * DAY))
readonly MONTH=$((30 * DAY))

# Report types
REPORT_TYPE="${1:-summary}"
PERIOD="${2:-day}"
OUTPUT_FORMAT="${3:-terminal}"

# Initialize
mkdir -p "$REPORT_DIR"

# Generate timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_FILE="$REPORT_DIR/threat_report_${TIMESTAMP}"

# SQL queries for threat data
get_threat_summary() {
    local period="$1"
    local start_time=$(($(date +%s) - period))
    
    sqlite3 "$THREAT_DB" <<EOF
SELECT 
    severity,
    COUNT(*) as count,
    COUNT(DISTINCT source_ip) as unique_sources,
    COUNT(DISTINCT target) as unique_targets
FROM threats
WHERE timestamp > $start_time
GROUP BY severity
ORDER BY 
    CASE severity
        WHEN 'critical' THEN 5
        WHEN 'high' THEN 4
        WHEN 'medium' THEN 3
        WHEN 'low' THEN 2
        WHEN 'info' THEN 1
    END DESC;
EOF
}

get_top_threats() {
    local period="$1"
    local limit="${2:-10}"
    local start_time=$(($(date +%s) - period))
    
    sqlite3 "$THREAT_DB" <<EOF
SELECT 
    threat_type,
    COUNT(*) as occurrences,
    MAX(severity) as max_severity,
    COUNT(DISTINCT target) as affected_targets
FROM threats
WHERE timestamp > $start_time
GROUP BY threat_type
ORDER BY occurrences DESC
LIMIT $limit;
EOF
}

get_threat_timeline() {
    local period="$1"
    local start_time=$(($(date +%s) - period))
    
    sqlite3 "$THREAT_DB" <<EOF
SELECT 
    strftime('%Y-%m-%d %H:00', timestamp, 'unixepoch') as hour,
    severity,
    COUNT(*) as count
FROM threats
WHERE timestamp > $start_time
GROUP BY hour, severity
ORDER BY hour;
EOF
}

get_affected_vms() {
    local period="$1"
    local start_time=$(($(date +%s) - period))
    
    sqlite3 "$THREAT_DB" <<EOF
SELECT 
    target as vm_name,
    COUNT(*) as threat_count,
    GROUP_CONCAT(DISTINCT threat_type) as threat_types,
    MAX(severity) as max_severity
FROM threats
WHERE timestamp > $start_time
    AND target_type = 'vm'
GROUP BY target
ORDER BY threat_count DESC;
EOF
}

# Generate executive summary
generate_executive_summary() {
    local period="$1"
    
    cat <<EOF
EXECUTIVE SUMMARY
=================

Report Period: $(date -d "@$(($(date +%s) - period))" '+%Y-%m-%d %H:%M') - $(date '+%Y-%m-%d %H:%M')
Generated: $(date '+%Y-%m-%d %H:%M:%S')

THREAT LANDSCAPE
----------------
EOF
    
    # Get threat counts by severity
    local critical_count=$(sqlite3 "$THREAT_DB" "SELECT COUNT(*) FROM threats WHERE severity='critical' AND timestamp > $(($(date +%s) - period))")
    local high_count=$(sqlite3 "$THREAT_DB" "SELECT COUNT(*) FROM threats WHERE severity='high' AND timestamp > $(($(date +%s) - period))")
    local medium_count=$(sqlite3 "$THREAT_DB" "SELECT COUNT(*) FROM threats WHERE severity='medium' AND timestamp > $(($(date +%s) - period))")
    local total_count=$((critical_count + high_count + medium_count))
    
    echo "Total Security Events: $total_count"
    echo "├─ Critical: $critical_count"
    echo "├─ High: $high_count"
    echo "└─ Medium: $medium_count"
    echo
    
    # Risk assessment
    echo "RISK ASSESSMENT"
    echo "---------------"
    if [[ $critical_count -gt 0 ]]; then
        echo "Status: HIGH RISK ⚠️"
        echo "Action Required: IMMEDIATE"
    elif [[ $high_count -gt 5 ]]; then
        echo "Status: ELEVATED RISK"
        echo "Action Required: URGENT"
    elif [[ $total_count -gt 20 ]]; then
        echo "Status: MODERATE RISK"
        echo "Action Required: REVIEW"
    else
        echo "Status: LOW RISK ✓"
        echo "Action Required: MONITOR"
    fi
    echo
    
    # Key findings
    echo "KEY FINDINGS"
    echo "------------"
    
    # Most common threat
    local top_threat=$(sqlite3 "$THREAT_DB" "SELECT threat_type, COUNT(*) as c FROM threats WHERE timestamp > $(($(date +%s) - period)) GROUP BY threat_type ORDER BY c DESC LIMIT 1")
    if [[ -n "$top_threat" ]]; then
        echo "• Most Common Threat: ${top_threat%|*} (${top_threat##*|} occurrences)"
    fi
    
    # Most targeted VM
    local top_vm=$(sqlite3 "$THREAT_DB" "SELECT target, COUNT(*) as c FROM threats WHERE target_type='vm' AND timestamp > $(($(date +%s) - period)) GROUP BY target ORDER BY c DESC LIMIT 1")
    if [[ -n "$top_vm" ]]; then
        echo "• Most Targeted VM: ${top_vm%|*} (${top_vm##*|} events)"
    fi
    
    # Zero-day indicators
    local zero_day_count=$(sqlite3 "$THREAT_DB" "SELECT COUNT(*) FROM threats WHERE threat_type LIKE '%zero_day%' AND timestamp > $(($(date +%s) - period))")
    if [[ $zero_day_count -gt 0 ]]; then
        echo "• Potential Zero-Day Activity: $zero_day_count indicators"
    fi
    
    echo
}

# Generate detailed threat analysis
generate_threat_analysis() {
    local period="$1"
    
    cat <<EOF

DETAILED THREAT ANALYSIS
========================

TOP THREAT TYPES
----------------
EOF
    
    # Show top threats table
    echo "Rank | Threat Type          | Count | Severity | Targets"
    echo "-----|---------------------|-------|----------|--------"
    
    local rank=1
    while IFS='|' read -r threat_type count severity targets; do
        printf "%-4d | %-19s | %-5d | %-8s | %s\n" \
            "$rank" "$threat_type" "$count" "$severity" "$targets"
        rank=$((rank + 1))
    done < <(get_top_threats "$period" 10)
    
    echo
    
    # Threat timeline
    cat <<EOF
THREAT TIMELINE
---------------
Hour                | Critical | High | Medium | Low | Total
--------------------|----------|------|--------|-----|------
EOF
    
    sqlite3 "$THREAT_DB" <<SQL | while IFS='|' read -r hour critical high medium low; do
SELECT 
    h.hour,
    COALESCE(c.count, 0) as critical,
    COALESCE(h.count, 0) as high,
    COALESCE(m.count, 0) as medium,
    COALESCE(l.count, 0) as low
FROM (
    SELECT DISTINCT strftime('%Y-%m-%d %H:00', timestamp, 'unixepoch') as hour
    FROM threats
    WHERE timestamp > $(($(date +%s) - period))
) h
LEFT JOIN (
    SELECT strftime('%Y-%m-%d %H:00', timestamp, 'unixepoch') as hour, COUNT(*) as count
    FROM threats
    WHERE severity = 'critical' AND timestamp > $(($(date +%s) - period))
    GROUP BY hour
) c ON h.hour = c.hour
LEFT JOIN (
    SELECT strftime('%Y-%m-%d %H:00', timestamp, 'unixepoch') as hour, COUNT(*) as count
    FROM threats
    WHERE severity = 'high' AND timestamp > $(($(date +%s) - period))
    GROUP BY hour
) h ON h.hour = h.hour
LEFT JOIN (
    SELECT strftime('%Y-%m-%d %H:00', timestamp, 'unixepoch') as hour, COUNT(*) as count
    FROM threats
    WHERE severity = 'medium' AND timestamp > $(($(date +%s) - period))
    GROUP BY hour
) m ON h.hour = m.hour
LEFT JOIN (
    SELECT strftime('%Y-%m-%d %H:00', timestamp, 'unixepoch') as hour, COUNT(*) as count
    FROM threats
    WHERE severity = 'low' AND timestamp > $(($(date +%s) - period))
    GROUP BY hour
) l ON h.hour = l.hour
ORDER BY h.hour
LIMIT 24;
SQL
        local total=$((critical + high + medium + low))
        printf "%-19s | %-8d | %-4d | %-6d | %-3d | %d\n" \
            "$hour" "$critical" "$high" "$medium" "$low" "$total"
    done
}

# Generate VM security report
generate_vm_report() {
    local period="$1"
    
    cat <<EOF

VIRTUAL MACHINE SECURITY REPORT
===============================

AFFECTED VMS
------------
VM Name            | Events | Max Severity | Threat Types
-------------------|--------|--------------|-------------
EOF
    
    while IFS='|' read -r vm_name count threat_types severity; do
        printf "%-18s | %-6d | %-12s | %s\n" \
            "$vm_name" "$count" "$severity" "$threat_types"
    done < <(get_affected_vms "$period")
    
    echo
    
    # VM-specific recommendations
    echo "VM-SPECIFIC RECOMMENDATIONS"
    echo "---------------------------"
    
    while IFS='|' read -r vm_name count threat_types severity; do
        if [[ "$severity" == "critical" ]] || [[ $count -gt 10 ]]; then
            echo
            echo "VM: $vm_name"
            echo "├─ Risk Level: HIGH"
            echo "├─ Recommendation: Immediate isolation and investigation"
            echo "└─ Actions:"
            echo "   ├─ Create forensic snapshot"
            echo "   ├─ Review VM logs"
            echo "   ├─ Check for unauthorized changes"
            echo "   └─ Consider restoring from clean backup"
        fi
    done < <(get_affected_vms "$period")
}

# Generate threat intelligence report
generate_intel_report() {
    local period="$1"
    
    cat <<EOF

THREAT INTELLIGENCE REPORT
==========================

MATCHED INDICATORS
------------------
EOF
    
    # Check threat intel matches
    sqlite3 "$INTEL_DB" <<SQL
SELECT 
    ti.indicator_type,
    ti.indicator_value,
    ti.confidence,
    ti.source,
    COUNT(t.id) as matches
FROM threat_indicators ti
JOIN threats t ON t.ioc = ti.indicator_value
WHERE t.timestamp > $(($(date +%s) - period))
GROUP BY ti.indicator_type, ti.indicator_value
ORDER BY matches DESC
LIMIT 20;
SQL
    
    echo
    
    # New indicators
    echo "NEW THREAT INDICATORS"
    echo "---------------------"
    
    sqlite3 "$INTEL_DB" <<SQL
SELECT 
    indicator_type,
    COUNT(*) as count,
    MAX(confidence) as max_confidence
FROM threat_indicators
WHERE first_seen > $(($(date +%s) - period))
GROUP BY indicator_type;
SQL
}

# Generate recommendations
generate_recommendations() {
    local period="$1"
    local critical_count=$(sqlite3 "$THREAT_DB" "SELECT COUNT(*) FROM threats WHERE severity='critical' AND timestamp > $(($(date +%s) - period))")
    
    cat <<EOF

SECURITY RECOMMENDATIONS
========================

IMMEDIATE ACTIONS
-----------------
EOF
    
    if [[ $critical_count -gt 0 ]]; then
        cat <<EOF
1. CRITICAL THREATS DETECTED
   • Isolate affected systems immediately
   • Initiate incident response procedures
   • Create forensic snapshots
   • Review all critical alerts

EOF
    fi
    
    cat <<EOF
2. GENERAL RECOMMENDATIONS
   • Review and patch all systems
   • Update threat intelligence feeds
   • Verify backup integrity
   • Review access logs

3. PREVENTIVE MEASURES
   • Enable enhanced monitoring
   • Implement network segmentation
   • Review firewall rules
   • Update security policies

4. MONITORING FOCUS AREAS
EOF
    
    # Dynamic recommendations based on threats
    local top_threats=$(sqlite3 "$THREAT_DB" "SELECT DISTINCT threat_type FROM threats WHERE timestamp > $(($(date +%s) - period)) ORDER BY COUNT(*) DESC LIMIT 5")
    
    while read -r threat; do
        case "$threat" in
            *port_scan*)
                echo "   • Network perimeter - Port scanning detected"
                ;;
            *brute_force*)
                echo "   • Authentication systems - Brute force attempts"
                ;;
            *malware*)
                echo "   • Endpoint protection - Malware indicators"
                ;;
            *exfiltration*)
                echo "   • Data loss prevention - Potential exfiltration"
                ;;
        esac
    done <<< "$top_threats"
}

# Generate HTML report
generate_html_report() {
    local period="$1"
    local output_file="${REPORT_FILE}.html"
    
    cat > "$output_file" <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>Hyper-NixOS Security Report - $(date '+%Y-%m-%d')</title>
    <style>
        body { 
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            margin: 20px;
            background: #f5f5f5;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        h1, h2, h3 { color: #333; }
        .severity-critical { color: #d32f2f; font-weight: bold; }
        .severity-high { color: #f57c00; font-weight: bold; }
        .severity-medium { color: #fbc02d; }
        .severity-low { color: #388e3c; }
        .metric-card {
            display: inline-block;
            padding: 20px;
            margin: 10px;
            border-radius: 8px;
            background: #f8f9fa;
            text-align: center;
            min-width: 150px;
        }
        .metric-value {
            font-size: 36px;
            font-weight: bold;
            margin: 10px 0;
        }
        .metric-label {
            color: #666;
            font-size: 14px;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin: 20px 0;
        }
        th, td {
            padding: 12px;
            text-align: left;
            border-bottom: 1px solid #ddd;
        }
        th {
            background: #f8f9fa;
            font-weight: 600;
        }
        .chart {
            margin: 20px 0;
            height: 300px;
            background: #f8f9fa;
            border-radius: 8px;
            display: flex;
            align-items: center;
            justify-content: center;
            color: #999;
        }
        .alert {
            padding: 15px;
            margin: 20px 0;
            border-radius: 8px;
            border-left: 4px solid;
        }
        .alert-critical {
            background: #ffebee;
            border-color: #d32f2f;
            color: #b71c1c;
        }
        .alert-warning {
            background: #fff3e0;
            border-color: #f57c00;
            color: #e65100;
        }
        .alert-info {
            background: #e3f2fd;
            border-color: #1976d2;
            color: #0d47a1;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Hyper-NixOS Security Report</h1>
        <p>Generated: $(date '+%Y-%m-%d %H:%M:%S')</p>
        
        <h2>Executive Summary</h2>
        <div class="metrics">
EOF
    
    # Add metric cards
    local critical=$(sqlite3 "$THREAT_DB" "SELECT COUNT(*) FROM threats WHERE severity='critical' AND timestamp > $(($(date +%s) - period))")
    local high=$(sqlite3 "$THREAT_DB" "SELECT COUNT(*) FROM threats WHERE severity='high' AND timestamp > $(($(date +%s) - period))")
    local total=$(sqlite3 "$THREAT_DB" "SELECT COUNT(*) FROM threats WHERE timestamp > $(($(date +%s) - period))")
    
    cat >> "$output_file" <<EOF
            <div class="metric-card">
                <div class="metric-label">Total Threats</div>
                <div class="metric-value">$total</div>
            </div>
            <div class="metric-card">
                <div class="metric-label">Critical</div>
                <div class="metric-value severity-critical">$critical</div>
            </div>
            <div class="metric-card">
                <div class="metric-label">High</div>
                <div class="metric-value severity-high">$high</div>
            </div>
        </div>
EOF
    
    # Add alerts if needed
    if [[ $critical -gt 0 ]]; then
        cat >> "$output_file" <<EOF
        <div class="alert alert-critical">
            <strong>⚠️ Critical Security Alert</strong><br>
            $critical critical threats detected. Immediate action required.
        </div>
EOF
    fi
    
    # Add threat table
    cat >> "$output_file" <<EOF
        <h2>Top Threats</h2>
        <table>
            <thead>
                <tr>
                    <th>Threat Type</th>
                    <th>Count</th>
                    <th>Severity</th>
                    <th>Affected Targets</th>
                </tr>
            </thead>
            <tbody>
EOF
    
    while IFS='|' read -r threat_type count severity targets; do
        cat >> "$output_file" <<EOF
                <tr>
                    <td>$threat_type</td>
                    <td>$count</td>
                    <td class="severity-$severity">$severity</td>
                    <td>$targets</td>
                </tr>
EOF
    done < <(get_top_threats "$period" 10)
    
    cat >> "$output_file" <<EOF
            </tbody>
        </table>
        
        <h2>Threat Timeline</h2>
        <div class="chart">
            Chart placeholder - Would show threat timeline
        </div>
        
        <h2>Recommendations</h2>
        <div class="recommendations">
            <h3>Immediate Actions</h3>
            <ul>
                <li>Review all critical alerts</li>
                <li>Verify system integrity</li>
                <li>Update security policies</li>
            </ul>
        </div>
    </div>
</body>
</html>
EOF
    
    echo "HTML report generated: $output_file"
}

# Generate PDF report (requires wkhtmltopdf)
generate_pdf_report() {
    local html_file="${REPORT_FILE}.html"
    local pdf_file="${REPORT_FILE}.pdf"
    
    # First generate HTML
    generate_html_report "$1"
    
    # Convert to PDF if tool available
    if command -v wkhtmltopdf &>/dev/null; then
        wkhtmltopdf "$html_file" "$pdf_file"
        echo "PDF report generated: $pdf_file"
    else
        echo "PDF generation requires wkhtmltopdf"
    fi
}

# Main report generation
main() {
    # Convert period to seconds
    local period_seconds
    case "$PERIOD" in
        hour) period_seconds=$HOUR ;;
        day) period_seconds=$DAY ;;
        week) period_seconds=$WEEK ;;
        month) period_seconds=$MONTH ;;
        *) period_seconds=$DAY ;;
    esac
    
    case "$REPORT_TYPE" in
        summary)
            generate_executive_summary "$period_seconds"
            ;;
        detailed)
            generate_executive_summary "$period_seconds"
            generate_threat_analysis "$period_seconds"
            generate_vm_report "$period_seconds"
            generate_intel_report "$period_seconds"
            generate_recommendations "$period_seconds"
            ;;
        html)
            generate_html_report "$period_seconds"
            ;;
        pdf)
            generate_pdf_report "$period_seconds"
            ;;
        *)
            echo "Usage: $0 [summary|detailed|html|pdf] [hour|day|week|month]"
            exit 1
            ;;
    esac
}

# Create sample database if it doesn't exist
if [[ ! -f "$THREAT_DB" ]]; then
    mkdir -p "$(dirname "$THREAT_DB")"
    sqlite3 "$THREAT_DB" <<EOF
CREATE TABLE IF NOT EXISTS threats (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp INTEGER NOT NULL,
    threat_type TEXT NOT NULL,
    severity TEXT NOT NULL,
    source_ip TEXT,
    target TEXT,
    target_type TEXT,
    description TEXT,
    ioc TEXT,
    response_taken TEXT
);

-- Insert sample data for demo
INSERT INTO threats (timestamp, threat_type, severity, source_ip, target, target_type, description)
VALUES 
    ($(date +%s), 'port_scan', 'medium', '192.168.1.100', 'hypervisor', 'host', 'Port scan detected'),
    ($(($(date +%s) - 3600)), 'brute_force', 'high', '10.0.0.50', 'webserver', 'vm', 'SSH brute force attempt'),
    ($(($(date +%s) - 7200)), 'malware', 'critical', '', 'database', 'vm', 'Malware detected in VM');
EOF
fi

main "$@"