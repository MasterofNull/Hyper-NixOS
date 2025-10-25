#!/usr/bin/env python3
"""
Security Compliance Checking Framework
Validates systems against security standards and policies
"""

import asyncio
import json
import yaml
from pathlib import Path
from datetime import datetime
from typing import List, Dict, Any, Optional, Tuple
import logging
import subprocess
import re
from dataclasses import dataclass, field
from enum import Enum
import hashlib

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class ComplianceStatus(Enum):
    """Compliance check status"""
    PASS = "pass"
    FAIL = "fail"
    WARNING = "warning"
    ERROR = "error"
    NOT_APPLICABLE = "not_applicable"


class ComplianceFramework(Enum):
    """Supported compliance frameworks"""
    CIS = "cis"
    NIST = "nist"
    PCI_DSS = "pci_dss"
    HIPAA = "hipaa"
    SOC2 = "soc2"
    CUSTOM = "custom"


@dataclass
class ComplianceCheck:
    """Represents a single compliance check"""
    check_id: str
    title: str
    description: str
    category: str
    severity: str  # critical, high, medium, low
    framework: ComplianceFramework
    reference: str
    check_type: str  # file, command, package, service, configuration
    check_command: Optional[str] = None
    expected_result: Optional[str] = None
    remediation: Optional[str] = None
    tags: List[str] = field(default_factory=list)


@dataclass
class ComplianceResult:
    """Result of a compliance check"""
    check_id: str
    status: ComplianceStatus
    actual_result: str
    expected_result: str
    evidence: str
    timestamp: datetime
    duration: float
    error_message: Optional[str] = None


@dataclass
class ComplianceReport:
    """Compliance assessment report"""
    report_id: str
    framework: ComplianceFramework
    scan_date: datetime
    total_checks: int
    passed_checks: int
    failed_checks: int
    warning_checks: int
    error_checks: int
    compliance_score: float
    critical_failures: List[str]
    results: List[ComplianceResult]
    recommendations: List[str]


class ComplianceChecker:
    """Base class for compliance checkers"""
    
    def __init__(self):
        self.checks = []
    
    async def check(self, check: ComplianceCheck) -> ComplianceResult:
        """Execute a compliance check"""
        start_time = datetime.now()
        
        try:
            if check.check_type == 'file':
                result = await self._check_file(check)
            elif check.check_type == 'command':
                result = await self._check_command(check)
            elif check.check_type == 'package':
                result = await self._check_package(check)
            elif check.check_type == 'service':
                result = await self._check_service(check)
            elif check.check_type == 'configuration':
                result = await self._check_configuration(check)
            else:
                result = ComplianceResult(
                    check_id=check.check_id,
                    status=ComplianceStatus.ERROR,
                    actual_result="",
                    expected_result=check.expected_result or "",
                    evidence="Unknown check type",
                    timestamp=datetime.now(),
                    duration=0,
                    error_message=f"Unknown check type: {check.check_type}"
                )
            
            result.duration = (datetime.now() - start_time).total_seconds()
            return result
            
        except Exception as e:
            return ComplianceResult(
                check_id=check.check_id,
                status=ComplianceStatus.ERROR,
                actual_result="",
                expected_result=check.expected_result or "",
                evidence="",
                timestamp=datetime.now(),
                duration=(datetime.now() - start_time).total_seconds(),
                error_message=str(e)
            )
    
    async def _check_file(self, check: ComplianceCheck) -> ComplianceResult:
        """Check file-based compliance"""
        file_path = check.check_command
        
        if not file_path:
            raise ValueError("File path not specified")
        
        path = Path(file_path)
        
        # Check file existence
        if not path.exists():
            return ComplianceResult(
                check_id=check.check_id,
                status=ComplianceStatus.FAIL,
                actual_result="File does not exist",
                expected_result=check.expected_result or "File should exist",
                evidence=f"File {file_path} not found",
                timestamp=datetime.now(),
                duration=0
            )
        
        # Check file permissions
        if check.expected_result and check.expected_result.startswith('permissions:'):
            expected_perms = check.expected_result.split(':')[1]
            actual_perms = oct(path.stat().st_mode)[-3:]
            
            status = ComplianceStatus.PASS if actual_perms == expected_perms else ComplianceStatus.FAIL
            
            return ComplianceResult(
                check_id=check.check_id,
                status=status,
                actual_result=f"permissions:{actual_perms}",
                expected_result=check.expected_result,
                evidence=f"File permissions: {actual_perms}",
                timestamp=datetime.now(),
                duration=0
            )
        
        # Check file content
        if check.expected_result and check.expected_result.startswith('contains:'):
            search_string = check.expected_result.split(':', 1)[1]
            content = path.read_text()
            
            if search_string in content:
                status = ComplianceStatus.PASS
                evidence = f"Found '{search_string}' in file"
            else:
                status = ComplianceStatus.FAIL
                evidence = f"'{search_string}' not found in file"
            
            return ComplianceResult(
                check_id=check.check_id,
                status=status,
                actual_result=f"contains:{search_string in content}",
                expected_result=check.expected_result,
                evidence=evidence,
                timestamp=datetime.now(),
                duration=0
            )
        
        # Default: just check existence
        return ComplianceResult(
            check_id=check.check_id,
            status=ComplianceStatus.PASS,
            actual_result="File exists",
            expected_result=check.expected_result or "File should exist",
            evidence=f"File {file_path} exists",
            timestamp=datetime.now(),
            duration=0
        )
    
    async def _check_command(self, check: ComplianceCheck) -> ComplianceResult:
        """Execute command-based compliance check"""
        if not check.check_command:
            raise ValueError("Check command not specified")
        
        try:
            process = await asyncio.create_subprocess_shell(
                check.check_command,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            
            stdout, stderr = await process.communicate()
            output = stdout.decode().strip()
            
            # Determine status based on expected result
            if check.expected_result:
                if check.expected_result.startswith('regex:'):
                    pattern = check.expected_result.split(':', 1)[1]
                    if re.search(pattern, output):
                        status = ComplianceStatus.PASS
                        evidence = f"Output matches pattern: {pattern}"
                    else:
                        status = ComplianceStatus.FAIL
                        evidence = f"Output does not match pattern: {pattern}"
                elif check.expected_result.startswith('exitcode:'):
                    expected_code = int(check.expected_result.split(':')[1])
                    if process.returncode == expected_code:
                        status = ComplianceStatus.PASS
                        evidence = f"Exit code: {process.returncode}"
                    else:
                        status = ComplianceStatus.FAIL
                        evidence = f"Exit code: {process.returncode} (expected: {expected_code})"
                else:
                    # Exact match
                    if output == check.expected_result:
                        status = ComplianceStatus.PASS
                        evidence = "Output matches expected"
                    else:
                        status = ComplianceStatus.FAIL
                        evidence = "Output does not match expected"
            else:
                # Just check if command succeeded
                if process.returncode == 0:
                    status = ComplianceStatus.PASS
                    evidence = "Command executed successfully"
                else:
                    status = ComplianceStatus.FAIL
                    evidence = f"Command failed with exit code: {process.returncode}"
            
            return ComplianceResult(
                check_id=check.check_id,
                status=status,
                actual_result=output[:500],  # Limit output size
                expected_result=check.expected_result or "exitcode:0",
                evidence=evidence,
                timestamp=datetime.now(),
                duration=0
            )
            
        except Exception as e:
            raise Exception(f"Command execution failed: {str(e)}")
    
    async def _check_package(self, check: ComplianceCheck) -> ComplianceResult:
        """Check package installation status"""
        package_name = check.check_command
        
        if not package_name:
            raise ValueError("Package name not specified")
        
        # Try different package managers
        package_managers = [
            ('dpkg -l | grep -E "^ii\\s+{}"', 'apt'),
            ('rpm -q {}', 'rpm'),
            ('pip show {}', 'pip'),
            ('npm list -g {} 2>/dev/null', 'npm')
        ]
        
        for cmd_template, pm_type in package_managers:
            cmd = cmd_template.format(package_name)
            
            try:
                process = await asyncio.create_subprocess_shell(
                    cmd,
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.PIPE
                )
                
                stdout, stderr = await process.communicate()
                
                if process.returncode == 0:
                    # Package found
                    output = stdout.decode().strip()
                    
                    if check.expected_result == 'installed':
                        status = ComplianceStatus.PASS
                        evidence = f"Package {package_name} is installed ({pm_type})"
                    elif check.expected_result == 'not_installed':
                        status = ComplianceStatus.FAIL
                        evidence = f"Package {package_name} is installed but should not be"
                    elif check.expected_result and check.expected_result.startswith('version:'):
                        expected_version = check.expected_result.split(':', 1)[1]
                        if expected_version in output:
                            status = ComplianceStatus.PASS
                            evidence = f"Package version matches: {expected_version}"
                        else:
                            status = ComplianceStatus.FAIL
                            evidence = f"Package version mismatch"
                    else:
                        status = ComplianceStatus.PASS
                        evidence = f"Package {package_name} found"
                    
                    return ComplianceResult(
                        check_id=check.check_id,
                        status=status,
                        actual_result=output[:200],
                        expected_result=check.expected_result or "installed",
                        evidence=evidence,
                        timestamp=datetime.now(),
                        duration=0
                    )
            
            except:
                continue
        
        # Package not found
        if check.expected_result == 'not_installed':
            status = ComplianceStatus.PASS
            evidence = f"Package {package_name} is not installed"
        else:
            status = ComplianceStatus.FAIL
            evidence = f"Package {package_name} not found"
        
        return ComplianceResult(
            check_id=check.check_id,
            status=status,
            actual_result="not_installed",
            expected_result=check.expected_result or "installed",
            evidence=evidence,
            timestamp=datetime.now(),
            duration=0
        )
    
    async def _check_service(self, check: ComplianceCheck) -> ComplianceResult:
        """Check service status"""
        service_name = check.check_command
        
        if not service_name:
            raise ValueError("Service name not specified")
        
        # Check service status using systemctl
        cmd = f"systemctl is-active {service_name}"
        
        try:
            process = await asyncio.create_subprocess_shell(
                cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            
            stdout, stderr = await process.communicate()
            output = stdout.decode().strip()
            
            if check.expected_result == 'active':
                if output == 'active':
                    status = ComplianceStatus.PASS
                    evidence = f"Service {service_name} is active"
                else:
                    status = ComplianceStatus.FAIL
                    evidence = f"Service {service_name} is {output}"
            elif check.expected_result == 'inactive':
                if output == 'inactive':
                    status = ComplianceStatus.PASS
                    evidence = f"Service {service_name} is inactive"
                else:
                    status = ComplianceStatus.FAIL
                    evidence = f"Service {service_name} is {output} but should be inactive"
            else:
                # Just report status
                status = ComplianceStatus.PASS if output == 'active' else ComplianceStatus.WARNING
                evidence = f"Service {service_name} is {output}"
            
            return ComplianceResult(
                check_id=check.check_id,
                status=status,
                actual_result=output,
                expected_result=check.expected_result or "active",
                evidence=evidence,
                timestamp=datetime.now(),
                duration=0
            )
            
        except Exception as e:
            raise Exception(f"Service check failed: {str(e)}")
    
    async def _check_configuration(self, check: ComplianceCheck) -> ComplianceResult:
        """Check configuration settings"""
        # This would be extended to check various configuration files
        # For now, delegate to command check
        return await self._check_command(check)


class CISBenchmarkChecker(ComplianceChecker):
    """CIS Benchmark compliance checker"""
    
    def __init__(self):
        super().__init__()
        self.load_cis_checks()
    
    def load_cis_checks(self):
        """Load CIS benchmark checks"""
        # These are example CIS checks - in production would load from configuration
        self.checks = [
            ComplianceCheck(
                check_id="CIS-1.1.1",
                title="Ensure mounting of cramfs filesystems is disabled",
                description="The cramfs filesystem type is a compressed read-only Linux filesystem",
                category="Filesystem",
                severity="medium",
                framework=ComplianceFramework.CIS,
                reference="CIS Ubuntu Linux 20.04 LTS Benchmark v1.1.0",
                check_type="command",
                check_command="modprobe -n -v cramfs 2>&1 | grep -E '(install /bin/true|FATAL)'",
                expected_result="regex:install /bin/true",
                remediation="Add 'install cramfs /bin/true' to /etc/modprobe.d/cramfs.conf"
            ),
            ComplianceCheck(
                check_id="CIS-1.1.21",
                title="Ensure sticky bit is set on world-writable directories",
                description="Setting the sticky bit on world writable directories prevents unprivileged users from deleting files",
                category="Filesystem",
                severity="high",
                framework=ComplianceFramework.CIS,
                reference="CIS Ubuntu Linux 20.04 LTS Benchmark v1.1.0",
                check_type="command",
                check_command="find / -path /proc -prune -o -type d \\( -perm -0002 -a ! -perm -1000 \\) -print 2>/dev/null | wc -l",
                expected_result="0",
                remediation="Run: find / -path /proc -prune -o -type d -perm -0002 -exec chmod +t {} +"
            ),
            ComplianceCheck(
                check_id="CIS-2.2.2",
                title="Ensure X Window System is not installed",
                description="The X Window System provides a GUI",
                category="Services",
                severity="medium",
                framework=ComplianceFramework.CIS,
                reference="CIS Ubuntu Linux 20.04 LTS Benchmark v1.1.0",
                check_type="package",
                check_command="xserver-xorg*",
                expected_result="not_installed",
                remediation="Run: apt purge xserver-xorg*"
            ),
            ComplianceCheck(
                check_id="CIS-5.2.1",
                title="Ensure permissions on /etc/ssh/sshd_config are configured",
                description="The /etc/ssh/sshd_config file contains configuration for SSH daemon",
                category="Access Control",
                severity="high",
                framework=ComplianceFramework.CIS,
                reference="CIS Ubuntu Linux 20.04 LTS Benchmark v1.1.0",
                check_type="file",
                check_command="/etc/ssh/sshd_config",
                expected_result="permissions:600",
                remediation="Run: chmod 600 /etc/ssh/sshd_config"
            ),
            ComplianceCheck(
                check_id="CIS-5.2.5",
                title="Ensure SSH LogLevel is appropriate",
                description="SSH provides logging levels",
                category="Logging",
                severity="medium",
                framework=ComplianceFramework.CIS,
                reference="CIS Ubuntu Linux 20.04 LTS Benchmark v1.1.0",
                check_type="command",
                check_command="sshd -T | grep loglevel",
                expected_result="loglevel INFO",
                remediation="Set 'LogLevel INFO' in /etc/ssh/sshd_config"
            )
        ]


class ComplianceScanner:
    """Main compliance scanning engine"""
    
    def __init__(self):
        self.checkers = {
            ComplianceFramework.CIS: CISBenchmarkChecker(),
            # Additional frameworks would be added here
        }
        self.results_dir = Path("/var/log/security/compliance")
        self.results_dir.mkdir(parents=True, exist_ok=True)
    
    async def scan(self, framework: ComplianceFramework, 
                   categories: Optional[List[str]] = None) -> ComplianceReport:
        """Run compliance scan for specified framework"""
        if framework not in self.checkers:
            raise ValueError(f"Unsupported framework: {framework}")
        
        checker = self.checkers[framework]
        scan_start = datetime.now()
        report_id = f"compliance_{framework.value}_{scan_start.strftime('%Y%m%d_%H%M%S')}"
        
        results = []
        passed = 0
        failed = 0
        warnings = 0
        errors = 0
        critical_failures = []
        
        # Filter checks by category if specified
        checks_to_run = checker.checks
        if categories:
            checks_to_run = [c for c in checks_to_run if c.category in categories]
        
        logger.info(f"Running {len(checks_to_run)} compliance checks for {framework.value}")
        
        # Run checks
        for check in checks_to_run:
            logger.info(f"Running check: {check.check_id} - {check.title}")
            
            result = await checker.check(check)
            results.append(result)
            
            # Count results
            if result.status == ComplianceStatus.PASS:
                passed += 1
            elif result.status == ComplianceStatus.FAIL:
                failed += 1
                if check.severity == 'critical':
                    critical_failures.append(check.check_id)
            elif result.status == ComplianceStatus.WARNING:
                warnings += 1
            elif result.status == ComplianceStatus.ERROR:
                errors += 1
        
        # Calculate compliance score
        total_checks = len(results)
        if total_checks > 0:
            # Weight failures by severity
            severity_weights = {
                'critical': 1.0,
                'high': 0.7,
                'medium': 0.4,
                'low': 0.2
            }
            
            weighted_score = 0
            total_weight = 0
            
            for i, result in enumerate(results):
                check = checks_to_run[i]
                weight = severity_weights.get(check.severity, 0.5)
                total_weight += weight
                
                if result.status == ComplianceStatus.PASS:
                    weighted_score += weight
                elif result.status == ComplianceStatus.WARNING:
                    weighted_score += weight * 0.5
            
            compliance_score = (weighted_score / total_weight * 100) if total_weight > 0 else 0
        else:
            compliance_score = 0
        
        # Generate recommendations
        recommendations = self._generate_recommendations(results, checks_to_run)
        
        # Create report
        report = ComplianceReport(
            report_id=report_id,
            framework=framework,
            scan_date=scan_start,
            total_checks=total_checks,
            passed_checks=passed,
            failed_checks=failed,
            warning_checks=warnings,
            error_checks=errors,
            compliance_score=round(compliance_score, 2),
            critical_failures=critical_failures,
            results=results,
            recommendations=recommendations
        )
        
        # Save report
        await self._save_report(report)
        
        return report
    
    def _generate_recommendations(self, results: List[ComplianceResult], 
                                checks: List[ComplianceCheck]) -> List[str]:
        """Generate recommendations based on results"""
        recommendations = []
        
        # Group failures by category
        failures_by_category = {}
        
        for i, result in enumerate(results):
            if result.status == ComplianceStatus.FAIL:
                check = checks[i]
                category = check.category
                
                if category not in failures_by_category:
                    failures_by_category[category] = []
                
                failures_by_category[category].append(check)
        
        # Generate category-based recommendations
        if 'Access Control' in failures_by_category:
            recommendations.append(
                "Review and strengthen access control policies. "
                "Multiple permission-related failures detected."
            )
        
        if 'Services' in failures_by_category:
            recommendations.append(
                "Disable unnecessary services to reduce attack surface."
            )
        
        if 'Logging' in failures_by_category:
            recommendations.append(
                "Enhance logging configuration to ensure proper audit trails."
            )
        
        # Add critical failure recommendations
        critical_count = sum(1 for c in checks for r in results 
                           if r.check_id == c.check_id and 
                           r.status == ComplianceStatus.FAIL and 
                           c.severity == 'critical')
        
        if critical_count > 0:
            recommendations.insert(0,
                f"URGENT: Address {critical_count} critical compliance failures immediately."
            )
        
        # Add general recommendations
        if len(recommendations) == 0:
            recommendations.append("System shows good compliance. Continue regular reviews.")
        else:
            recommendations.append(
                "Schedule regular compliance scans to track improvement."
            )
        
        return recommendations
    
    async def _save_report(self, report: ComplianceReport):
        """Save compliance report"""
        # Save detailed JSON report
        json_file = self.results_dir / f"{report.report_id}.json"
        
        report_dict = {
            'report_id': report.report_id,
            'framework': report.framework.value,
            'scan_date': report.scan_date.isoformat(),
            'summary': {
                'total_checks': report.total_checks,
                'passed': report.passed_checks,
                'failed': report.failed_checks,
                'warnings': report.warning_checks,
                'errors': report.error_checks,
                'compliance_score': report.compliance_score
            },
            'critical_failures': report.critical_failures,
            'results': [
                {
                    'check_id': r.check_id,
                    'status': r.status.value,
                    'actual_result': r.actual_result,
                    'expected_result': r.expected_result,
                    'evidence': r.evidence,
                    'duration': r.duration,
                    'error_message': r.error_message
                }
                for r in report.results
            ],
            'recommendations': report.recommendations
        }
        
        with open(json_file, 'w') as f:
            json.dump(report_dict, f, indent=2)
        
        # Save summary CSV for trending
        csv_file = self.results_dir / "compliance_history.csv"
        
        csv_exists = csv_file.exists()
        
        with open(csv_file, 'a') as f:
            if not csv_exists:
                f.write("timestamp,framework,total,passed,failed,score\n")
            
            f.write(f"{report.scan_date.isoformat()},{report.framework.value},"
                   f"{report.total_checks},{report.passed_checks},"
                   f"{report.failed_checks},{report.compliance_score}\n")


class ComplianceReporter:
    """Generate compliance reports in various formats"""
    
    @staticmethod
    def generate_html_report(report: ComplianceReport) -> str:
        """Generate HTML compliance report"""
        html = f"""
<!DOCTYPE html>
<html>
<head>
    <title>Compliance Report - {report.framework.value.upper()}</title>
    <style>
        body {{ font-family: Arial, sans-serif; margin: 20px; }}
        .header {{ background-color: #f0f0f0; padding: 20px; border-radius: 5px; }}
        .summary {{ margin: 20px 0; }}
        .score {{ font-size: 48px; font-weight: bold; }}
        .pass {{ color: #28a745; }}
        .fail {{ color: #dc3545; }}
        .warning {{ color: #ffc107; }}
        .error {{ color: #6c757d; }}
        table {{ border-collapse: collapse; width: 100%; margin: 20px 0; }}
        th, td {{ border: 1px solid #ddd; padding: 8px; text-align: left; }}
        th {{ background-color: #f2f2f2; }}
        .recommendations {{ background-color: #e9ecef; padding: 15px; border-radius: 5px; }}
    </style>
</head>
<body>
    <div class="header">
        <h1>Compliance Report - {report.framework.value.upper()}</h1>
        <p>Scan Date: {report.scan_date.strftime('%Y-%m-%d %H:%M:%S')}</p>
        <p>Report ID: {report.report_id}</p>
    </div>
    
    <div class="summary">
        <h2>Compliance Score</h2>
        <div class="score {('pass' if report.compliance_score >= 80 else 'fail')}">
            {report.compliance_score}%
        </div>
        
        <h3>Summary</h3>
        <ul>
            <li>Total Checks: {report.total_checks}</li>
            <li class="pass">Passed: {report.passed_checks}</li>
            <li class="fail">Failed: {report.failed_checks}</li>
            <li class="warning">Warnings: {report.warning_checks}</li>
            <li class="error">Errors: {report.error_checks}</li>
        </ul>
    </div>
    
    <h2>Critical Failures</h2>
    {('<ul>' + ''.join(f'<li>{cf}</li>' for cf in report.critical_failures) + '</ul>') 
     if report.critical_failures else '<p>No critical failures</p>'}
    
    <h2>Detailed Results</h2>
    <table>
        <tr>
            <th>Check ID</th>
            <th>Status</th>
            <th>Expected</th>
            <th>Actual</th>
            <th>Evidence</th>
        </tr>
"""
        
        for result in report.results:
            status_class = result.status.value
            html += f"""
        <tr>
            <td>{result.check_id}</td>
            <td class="{status_class}">{result.status.value.upper()}</td>
            <td>{result.expected_result}</td>
            <td>{result.actual_result[:100]}...</td>
            <td>{result.evidence}</td>
        </tr>
"""
        
        html += """
    </table>
    
    <div class="recommendations">
        <h2>Recommendations</h2>
        <ul>
"""
        
        for rec in report.recommendations:
            html += f"            <li>{rec}</li>\n"
        
        html += """
        </ul>
    </div>
</body>
</html>
"""
        
        return html
    
    @staticmethod
    def generate_markdown_report(report: ComplianceReport) -> str:
        """Generate Markdown compliance report"""
        md = f"""# Compliance Report - {report.framework.value.upper()}

**Report ID:** {report.report_id}  
**Scan Date:** {report.scan_date.strftime('%Y-%m-%d %H:%M:%S')}

## Executive Summary

**Compliance Score:** {report.compliance_score}%

| Metric | Count |
|--------|-------|
| Total Checks | {report.total_checks} |
| Passed | {report.passed_checks} |
| Failed | {report.failed_checks} |
| Warnings | {report.warning_checks} |
| Errors | {report.error_checks} |

## Critical Failures

"""
        
        if report.critical_failures:
            for cf in report.critical_failures:
                md += f"- {cf}\n"
        else:
            md += "No critical failures detected.\n"
        
        md += "\n## Recommendations\n\n"
        
        for i, rec in enumerate(report.recommendations, 1):
            md += f"{i}. {rec}\n"
        
        md += "\n## Failed Checks\n\n"
        
        # Show only failed checks
        failed_results = [r for r in report.results if r.status == ComplianceStatus.FAIL]
        
        if failed_results:
            md += "| Check ID | Expected | Actual | Evidence |\n"
            md += "|----------|----------|---------|----------|\n"
            
            for result in failed_results:
                md += f"| {result.check_id} | {result.expected_result} | "
                md += f"{result.actual_result[:50]}... | {result.evidence} |\n"
        else:
            md += "No failed checks.\n"
        
        return md


async def main():
    """Main entry point"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Security Compliance Checker')
    parser.add_argument('--framework', choices=['cis', 'nist', 'pci_dss', 'custom'],
                       default='cis', help='Compliance framework to check')
    parser.add_argument('--categories', nargs='+',
                       help='Specific categories to check')
    parser.add_argument('--output', choices=['json', 'html', 'markdown'],
                       default='json', help='Output format')
    parser.add_argument('--output-file', help='Output file path')
    
    args = parser.parse_args()
    
    # Convert framework string to enum
    framework_map = {
        'cis': ComplianceFramework.CIS,
        'nist': ComplianceFramework.NIST,
        'pci_dss': ComplianceFramework.PCI_DSS,
        'custom': ComplianceFramework.CUSTOM
    }
    
    framework = framework_map[args.framework]
    
    # Run compliance scan
    scanner = ComplianceScanner()
    report = await scanner.scan(framework, args.categories)
    
    # Generate output
    if args.output == 'json':
        output = json.dumps({
            'report_id': report.report_id,
            'framework': report.framework.value,
            'scan_date': report.scan_date.isoformat(),
            'compliance_score': report.compliance_score,
            'summary': {
                'total': report.total_checks,
                'passed': report.passed_checks,
                'failed': report.failed_checks,
                'warnings': report.warning_checks,
                'errors': report.error_checks
            },
            'critical_failures': report.critical_failures,
            'recommendations': report.recommendations
        }, indent=2)
    elif args.output == 'html':
        output = ComplianceReporter.generate_html_report(report)
    elif args.output == 'markdown':
        output = ComplianceReporter.generate_markdown_report(report)
    
    # Write output
    if args.output_file:
        with open(args.output_file, 'w') as f:
            f.write(output)
        print(f"Report saved to: {args.output_file}")
    else:
        print(output)
    
    # Print summary
    print(f"\nCompliance Score: {report.compliance_score}%")
    print(f"Critical Failures: {len(report.critical_failures)}")


if __name__ == "__main__":
    asyncio.run(main())