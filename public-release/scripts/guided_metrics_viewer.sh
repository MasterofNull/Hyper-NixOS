#!/usr/bin/env bash
#
# Hyper-NixOS Guided Metrics Viewer
# Copyright (C) 2024-2025 MasterofNull
# Licensed under GPL v3.0
#
# Educational wizard for understanding system metrics and performance
#

set -euo pipefail
PATH="/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin"

DIALOG="${DIALOG:-whiptail}"
METRICS_DIR="/var/lib/hypervisor/metrics"
STATE_DIR="/var/lib/hypervisor"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

show_intro() {
  $DIALOG --title "Metrics & Performance Wizard" --msgbox "\
╔════════════════════════════════════════════════════════════════╗
║     Welcome to Metrics - Learn Performance Monitoring         ║
╚════════════════════════════════════════════════════════════════╝

QUESTION:
How do you know if your system is healthy?
How do you know when to add more RAM?
How do you prove performance to users?

ANSWER: METRICS!

═══════════════════════════════════════════════════════════════

WHAT YOU'LL LEARN:

• What metrics are and why they matter
• How to read system performance data
• How to spot problems before they occur
• How to capacity plan (when to upgrade)
• Industry-standard monitoring practices

METRICS WE TRACK:

• CPU Usage: How busy is your processor?
• Memory Usage: Are you running out of RAM?
• Disk Usage: Will you run out of space?
• Network Usage: Bandwidth consumption
• VM Resource Usage: Per-VM performance
• System Load: Overall stress level

═══════════════════════════════════════════════════════════════

PROFESSIONAL INSIGHT:

Companies spend millions on monitoring systems.
You're learning the same concepts for free!

Tools like Prometheus, Grafana, Datadog all track these same metrics.
Understanding them here prepares you for enterprise systems.

Press OK to begin..." 42 78
}

explain_metrics_basics() {
  $DIALOG --title "Understanding Metrics" --msgbox "\
═══════════════════════════════════════════════════════════════
                    METRICS FUNDAMENTALS
═══════════════════════════════════════════════════════════════

THREE TYPES OF METRICS:

1. GAUGE (Current Value)
   Example: CPU at 45%
   • Shows current state
   • Goes up and down
   • Like a speedometer

2. COUNTER (Cumulative)
   Example: 1,234 network packets sent
   • Always increases
   • Resets on reboot
   • Like an odometer

3. HISTOGRAM (Distribution)
   Example: Response times: 10ms (50%), 50ms (95%), 200ms (99%)
   • Shows patterns
   • Identifies outliers
   • Advanced metric type

═══════════════════════════════════════════════════════════════
                    WHY METRICS MATTER
═══════════════════════════════════════════════════════════════

WITHOUT METRICS:
\"My system seems slow...\" (guessing)
\"I think we need more RAM...\" (guessing)
\"It's probably the network...\" (guessing)

WITH METRICS:
\"CPU at 95% for past hour\" (data)
\"RAM usage increased 20% this month\" (trend)
\"Network latency spiked at 3 PM\" (facts)

DECISIONS BECOME:
• Data-driven (not gut-feel)
• Justifiable (show graphs to management)
• Preventive (fix before it breaks)

═══════════════════════════════════════════════════════════════

INDUSTRY TERMS (Learn These):

• SLA: Service Level Agreement (uptime guarantee)
• SLO: Service Level Objective (performance target)
• SLI: Service Level Indicator (measured metric)

Example:
• SLO: \"99.9% uptime\"
• SLI: \"Actual uptime this month: 99.95%\"
• Result: We're meeting our SLA!

Press OK to view your metrics..." 50 78
}

show_current_metrics() {
  echo ""
  echo -e "${BOLD}${CYAN}Current System Metrics${NC}"
  echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
  echo ""
  
  # CPU
  echo -e "${BOLD}CPU Usage:${NC}"
  echo -n "• Current load: "
  local load=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
  local cpus=$(nproc)
  local load_pct=$(echo "scale=0; $load * 100 / $cpus" | bc 2>/dev/null || echo "0")
  
  if [[ $load_pct -lt 70 ]]; then
    echo -e "${GREEN}$load_pct%${NC} (healthy)"
  elif [[ $load_pct -lt 90 ]]; then
    echo -e "${YELLOW}$load_pct%${NC} (busy)"
  else
    echo -e "${RED}$load_pct%${NC} (overloaded)"
  fi
  
  echo "• Number of CPUs: $cpus"
  echo "• Load average (1/5/15 min): $(uptime | awk -F'load average:' '{print $2}')"
  echo ""
  
  # Memory
  echo -e "${BOLD}Memory Usage:${NC}"
  free -h | awk 'NR==2{
    used=$3; total=$2; pct=int($3/$2*100);
    color="\033[0;32m";
    if(pct>70) color="\033[1;33m";
    if(pct>90) color="\033[0;31m";
    printf "• Used: "color"%s""\033[0m"" / %s (%d%%)\n", used, total, pct
  }'
  
  # Disk
  echo ""
  echo -e "${BOLD}Disk Usage:${NC}"
  df -h / | awk 'NR==2{
    used=$3; total=$2; pct=int($5);
    color="\033[0;32m";
    if(pct>70) color="\033[1;33m";
    if(pct>85) color="\033[0;31m";
    printf "• Root filesystem: "color"%s""\033[0m"" / %s (%d%%)\n", used, total, pct
  }'
  
  if [[ -d /var/lib/libvirt/images ]]; then
    df -h /var/lib/libvirt/images | awk 'NR==2{
      used=$3; total=$2; pct=int($5);
      printf "• VM storage: %s / %s (%d%%)\n", used, total, pct
    }'
  fi
  
  # Running VMs
  echo ""
  echo -e "${BOLD}Virtual Machines:${NC}"
  local vm_count=$(virsh list --name 2>/dev/null | grep -v '^$' | wc -l)
  local vm_total=$(virsh list --all --name 2>/dev/null | grep -v '^$' | wc -l)
  echo "• Running: $vm_count / $vm_total total"
  
  echo ""
  
  $DIALOG --title "Current System State" --msgbox "\
Current metrics captured!

$(show_current_metrics 2>&1 | head -20)

WHAT THESE NUMBERS MEAN:

CPU LOAD:
• <70% = Healthy (plenty of capacity)
• 70-90% = Busy (monitor closely)
• >90% = Overloaded (add CPUs or reduce load)

MEMORY:
• <70% = Comfortable
• 70-90% = Watch for growth
• >90% = Critical (add RAM soon)

DISK:
• <70% = Safe
• 70-85% = Plan for more storage
• >85% = Urgent (clean up or expand)

PROFESSIONAL TIP:
Set thresholds BEFORE you hit them:
• Alert at 70% (time to plan)
• Urgent at 85% (time to act)
• Never hit 100% (disaster)

Press OK to see trends..." 35 78
}

show_trends() {
  $DIALOG --title "Understanding Trends" --msgbox "\
═══════════════════════════════════════════════════════════════
                    METRICS vs TRENDS
═══════════════════════════════════════════════════════════════

CURRENT METRICS (Snapshot):
\"CPU is at 60% right now\"
• Useful: Tells you current state
• Limited: Could be temporary spike

TRENDS (Over Time):
\"CPU averages 60%, up from 40% last month\"
• Powerful: Shows direction
• Actionable: Tells you to plan capacity
• Predictive: Forecast future needs

═══════════════════════════════════════════════════════════════
                    CAPACITY PLANNING
═══════════════════════════════════════════════════════════════

EXAMPLE SCENARIO:

Month 1: RAM usage = 40%
Month 2: RAM usage = 55%
Month 3: RAM usage = 70%

TREND: +15% per month

PREDICTION:
• Month 4: 85% (Warning level)
• Month 5: 100% (System fails!)

ACTION: Order more RAM in Month 3, install in Month 4
RESULT: Never hit critical level!

THIS IS CAPACITY PLANNING:
Using trends to prevent problems before they occur.

═══════════════════════════════════════════════════════════════

WHAT HYPER-NIXOS TRACKS:

We collect metrics hourly, stored in:
  $METRICS_DIR/

Format: JSON (easy to parse)
Retention: 90 days
Collection: Automatic (systemd timer)

AVAILABLE DATA:
• CPU usage over time
• Memory growth trends
• Disk space consumption rate
• Per-VM resource usage
• Network bandwidth patterns

Press OK to view your data..." 56 78
}

visualize_metrics() {
  if [[ ! -d "$METRICS_DIR" ]]; then
    $DIALOG --title "No Metrics Data" --msgbox "\
No metrics directory found!

This means:
• Metrics collection hasn't started yet
• Or metrics are stored elsewhere

To enable metrics collection:
  sudo systemctl enable --now hypervisor-metrics.timer

Wait 1 hour, then run this wizard again.

METRICS COLLECTION:

Automated collection runs hourly and records:
• System resources (CPU, RAM, disk)
• VM statistics (per-VM usage)
• Network throughput
• Service health

This data is invaluable for:
• Troubleshooting performance issues
• Capacity planning
• Proving SLA compliance
• Identifying trends

Press OK to exit..." 28 78
    return 1
  fi
  
  local metric_files=$(find "$METRICS_DIR" -name "*.json" 2>/dev/null | wc -l)
  
  if [[ $metric_files -eq 0 ]]; then
    $DIALOG --title "No Metrics Yet" --msgbox "\
Metrics directory exists but no data collected yet.

Found: 0 metric files

Metrics are collected hourly by systemd timer.

First collection will occur within the next hour.

To collect immediately:
  sudo systemctl start hypervisor-metrics.service

Then re-run this wizard.

Press OK..." 18 78
    return 1
  fi
  
  $DIALOG --title "Metrics Available" --msgbox "\
Found $metric_files metric snapshots!

Data coverage: $(date -d "-$metric_files hours" +"%Y-%m-%d %H:%M") to now

WHAT WE CAN ANALYZE:

✓ Short-term trends (last 24 hours)
✓ Weekly patterns (last 7 days)
✓ Growth rates (project future needs)

ANALYSIS MODES:

1. Simple Report (text-based)
   • Min/max/average for each metric
   • Trend direction (increasing/decreasing)
   • Recommendations

2. Graph Generation (ASCII art)
   • Visual representation
   • Pattern recognition
   • Easy to share

3. Export for Graphing
   • CSV format
   • Import to Excel, Grafana, etc.
   • Professional presentations

Choose analysis mode next...

Press OK to continue..." 32 78
}

generate_simple_report() {
  echo ""
  echo -e "${BOLD}${CYAN}Generating Performance Report${NC}"
  echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
  echo ""
  
  echo "Analyzing metrics..."
  
  # Get latest metric files
  local recent_metrics=$(find "$METRICS_DIR" -name "*.json" -mtime -7 2>/dev/null | sort | tail -168)  # Last 7 days (hourly)
  
  if [[ -z "$recent_metrics" ]]; then
    echo "No recent metrics found"
    return 1
  fi
  
  # Extract CPU data
  echo -n "• Analyzing CPU usage... "
  local cpu_values=()
  while IFS= read -r file; do
    local cpu=$(jq -r '.cpu.usage_percent // 0' "$file" 2>/dev/null)
    [[ "$cpu" != "null" && "$cpu" != "0" ]] && cpu_values+=("$cpu")
  done <<< "$recent_metrics"
  
  if [[ ${#cpu_values[@]} -gt 0 ]]; then
    local cpu_avg=$(printf '%s\n' "${cpu_values[@]}" | awk '{sum+=$1; count++} END {printf "%.1f", sum/count}')
    local cpu_max=$(printf '%s\n' "${cpu_values[@]}" | sort -n | tail -1)
    local cpu_min=$(printf '%s\n' "${cpu_values[@]}" | sort -n | head -1)
    echo -e "${GREEN}✓${NC}"
  else
    echo -e "${YELLOW}⚠ No data${NC}"
    cpu_avg=0
    cpu_max=0
    cpu_min=0
  fi
  
  # Extract memory data  
  echo -n "• Analyzing memory usage... "
  local mem_values=()
  while IFS= read -r file; do
    local mem=$(jq -r '.memory.used_percent // 0' "$file" 2>/dev/null)
    [[ "$mem" != "null" && "$mem" != "0" ]] && mem_values+=("$mem")
  done <<< "$recent_metrics"
  
  if [[ ${#mem_values[@]} -gt 0 ]]; then
    local mem_avg=$(printf '%s\n' "${mem_values[@]}" | awk '{sum+=$1; count++} END {printf "%.1f", sum/count}')
    local mem_max=$(printf '%s\n' "${mem_values[@]}" | sort -n | tail -1)
    local mem_min=$(printf '%s\n' "${mem_values[@]}" | sort -n | head -1)
    echo -e "${GREEN}✓${NC}"
  else
    echo -e "${YELLOW}⚠ No data${NC}"
    mem_avg=0
    mem_max=0
    mem_min=0
  fi
  
  # Generate report
  local report_file="/var/lib/hypervisor/performance-report-$(date +%Y%m%d-%H%M%S).txt"
  
  cat > "$report_file" << EOF
╔════════════════════════════════════════════════════════════════╗
║          SYSTEM PERFORMANCE REPORT                             ║
╚════════════════════════════════════════════════════════════════╝

Generated: $(date)
Data Period: Last 7 days (${#cpu_values[@]} samples)
Collection: Hourly automated

═══════════════════════════════════════════════════════════════
CPU USAGE
═══════════════════════════════════════════════════════════════

Average:  ${cpu_avg}%
Minimum:  ${cpu_min}%
Maximum:  ${cpu_max}%

INTERPRETATION:
$(if (( $(echo "$cpu_avg < 50" | bc -l 2>/dev/null || echo 0) )); then echo "\
✓ CPU usage is healthy
  Your system has plenty of compute capacity.
  You can add more VMs without issues."; elif (( $(echo "$cpu_avg < 80" | bc -l 2>/dev/null || echo 0) )); then echo "\
⚠ CPU usage is moderate
  Your system is working but not stressed.
  Monitor trends - if increasing, plan to add CPUs."; else echo "\
⚠ CPU usage is high!
  Your system is working hard.
  Consider: Reduce VMs, upgrade CPUs, or optimize workloads."; fi)

═══════════════════════════════════════════════════════════════
MEMORY USAGE
═══════════════════════════════════════════════════════════════

Average:  ${mem_avg}%
Minimum:  ${mem_min}%
Maximum:  ${mem_max}%

INTERPRETATION:
$(if (( $(echo "$mem_avg < 70" | bc -l 2>/dev/null || echo 0) )); then echo "\
✓ Memory usage is healthy
  You have adequate RAM for current workload."; elif (( $(echo "$mem_avg < 85" | bc -l 2>/dev/null || echo 0) )); then echo "\
⚠ Memory usage is elevated
  You're using most of your RAM.
  If trending up, plan to add more RAM soon."; else echo "\
⚠ Memory usage is critical!
  You're running out of RAM.
  This can cause:
  • Swapping (very slow)
  • OOM kills (crashed processes)
  • System instability
  
  ACTION: Add RAM immediately or reduce VM count."; fi)

═══════════════════════════════════════════════════════════════
CAPACITY PLANNING RECOMMENDATIONS
═══════════════════════════════════════════════════════════════

Based on current metrics:

$(if (( $(echo "$cpu_avg > 70" | bc -l 2>/dev/null || echo 0) )); then echo "\
• CPU: Consider upgrade within 1-2 months"; fi)

$(if (( $(echo "$mem_avg > 70" | bc -l 2>/dev/null || echo 0) )); then echo "\
• RAM: Monitor closely, plan upgrade if trending up"; fi)

GROWTH PROJECTION:
(Requires longer history - check back in 30 days)

═══════════════════════════════════════════════════════════════
PROFESSIONAL SKILLS YOU'RE LEARNING
═══════════════════════════════════════════════════════════════

1. READING METRICS
   You can now interpret CPU/memory/disk metrics
   This skill applies to:
   • Any server (Linux, Windows, cloud)
   • Containers (Docker stats)
   • Databases (pg_stat, MySQL status)

2. CAPACITY PLANNING
   You understand when to scale up
   This is a critical DevOps/SRE skill

3. PERFORMANCE ANALYSIS
   You can diagnose "my system is slow" complaints
   With data, not guesses

═══════════════════════════════════════════════════════════════

NEXT STEPS:

1. Review this report monthly
2. Compare trends over time
3. Document decisions: "Added RAM because usage hit 85%"
4. Share with team: Data-driven conversations

Report saved: $report_file

═══════════════════════════════════════════════════════════════
EOF

  $DIALOG --title "📊 Performance Report Generated" --textbox "$report_file" 45 80
  
  $DIALOG --title "Understanding Your Report" --msgbox "\
You just generated a professional performance report!

WHAT TO DO WITH THIS:

1. IMMEDIATE
   • Check if any metrics are critical
   • Take action if needed

2. MONTHLY
   • Generate new report
   • Compare to previous month
   • Look for trends

3. PLANNING
   • Use data to justify upgrades
   • Forecast future needs
   • Budget accordingly

4. DOCUMENTATION
   • Keep reports for history
   • Track capacity over time
   • Prove ROI of upgrades

═══════════════════════════════════════════════════════════════

CAREER SKILL: Reporting

Being able to generate and interpret performance reports is a
valuable skill in:
• System Administration
• DevOps Engineering
• Site Reliability Engineering
• IT Management

You now have this skill!

Report location: $report_file

Press OK to return to menu..." 42 78
  
  echo ""
  echo -e "${GREEN}Report saved to: $report_file${NC}"
  echo ""
}

show_ascii_graph() {
  local metric_name="$1"
  local description="$2"
  
  $DIALOG --title "Graphing: $metric_name" --msgbox "\
═══════════════════════════════════════════════════════════════

VISUALIZATION: Why Graphs Matter

Numbers are good: \"CPU: 45%, 52%, 61%, 58%\"
Graphs are better:

    CPU Usage (Last 24 Hours)
    100% |                    
     80% |          *         
     60% |      *  ***  *     
     40% |  *  ****   ****    
     20% | ****************   
      0% |____________________
         0h  6h  12h 18h 24h

WHAT GRAPHS SHOW:

• PATTERNS: \"CPU spikes every night at midnight\"
           → Probably scheduled backup
           
• TRENDS: Graph sloping up over time
         → Capacity increasing
         
• ANOMALIES: Sudden spike or drop
            → Something changed

HUMANS ARE VISUAL:
Our brains process images 60,000x faster than text!
Graphs let you spot problems instantly.

═══════════════════════════════════════════════════════════════

We'll now generate an ASCII graph for: $metric_name
($description)

This teaches you:
• How to visualize time-series data
• How to spot patterns
• How to communicate findings

Press OK to generate graph..." 42 78
  
  # Generate simple ASCII graph
  echo ""
  echo -e "${BOLD}${CYAN}$metric_name - Last 24 Hours${NC}"
  echo ""
  
  # Get last 24 data points
  local recent=$(find "$METRICS_DIR" -name "*.json" -mtime -1 2>/dev/null | sort | tail -24)
  local values=()
  
  if [[ "$metric_name" == "CPU" ]]; then
    while IFS= read -r file; do
      local val=$(jq -r '.cpu.usage_percent // 0' "$file" 2>/dev/null)
      values+=("$val")
    done <<< "$recent"
  elif [[ "$metric_name" == "Memory" ]]; then
    while IFS= read -r file; do
      local val=$(jq -r '.memory.used_percent // 0' "$file" 2>/dev/null)
      values+=("$val")
    done <<< "$recent"
  fi
  
  if [[ ${#values[@]} -lt 2 ]]; then
    echo "Not enough data yet (need 24 hours of metrics)"
    echo "Current data points: ${#values[@]}"
    return 0
  fi
  
  # Simple ASCII graph (10 rows)
  local max_val=$(printf '%s\n' "${values[@]}" | sort -n | tail -1)
  local max=${max_val%.*}
  [[ $max -lt 10 ]] && max=10
  
  for row in $(seq 10 -1 0); do
    local threshold=$((max * row / 10))
    printf "%3d%% |" "$threshold"
    
    for val in "${values[@]}"; do
      local v=${val%.*}
      [[ -z "$v" ]] && v=0
      if [[ $v -ge $threshold ]]; then
        echo -n "█"
      else
        echo -n " "
      fi
    done
    echo ""
  done
  
  echo "     +$(printf '─%.0s' {1..24})"
  printf "      "
  for hour in $(seq 0 6 23); do
    printf "%-4s" "${hour}h"
  done
  echo ""
  echo ""
  
  $DIALOG --title "Graph Analysis" --msgbox "\
$(show_ascii_graph "$metric_name" "$description" 2>&1 | tail -15)

READING THE GRAPH:

Y-AXIS (Vertical): Percentage (0-100%)
X-AXIS (Horizontal): Time (24 hours)
█ = Data point at or above that level

WHAT TO LOOK FOR:

• FLAT LINE: Consistent usage (good!)
• GRADUAL SLOPE: Trend (up = growing load)
• SPIKES: Sudden increase (investigate what caused it)
• DROPS: Sudden decrease (maybe VMs stopped?)
• PATTERN: Regular ups/downs (daily cycle)

PROFESSIONAL ANALYSIS:

Look at YOUR graph and ask:
• Is usage increasing over time? (capacity issue)
• Are there regular patterns? (scheduled jobs)
• Any unexplained spikes? (investigate)
• Overall healthy or concerning?

This is exactly how professional SREs analyze systems!

Press OK..." 35 78
}

explain_slo_sli() {
  $DIALOG --title "Advanced: SLOs and SLIs" --msgbox "\
═══════════════════════════════════════════════════════════════
            PROFESSIONAL MONITORING CONCEPTS
═══════════════════════════════════════════════════════════════

SLO: Service Level Objective (Your Goal)
Example: \"99.9% uptime\" or \"CPU < 80% average\"

SLI: Service Level Indicator (Actual Measurement)
Example: \"Actual uptime: 99.95%\" or \"CPU average: 65%\"

SLA: Service Level Agreement (Contract)
Example: \"We guarantee 99.9% uptime or money back\"

═══════════════════════════════════════════════════════════════
YOUR HYPERVISOR SLOs (Suggested)
═══════════════════════════════════════════════════════════════

Uptime: 99.5% (4.3 hours downtime/month acceptable)
Performance: CPU < 80% average, RAM < 85%
Response: Health check passes 95% of time
Backup: All backups verified monthly

MEASURING YOUR SLIs:

Based on your metrics:
• Current uptime: $(uptime -p)
• CPU average: Check metrics
• Backup verification: Run monthly

MEETING SLOs:

If SLI > SLO: ✓ You're meeting your goals!
If SLI < SLO: ⚠ Need improvement

═══════════════════════════════════════════════════════════════

WHY THIS MATTERS:

In professional environments:
• SLOs guide operations
• SLIs prove performance
• SLAs are contractual commitments

Learning to set and measure SLOs is advanced stuff!

Press OK..." 48 78
}

main_menu() {
  while true; do
    local choice
    choice=$($DIALOG --title "Guided Metrics & Performance Wizard" --menu "\
What would you like to learn about?

Each option includes:
• Educational explanation
• Step-by-step guidance
• Real-world applications
• Career skills

Choose a topic:" 20 78 10 \
      "1" "📖 Introduction to Metrics (Start here!)" \
      "2" "📊 View Current System Metrics" \
      "3" "📈 Analyze Trends (Last 7 days)" \
      "4" "📉 Generate Performance Report" \
      "5" "🎨 Visualize Metrics (ASCII Graphs)" \
      "6" "🎓 Learn: SLOs and SLIs (Advanced)" \
      "7" "💾 Export Data (CSV for Excel/Grafana)" \
      "8" "🔧 Troubleshooting: Performance Issues" \
      "9" "Exit" \
      3>&1 1>&2 2>&3)
    
    case "$choice" in
      1)
        explain_metrics_basics
        ;;
      2)
        show_current_metrics
        ;;
      3)
        show_trends
        visualize_metrics
        ;;
      4)
        generate_simple_report
        ;;
      5)
        show_ascii_graph "CPU" "Processor usage over time"
        show_ascii_graph "Memory" "Memory consumption over time"
        ;;
      6)
        explain_slo_sli
        ;;
      7)
        export_metrics_csv
        ;;
      8)
        troubleshoot_performance
        ;;
      9|"")
        break
        ;;
    esac
  done
}

export_metrics_csv() {
  local output="/var/lib/hypervisor/metrics-export-$(date +%Y%m%d).csv"
  
  echo "Exporting metrics to CSV..."
  echo "timestamp,cpu_percent,memory_percent,disk_percent" > "$output"
  
  find "$METRICS_DIR" -name "*.json" -mtime -30 2>/dev/null | sort | while read -r file; do
    local ts=$(jq -r '.timestamp // ""' "$file" 2>/dev/null)
    local cpu=$(jq -r '.cpu.usage_percent // 0' "$file" 2>/dev/null)
    local mem=$(jq -r '.memory.used_percent // 0' "$file" 2>/dev/null)
    local disk=$(jq -r '.disk.used_percent // 0' "$file" 2>/dev/null)
    echo "$ts,$cpu,$mem,$disk" >> "$output"
  done
  
  $DIALOG --title "📊 Data Exported" --msgbox "\
Metrics exported to CSV format!

File: $output

WHAT YOU CAN DO WITH THIS:

1. EXCEL/GOOGLE SHEETS
   • Import CSV
   • Create charts
   • Share with team

2. GRAFANA/PROMETHEUS
   • Professional dashboards
   • Real-time monitoring
   • Alerting rules

3. CUSTOM ANALYSIS
   • Python pandas
   • R statistical analysis
   • Machine learning

HOW TO USE:

In Excel:
  File → Open → Select CSV
  Insert → Chart → Line Chart

In Grafana:
  Add CSV data source
  Create dashboard
  Set up alerts

CAREER SKILL:
Data export and visualization is critical in tech.
You're learning to work with time-series data!

Press OK..." 38 78
  
  echo "Exported to: $output"
}

troubleshoot_performance() {
  $DIALOG --title "Performance Troubleshooting Guide" --msgbox "\
═══════════════════════════════════════════════════════════════
        PERFORMANCE TROUBLESHOOTING FLOWCHART
═══════════════════════════════════════════════════════════════

SYMPTOM: \"System is slow\"

STEP 1: IDENTIFY THE BOTTLENECK

Check CPU:
  $ top
  If >80%: CPU bound

Check Memory:
  $ free -h
  If <10% free: Memory bound

Check Disk I/O:
  $ iostat -x 1
  If %util >80%: Disk bound

Check Network:
  $ iftop
  If saturated: Network bound

═══════════════════════════════════════════════════════════════

STEP 2: DIAGNOSE ROOT CAUSE

CPU High:
  $ top (find which process)
  → Is it a runaway process? Kill it
  → Is it a VM? Limit its CPUs
  → Is it normal load? Add CPUs

Memory High:
  $ top (sort by memory: Shift+M)
  → Which process uses most RAM?
  → Is it a leak? Restart service
  → Is it normal? Add RAM

Disk I/O High:
  $ iotop
  → Which process does I/O?
  → Can you optimize it?
  → Need faster disks? (SSD)

═══════════════════════════════════════════════════════════════

STEP 3: FIX THE PROBLEM

SHORT-TERM (Immediate):
• Stop non-essential VMs
• Kill runaway processes
• Clear disk space
• Reduce load

LONG-TERM (Planned):
• Upgrade hardware
• Optimize workloads
• Migrate VMs to other hosts
• Tune kernel parameters

═══════════════════════════════════════════════════════════════

COMMANDS YOU SHOULD KNOW:

top       - CPU and memory usage
htop      - Better version of top
free      - Memory details
df        - Disk space
du        - Disk usage
iostat    - Disk I/O stats
iftop     - Network usage
vmstat    - Overall system stats

These work on ANY Linux system!

Press OK..." 68 78
}

main() {
  log "Guided metrics viewer started"
  
  show_intro
  main_menu
  
  log "Guided metrics viewer completed"
  
  echo ""
  echo -e "${GREEN}Thank you for learning about performance monitoring!${NC}"
  echo ""
}

main "$@"
