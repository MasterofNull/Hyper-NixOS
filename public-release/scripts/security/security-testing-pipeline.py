#!/usr/bin/env python3
"""
Automated Security Testing Pipeline
Orchestrates multiple security tools for comprehensive testing
"""

import asyncio
import subprocess
import json
import yaml
from pathlib import Path
from datetime import datetime
from typing import List, Dict, Any, Optional
import argparse
import tempfile
import shutil
from dataclasses import dataclass, field
import logging

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


@dataclass
class TestResult:
    """Result from a security test"""
    tool: str
    target: str
    test_type: str
    status: str  # passed, failed, error
    findings: List[Dict[str, Any]]
    severity_counts: Dict[str, int]
    timestamp: datetime
    duration: float
    raw_output: str


@dataclass
class PipelineConfig:
    """Pipeline configuration"""
    name: str
    description: str
    targets: List[str]
    tests: List[Dict[str, Any]]
    notifications: Dict[str, Any] = field(default_factory=dict)
    thresholds: Dict[str, int] = field(default_factory=dict)
    parallel: bool = True
    stop_on_failure: bool = False


class SecurityTest:
    """Base class for security tests"""
    
    def __init__(self, config: Dict[str, Any]):
        self.config = config
        self.name = config.get('name', self.__class__.__name__)
        self.enabled = config.get('enabled', True)
    
    async def run(self, target: str) -> TestResult:
        """Run the security test"""
        raise NotImplementedError


class NmapTest(SecurityTest):
    """Network scanning with nmap"""
    
    async def run(self, target: str) -> TestResult:
        start_time = datetime.now()
        
        # Build nmap command
        ports = self.config.get('ports', '1-65535')
        scripts = self.config.get('scripts', 'default,vuln')
        
        cmd = [
            'nmap',
            '-sV',  # Version detection
            '-sS',  # SYN scan
            '-p', ports,
            '--script', scripts,
            '-oX', '-',  # XML output
            target
        ]
        
        if not self._is_root():
            cmd = ['sudo'] + cmd
        
        try:
            process = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            
            stdout, stderr = await process.communicate()
            duration = (datetime.now() - start_time).total_seconds()
            
            if process.returncode != 0:
                return TestResult(
                    tool='nmap',
                    target=target,
                    test_type='network_scan',
                    status='error',
                    findings=[],
                    severity_counts={},
                    timestamp=start_time,
                    duration=duration,
                    raw_output=stderr.decode()
                )
            
            # Parse results
            findings = self._parse_nmap_results(stdout.decode())
            severity_counts = self._count_severities(findings)
            
            return TestResult(
                tool='nmap',
                target=target,
                test_type='network_scan',
                status='passed' if not findings else 'failed',
                findings=findings,
                severity_counts=severity_counts,
                timestamp=start_time,
                duration=duration,
                raw_output=stdout.decode()
            )
            
        except Exception as e:
            duration = (datetime.now() - start_time).total_seconds()
            return TestResult(
                tool='nmap',
                target=target,
                test_type='network_scan',
                status='error',
                findings=[],
                severity_counts={},
                timestamp=start_time,
                duration=duration,
                raw_output=str(e)
            )
    
    def _is_root(self) -> bool:
        import os
        return os.geteuid() == 0
    
    def _parse_nmap_results(self, xml_data: str) -> List[Dict[str, Any]]:
        """Parse nmap XML output for findings"""
        findings = []
        
        try:
            import xml.etree.ElementTree as ET
            root = ET.fromstring(xml_data)
            
            for host in root.findall('.//host'):
                # Check for open ports
                for port in host.findall('.//port'):
                    state = port.find('state')
                    if state is not None and state.get('state') == 'open':
                        port_id = port.get('portid')
                        service = port.find('service')
                        service_name = service.get('name', 'unknown') if service is not None else 'unknown'
                        
                        findings.append({
                            'type': 'open_port',
                            'severity': 'info',
                            'port': int(port_id),
                            'service': service_name,
                            'description': f"Open port {port_id} ({service_name})"
                        })
                
                # Check for vulnerabilities
                for script in host.findall('.//script'):
                    if 'vuln' in script.get('id', ''):
                        output = script.get('output', '')
                        if 'VULNERABLE' in output:
                            findings.append({
                                'type': 'vulnerability',
                                'severity': 'high',
                                'script': script.get('id'),
                                'description': output[:200]
                            })
        
        except Exception as e:
            logger.error(f"Error parsing nmap results: {str(e)}")
        
        return findings
    
    def _count_severities(self, findings: List[Dict[str, Any]]) -> Dict[str, int]:
        """Count findings by severity"""
        counts = {'critical': 0, 'high': 0, 'medium': 0, 'low': 0, 'info': 0}
        for finding in findings:
            severity = finding.get('severity', 'info')
            counts[severity] = counts.get(severity, 0) + 1
        return counts


class TrivyTest(SecurityTest):
    """Container and filesystem vulnerability scanning"""
    
    async def run(self, target: str) -> TestResult:
        start_time = datetime.now()
        
        scan_type = self.config.get('scan_type', 'image')
        severity = self.config.get('severity', 'CRITICAL,HIGH,MEDIUM')
        
        cmd = [
            'trivy',
            scan_type,
            '--severity', severity,
            '--format', 'json',
            '--quiet',
            target
        ]
        
        try:
            process = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            
            stdout, stderr = await process.communicate()
            duration = (datetime.now() - start_time).total_seconds()
            
            if process.returncode not in [0, 1]:  # Trivy returns 1 if vulnerabilities found
                return TestResult(
                    tool='trivy',
                    target=target,
                    test_type=f'{scan_type}_scan',
                    status='error',
                    findings=[],
                    severity_counts={},
                    timestamp=start_time,
                    duration=duration,
                    raw_output=stderr.decode()
                )
            
            # Parse results
            findings = self._parse_trivy_results(stdout.decode())
            severity_counts = self._count_severities(findings)
            
            return TestResult(
                tool='trivy',
                target=target,
                test_type=f'{scan_type}_scan',
                status='passed' if not findings else 'failed',
                findings=findings,
                severity_counts=severity_counts,
                timestamp=start_time,
                duration=duration,
                raw_output=stdout.decode()
            )
            
        except Exception as e:
            duration = (datetime.now() - start_time).total_seconds()
            return TestResult(
                tool='trivy',
                target=target,
                test_type=f'{scan_type}_scan',
                status='error',
                findings=[],
                severity_counts={},
                timestamp=start_time,
                duration=duration,
                raw_output=str(e)
            )
    
    def _parse_trivy_results(self, json_data: str) -> List[Dict[str, Any]]:
        """Parse Trivy JSON output"""
        findings = []
        
        try:
            data = json.loads(json_data)
            
            for result in data.get('Results', []):
                for vuln in result.get('Vulnerabilities', []):
                    findings.append({
                        'type': 'vulnerability',
                        'severity': vuln.get('Severity', 'UNKNOWN').lower(),
                        'cve': vuln.get('VulnerabilityID'),
                        'package': vuln.get('PkgName'),
                        'version': vuln.get('InstalledVersion'),
                        'fixed_version': vuln.get('FixedVersion', 'None'),
                        'description': vuln.get('Title', vuln.get('Description', ''))[:200]
                    })
        
        except Exception as e:
            logger.error(f"Error parsing Trivy results: {str(e)}")
        
        return findings
    
    def _count_severities(self, findings: List[Dict[str, Any]]) -> Dict[str, int]:
        """Count findings by severity"""
        counts = {'critical': 0, 'high': 0, 'medium': 0, 'low': 0, 'unknown': 0}
        for finding in findings:
            severity = finding.get('severity', 'unknown')
            counts[severity] = counts.get(severity, 0) + 1
        return counts


class NucleiTest(SecurityTest):
    """Web vulnerability scanning with Nuclei"""
    
    async def run(self, target: str) -> TestResult:
        start_time = datetime.now()
        
        templates = self.config.get('templates', 'cves,vulnerabilities,exposures')
        severity = self.config.get('severity', 'critical,high,medium')
        
        cmd = [
            'nuclei',
            '-u', target,
            '-t', templates,
            '-severity', severity,
            '-json',
            '-silent'
        ]
        
        try:
            process = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            
            stdout, stderr = await process.communicate()
            duration = (datetime.now() - start_time).total_seconds()
            
            # Parse results
            findings = self._parse_nuclei_results(stdout.decode())
            severity_counts = self._count_severities(findings)
            
            return TestResult(
                tool='nuclei',
                target=target,
                test_type='web_vulnerability_scan',
                status='passed' if not findings else 'failed',
                findings=findings,
                severity_counts=severity_counts,
                timestamp=start_time,
                duration=duration,
                raw_output=stdout.decode()
            )
            
        except Exception as e:
            duration = (datetime.now() - start_time).total_seconds()
            return TestResult(
                tool='nuclei',
                target=target,
                test_type='web_vulnerability_scan',
                status='error',
                findings=[],
                severity_counts={},
                timestamp=start_time,
                duration=duration,
                raw_output=str(e)
            )
    
    def _parse_nuclei_results(self, output: str) -> List[Dict[str, Any]]:
        """Parse Nuclei JSON output"""
        findings = []
        
        for line in output.strip().split('\n'):
            if not line:
                continue
            
            try:
                data = json.loads(line)
                findings.append({
                    'type': 'vulnerability',
                    'severity': data.get('info', {}).get('severity', 'info'),
                    'template': data.get('template-id'),
                    'name': data.get('info', {}).get('name'),
                    'matched': data.get('matched-at'),
                    'description': data.get('info', {}).get('description', '')[:200]
                })
            except:
                continue
        
        return findings
    
    def _count_severities(self, findings: List[Dict[str, Any]]) -> Dict[str, int]:
        """Count findings by severity"""
        counts = {'critical': 0, 'high': 0, 'medium': 0, 'low': 0, 'info': 0}
        for finding in findings:
            severity = finding.get('severity', 'info')
            counts[severity] = counts.get(severity, 0) + 1
        return counts


class SecurityPipeline:
    """Main security testing pipeline"""
    
    def __init__(self):
        self.test_classes = {
            'nmap': NmapTest,
            'trivy': TrivyTest,
            'nuclei': NucleiTest
        }
        
        self.results_dir = Path("/var/log/security/pipeline-results")
        self.results_dir.mkdir(parents=True, exist_ok=True)
    
    async def run_pipeline(self, config: PipelineConfig) -> Dict[str, Any]:
        """Run security testing pipeline"""
        logger.info(f"Starting pipeline: {config.name}")
        
        start_time = datetime.now()
        all_results = []
        failed_tests = 0
        
        # Run tests for each target
        for target in config.targets:
            logger.info(f"Testing target: {target}")
            
            if config.parallel:
                # Run tests in parallel
                tasks = []
                for test_config in config.tests:
                    if test_config.get('enabled', True):
                        test = self._create_test(test_config)
                        if test:
                            tasks.append(test.run(target))
                
                results = await asyncio.gather(*tasks, return_exceptions=True)
                
                for result in results:
                    if isinstance(result, Exception):
                        logger.error(f"Test failed with exception: {str(result)}")
                        failed_tests += 1
                    else:
                        all_results.append(result)
                        if result.status == 'failed':
                            failed_tests += 1
            else:
                # Run tests sequentially
                for test_config in config.tests:
                    if test_config.get('enabled', True):
                        test = self._create_test(test_config)
                        if test:
                            try:
                                result = await test.run(target)
                                all_results.append(result)
                                
                                if result.status == 'failed':
                                    failed_tests += 1
                                    
                                    if config.stop_on_failure:
                                        logger.warning("Stopping pipeline due to test failure")
                                        break
                            
                            except Exception as e:
                                logger.error(f"Test failed with exception: {str(e)}")
                                failed_tests += 1
                                
                                if config.stop_on_failure:
                                    break
        
        # Calculate summary
        duration = (datetime.now() - start_time).total_seconds()
        
        summary = {
            'pipeline': config.name,
            'timestamp': start_time.isoformat(),
            'duration': duration,
            'targets_tested': len(config.targets),
            'tests_run': len(all_results),
            'failed_tests': failed_tests,
            'total_findings': sum(len(r.findings) for r in all_results),
            'severity_summary': self._aggregate_severities(all_results),
            'status': 'passed' if failed_tests == 0 else 'failed'
        }
        
        # Check thresholds
        threshold_violations = self._check_thresholds(summary['severity_summary'], config.thresholds)
        if threshold_violations:
            summary['status'] = 'failed'
            summary['threshold_violations'] = threshold_violations
        
        # Save results
        report = {
            'summary': summary,
            'config': {
                'name': config.name,
                'description': config.description,
                'targets': config.targets,
                'tests': config.tests
            },
            'results': [self._serialize_result(r) for r in all_results]
        }
        
        report_file = await self._save_report(report)
        summary['report_file'] = str(report_file)
        
        # Send notifications
        if config.notifications:
            await self._send_notifications(summary, config.notifications)
        
        logger.info(f"Pipeline completed: {summary['status']}")
        
        return summary
    
    def _create_test(self, test_config: Dict[str, Any]) -> Optional[SecurityTest]:
        """Create test instance from config"""
        test_type = test_config.get('type')
        
        if test_type not in self.test_classes:
            logger.error(f"Unknown test type: {test_type}")
            return None
        
        return self.test_classes[test_type](test_config)
    
    def _aggregate_severities(self, results: List[TestResult]) -> Dict[str, int]:
        """Aggregate severity counts from all results"""
        total = {'critical': 0, 'high': 0, 'medium': 0, 'low': 0, 'info': 0}
        
        for result in results:
            for severity, count in result.severity_counts.items():
                total[severity] = total.get(severity, 0) + count
        
        return total
    
    def _check_thresholds(self, severity_counts: Dict[str, int], 
                         thresholds: Dict[str, int]) -> List[str]:
        """Check if severity counts exceed thresholds"""
        violations = []
        
        for severity, threshold in thresholds.items():
            count = severity_counts.get(severity, 0)
            if count > threshold:
                violations.append(f"{severity}: {count} > {threshold}")
        
        return violations
    
    def _serialize_result(self, result: TestResult) -> Dict[str, Any]:
        """Serialize test result for JSON"""
        return {
            'tool': result.tool,
            'target': result.target,
            'test_type': result.test_type,
            'status': result.status,
            'findings_count': len(result.findings),
            'severity_counts': result.severity_counts,
            'timestamp': result.timestamp.isoformat(),
            'duration': result.duration,
            'findings': result.findings[:10]  # Limit to first 10
        }
    
    async def _save_report(self, report: Dict[str, Any]) -> Path:
        """Save pipeline report"""
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        filename = f"pipeline_{report['config']['name']}_{timestamp}.json"
        filepath = self.results_dir / filename
        
        async with asyncio.Lock():
            filepath.write_text(json.dumps(report, indent=2))
        
        logger.info(f"Report saved to: {filepath}")
        return filepath
    
    async def _send_notifications(self, summary: Dict[str, Any], 
                                 notification_config: Dict[str, Any]):
        """Send pipeline notifications"""
        if summary['status'] == 'failed' or notification_config.get('always_notify', False):
            # Prepare notification message
            message = f"""
Security Pipeline Results

Pipeline: {summary['pipeline']}
Status: {summary['status']}
Duration: {summary['duration']:.1f}s
Targets: {summary['targets_tested']}
Findings: {summary['total_findings']}

Severity Summary:
- Critical: {summary['severity_summary']['critical']}
- High: {summary['severity_summary']['high']}
- Medium: {summary['severity_summary']['medium']}
- Low: {summary['severity_summary']['low']}

Report: {summary.get('report_file', 'N/A')}
"""
            
            # Send notification
            notify_script = "/opt/scripts/automation/notify.sh"
            if Path(notify_script).exists():
                title = f"Security Pipeline: {summary['status'].upper()}"
                severity = 'critical' if summary['status'] == 'failed' else 'info'
                
                cmd = [notify_script, title, message, severity]
                subprocess.run(cmd, capture_output=True)


def load_pipeline_config(config_file: str) -> PipelineConfig:
    """Load pipeline configuration from YAML file"""
    with open(config_file, 'r') as f:
        data = yaml.safe_load(f)
    
    return PipelineConfig(
        name=data['name'],
        description=data.get('description', ''),
        targets=data['targets'],
        tests=data['tests'],
        notifications=data.get('notifications', {}),
        thresholds=data.get('thresholds', {}),
        parallel=data.get('parallel', True),
        stop_on_failure=data.get('stop_on_failure', False)
    )


async def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(description='Security Testing Pipeline')
    parser.add_argument('config', help='Pipeline configuration file (YAML)')
    parser.add_argument('--targets', nargs='+', help='Override targets from config')
    parser.add_argument('--tests', nargs='+', help='Run only specified tests')
    parser.add_argument('--no-parallel', action='store_true', help='Disable parallel execution')
    
    args = parser.parse_args()
    
    # Load configuration
    config = load_pipeline_config(args.config)
    
    # Override settings from command line
    if args.targets:
        config.targets = args.targets
    
    if args.tests:
        # Filter tests
        config.tests = [t for t in config.tests if t.get('name') in args.tests]
    
    if args.no_parallel:
        config.parallel = False
    
    # Run pipeline
    pipeline = SecurityPipeline()
    summary = await pipeline.run_pipeline(config)
    
    # Print summary
    print(f"\nPipeline Summary:")
    print(f"  Status: {summary['status']}")
    print(f"  Duration: {summary['duration']:.1f}s")
    print(f"  Total Findings: {summary['total_findings']}")
    print(f"  Report: {summary.get('report_file', 'N/A')}")
    
    # Exit with appropriate code
    sys.exit(0 if summary['status'] == 'passed' else 1)


if __name__ == "__main__":
    import sys
    asyncio.run(main())