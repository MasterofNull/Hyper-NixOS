#!/usr/bin/env python3
"""
Container Security Automation
Comprehensive Docker container security scanning and enforcement
"""

import asyncio
import docker
import json
import yaml
from pathlib import Path
from datetime import datetime, timedelta
from typing import List, Dict, Any, Optional, Set
import argparse
import logging
from dataclasses import dataclass, field
import subprocess
import hashlib
import re

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


@dataclass
class ContainerScanResult:
    """Container scan result"""
    container_id: str
    container_name: str
    image: str
    image_id: str
    scan_type: str
    findings: List[Dict[str, Any]]
    risk_score: int
    timestamp: datetime
    recommendations: List[str]


@dataclass
class SecurityPolicy:
    """Container security policy"""
    name: str
    description: str
    rules: List[Dict[str, Any]]
    enforcement: str  # warn, block, quarantine
    exceptions: List[str] = field(default_factory=list)


class ContainerSecurityScanner:
    """Scans containers for security issues"""
    
    def __init__(self):
        self.docker_client = docker.from_env()
        self.scan_history = {}
        
    async def scan_container(self, container_id: str) -> ContainerScanResult:
        """Comprehensive container security scan"""
        try:
            container = self.docker_client.containers.get(container_id)
            
            # Get container info
            container_name = container.name
            image = container.image.tags[0] if container.image.tags else container.image.id
            image_id = container.image.id
            
            findings = []
            
            # 1. Check for privileged mode
            if container.attrs['HostConfig'].get('Privileged', False):
                findings.append({
                    'type': 'configuration',
                    'severity': 'critical',
                    'title': 'Privileged Container',
                    'description': 'Container is running in privileged mode',
                    'remediation': 'Remove privileged flag unless absolutely necessary'
                })
            
            # 2. Check capabilities
            cap_add = container.attrs['HostConfig'].get('CapAdd', [])
            dangerous_caps = ['SYS_ADMIN', 'SYS_PTRACE', 'SYS_MODULE', 'NET_ADMIN']
            for cap in cap_add:
                if cap in dangerous_caps:
                    findings.append({
                        'type': 'capability',
                        'severity': 'high',
                        'title': f'Dangerous Capability: {cap}',
                        'description': f'Container has dangerous capability {cap}',
                        'remediation': f'Remove capability {cap} if not required'
                    })
            
            # 3. Check volume mounts
            mounts = container.attrs.get('Mounts', [])
            dangerous_paths = ['/', '/etc', '/var/run/docker.sock', '/root', '/home']
            for mount in mounts:
                source = mount.get('Source', '')
                for dangerous_path in dangerous_paths:
                    if source.startswith(dangerous_path):
                        findings.append({
                            'type': 'mount',
                            'severity': 'high',
                            'title': f'Dangerous Mount: {source}',
                            'description': f'Container mounts sensitive path {source}',
                            'remediation': 'Use more restrictive mount paths'
                        })
            
            # 4. Check for root user
            user = container.attrs['Config'].get('User', '')
            if not user or user == 'root' or user == '0':
                findings.append({
                    'type': 'user',
                    'severity': 'medium',
                    'title': 'Running as Root',
                    'description': 'Container is running as root user',
                    'remediation': 'Use non-root user in Dockerfile'
                })
            
            # 5. Check network mode
            network_mode = container.attrs['HostConfig'].get('NetworkMode', '')
            if network_mode == 'host':
                findings.append({
                    'type': 'network',
                    'severity': 'high',
                    'title': 'Host Network Mode',
                    'description': 'Container uses host network mode',
                    'remediation': 'Use bridge or custom network instead'
                })
            
            # 6. Check PID mode
            pid_mode = container.attrs['HostConfig'].get('PidMode', '')
            if pid_mode == 'host':
                findings.append({
                    'type': 'namespace',
                    'severity': 'high',
                    'title': 'Host PID Namespace',
                    'description': 'Container shares host PID namespace',
                    'remediation': 'Use container PID namespace'
                })
            
            # 7. Check security options
            security_opt = container.attrs['HostConfig'].get('SecurityOpt', [])
            if not any('seccomp' in opt for opt in security_opt):
                findings.append({
                    'type': 'seccomp',
                    'severity': 'medium',
                    'title': 'No Seccomp Profile',
                    'description': 'Container runs without seccomp profile',
                    'remediation': 'Apply seccomp profile'
                })
            
            # 8. Check resource limits
            if not container.attrs['HostConfig'].get('Memory'):
                findings.append({
                    'type': 'resources',
                    'severity': 'low',
                    'title': 'No Memory Limit',
                    'description': 'Container has no memory limit',
                    'remediation': 'Set memory limits to prevent DoS'
                })
            
            # 9. Scan image for vulnerabilities
            image_findings = await self._scan_image_vulnerabilities(image)
            findings.extend(image_findings)
            
            # Calculate risk score
            risk_score = self._calculate_risk_score(findings)
            
            # Generate recommendations
            recommendations = self._generate_recommendations(findings)
            
            return ContainerScanResult(
                container_id=container_id,
                container_name=container_name,
                image=image,
                image_id=image_id,
                scan_type='comprehensive',
                findings=findings,
                risk_score=risk_score,
                timestamp=datetime.now(),
                recommendations=recommendations
            )
            
        except docker.errors.NotFound:
            logger.error(f"Container {container_id} not found")
            raise
        except Exception as e:
            logger.error(f"Error scanning container {container_id}: {str(e)}")
            raise
    
    async def _scan_image_vulnerabilities(self, image: str) -> List[Dict[str, Any]]:
        """Scan image for vulnerabilities using Trivy"""
        findings = []
        
        try:
            # Run Trivy scan
            cmd = [
                'trivy', 'image',
                '--format', 'json',
                '--quiet',
                '--severity', 'CRITICAL,HIGH,MEDIUM',
                image
            ]
            
            process = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            
            stdout, stderr = await process.communicate()
            
            if process.returncode == 0 or process.returncode == 1:
                # Parse Trivy output
                data = json.loads(stdout.decode())
                
                vuln_summary = {'CRITICAL': 0, 'HIGH': 0, 'MEDIUM': 0}
                
                for result in data.get('Results', []):
                    for vuln in result.get('Vulnerabilities', []):
                        severity = vuln.get('Severity', 'UNKNOWN')
                        if severity in vuln_summary:
                            vuln_summary[severity] += 1
                
                # Add findings based on vulnerability counts
                if vuln_summary['CRITICAL'] > 0:
                    findings.append({
                        'type': 'vulnerability',
                        'severity': 'critical',
                        'title': f"{vuln_summary['CRITICAL']} Critical Vulnerabilities",
                        'description': f"Image contains {vuln_summary['CRITICAL']} critical vulnerabilities",
                        'remediation': 'Update base image and dependencies'
                    })
                
                if vuln_summary['HIGH'] > 5:
                    findings.append({
                        'type': 'vulnerability',
                        'severity': 'high',
                        'title': f"{vuln_summary['HIGH']} High Vulnerabilities",
                        'description': f"Image contains {vuln_summary['HIGH']} high severity vulnerabilities",
                        'remediation': 'Review and patch high severity vulnerabilities'
                    })
                    
        except Exception as e:
            logger.warning(f"Failed to scan image vulnerabilities: {str(e)}")
        
        return findings
    
    def _calculate_risk_score(self, findings: List[Dict[str, Any]]) -> int:
        """Calculate overall risk score (0-100)"""
        severity_weights = {
            'critical': 25,
            'high': 15,
            'medium': 5,
            'low': 1
        }
        
        score = 0
        for finding in findings:
            severity = finding.get('severity', 'low')
            score += severity_weights.get(severity, 0)
        
        return min(score, 100)
    
    def _generate_recommendations(self, findings: List[Dict[str, Any]]) -> List[str]:
        """Generate security recommendations"""
        recommendations = []
        
        finding_types = {f['type'] for f in findings}
        
        if 'configuration' in finding_types:
            recommendations.append("Review container configuration and remove unnecessary privileges")
        
        if 'capability' in finding_types:
            recommendations.append("Audit and minimize container capabilities")
        
        if 'mount' in finding_types:
            recommendations.append("Use volume mounts with minimal required access")
        
        if 'user' in finding_types:
            recommendations.append("Configure containers to run as non-root user")
        
        if 'vulnerability' in finding_types:
            recommendations.append("Regularly update base images and scan for vulnerabilities")
        
        if not findings:
            recommendations.append("Container follows security best practices")
        
        return recommendations


class ContainerSecurityEnforcer:
    """Enforces container security policies"""
    
    def __init__(self):
        self.docker_client = docker.from_env()
        self.policies = {}
        self.quarantine_network = None
        
    def load_policy(self, policy_file: str):
        """Load security policy from file"""
        with open(policy_file, 'r') as f:
            policy_data = yaml.safe_load(f)
        
        policy = SecurityPolicy(
            name=policy_data['name'],
            description=policy_data['description'],
            rules=policy_data['rules'],
            enforcement=policy_data.get('enforcement', 'warn'),
            exceptions=policy_data.get('exceptions', [])
        )
        
        self.policies[policy.name] = policy
        logger.info(f"Loaded policy: {policy.name}")
    
    async def enforce_policies(self, container_id: str, 
                             scan_result: ContainerScanResult) -> Dict[str, Any]:
        """Enforce security policies on container"""
        enforcement_results = {
            'container_id': container_id,
            'policies_checked': [],
            'violations': [],
            'actions_taken': []
        }
        
        for policy_name, policy in self.policies.items():
            # Check if container is excepted
            if container_id in policy.exceptions or scan_result.container_name in policy.exceptions:
                continue
            
            enforcement_results['policies_checked'].append(policy_name)
            
            # Check each rule
            for rule in policy.rules:
                violation = self._check_rule_violation(rule, scan_result)
                
                if violation:
                    enforcement_results['violations'].append({
                        'policy': policy_name,
                        'rule': rule['name'],
                        'severity': rule.get('severity', 'medium')
                    })
                    
                    # Take enforcement action
                    action = await self._enforce_action(
                        policy.enforcement,
                        container_id,
                        violation
                    )
                    
                    if action:
                        enforcement_results['actions_taken'].append(action)
        
        return enforcement_results
    
    def _check_rule_violation(self, rule: Dict[str, Any], 
                             scan_result: ContainerScanResult) -> Optional[Dict[str, Any]]:
        """Check if scan result violates a rule"""
        rule_type = rule['type']
        
        if rule_type == 'max_risk_score':
            max_score = rule['value']
            if scan_result.risk_score > max_score:
                return {
                    'rule': rule['name'],
                    'message': f"Risk score {scan_result.risk_score} exceeds maximum {max_score}"
                }
        
        elif rule_type == 'forbidden_capability':
            forbidden_caps = rule['value']
            for finding in scan_result.findings:
                if finding['type'] == 'capability':
                    for cap in forbidden_caps:
                        if cap in finding['title']:
                            return {
                                'rule': rule['name'],
                                'message': f"Forbidden capability detected: {cap}"
                            }
        
        elif rule_type == 'required_user':
            required_user = rule['value']
            for finding in scan_result.findings:
                if finding['type'] == 'user' and required_user == 'non-root':
                    return {
                        'rule': rule['name'],
                        'message': "Container must run as non-root user"
                    }
        
        elif rule_type == 'max_vulnerabilities':
            severity = rule.get('severity', 'high')
            max_count = rule['value']
            
            vuln_count = sum(1 for f in scan_result.findings 
                           if f['type'] == 'vulnerability' and f['severity'] == severity)
            
            if vuln_count > max_count:
                return {
                    'rule': rule['name'],
                    'message': f"Too many {severity} vulnerabilities: {vuln_count} > {max_count}"
                }
        
        return None
    
    async def _enforce_action(self, enforcement_mode: str, 
                            container_id: str, 
                            violation: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """Take enforcement action based on policy"""
        try:
            container = self.docker_client.containers.get(container_id)
            
            if enforcement_mode == 'warn':
                # Just log warning
                logger.warning(f"Policy violation for {container_id}: {violation['message']}")
                return {
                    'action': 'warn',
                    'message': violation['message']
                }
            
            elif enforcement_mode == 'block':
                # Stop container
                container.stop()
                logger.info(f"Stopped container {container_id} due to policy violation")
                return {
                    'action': 'stop',
                    'message': f"Container stopped: {violation['message']}"
                }
            
            elif enforcement_mode == 'quarantine':
                # Move to quarantine network
                await self._quarantine_container(container)
                logger.info(f"Quarantined container {container_id}")
                return {
                    'action': 'quarantine',
                    'message': f"Container quarantined: {violation['message']}"
                }
            
        except Exception as e:
            logger.error(f"Failed to enforce action: {str(e)}")
        
        return None
    
    async def _quarantine_container(self, container):
        """Move container to quarantine network"""
        # Create quarantine network if it doesn't exist
        if not self.quarantine_network:
            try:
                self.quarantine_network = self.docker_client.networks.get('quarantine')
            except docker.errors.NotFound:
                self.quarantine_network = self.docker_client.networks.create(
                    'quarantine',
                    driver='bridge',
                    internal=True,  # No external access
                    labels={'security': 'quarantine'}
                )
        
        # Disconnect from all networks
        for network in container.attrs['NetworkSettings']['Networks']:
            try:
                network_obj = self.docker_client.networks.get(network)
                network_obj.disconnect(container)
            except:
                pass
        
        # Connect to quarantine network
        self.quarantine_network.connect(container)


class ContainerSecurityMonitor:
    """Continuous container security monitoring"""
    
    def __init__(self):
        self.docker_client = docker.from_env()
        self.scanner = ContainerSecurityScanner()
        self.enforcer = ContainerSecurityEnforcer()
        self.scan_interval = 300  # 5 minutes
        self.results_dir = Path("/var/log/security/container-scans")
        self.results_dir.mkdir(parents=True, exist_ok=True)
    
    async def start_monitoring(self):
        """Start continuous monitoring"""
        logger.info("Starting container security monitoring")
        
        while True:
            try:
                # Get all running containers
                containers = self.docker_client.containers.list()
                
                logger.info(f"Scanning {len(containers)} running containers")
                
                # Scan each container
                for container in containers:
                    try:
                        # Skip system containers
                        if self._is_system_container(container):
                            continue
                        
                        # Scan container
                        scan_result = await self.scanner.scan_container(container.id)
                        
                        # Save scan result
                        await self._save_scan_result(scan_result)
                        
                        # Enforce policies
                        if self.enforcer.policies:
                            enforcement_result = await self.enforcer.enforce_policies(
                                container.id,
                                scan_result
                            )
                            
                            if enforcement_result['actions_taken']:
                                await self._alert_enforcement_actions(enforcement_result)
                        
                        # Alert on high risk containers
                        if scan_result.risk_score >= 75:
                            await self._alert_high_risk_container(scan_result)
                        
                    except Exception as e:
                        logger.error(f"Error scanning container {container.id}: {str(e)}")
                
                # Monitor for new containers
                await self._monitor_container_events()
                
            except Exception as e:
                logger.error(f"Monitoring error: {str(e)}")
            
            # Wait before next scan cycle
            await asyncio.sleep(self.scan_interval)
    
    def _is_system_container(self, container) -> bool:
        """Check if container is a system container"""
        system_prefixes = ['k8s_', 'kube-', 'calico-', 'weave-']
        return any(container.name.startswith(prefix) for prefix in system_prefixes)
    
    async def _save_scan_result(self, scan_result: ContainerScanResult):
        """Save scan result to file"""
        filename = f"scan_{scan_result.container_name}_{scan_result.timestamp.strftime('%Y%m%d_%H%M%S')}.json"
        filepath = self.results_dir / filename
        
        data = {
            'container_id': scan_result.container_id,
            'container_name': scan_result.container_name,
            'image': scan_result.image,
            'timestamp': scan_result.timestamp.isoformat(),
            'risk_score': scan_result.risk_score,
            'findings_count': len(scan_result.findings),
            'findings': scan_result.findings,
            'recommendations': scan_result.recommendations
        }
        
        async with asyncio.Lock():
            filepath.write_text(json.dumps(data, indent=2))
    
    async def _monitor_container_events(self):
        """Monitor for new container events"""
        # This would ideally use Docker events API
        # For now, we'll rely on periodic scanning
        pass
    
    async def _alert_high_risk_container(self, scan_result: ContainerScanResult):
        """Alert on high risk container"""
        message = f"""
High Risk Container Detected

Container: {scan_result.container_name}
Image: {scan_result.image}
Risk Score: {scan_result.risk_score}/100
Critical Findings: {sum(1 for f in scan_result.findings if f['severity'] == 'critical')}

Top Recommendations:
{chr(10).join(f"- {r}" for r in scan_result.recommendations[:3])}
"""
        
        # Send notification
        notify_script = "/opt/scripts/automation/notify.sh"
        if Path(notify_script).exists():
            subprocess.run([
                notify_script,
                "High Risk Container Alert",
                message,
                "high"
            ], capture_output=True)
    
    async def _alert_enforcement_actions(self, enforcement_result: Dict[str, Any]):
        """Alert on policy enforcement actions"""
        actions = enforcement_result['actions_taken']
        if not actions:
            return
        
        message = f"""
Container Security Policy Enforced

Container: {enforcement_result['container_id']}
Violations: {len(enforcement_result['violations'])}
Actions Taken:
{chr(10).join(f"- {a['action']}: {a['message']}" for a in actions)}
"""
        
        # Send notification
        notify_script = "/opt/scripts/automation/notify.sh"
        if Path(notify_script).exists():
            subprocess.run([
                notify_script,
                "Container Policy Enforcement",
                message,
                "warning"
            ], capture_output=True)


async def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(description='Container Security Automation')
    parser.add_argument('command', choices=['scan', 'monitor', 'enforce'],
                       help='Command to run')
    parser.add_argument('--container', help='Container ID or name to scan')
    parser.add_argument('--policy', help='Policy file to load')
    parser.add_argument('--interval', type=int, default=300,
                       help='Monitoring interval in seconds')
    
    args = parser.parse_args()
    
    if args.command == 'scan':
        if not args.container:
            print("Error: --container required for scan command")
            return
        
        scanner = ContainerSecurityScanner()
        result = await scanner.scan_container(args.container)
        
        print(f"\nContainer Security Scan Results")
        print(f"===============================")
        print(f"Container: {result.container_name}")
        print(f"Image: {result.image}")
        print(f"Risk Score: {result.risk_score}/100")
        print(f"\nFindings ({len(result.findings)}):")
        
        for finding in result.findings:
            severity_color = {
                'critical': '\033[91m',
                'high': '\033[93m',
                'medium': '\033[94m',
                'low': '\033[92m'
            }.get(finding['severity'], '')
            
            print(f"\n{severity_color}[{finding['severity'].upper()}]\033[0m {finding['title']}")
            print(f"  {finding['description']}")
            print(f"  Remediation: {finding['remediation']}")
        
        print(f"\nRecommendations:")
        for rec in result.recommendations:
            print(f"  - {rec}")
    
    elif args.command == 'monitor':
        monitor = ContainerSecurityMonitor()
        monitor.scan_interval = args.interval
        
        if args.policy:
            monitor.enforcer.load_policy(args.policy)
        
        await monitor.start_monitoring()
    
    elif args.command == 'enforce':
        if not args.policy:
            print("Error: --policy required for enforce command")
            return
        
        enforcer = ContainerSecurityEnforcer()
        enforcer.load_policy(args.policy)
        
        print(f"Loaded policy: {args.policy}")
        print("Policy enforcement active")


if __name__ == "__main__":
    asyncio.run(main())