#!/usr/bin/env python3
"""
Security Event Monitor
Monitors various sources for security events and triggers playbooks
"""

import asyncio
import re
import json
import logging
import subprocess
from datetime import datetime, timedelta
from pathlib import Path
from collections import defaultdict
from typing import Dict, List, Optional
import aiofiles
import docker
import pyinotify

from playbook_executor import PlaybookExecutor, SecurityEvent

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class EventDetector:
    """Base class for event detection"""
    
    def __init__(self):
        self.event_counts = defaultdict(lambda: defaultdict(int))
        self.event_windows = defaultdict(list)
    
    def check_threshold(self, event_key: str, threshold: int, window: int) -> bool:
        """Check if events exceed threshold within time window"""
        current_time = datetime.now()
        window_start = current_time - timedelta(seconds=window)
        
        # Clean old events
        self.event_windows[event_key] = [
            t for t in self.event_windows[event_key] 
            if t > window_start
        ]
        
        # Add current event
        self.event_windows[event_key].append(current_time)
        
        # Check threshold
        return len(self.event_windows[event_key]) >= threshold


class SSHMonitor(EventDetector):
    """Monitor SSH authentication events"""
    
    def __init__(self, log_file: str = "/var/log/auth.log"):
        super().__init__()
        self.log_file = Path(log_file)
        self.failed_pattern = re.compile(
            r'Failed password for (\S+) from (\S+) port \d+ ssh'
        )
        self.success_pattern = re.compile(
            r'Accepted \w+ for (\S+) from (\S+) port \d+ ssh'
        )
    
    async def monitor(self, callback):
        """Monitor SSH logs for security events"""
        if not self.log_file.exists():
            logger.error(f"SSH log file {self.log_file} not found")
            return
        
        # Start tailing the log file
        process = await asyncio.create_subprocess_exec(
            'tail', '-F', str(self.log_file),
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )
        
        async for line in process.stdout:
            line = line.decode('utf-8').strip()
            
            # Check for failed login
            match = self.failed_pattern.search(line)
            if match:
                user = match.group(1)
                source_ip = match.group(2)
                
                # Check for brute force
                event_key = f"ssh_failed_{source_ip}"
                if self.check_threshold(event_key, 5, 300):  # 5 failures in 5 minutes
                    event = SecurityEvent(
                        event_type='brute_force',
                        source_ip=source_ip,
                        user=user,
                        details={
                            'service': 'ssh',
                            'failed_attempts': len(self.event_windows[event_key])
                        }
                    )
                    await callback(event)
            
            # Check for successful login from unknown IP
            match = self.success_pattern.search(line)
            if match:
                user = match.group(1)
                source_ip = match.group(2)
                
                # Check whitelist
                if not await self._is_whitelisted(source_ip):
                    event = SecurityEvent(
                        event_type='unauthorized_access',
                        source_ip=source_ip,
                        user=user,
                        details={'service': 'ssh', 'action': 'login'}
                    )
                    await callback(event)
    
    async def _is_whitelisted(self, ip: str) -> bool:
        """Check if IP is whitelisted"""
        whitelist_file = Path("/etc/ssh/whitelist.ips")
        if not whitelist_file.exists():
            return False
        
        async with aiofiles.open(whitelist_file, 'r') as f:
            whitelist = await f.read()
            return ip in whitelist


class DockerMonitor(EventDetector):
    """Monitor Docker events"""
    
    def __init__(self):
        super().__init__()
        self.client = docker.from_env()
        self.dangerous_images = ['alpine', 'busybox']  # Example
        self.dangerous_mounts = ['/', '/etc', '/root', '/var/run/docker.sock']
    
    async def monitor(self, callback):
        """Monitor Docker events"""
        # Monitor events in a separate thread
        loop = asyncio.get_event_loop()
        
        def event_generator():
            for event in self.client.events(decode=True):
                loop.create_task(self._process_event(event, callback))
        
        # Run in executor to avoid blocking
        await loop.run_in_executor(None, event_generator)
    
    async def _process_event(self, event: Dict, callback):
        """Process Docker event"""
        status = event.get('status', '')
        actor = event.get('Actor', {})
        
        # Container started
        if status == 'start':
            container_id = actor.get('ID', '')
            attributes = actor.get('Attributes', {})
            image = attributes.get('image', '')
            
            try:
                container = self.client.containers.get(container_id)
                
                # Check for privileged container
                if container.attrs['HostConfig'].get('Privileged'):
                    await callback(SecurityEvent(
                        event_type='container_compromise',
                        container_id=container_id,
                        details={
                            'reason': 'privileged_container',
                            'image': image
                        }
                    ))
                
                # Check for dangerous mounts
                mounts = container.attrs['Mounts']
                for mount in mounts:
                    source = mount.get('Source', '')
                    if any(source.startswith(dangerous) for dangerous in self.dangerous_mounts):
                        await callback(SecurityEvent(
                            event_type='container_compromise',
                            container_id=container_id,
                            details={
                                'reason': 'dangerous_mount',
                                'mount': source,
                                'image': image
                            }
                        ))
                
            except docker.errors.NotFound:
                pass


class NetworkMonitor(EventDetector):
    """Monitor network events"""
    
    def __init__(self):
        super().__init__()
        self.port_scan_threshold = 20  # ports in 10 seconds
        self.data_exfil_threshold = 1073741824  # 1GB
    
    async def monitor(self, callback):
        """Monitor network activity"""
        while True:
            try:
                # Check for port scans using netstat
                await self._check_port_scans(callback)
                
                # Check for data exfiltration
                await self._check_data_exfiltration(callback)
                
                await asyncio.sleep(10)  # Check every 10 seconds
                
            except Exception as e:
                logger.error(f"Network monitoring error: {str(e)}")
                await asyncio.sleep(60)
    
    async def _check_port_scans(self, callback):
        """Check for port scanning activity"""
        # Get current connections
        result = subprocess.run(
            ['ss', '-tn'], 
            capture_output=True, 
            text=True
        )
        
        if result.returncode != 0:
            return
        
        # Count SYN_SENT connections per source IP
        syn_counts = defaultdict(int)
        for line in result.stdout.split('\n'):
            if 'SYN-SENT' in line:
                parts = line.split()
                if len(parts) >= 5:
                    # Extract source IP
                    src = parts[4].split(':')[0]
                    syn_counts[src] += 1
        
        # Check for port scan threshold
        for src_ip, count in syn_counts.items():
            if count >= self.port_scan_threshold:
                event_key = f"port_scan_{src_ip}"
                if self.check_threshold(event_key, 1, 60):  # Once per minute
                    await callback(SecurityEvent(
                        event_type='port_scan',
                        source_ip=src_ip,
                        details={
                            'syn_count': count,
                            'threshold': self.port_scan_threshold
                        }
                    ))
    
    async def _check_data_exfiltration(self, callback):
        """Check for unusual outbound data transfers"""
        # Read network statistics
        with open('/proc/net/dev', 'r') as f:
            lines = f.readlines()
        
        for line in lines[2:]:  # Skip headers
            if ':' in line:
                interface, stats = line.split(':')
                interface = interface.strip()
                
                # Skip loopback
                if interface == 'lo':
                    continue
                
                # Parse transmitted bytes (10th field)
                fields = stats.split()
                if len(fields) >= 9:
                    tx_bytes = int(fields[8])
                    
                    # Check threshold
                    event_key = f"data_exfil_{interface}"
                    
                    # Store baseline if first time
                    if event_key not in self.event_counts:
                        self.event_counts[event_key]['baseline'] = tx_bytes
                        self.event_counts[event_key]['last_check'] = datetime.now()
                        continue
                    
                    # Calculate rate
                    baseline = self.event_counts[event_key]['baseline']
                    last_check = self.event_counts[event_key]['last_check']
                    time_diff = (datetime.now() - last_check).total_seconds()
                    
                    if time_diff > 0:
                        byte_diff = tx_bytes - baseline
                        rate = byte_diff / time_diff  # bytes per second
                        
                        # Check if rate exceeds threshold (1GB in 1 hour = ~300KB/s)
                        if rate > 300000:  # 300KB/s
                            await callback(SecurityEvent(
                                event_type='data_exfiltration',
                                details={
                                    'interface': interface,
                                    'rate_mbps': rate / 1048576,
                                    'total_bytes': byte_diff
                                }
                            ))
                    
                    # Update baseline
                    self.event_counts[event_key]['baseline'] = tx_bytes
                    self.event_counts[event_key]['last_check'] = datetime.now()


class ProcessMonitor(EventDetector):
    """Monitor suspicious processes"""
    
    def __init__(self):
        super().__init__()
        self.suspicious_names = [
            'cryptominer', 'xmrig', 'minerd', 'xmr-stak',
            'ccminer', 'xmrMiner', 'wolf-xmr-miner',
            'nicehashminer', 'excavator'
        ]
        self.suspicious_paths = ['/tmp/', '/var/tmp/', '/dev/shm/']
    
    async def monitor(self, callback):
        """Monitor for suspicious processes"""
        while True:
            try:
                # Get process list
                result = subprocess.run(
                    ['ps', 'aux'], 
                    capture_output=True, 
                    text=True
                )
                
                if result.returncode == 0:
                    for line in result.stdout.split('\n')[1:]:  # Skip header
                        fields = line.split(None, 10)
                        if len(fields) >= 11:
                            user = fields[0]
                            pid = fields[1]
                            cpu = float(fields[2])
                            mem = float(fields[3])
                            command = fields[10]
                            
                            # Check for suspicious process names
                            for sus_name in self.suspicious_names:
                                if sus_name in command.lower():
                                    await callback(SecurityEvent(
                                        event_type='malware',
                                        process_name=sus_name,
                                        user=user,
                                        details={
                                            'pid': pid,
                                            'cpu_percent': cpu,
                                            'mem_percent': mem,
                                            'command': command
                                        }
                                    ))
                                    break
                            
                            # Check for suspicious paths
                            for sus_path in self.suspicious_paths:
                                if sus_path in command and cpu > 50:
                                    await callback(SecurityEvent(
                                        event_type='suspicious_process',
                                        process_name=command.split()[0],
                                        user=user,
                                        details={
                                            'pid': pid,
                                            'cpu_percent': cpu,
                                            'path': sus_path,
                                            'command': command
                                        }
                                    ))
                                    break
                
                await asyncio.sleep(30)  # Check every 30 seconds
                
            except Exception as e:
                logger.error(f"Process monitoring error: {str(e)}")
                await asyncio.sleep(60)


class SecurityEventMonitor:
    """Main security event monitoring system"""
    
    def __init__(self):
        self.monitors = []
        self.executor = PlaybookExecutor()
        self.event_log = Path("/var/log/security/events.json")
        self.event_log.parent.mkdir(parents=True, exist_ok=True)
    
    def add_monitor(self, monitor: EventDetector):
        """Add a monitor to the system"""
        self.monitors.append(monitor)
    
    async def process_event(self, event: SecurityEvent):
        """Process security event and trigger appropriate playbook"""
        logger.info(f"Security event detected: {event.event_type}")
        
        # Log event
        await self._log_event(event)
        
        # Find matching playbook
        playbook = self.executor.match_event_to_playbook(event)
        
        if playbook:
            logger.info(f"Triggering playbook: {playbook}")
            await self.executor.execute_playbook(playbook, event)
        else:
            logger.warning(f"No playbook found for event type: {event.event_type}")
    
    async def _log_event(self, event: SecurityEvent):
        """Log security event to file"""
        event_data = {
            'timestamp': event.timestamp.isoformat(),
            'type': event.event_type,
            'source_ip': event.source_ip,
            'target_ip': event.target_ip,
            'user': event.user,
            'process': event.process_name,
            'container': event.container_id,
            'details': event.details
        }
        
        # Append to log file
        async with aiofiles.open(self.event_log, 'a') as f:
            await f.write(json.dumps(event_data) + '\n')
    
    async def start(self):
        """Start all monitors"""
        logger.info("Starting security event monitoring...")
        
        # Create monitor tasks
        tasks = []
        for monitor in self.monitors:
            task = asyncio.create_task(monitor.monitor(self.process_event))
            tasks.append(task)
        
        # Wait for all monitors
        try:
            await asyncio.gather(*tasks)
        except KeyboardInterrupt:
            logger.info("Monitoring stopped by user")
        except Exception as e:
            logger.error(f"Monitoring error: {str(e)}")


async def main():
    """Main entry point"""
    # Create monitoring system
    monitor_system = SecurityEventMonitor()
    
    # Add monitors
    monitor_system.add_monitor(SSHMonitor())
    monitor_system.add_monitor(DockerMonitor())
    monitor_system.add_monitor(NetworkMonitor())
    monitor_system.add_monitor(ProcessMonitor())
    
    # Start monitoring
    await monitor_system.start()


if __name__ == "__main__":
    asyncio.run(main())