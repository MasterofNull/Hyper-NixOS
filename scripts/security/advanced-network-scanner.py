#!/usr/bin/env python3
"""
Advanced Network Scanner
Implements sophisticated scanning patterns with evasion techniques
"""

import asyncio
import subprocess
import json
import random
import time
from pathlib import Path
from typing import List, Dict, Any, Tuple
import argparse
import ipaddress
from dataclasses import dataclass
from datetime import datetime
import xml.etree.ElementTree as ET

@dataclass
class ScanResult:
    """Represents a scan result"""
    target: str
    scan_type: str
    timestamp: datetime
    open_ports: List[int]
    services: Dict[int, str]
    os_detection: str
    vulnerabilities: List[str]
    raw_output: str

class AdvancedScanner:
    """Advanced network scanner with multiple techniques"""
    
    def __init__(self):
        self.scan_techniques = {
            'stealth': self._stealth_scan,
            'aggressive': self._aggressive_scan,
            'smart': self._smart_scan,
            'evasive': self._evasive_scan,
            'comprehensive': self._comprehensive_scan
        }
        
        # Timing profiles (0-5, higher is slower/stealthier)
        self.timing_profiles = {
            'paranoid': 0,
            'sneaky': 1,
            'polite': 2,
            'normal': 3,
            'aggressive': 4,
            'insane': 5
        }
        
        # Scan results storage
        self.results_dir = Path("/var/log/security/scans")
        self.results_dir.mkdir(parents=True, exist_ok=True)
    
    async def scan(self, targets: List[str], scan_type: str = 'smart', 
                   options: Dict[str, Any] = None) -> List[ScanResult]:
        """Perform network scan with specified technique"""
        options = options or {}
        
        if scan_type not in self.scan_techniques:
            raise ValueError(f"Unknown scan type: {scan_type}")
        
        results = []
        for target in targets:
            result = await self.scan_techniques[scan_type](target, options)
            results.append(result)
            
            # Save result
            await self._save_result(result)
        
        return results
    
    async def _stealth_scan(self, target: str, options: Dict) -> ScanResult:
        """Stealth SYN scan with decoys"""
        print(f"[*] Performing stealth scan on {target}")
        
        # Generate random decoys
        decoys = self._generate_decoys(5)
        decoy_string = ','.join(decoys)
        
        # Build nmap command
        cmd = [
            'nmap',
            '-sS',  # SYN scan
            '-Pn',  # No ping
            '-T1',  # Sneaky timing
            '-D', f"{decoy_string},ME",  # Decoys
            '--randomize-hosts',
            '--scan-delay', '5s',
            '-oX', '-',  # XML output
            target
        ]
        
        result = await self._run_scan(cmd, target, 'stealth')
        return result
    
    async def _aggressive_scan(self, target: str, options: Dict) -> ScanResult:
        """Aggressive scan with service detection"""
        print(f"[*] Performing aggressive scan on {target}")
        
        cmd = [
            'nmap',
            '-sS',  # SYN scan
            '-sV',  # Version detection
            '-O',   # OS detection
            '-A',   # Aggressive
            '-T4',  # Aggressive timing
            '--script', 'default,vuln',  # Run scripts
            '-oX', '-',
            target
        ]
        
        result = await self._run_scan(cmd, target, 'aggressive')
        return result
    
    async def _smart_scan(self, target: str, options: Dict) -> ScanResult:
        """Smart scan that adapts based on target"""
        print(f"[*] Performing smart scan on {target}")
        
        # First, do a quick ping scan to check if alive
        is_alive = await self._check_alive(target)
        
        if not is_alive:
            print(f"[!] Target {target} appears to be down")
            return ScanResult(
                target=target,
                scan_type='smart',
                timestamp=datetime.now(),
                open_ports=[],
                services={},
                os_detection='Unknown',
                vulnerabilities=[],
                raw_output='Target appears to be down'
            )
        
        # Determine scan intensity based on target type
        if self._is_internal_ip(target):
            # More aggressive for internal IPs
            timing = 'T3'
            scripts = 'default,safe'
        else:
            # Stealthier for external IPs
            timing = 'T2'
            scripts = 'default'
        
        cmd = [
            'nmap',
            '-sS',
            '-sV',
            '-O',
            f'-{timing}',
            '--script', scripts,
            '-oX', '-',
            target
        ]
        
        result = await self._run_scan(cmd, target, 'smart')
        return result
    
    async def _evasive_scan(self, target: str, options: Dict) -> ScanResult:
        """Evasive scan with fragmentation and timing randomization"""
        print(f"[*] Performing evasive scan on {target}")
        
        # Random source port
        source_port = random.randint(20000, 60000)
        
        # Fragment packets
        mtu = random.choice([8, 16, 24])
        
        cmd = [
            'nmap',
            '-sS',
            '-f',  # Fragment packets
            '--mtu', str(mtu),
            '--source-port', str(source_port),
            '--data-length', str(random.randint(10, 50)),  # Random data
            '-T0',  # Paranoid timing
            '--max-retries', '1',
            '--randomize-hosts',
            '-oX', '-',
            target
        ]
        
        result = await self._run_scan(cmd, target, 'evasive')
        return result
    
    async def _comprehensive_scan(self, target: str, options: Dict) -> ScanResult:
        """Comprehensive scan combining multiple techniques"""
        print(f"[*] Performing comprehensive scan on {target}")
        
        # Phase 1: TCP scan
        tcp_cmd = [
            'nmap',
            '-sS',
            '-p-',  # All ports
            '-T3',
            '-oX', '-',
            target
        ]
        
        tcp_result = await self._run_scan(tcp_cmd, target, 'comprehensive-tcp')
        
        # Extract open ports
        open_ports = tcp_result.open_ports
        
        if open_ports:
            # Phase 2: Service detection on open ports
            port_string = ','.join(map(str, open_ports[:100]))  # Limit to 100 ports
            
            service_cmd = [
                'nmap',
                '-sV',
                '-sC',  # Default scripts
                '-O',   # OS detection
                '-p', port_string,
                '--script', 'default,vuln,discovery',
                '-oX', '-',
                target
            ]
            
            result = await self._run_scan(service_cmd, target, 'comprehensive')
        else:
            result = tcp_result
        
        # Phase 3: UDP scan (top 20 ports)
        udp_cmd = [
            'nmap',
            '-sU',
            '--top-ports', '20',
            '-T4',
            target
        ]
        
        # Run UDP scan in background (it's slow)
        asyncio.create_task(self._run_udp_scan(udp_cmd, target))
        
        return result
    
    async def _run_scan(self, cmd: List[str], target: str, scan_type: str) -> ScanResult:
        """Execute scan command and parse results"""
        try:
            # Add sudo if needed
            if not self._is_root():
                cmd = ['sudo'] + cmd
            
            # Run scan
            process = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            
            stdout, stderr = await process.communicate()
            
            if process.returncode != 0:
                print(f"[!] Scan failed: {stderr.decode()}")
                return ScanResult(
                    target=target,
                    scan_type=scan_type,
                    timestamp=datetime.now(),
                    open_ports=[],
                    services={},
                    os_detection='Unknown',
                    vulnerabilities=[],
                    raw_output=stderr.decode()
                )
            
            # Parse XML output
            return self._parse_nmap_xml(stdout.decode(), target, scan_type)
            
        except Exception as e:
            print(f"[!] Scan error: {str(e)}")
            return ScanResult(
                target=target,
                scan_type=scan_type,
                timestamp=datetime.now(),
                open_ports=[],
                services={},
                os_detection='Unknown',
                vulnerabilities=[],
                raw_output=str(e)
            )
    
    def _parse_nmap_xml(self, xml_data: str, target: str, scan_type: str) -> ScanResult:
        """Parse nmap XML output"""
        try:
            root = ET.fromstring(xml_data)
            
            open_ports = []
            services = {}
            os_detection = 'Unknown'
            vulnerabilities = []
            
            # Find host
            host = root.find('.//host')
            if host is not None:
                # Parse ports
                for port in host.findall('.//port'):
                    port_id = int(port.get('portid'))
                    state = port.find('state')
                    
                    if state is not None and state.get('state') == 'open':
                        open_ports.append(port_id)
                        
                        # Get service info
                        service = port.find('service')
                        if service is not None:
                            service_name = service.get('name', 'unknown')
                            service_version = service.get('version', '')
                            services[port_id] = f"{service_name} {service_version}".strip()
                
                # Parse OS detection
                os_match = host.find('.//osmatch')
                if os_match is not None:
                    os_detection = os_match.get('name', 'Unknown')
                
                # Parse script results for vulnerabilities
                for script in host.findall('.//script'):
                    if 'vuln' in script.get('id', ''):
                        output = script.get('output', '')
                        if 'VULNERABLE' in output:
                            vulnerabilities.append(f"{script.get('id')}: {output[:100]}")
            
            return ScanResult(
                target=target,
                scan_type=scan_type,
                timestamp=datetime.now(),
                open_ports=open_ports,
                services=services,
                os_detection=os_detection,
                vulnerabilities=vulnerabilities,
                raw_output=xml_data
            )
            
        except Exception as e:
            print(f"[!] XML parsing error: {str(e)}")
            return ScanResult(
                target=target,
                scan_type=scan_type,
                timestamp=datetime.now(),
                open_ports=[],
                services={},
                os_detection='Unknown',
                vulnerabilities=[],
                raw_output=xml_data
            )
    
    async def _check_alive(self, target: str) -> bool:
        """Check if target is alive"""
        cmd = ['ping', '-c', '1', '-W', '2', target]
        
        try:
            process = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.DEVNULL,
                stderr=asyncio.subprocess.DEVNULL
            )
            
            await process.communicate()
            return process.returncode == 0
            
        except:
            return False
    
    def _is_internal_ip(self, target: str) -> bool:
        """Check if IP is internal"""
        try:
            ip = ipaddress.ip_address(target)
            return ip.is_private
        except:
            return False
    
    def _is_root(self) -> bool:
        """Check if running as root"""
        import os
        return os.geteuid() == 0
    
    def _generate_decoys(self, count: int) -> List[str]:
        """Generate random decoy IPs"""
        decoys = []
        for _ in range(count):
            # Generate random public IP
            ip = f"{random.randint(1,223)}.{random.randint(0,255)}.{random.randint(0,255)}.{random.randint(0,255)}"
            decoys.append(ip)
        return decoys
    
    async def _run_udp_scan(self, cmd: List[str], target: str):
        """Run UDP scan in background"""
        try:
            if not self._is_root():
                cmd = ['sudo'] + cmd
            
            process = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            
            stdout, stderr = await process.communicate()
            
            # Save UDP results separately
            udp_file = self.results_dir / f"udp_{target.replace('.', '_')}_{int(time.time())}.txt"
            udp_file.write_text(stdout.decode())
            
        except Exception as e:
            print(f"[!] UDP scan error: {str(e)}")
    
    async def _save_result(self, result: ScanResult):
        """Save scan result to file"""
        filename = f"scan_{result.target.replace('.', '_')}_{result.scan_type}_{int(time.time())}.json"
        filepath = self.results_dir / filename
        
        data = {
            'target': result.target,
            'scan_type': result.scan_type,
            'timestamp': result.timestamp.isoformat(),
            'open_ports': result.open_ports,
            'services': result.services,
            'os_detection': result.os_detection,
            'vulnerabilities': result.vulnerabilities
        }
        
        filepath.write_text(json.dumps(data, indent=2))
        print(f"[+] Results saved to {filepath}")


class ParallelScanner:
    """Parallel scanning orchestrator"""
    
    def __init__(self, max_concurrent: int = 5):
        self.scanner = AdvancedScanner()
        self.max_concurrent = max_concurrent
    
    async def scan_network(self, network: str, scan_type: str = 'smart') -> List[ScanResult]:
        """Scan entire network in parallel"""
        try:
            # Parse network
            net = ipaddress.ip_network(network, strict=False)
            hosts = [str(ip) for ip in net.hosts()]
            
            print(f"[*] Scanning {len(hosts)} hosts in {network}")
            
            # Create semaphore for concurrency control
            sem = asyncio.Semaphore(self.max_concurrent)
            
            async def scan_with_sem(host):
                async with sem:
                    return await self.scanner.scan([host], scan_type)
            
            # Scan all hosts in parallel
            tasks = [scan_with_sem(host) for host in hosts]
            results = await asyncio.gather(*tasks)
            
            # Flatten results
            all_results = []
            for result_list in results:
                all_results.extend(result_list)
            
            return all_results
            
        except Exception as e:
            print(f"[!] Network scan error: {str(e)}")
            return []
    
    async def targeted_scan(self, targets_file: str, scan_type: str = 'smart') -> List[ScanResult]:
        """Scan targets from file"""
        targets = []
        
        with open(targets_file, 'r') as f:
            for line in f:
                target = line.strip()
                if target and not target.startswith('#'):
                    targets.append(target)
        
        print(f"[*] Scanning {len(targets)} targets")
        
        # Scan in batches
        results = []
        for i in range(0, len(targets), self.max_concurrent):
            batch = targets[i:i + self.max_concurrent]
            batch_results = await asyncio.gather(
                *[self.scanner.scan([target], scan_type) for target in batch]
            )
            
            for result_list in batch_results:
                results.extend(result_list)
        
        return results


async def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(description='Advanced Network Scanner')
    parser.add_argument('targets', nargs='+', help='Target IPs, hostnames, or CIDR ranges')
    parser.add_argument('-t', '--type', default='smart',
                       choices=['stealth', 'aggressive', 'smart', 'evasive', 'comprehensive'],
                       help='Scan type (default: smart)')
    parser.add_argument('-p', '--parallel', type=int, default=5,
                       help='Max parallel scans (default: 5)')
    parser.add_argument('-f', '--file', action='store_true',
                       help='Treat target as filename containing targets')
    parser.add_argument('-o', '--output', help='Output file for results')
    
    args = parser.parse_args()
    
    if args.file:
        # Scan from file
        scanner = ParallelScanner(args.parallel)
        results = await scanner.targeted_scan(args.targets[0], args.type)
    else:
        # Direct scan
        scanner = AdvancedScanner()
        results = []
        
        for target in args.targets:
            if '/' in target:
                # Network range
                parallel_scanner = ParallelScanner(args.parallel)
                network_results = await parallel_scanner.scan_network(target, args.type)
                results.extend(network_results)
            else:
                # Single target
                target_results = await scanner.scan([target], args.type)
                results.extend(target_results)
    
    # Display results
    print(f"\n[+] Scan complete. Found {len(results)} hosts")
    
    for result in results:
        if result.open_ports:
            print(f"\n[+] {result.target}")
            print(f"    OS: {result.os_detection}")
            print(f"    Open ports: {', '.join(map(str, result.open_ports[:10]))}")
            
            if result.services:
                print("    Services:")
                for port, service in list(result.services.items())[:5]:
                    print(f"      {port}: {service}")
            
            if result.vulnerabilities:
                print("    Vulnerabilities:")
                for vuln in result.vulnerabilities[:3]:
                    print(f"      - {vuln}")
    
    # Save to output file if specified
    if args.output:
        output_data = []
        for result in results:
            output_data.append({
                'target': result.target,
                'open_ports': result.open_ports,
                'services': result.services,
                'os': result.os_detection,
                'vulnerabilities': result.vulnerabilities
            })
        
        with open(args.output, 'w') as f:
            json.dump(output_data, f, indent=2)
        
        print(f"\n[+] Results saved to {args.output}")


if __name__ == "__main__":
    asyncio.run(main())