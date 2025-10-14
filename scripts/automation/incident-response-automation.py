#!/usr/bin/env python3
"""
Automated Incident Response System
Implements security-first automated response patterns
"""

import asyncio
import json
import logging
import os
import subprocess
import time
from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum
from typing import Dict, List, Optional, Callable, Any
from pathlib import Path

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class IncidentSeverity(Enum):
    """Incident severity levels"""
    CRITICAL = 1
    HIGH = 2
    MEDIUM = 3
    LOW = 4
    INFO = 5


class IncidentType(Enum):
    """Types of security incidents"""
    BRUTE_FORCE = "brute_force"
    PORT_SCAN = "port_scan"
    MALWARE_DETECTED = "malware_detected"
    DATA_EXFILTRATION = "data_exfiltration"
    PRIVILEGE_ESCALATION = "privilege_escalation"
    DOS_ATTACK = "dos_attack"
    UNAUTHORIZED_ACCESS = "unauthorized_access"
    SUSPICIOUS_PROCESS = "suspicious_process"
    FILE_INTEGRITY = "file_integrity"


@dataclass
class Incident:
    """Security incident data structure"""
    id: str
    type: IncidentType
    severity: IncidentSeverity
    source_ip: Optional[str] = None
    target_ip: Optional[str] = None
    process_name: Optional[str] = None
    user: Optional[str] = None
    description: str = ""
    timestamp: datetime = field(default_factory=datetime.now)
    metadata: Dict[str, Any] = field(default_factory=dict)
    actions_taken: List[str] = field(default_factory=list)


class ResponseAction:
    """Base class for response actions"""
    
    def __init__(self, name: str):
        self.name = name
        self.logger = logging.getLogger(f"{__name__}.{name}")
    
    async def execute(self, incident: Incident) -> bool:
        """Execute the response action"""
        raise NotImplementedError
    
    def log_action(self, incident: Incident, success: bool, details: str = ""):
        """Log the action taken"""
        status = "SUCCESS" if success else "FAILED"
        self.logger.info(f"[{status}] {self.name} for incident {incident.id}: {details}")
        incident.actions_taken.append(f"{self.name}: {status} - {details}")


class BlockIPAction(ResponseAction):
    """Block IP address using iptables"""
    
    def __init__(self):
        super().__init__("Block IP")
    
    async def execute(self, incident: Incident) -> bool:
        if not incident.source_ip:
            self.log_action(incident, False, "No source IP provided")
            return False
        
        try:
            # Check if IP is already blocked
            check_cmd = f"sudo iptables -L INPUT -n | grep {incident.source_ip}"
            result = subprocess.run(check_cmd, shell=True, capture_output=True)
            
            if result.returncode == 0:
                self.log_action(incident, True, f"IP {incident.source_ip} already blocked")
                return True
            
            # Block the IP
            block_cmd = f"sudo iptables -A INPUT -s {incident.source_ip} -j DROP"
            result = subprocess.run(block_cmd, shell=True, capture_output=True)
            
            if result.returncode == 0:
                self.log_action(incident, True, f"Blocked IP {incident.source_ip}")
                return True
            else:
                self.log_action(incident, False, f"Failed to block IP: {result.stderr.decode()}")
                return False
                
        except Exception as e:
            self.log_action(incident, False, f"Error: {str(e)}")
            return False


class IsolateHostAction(ResponseAction):
    """Isolate host from network"""
    
    def __init__(self):
        super().__init__("Isolate Host")
    
    async def execute(self, incident: Incident) -> bool:
        try:
            # Create isolation rules
            isolation_rules = [
                # Allow only SSH from management network
                "sudo iptables -A INPUT -p tcp --dport 22 -s 10.0.0.0/8 -j ACCEPT",
                # Drop all other incoming
                "sudo iptables -A INPUT -j DROP",
                # Drop all outgoing except to management
                "sudo iptables -A OUTPUT -d 10.0.0.0/8 -j ACCEPT",
                "sudo iptables -A OUTPUT -j DROP"
            ]
            
            for rule in isolation_rules:
                subprocess.run(rule, shell=True, check=True)
            
            self.log_action(incident, True, "Host isolated from network")
            return True
            
        except Exception as e:
            self.log_action(incident, False, f"Error: {str(e)}")
            return False


class KillProcessAction(ResponseAction):
    """Kill suspicious process"""
    
    def __init__(self):
        super().__init__("Kill Process")
    
    async def execute(self, incident: Incident) -> bool:
        if not incident.process_name:
            self.log_action(incident, False, "No process name provided")
            return False
        
        try:
            # Find process PIDs
            find_cmd = f"pgrep -f {incident.process_name}"
            result = subprocess.run(find_cmd, shell=True, capture_output=True, text=True)
            
            if result.returncode != 0:
                self.log_action(incident, False, "Process not found")
                return False
            
            pids = result.stdout.strip().split('\n')
            
            # Kill processes
            for pid in pids:
                if pid:
                    kill_cmd = f"sudo kill -9 {pid}"
                    subprocess.run(kill_cmd, shell=True)
            
            self.log_action(incident, True, f"Killed process {incident.process_name} (PIDs: {', '.join(pids)})")
            return True
            
        except Exception as e:
            self.log_action(incident, False, f"Error: {str(e)}")
            return False


class CollectForensicsAction(ResponseAction):
    """Collect forensic evidence"""
    
    def __init__(self):
        super().__init__("Collect Forensics")
    
    async def execute(self, incident: Incident) -> bool:
        try:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            evidence_dir = f"/tmp/incident_{incident.id}_{timestamp}"
            os.makedirs(evidence_dir, exist_ok=True)
            
            # Commands to collect evidence
            evidence_commands = {
                "processes.txt": "ps auxf",
                "network_connections.txt": "ss -tulpn",
                "logged_users.txt": "w",
                "last_logins.txt": "last -50",
                "system_info.txt": "uname -a && uptime && df -h",
                "memory_info.txt": "free -h && cat /proc/meminfo",
                "loaded_modules.txt": "lsmod",
                "open_files.txt": "lsof",
                "iptables_rules.txt": "sudo iptables -L -n -v",
                "recent_commands.txt": "history",
            }
            
            # Collect logs
            log_files = [
                "/var/log/auth.log",
                "/var/log/syslog",
                "/var/log/kern.log",
                "/var/log/messages"
            ]
            
            # Execute evidence collection
            for filename, command in evidence_commands.items():
                output_file = os.path.join(evidence_dir, filename)
                subprocess.run(f"{command} > {output_file} 2>&1", shell=True)
            
            # Copy log files
            for log_file in log_files:
                if os.path.exists(log_file):
                    subprocess.run(f"sudo cp {log_file} {evidence_dir}/", shell=True)
            
            # Create archive
            archive_name = f"{evidence_dir}.tar.gz"
            subprocess.run(f"tar -czf {archive_name} -C /tmp {os.path.basename(evidence_dir)}", shell=True)
            
            self.log_action(incident, True, f"Forensics collected: {archive_name}")
            return True
            
        except Exception as e:
            self.log_action(incident, False, f"Error: {str(e)}")
            return False


class NotificationAction(ResponseAction):
    """Send notifications about incident"""
    
    def __init__(self):
        super().__init__("Send Notification")
    
    async def execute(self, incident: Incident) -> bool:
        try:
            # Format notification message
            message = f"""
🚨 SECURITY INCIDENT DETECTED 🚨

ID: {incident.id}
Type: {incident.type.value}
Severity: {incident.severity.name}
Time: {incident.timestamp}
Source IP: {incident.source_ip or 'N/A'}
Target IP: {incident.target_ip or 'N/A'}
Description: {incident.description}

Actions Taken:
{chr(10).join('- ' + action for action in incident.actions_taken)}
"""
            
            # Log to file (simulating notification)
            with open("/var/log/security_incidents.log", "a") as f:
                f.write(f"\n{'-'*50}\n{message}\n")
            
            # In production, integrate with Slack, PagerDuty, email, etc.
            self.log_action(incident, True, "Notification sent")
            return True
            
        except Exception as e:
            self.log_action(incident, False, f"Error: {str(e)}")
            return False


class IncidentResponseOrchestrator:
    """Orchestrates incident response based on playbooks"""
    
    def __init__(self):
        self.playbooks = self._load_playbooks()
        self.actions = {
            "block_ip": BlockIPAction(),
            "isolate_host": IsolateHostAction(),
            "kill_process": KillProcessAction(),
            "collect_forensics": CollectForensicsAction(),
            "notify": NotificationAction(),
        }
        self.incident_history: List[Incident] = []
    
    def _load_playbooks(self) -> Dict[IncidentType, List[str]]:
        """Load response playbooks for each incident type"""
        return {
            IncidentType.BRUTE_FORCE: [
                "block_ip",
                "collect_forensics",
                "notify"
            ],
            IncidentType.PORT_SCAN: [
                "block_ip",
                "notify"
            ],
            IncidentType.MALWARE_DETECTED: [
                "kill_process",
                "isolate_host",
                "collect_forensics",
                "notify"
            ],
            IncidentType.DATA_EXFILTRATION: [
                "isolate_host",
                "collect_forensics",
                "notify"
            ],
            IncidentType.PRIVILEGE_ESCALATION: [
                "kill_process",
                "collect_forensics",
                "isolate_host",
                "notify"
            ],
            IncidentType.DOS_ATTACK: [
                "block_ip",
                "notify"
            ],
            IncidentType.UNAUTHORIZED_ACCESS: [
                "block_ip",
                "collect_forensics",
                "notify"
            ],
            IncidentType.SUSPICIOUS_PROCESS: [
                "kill_process",
                "collect_forensics",
                "notify"
            ],
            IncidentType.FILE_INTEGRITY: [
                "collect_forensics",
                "notify"
            ]
        }
    
    async def respond_to_incident(self, incident: Incident):
        """Execute incident response playbook"""
        logger.info(f"Responding to incident {incident.id} - Type: {incident.type.value}, Severity: {incident.severity.name}")
        
        # Get playbook for incident type
        playbook = self.playbooks.get(incident.type, ["collect_forensics", "notify"])
        
        # Execute actions based on severity
        if incident.severity == IncidentSeverity.CRITICAL:
            # Execute all actions immediately in parallel for critical incidents
            tasks = []
            for action_name in playbook:
                if action_name in self.actions:
                    tasks.append(self.actions[action_name].execute(incident))
            
            results = await asyncio.gather(*tasks, return_exceptions=True)
            
        else:
            # Execute actions sequentially for non-critical incidents
            for action_name in playbook:
                if action_name in self.actions:
                    try:
                        await self.actions[action_name].execute(incident)
                    except Exception as e:
                        logger.error(f"Error executing {action_name}: {str(e)}")
        
        # Save incident to history
        self.incident_history.append(incident)
        self._save_incident_report(incident)
    
    def _save_incident_report(self, incident: Incident):
        """Save detailed incident report"""
        report_dir = "/var/log/incident_reports"
        os.makedirs(report_dir, exist_ok=True)
        
        report_file = os.path.join(report_dir, f"incident_{incident.id}.json")
        
        report_data = {
            "id": incident.id,
            "type": incident.type.value,
            "severity": incident.severity.name,
            "timestamp": incident.timestamp.isoformat(),
            "source_ip": incident.source_ip,
            "target_ip": incident.target_ip,
            "process_name": incident.process_name,
            "user": incident.user,
            "description": incident.description,
            "metadata": incident.metadata,
            "actions_taken": incident.actions_taken
        }
        
        with open(report_file, "w") as f:
            json.dump(report_data, f, indent=2)


async def simulate_incident_response():
    """Simulate various incident responses for testing"""
    orchestrator = IncidentResponseOrchestrator()
    
    # Simulate different incidents
    test_incidents = [
        Incident(
            id="INC001",
            type=IncidentType.BRUTE_FORCE,
            severity=IncidentSeverity.HIGH,
            source_ip="192.168.1.100",
            description="Multiple failed SSH login attempts detected"
        ),
        Incident(
            id="INC002",
            type=IncidentType.SUSPICIOUS_PROCESS,
            severity=IncidentSeverity.CRITICAL,
            process_name="cryptominer",
            description="Cryptocurrency mining process detected"
        ),
        Incident(
            id="INC003",
            type=IncidentType.PORT_SCAN,
            severity=IncidentSeverity.MEDIUM,
            source_ip="10.0.0.50",
            description="Port scanning activity detected from internal host"
        )
    ]
    
    # Process incidents
    for incident in test_incidents:
        print(f"\n{'='*50}")
        print(f"Processing incident: {incident.id}")
        print(f"Type: {incident.type.value}")
        print(f"Severity: {incident.severity.name}")
        print(f"{'='*50}")
        
        await orchestrator.respond_to_incident(incident)
        
        # Wait between incidents
        await asyncio.sleep(2)
    
    # Print summary
    print(f"\n{'='*50}")
    print("INCIDENT RESPONSE SUMMARY")
    print(f"{'='*50}")
    print(f"Total incidents processed: {len(orchestrator.incident_history)}")
    for incident in orchestrator.incident_history:
        print(f"\nIncident {incident.id}:")
        print(f"  Type: {incident.type.value}")
        print(f"  Actions taken: {len(incident.actions_taken)}")
        for action in incident.actions_taken:
            print(f"    - {action}")


if __name__ == "__main__":
    # Run simulation
    print("Starting Incident Response System Simulation...")
    asyncio.run(simulate_incident_response())