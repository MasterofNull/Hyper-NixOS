#!/usr/bin/env python3
"""
Playbook Executor - Automated Incident Response
Executes response playbooks based on security events
"""

import yaml
import asyncio
import logging
import subprocess
import json
import time
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Any, Optional
import aiofiles
import docker
from dataclasses import dataclass, field

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


@dataclass
class SecurityEvent:
    """Represents a security event that triggers a playbook"""
    event_type: str
    source_ip: Optional[str] = None
    target_ip: Optional[str] = None
    process_name: Optional[str] = None
    container_id: Optional[str] = None
    user: Optional[str] = None
    details: Dict[str, Any] = field(default_factory=dict)
    timestamp: datetime = field(default_factory=datetime.now)


class ActionExecutor:
    """Executes individual playbook actions"""
    
    def __init__(self):
        self.docker_client = docker.from_env()
        self.rate_limits = {}  # Track notification rate limits
    
    async def execute_action(self, action: Dict, event: SecurityEvent) -> bool:
        """Execute a single action from a playbook"""
        action_type = action['type']
        parameters = action.get('parameters', {})
        
        try:
            if action_type == 'firewall':
                return await self._firewall_action(parameters, event)
            elif action_type == 'forensics':
                return await self._forensics_action(parameters, event)
            elif action_type == 'notification':
                return await self._notification_action(parameters, event)
            elif action_type == 'process':
                return await self._process_action(parameters, event)
            elif action_type == 'docker':
                return await self._docker_action(parameters, event)
            elif action_type == 'network':
                return await self._network_action(parameters, event)
            elif action_type == 'command':
                return await self._command_action(parameters, event)
            else:
                logger.warning(f"Unknown action type: {action_type}")
                return False
        except Exception as e:
            logger.error(f"Error executing {action_type} action: {str(e)}")
            return False
    
    async def _firewall_action(self, params: Dict, event: SecurityEvent) -> bool:
        """Execute firewall actions"""
        action = params.get('action', 'block')
        duration = params.get('duration', 3600)
        
        if action == 'block' and event.source_ip:
            # Block IP
            cmd = f"sudo iptables -A INPUT -s {event.source_ip} -j DROP"
            result = subprocess.run(cmd, shell=True, capture_output=True)
            
            if result.returncode == 0:
                logger.info(f"Blocked IP {event.source_ip}")
                
                # Schedule unblock
                if duration > 0:
                    unblock_cmd = f"echo 'sudo iptables -D INPUT -s {event.source_ip} -j DROP' | at now + {duration} seconds"
                    subprocess.run(unblock_cmd, shell=True)
                    logger.info(f"Scheduled unblock in {duration} seconds")
                
                return True
        
        return False
    
    async def _forensics_action(self, params: Dict, event: SecurityEvent) -> bool:
        """Collect forensic evidence"""
        evidence_dir = Path(f"/var/log/security/incidents/{event.timestamp.strftime('%Y%m%d_%H%M%S')}")
        evidence_dir.mkdir(parents=True, exist_ok=True)
        
        # Collect logs
        if 'logs' in params:
            for log_file in params['logs']:
                if Path(log_file).exists():
                    lines = params.get('lines', 100)
                    cmd = f"tail -n {lines} {log_file} > {evidence_dir}/{Path(log_file).name}"
                    subprocess.run(cmd, shell=True)
                    logger.info(f"Collected {log_file}")
        
        # Capture packets if requested
        if params.get('capture_packets'):
            pcap_size = params.get('pcap_size', '10M')
            pcap_file = evidence_dir / "capture.pcap"
            cmd = f"timeout 60 tcpdump -i any -w {pcap_file} -C {pcap_size}"
            subprocess.Popen(cmd, shell=True)
            logger.info("Started packet capture")
        
        # Memory dump if requested
        if params.get('dump_memory'):
            # This is a simplified example - real memory dumping requires specialized tools
            cmd = f"sudo cat /proc/meminfo > {evidence_dir}/meminfo.txt"
            subprocess.run(cmd, shell=True)
            cmd = f"sudo ps auxf > {evidence_dir}/processes.txt"
            subprocess.run(cmd, shell=True)
            logger.info("Collected memory information")
        
        # Full snapshot
        if params.get('full_snapshot'):
            snapshot_script = "/opt/scripts/security/ir-snapshot.sh"
            if Path(snapshot_script).exists():
                cmd = f"{snapshot_script} {evidence_dir}"
                subprocess.run(cmd, shell=True)
                logger.info("Created full system snapshot")
        
        return True
    
    async def _notification_action(self, params: Dict, event: SecurityEvent) -> bool:
        """Send notifications"""
        severity = params.get('severity', 'medium')
        channels = params.get('channels', ['email'])
        
        # Check rate limiting
        rate_key = f"{event.event_type}_{severity}"
        last_sent = self.rate_limits.get(rate_key, 0)
        current_time = time.time()
        
        if current_time - last_sent < 300:  # 5 minute rate limit
            logger.info("Notification rate limited")
            return True
        
        # Prepare notification
        message = f"""
Security Incident Detected

Type: {event.event_type}
Severity: {severity}
Time: {event.timestamp}
Source IP: {event.source_ip or 'N/A'}
Target IP: {event.target_ip or 'N/A'}
User: {event.user or 'N/A'}

Details: {json.dumps(event.details, indent=2)}
"""
        
        # Send to configured channels
        notification_script = "/opt/scripts/automation/notify.sh"
        if Path(notification_script).exists():
            title = f"Security Alert: {event.event_type}"
            cmd = f'{notification_script} "{title}" "{message}" "{severity}"'
            subprocess.run(cmd, shell=True)
            
            self.rate_limits[rate_key] = current_time
            logger.info(f"Notification sent to {channels}")
            return True
        
        return False
    
    async def _process_action(self, params: Dict, event: SecurityEvent) -> bool:
        """Handle process-related actions"""
        if not event.process_name:
            return False
        
        signal = params.get('signal', 'SIGTERM')
        
        # Find and kill process
        cmd = f"pkill -{signal} -f {event.process_name}"
        result = subprocess.run(cmd, shell=True, capture_output=True)
        
        if result.returncode == 0:
            logger.info(f"Killed process {event.process_name} with {signal}")
            return True
        
        return False
    
    async def _docker_action(self, params: Dict, event: SecurityEvent) -> bool:
        """Handle Docker container actions"""
        if not event.container_id:
            return False
        
        try:
            container = self.docker_client.containers.get(event.container_id)
            action = params.get('action', 'stop')
            
            if action == 'pause':
                container.pause()
                logger.info(f"Paused container {event.container_id}")
            elif action == 'stop':
                container.stop()
                logger.info(f"Stopped container {event.container_id}")
            elif action == 'remove':
                container.remove(force=True)
                logger.info(f"Removed container {event.container_id}")
            
            # Disconnect networks if requested
            if params.get('disconnect_networks'):
                for network in container.attrs['NetworkSettings']['Networks']:
                    container.disconnect(network)
                    logger.info(f"Disconnected from network {network}")
            
            return True
            
        except docker.errors.NotFound:
            logger.error(f"Container {event.container_id} not found")
            return False
        except Exception as e:
            logger.error(f"Docker action failed: {str(e)}")
            return False
    
    async def _network_action(self, params: Dict, event: SecurityEvent) -> bool:
        """Execute network-related actions"""
        action = params.get('action', 'isolate')
        
        if action == 'isolate':
            # Network isolation commands
            cmds = [
                "sudo iptables -I INPUT -j DROP",
                "sudo iptables -I OUTPUT -j DROP",
                "sudo iptables -I INPUT -s 10.0.0.0/8 -j ACCEPT",  # Allow management
                "sudo iptables -I OUTPUT -d 10.0.0.0/8 -j ACCEPT"
            ]
            
            for cmd in cmds:
                subprocess.run(cmd, shell=True)
            
            logger.info("Network isolated")
            return True
        
        elif action == 'throttle' and params.get('limit'):
            # Bandwidth throttling using tc
            limit = params['limit']
            cmd = f"sudo tc qdisc add dev eth0 root tbf rate {limit} burst 32kbit latency 400ms"
            subprocess.run(cmd, shell=True)
            logger.info(f"Bandwidth limited to {limit}")
            return True
        
        return False
    
    async def _command_action(self, params: Dict, event: SecurityEvent) -> bool:
        """Execute custom commands"""
        command = params.get('command')
        if not command:
            return False
        
        # Substitute event variables
        command = command.format(
            source_ip=event.source_ip or '',
            target_ip=event.target_ip or '',
            user=event.user or '',
            process=event.process_name or ''
        )
        
        result = subprocess.run(command, shell=True, capture_output=True)
        
        if result.returncode == 0:
            logger.info(f"Executed command: {command}")
            return True
        else:
            logger.error(f"Command failed: {result.stderr.decode()}")
            return False


class PlaybookExecutor:
    """Main playbook executor"""
    
    def __init__(self, playbook_file: str = "incident-response-playbooks.yaml"):
        self.playbook_file = Path(playbook_file)
        self.playbooks = self._load_playbooks()
        self.action_executor = ActionExecutor()
        self.execution_history = []
    
    def _load_playbooks(self) -> Dict:
        """Load playbooks from YAML file"""
        if not self.playbook_file.exists():
            logger.error(f"Playbook file {self.playbook_file} not found")
            return {}
        
        with open(self.playbook_file, 'r') as f:
            data = yaml.safe_load(f)
            return data.get('playbooks', {})
    
    async def execute_playbook(self, playbook_name: str, event: SecurityEvent):
        """Execute a specific playbook"""
        if playbook_name not in self.playbooks:
            logger.error(f"Playbook {playbook_name} not found")
            return
        
        playbook = self.playbooks[playbook_name]
        logger.info(f"Executing playbook: {playbook['name']}")
        
        # Record execution
        execution_record = {
            'playbook': playbook_name,
            'event': event,
            'timestamp': datetime.now(),
            'actions_executed': [],
            'success': True
        }
        
        # Execute each action
        for action in playbook['actions']:
            logger.info(f"Executing action: {action['name']}")
            
            success = await self.action_executor.execute_action(action, event)
            
            execution_record['actions_executed'].append({
                'name': action['name'],
                'success': success
            })
            
            if not success:
                execution_record['success'] = False
                logger.warning(f"Action {action['name']} failed")
        
        self.execution_history.append(execution_record)
        
        # Save execution history
        await self._save_execution_history()
    
    async def _save_execution_history(self):
        """Save execution history to file"""
        history_file = Path("/var/log/security/playbook_executions.json")
        history_file.parent.mkdir(parents=True, exist_ok=True)
        
        # Convert to serializable format
        history_data = []
        for record in self.execution_history[-100:]:  # Keep last 100 executions
            history_data.append({
                'playbook': record['playbook'],
                'timestamp': record['timestamp'].isoformat(),
                'success': record['success'],
                'actions': record['actions_executed']
            })
        
        async with aiofiles.open(history_file, 'w') as f:
            await f.write(json.dumps(history_data, indent=2))
    
    def match_event_to_playbook(self, event: SecurityEvent) -> Optional[str]:
        """Match an event to appropriate playbook"""
        # Simple matching based on event type
        event_playbook_map = {
            'brute_force': 'brute_force_ssh',
            'port_scan': 'port_scan_detected',
            'malware': 'malware_detected',
            'privilege_escalation': 'privilege_escalation',
            'data_exfiltration': 'data_exfiltration',
            'container_compromise': 'container_compromise'
        }
        
        return event_playbook_map.get(event.event_type)


async def main():
    """Example usage"""
    executor = PlaybookExecutor("/opt/scripts/security/incident-response-playbooks.yaml")
    
    # Example: Brute force attack
    event = SecurityEvent(
        event_type='brute_force',
        source_ip='192.168.1.100',
        target_ip='10.0.0.50',
        user='admin',
        details={'failed_attempts': 10}
    )
    
    playbook = executor.match_event_to_playbook(event)
    if playbook:
        await executor.execute_playbook(playbook, event)
    else:
        logger.warning(f"No playbook found for event type: {event.event_type}")


if __name__ == "__main__":
    asyncio.run(main())