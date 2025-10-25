#!/usr/bin/env python3
"""
Security Metrics Collector
Collects and exports security metrics for Prometheus
"""

import time
import json
import asyncio
import docker
import psutil
import subprocess
from pathlib import Path
from datetime import datetime, timedelta
from typing import Dict, List, Any
from prometheus_client import Counter, Gauge, Histogram, Info, CollectorRegistry, write_to_textfile
from prometheus_client.core import GaugeMetricFamily, CounterMetricFamily
import logging

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Metrics
registry = CollectorRegistry()

# Security event metrics
security_events_total = Counter(
    'security_events_total',
    'Total number of security events',
    ['event_type', 'severity'],
    registry=registry
)

active_incidents = Gauge(
    'security_active_incidents',
    'Number of active security incidents',
    ['incident_type'],
    registry=registry
)

# Container security metrics
container_risk_score = Gauge(
    'container_risk_score',
    'Container security risk score',
    ['container_name', 'image'],
    registry=registry
)

container_vulnerabilities = Gauge(
    'container_vulnerabilities_total',
    'Number of vulnerabilities in container',
    ['container_name', 'severity'],
    registry=registry
)

# Network security metrics
network_connections = Gauge(
    'security_network_connections',
    'Number of network connections',
    ['state', 'protocol'],
    registry=registry
)

blocked_ips_total = Counter(
    'security_blocked_ips_total',
    'Total number of blocked IPs',
    ['reason'],
    registry=registry
)

# SSH metrics
ssh_login_attempts = Counter(
    'ssh_login_attempts_total',
    'Total SSH login attempts',
    ['result', 'source'],
    registry=registry
)

ssh_active_sessions = Gauge(
    'ssh_active_sessions',
    'Number of active SSH sessions',
    registry=registry
)

# File integrity metrics
file_changes = Counter(
    'security_file_changes_total',
    'Total file changes detected',
    ['file_path', 'change_type'],
    registry=registry
)

# System security metrics
security_score = Gauge(
    'system_security_score',
    'Overall system security score (0-100)',
    registry=registry
)

patch_compliance = Gauge(
    'security_patch_compliance',
    'Percentage of systems with latest patches',
    registry=registry
)

# Response time metrics
incident_response_time = Histogram(
    'security_incident_response_seconds',
    'Time taken to respond to security incidents',
    ['incident_type'],
    registry=registry
)


class SecurityMetricsCollector:
    """Collects various security metrics"""
    
    def __init__(self):
        self.docker_client = docker.from_env()
        self.metrics_file = Path("/var/lib/prometheus/node_exporter/security_metrics.prom")
        self.events_log = Path("/var/log/security/events.json")
        self.last_event_check = datetime.now()
        
    async def collect_all_metrics(self):
        """Collect all security metrics"""
        try:
            # Collect different metric types
            await self.collect_security_events()
            await self.collect_container_metrics()
            await self.collect_network_metrics()
            await self.collect_ssh_metrics()
            await self.collect_file_integrity_metrics()
            await self.calculate_security_score()
            
            # Write metrics to file for node_exporter
            self.metrics_file.parent.mkdir(parents=True, exist_ok=True)
            write_to_textfile(str(self.metrics_file), registry)
            
            logger.info("Security metrics collected successfully")
            
        except Exception as e:
            logger.error(f"Error collecting metrics: {str(e)}")
    
    async def collect_security_events(self):
        """Collect security event metrics"""
        if not self.events_log.exists():
            return
        
        # Count events by type and severity
        event_counts = {}
        active_count = {}
        
        try:
            with open(self.events_log, 'r') as f:
                for line in f:
                    try:
                        event = json.loads(line.strip())
                        event_type = event.get('type', 'unknown')
                        severity = event.get('severity', 'info')
                        
                        # Count total events
                        key = (event_type, severity)
                        event_counts[key] = event_counts.get(key, 0) + 1
                        
                        # Count active incidents (last hour)
                        event_time = datetime.fromisoformat(event.get('timestamp', ''))
                        if datetime.now() - event_time < timedelta(hours=1):
                            active_count[event_type] = active_count.get(event_type, 0) + 1
                    
                    except:
                        continue
            
            # Update metrics
            for (event_type, severity), count in event_counts.items():
                security_events_total.labels(
                    event_type=event_type,
                    severity=severity
                ).inc(count)
            
            for incident_type, count in active_count.items():
                active_incidents.labels(incident_type=incident_type).set(count)
                
        except Exception as e:
            logger.error(f"Error reading events log: {str(e)}")
    
    async def collect_container_metrics(self):
        """Collect container security metrics"""
        try:
            containers = self.docker_client.containers.list()
            
            for container in containers:
                # Get container scan results if available
                scan_results = await self._get_container_scan_results(container.name)
                
                if scan_results:
                    # Risk score
                    container_risk_score.labels(
                        container_name=container.name,
                        image=container.image.tags[0] if container.image.tags else 'unknown'
                    ).set(scan_results.get('risk_score', 0))
                    
                    # Vulnerabilities by severity
                    vuln_counts = scan_results.get('vulnerability_counts', {})
                    for severity, count in vuln_counts.items():
                        container_vulnerabilities.labels(
                            container_name=container.name,
                            severity=severity
                        ).set(count)
                
        except Exception as e:
            logger.error(f"Error collecting container metrics: {str(e)}")
    
    async def collect_network_metrics(self):
        """Collect network security metrics"""
        try:
            # Get network connections
            connections = psutil.net_connections()
            
            # Count by state and protocol
            conn_counts = {}
            for conn in connections:
                if conn.status != 'NONE':
                    key = (conn.status, 'tcp' if conn.type == 1 else 'udp')
                    conn_counts[key] = conn_counts.get(key, 0) + 1
            
            # Update metrics
            for (state, protocol), count in conn_counts.items():
                network_connections.labels(state=state, protocol=protocol).set(count)
            
            # Count blocked IPs from iptables
            blocked_count = await self._count_blocked_ips()
            if blocked_count is not None:
                blocked_ips_total.labels(reason='firewall').inc(blocked_count)
                
        except Exception as e:
            logger.error(f"Error collecting network metrics: {str(e)}")
    
    async def collect_ssh_metrics(self):
        """Collect SSH security metrics"""
        try:
            # Parse auth log for SSH attempts
            auth_log = Path("/var/log/auth.log")
            if auth_log.exists():
                # Count recent login attempts
                failed_attempts = 0
                successful_attempts = 0
                
                # Get last 1000 lines
                result = subprocess.run(
                    ['tail', '-n', '1000', str(auth_log)],
                    capture_output=True,
                    text=True
                )
                
                for line in result.stdout.split('\n'):
                    if 'sshd' in line:
                        if 'Failed password' in line:
                            failed_attempts += 1
                            # Extract source IP if possible
                            # ssh_login_attempts.labels(result='failed', source='external').inc()
                        elif 'Accepted' in line:
                            successful_attempts += 1
                            # ssh_login_attempts.labels(result='success', source='external').inc()
                
                # Simple increment for now
                if failed_attempts > 0:
                    ssh_login_attempts.labels(result='failed', source='external').inc(failed_attempts)
                if successful_attempts > 0:
                    ssh_login_attempts.labels(result='success', source='external').inc(successful_attempts)
            
            # Count active SSH sessions
            active_sessions = await self._count_ssh_sessions()
            ssh_active_sessions.set(active_sessions)
            
        except Exception as e:
            logger.error(f"Error collecting SSH metrics: {str(e)}")
    
    async def collect_file_integrity_metrics(self):
        """Collect file integrity metrics"""
        try:
            # Check for file changes in critical directories
            critical_files = [
                '/etc/passwd',
                '/etc/shadow',
                '/etc/ssh/sshd_config',
                '/etc/sudoers'
            ]
            
            for file_path in critical_files:
                if Path(file_path).exists():
                    # Check if file was modified recently
                    mtime = Path(file_path).stat().st_mtime
                    if time.time() - mtime < 3600:  # Modified in last hour
                        file_changes.labels(
                            file_path=file_path,
                            change_type='modified'
                        ).inc()
                        
        except Exception as e:
            logger.error(f"Error collecting file integrity metrics: {str(e)}")
    
    async def calculate_security_score(self):
        """Calculate overall security score"""
        score = 100  # Start with perfect score
        
        try:
            # Deduct points for various issues
            
            # Check for high risk containers
            containers = self.docker_client.containers.list()
            high_risk_containers = 0
            for container in containers:
                scan_results = await self._get_container_scan_results(container.name)
                if scan_results and scan_results.get('risk_score', 0) > 75:
                    high_risk_containers += 1
            
            score -= high_risk_containers * 5  # -5 points per high risk container
            
            # Check for critical vulnerabilities
            critical_vulns = await self._count_critical_vulnerabilities()
            score -= critical_vulns * 10  # -10 points per critical vuln
            
            # Check for failed SSH attempts
            failed_ssh = await self._count_recent_failed_ssh()
            if failed_ssh > 10:
                score -= 10  # -10 points for many failed attempts
            
            # Check patch compliance
            patch_status = await self._check_patch_compliance()
            if patch_status < 90:
                score -= 15  # -15 points for poor patch compliance
            
            # Ensure score is between 0 and 100
            score = max(0, min(100, score))
            
            security_score.set(score)
            patch_compliance.set(patch_status)
            
        except Exception as e:
            logger.error(f"Error calculating security score: {str(e)}")
    
    async def _get_container_scan_results(self, container_name: str) -> Dict[str, Any]:
        """Get latest scan results for container"""
        scan_dir = Path("/var/log/security/container-scans")
        if not scan_dir.exists():
            return {}
        
        # Find most recent scan for this container
        pattern = f"scan_{container_name}_*.json"
        scan_files = list(scan_dir.glob(pattern))
        
        if not scan_files:
            return {}
        
        # Get most recent file
        latest_file = max(scan_files, key=lambda p: p.stat().st_mtime)
        
        try:
            with open(latest_file, 'r') as f:
                data = json.load(f)
                
            # Extract vulnerability counts
            vuln_counts = {'critical': 0, 'high': 0, 'medium': 0, 'low': 0}
            for finding in data.get('findings', []):
                severity = finding.get('severity', 'low')
                vuln_counts[severity] = vuln_counts.get(severity, 0) + 1
            
            return {
                'risk_score': data.get('risk_score', 0),
                'vulnerability_counts': vuln_counts
            }
            
        except:
            return {}
    
    async def _count_blocked_ips(self) -> int:
        """Count IPs blocked by iptables"""
        try:
            result = subprocess.run(
                ['sudo', 'iptables', '-L', 'INPUT', '-n', '-v'],
                capture_output=True,
                text=True
            )
            
            blocked = 0
            for line in result.stdout.split('\n'):
                if 'DROP' in line and not '0.0.0.0/0' in line:
                    blocked += 1
            
            return blocked
            
        except:
            return 0
    
    async def _count_ssh_sessions(self) -> int:
        """Count active SSH sessions"""
        try:
            result = subprocess.run(['who'], capture_output=True, text=True)
            return len([line for line in result.stdout.split('\n') if 'pts/' in line])
        except:
            return 0
    
    async def _count_critical_vulnerabilities(self) -> int:
        """Count total critical vulnerabilities"""
        # This would aggregate from various sources
        return 0
    
    async def _count_recent_failed_ssh(self) -> int:
        """Count recent failed SSH attempts"""
        try:
            result = subprocess.run(
                ['grep', 'Failed password', '/var/log/auth.log'],
                capture_output=True,
                text=True
            )
            return len(result.stdout.split('\n'))
        except:
            return 0
    
    async def _check_patch_compliance(self) -> float:
        """Check system patch compliance percentage"""
        try:
            # Check for available updates
            result = subprocess.run(
                ['apt', 'list', '--upgradable'],
                capture_output=True,
                text=True
            )
            
            # Count upgradable packages
            upgradable = len([line for line in result.stdout.split('\n') if '/' in line])
            
            # Get total installed packages
            result = subprocess.run(
                ['dpkg', '-l'],
                capture_output=True,
                text=True
            )
            
            installed = len([line for line in result.stdout.split('\n') if line.startswith('ii')])
            
            if installed > 0:
                compliance = ((installed - upgradable) / installed) * 100
                return round(compliance, 2)
            
            return 100.0
            
        except:
            return 100.0


class MetricsExporter:
    """Exports metrics in various formats"""
    
    def __init__(self):
        self.collector = SecurityMetricsCollector()
    
    async def export_prometheus(self):
        """Export metrics for Prometheus"""
        await self.collector.collect_all_metrics()
    
    async def export_json(self) -> Dict[str, Any]:
        """Export metrics as JSON"""
        # Collect fresh metrics
        await self.collector.collect_all_metrics()
        
        # Read the prometheus file and convert to JSON
        metrics = {}
        
        if self.collector.metrics_file.exists():
            with open(self.collector.metrics_file, 'r') as f:
                for line in f:
                    if line.startswith('#'):
                        continue
                    
                    parts = line.strip().split(' ')
                    if len(parts) >= 2:
                        metric_name = parts[0].split('{')[0]
                        value = parts[-1]
                        
                        if metric_name not in metrics:
                            metrics[metric_name] = []
                        
                        metrics[metric_name].append({
                            'labels': parts[0],
                            'value': float(value)
                        })
        
        return {
            'timestamp': datetime.now().isoformat(),
            'metrics': metrics
        }


async def continuous_collection(interval: int = 60):
    """Continuously collect metrics"""
    exporter = MetricsExporter()
    
    while True:
        try:
            logger.info("Collecting security metrics...")
            await exporter.export_prometheus()
            
            # Also export JSON for dashboards
            json_metrics = await exporter.export_json()
            json_file = Path("/var/log/security/metrics/current.json")
            json_file.parent.mkdir(parents=True, exist_ok=True)
            
            with open(json_file, 'w') as f:
                json.dump(json_metrics, f, indent=2)
            
        except Exception as e:
            logger.error(f"Error in continuous collection: {str(e)}")
        
        await asyncio.sleep(interval)


def main():
    """Main entry point"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Security Metrics Collector')
    parser.add_argument('--once', action='store_true', help='Collect metrics once and exit')
    parser.add_argument('--interval', type=int, default=60, help='Collection interval in seconds')
    parser.add_argument('--output', choices=['prometheus', 'json'], default='prometheus',
                       help='Output format')
    
    args = parser.parse_args()
    
    if args.once:
        # Single collection
        exporter = MetricsExporter()
        
        if args.output == 'prometheus':
            asyncio.run(exporter.export_prometheus())
            print(f"Metrics written to {exporter.collector.metrics_file}")
        else:
            metrics = asyncio.run(exporter.export_json())
            print(json.dumps(metrics, indent=2))
    else:
        # Continuous collection
        asyncio.run(continuous_collection(args.interval))


if __name__ == "__main__":
    main()