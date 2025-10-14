#!/usr/bin/env python3
"""
Security Tool Deployment Framework
Automated deployment and management of security tools
Following security-first design patterns
"""

import asyncio
import docker
import json
import logging
import os
import subprocess
import yaml
from dataclasses import dataclass
from enum import Enum
from pathlib import Path
from typing import Dict, List, Optional, Any

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class ToolCategory(Enum):
    """Categories of security tools"""
    SCANNER = "scanner"
    MONITOR = "monitor"
    FIREWALL = "firewall"
    IDS_IPS = "ids_ips"
    SIEM = "siem"
    FORENSICS = "forensics"
    VULNERABILITY = "vulnerability"
    COMPLIANCE = "compliance"
    DECEPTION = "deception"


@dataclass
class SecurityTool:
    """Security tool configuration"""
    name: str
    category: ToolCategory
    image: str
    ports: Dict[str, int]
    environment: Dict[str, str]
    volumes: Dict[str, Dict[str, str]]
    capabilities: List[str] = None
    privileged: bool = False
    network_mode: str = "bridge"
    restart_policy: str = "unless-stopped"
    health_check: Optional[Dict[str, Any]] = None
    dependencies: List[str] = None


class SecurityToolDeployment:
    """Manages deployment of security tools"""
    
    def __init__(self):
        self.docker_client = docker.from_env()
        self.deployed_tools: Dict[str, Any] = {}
        self.tool_configs = self._load_tool_configurations()
    
    def _load_tool_configurations(self) -> Dict[str, SecurityTool]:
        """Load security tool configurations"""
        return {
            "prometheus": SecurityTool(
                name="prometheus",
                category=ToolCategory.MONITOR,
                image="prom/prometheus:latest",
                ports={"9090/tcp": 9090},
                environment={},
                volumes={
                    "/prometheus": {"bind": "/prometheus", "mode": "rw"},
                    "./configs/prometheus.yml": {"bind": "/etc/prometheus/prometheus.yml", "mode": "ro"}
                },
                health_check={
                    "test": ["CMD", "wget", "--spider", "-q", "http://localhost:9090/-/healthy"],
                    "interval": 30,
                    "timeout": 10,
                    "retries": 3
                }
            ),
            
            "grafana": SecurityTool(
                name="grafana",
                category=ToolCategory.MONITOR,
                image="grafana/grafana:latest",
                ports={"3000/tcp": 3000},
                environment={
                    "GF_SECURITY_ADMIN_PASSWORD": "SecurePass123!",
                    "GF_INSTALL_PLUGINS": "grafana-piechart-panel,grafana-worldmap-panel"
                },
                volumes={
                    "/var/lib/grafana": {"bind": "/var/lib/grafana", "mode": "rw"}
                },
                dependencies=["prometheus"]
            ),
            
            "suricata": SecurityTool(
                name="suricata",
                category=ToolCategory.IDS_IPS,
                image="jasonish/suricata:latest",
                ports={},
                environment={
                    "SURICATA_OPTIONS": "-i eth0"
                },
                volumes={
                    "/var/log/suricata": {"bind": "/var/log/suricata", "mode": "rw"},
                    "./configs/suricata.yaml": {"bind": "/etc/suricata/suricata.yaml", "mode": "ro"}
                },
                capabilities=["NET_ADMIN", "NET_RAW"],
                network_mode="host"
            ),
            
            "wazuh": SecurityTool(
                name="wazuh",
                category=ToolCategory.SIEM,
                image="wazuh/wazuh:latest",
                ports={
                    "1514/udp": 1514,
                    "1515/tcp": 1515,
                    "55000/tcp": 55000
                },
                environment={
                    "WAZUH_MANAGER_HOSTNAME": "wazuh-manager"
                },
                volumes={
                    "/var/ossec/data": {"bind": "/var/ossec/data", "mode": "rw"}
                }
            ),
            
            "openvas": SecurityTool(
                name="openvas",
                category=ToolCategory.VULNERABILITY,
                image="securecompliance/openvas:latest",
                ports={"9392/tcp": 9392},
                environment={
                    "OV_UPDATE": "yes"
                },
                volumes={
                    "/var/lib/openvas": {"bind": "/var/lib/openvas", "mode": "rw"}
                },
                privileged=True
            ),
            
            "trivy": SecurityTool(
                name="trivy",
                category=ToolCategory.SCANNER,
                image="aquasec/trivy:latest",
                ports={},
                environment={},
                volumes={
                    "/var/run/docker.sock": {"bind": "/var/run/docker.sock", "mode": "ro"}
                }
            ),
            
            "falco": SecurityTool(
                name="falco",
                category=ToolCategory.MONITOR,
                image="falcosecurity/falco:latest",
                ports={},
                environment={},
                volumes={
                    "/var/run/docker.sock": {"bind": "/var/run/docker.sock", "mode": "ro"},
                    "/dev": {"bind": "/host/dev", "mode": "ro"},
                    "/proc": {"bind": "/host/proc", "mode": "ro"}
                },
                privileged=True
            ),
            
            "honeypot": SecurityTool(
                name="honeypot",
                category=ToolCategory.DECEPTION,
                image="cowrie/cowrie:latest",
                ports={
                    "2222/tcp": 2222,
                    "2223/tcp": 2223
                },
                environment={
                    "COWRIE_TELNET_ENABLED": "yes"
                },
                volumes={
                    "/var/log/cowrie": {"bind": "/cowrie/var/log/cowrie", "mode": "rw"}
                }
            )
        }
    
    async def deploy_tool(self, tool_name: str) -> bool:
        """Deploy a single security tool"""
        if tool_name not in self.tool_configs:
            logger.error(f"Tool {tool_name} not found in configurations")
            return False
        
        tool = self.tool_configs[tool_name]
        
        # Check dependencies
        if tool.dependencies:
            for dep in tool.dependencies:
                if dep not in self.deployed_tools:
                    logger.info(f"Deploying dependency {dep} for {tool_name}")
                    await self.deploy_tool(dep)
        
        try:
            # Check if already running
            try:
                existing = self.docker_client.containers.get(f"security_{tool_name}")
                logger.info(f"Tool {tool_name} already running")
                self.deployed_tools[tool_name] = existing
                return True
            except docker.errors.NotFound:
                pass
            
            # Prepare container configuration
            container_config = {
                "image": tool.image,
                "name": f"security_{tool_name}",
                "ports": tool.ports,
                "environment": tool.environment,
                "volumes": tool.volumes,
                "detach": True,
                "restart_policy": {"Name": tool.restart_policy}
            }
            
            if tool.network_mode:
                container_config["network_mode"] = tool.network_mode
            
            if tool.privileged:
                container_config["privileged"] = tool.privileged
            
            if tool.capabilities:
                container_config["cap_add"] = tool.capabilities
            
            # Pull image if needed
            logger.info(f"Pulling image {tool.image}")
            self.docker_client.images.pull(tool.image)
            
            # Create and start container
            logger.info(f"Deploying {tool_name}")
            container = self.docker_client.containers.run(**container_config)
            
            self.deployed_tools[tool_name] = container
            logger.info(f"Successfully deployed {tool_name}")
            
            # Wait for health check if defined
            if tool.health_check:
                await self._wait_for_health(tool_name, tool.health_check)
            
            return True
            
        except Exception as e:
            logger.error(f"Failed to deploy {tool_name}: {str(e)}")
            return False
    
    async def _wait_for_health(self, tool_name: str, health_check: Dict[str, Any], timeout: int = 300):
        """Wait for tool to become healthy"""
        logger.info(f"Waiting for {tool_name} to become healthy...")
        start_time = asyncio.get_event_loop().time()
        
        while asyncio.get_event_loop().time() - start_time < timeout:
            try:
                container = self.deployed_tools[tool_name]
                container.reload()
                
                health = container.attrs.get("State", {}).get("Health", {})
                if health.get("Status") == "healthy":
                    logger.info(f"{tool_name} is healthy")
                    return True
                
            except Exception as e:
                logger.debug(f"Health check error: {e}")
            
            await asyncio.sleep(5)
        
        logger.warning(f"{tool_name} failed to become healthy within {timeout} seconds")
        return False
    
    async def deploy_stack(self, stack_name: str):
        """Deploy a predefined stack of security tools"""
        stacks = {
            "basic": ["prometheus", "grafana", "trivy"],
            "advanced": ["prometheus", "grafana", "suricata", "falco", "trivy"],
            "complete": list(self.tool_configs.keys())
        }
        
        if stack_name not in stacks:
            logger.error(f"Unknown stack: {stack_name}")
            return
        
        tools = stacks[stack_name]
        logger.info(f"Deploying {stack_name} stack with {len(tools)} tools")
        
        # Deploy tools in parallel where possible
        tasks = []
        for tool in tools:
            tasks.append(self.deploy_tool(tool))
        
        results = await asyncio.gather(*tasks, return_exceptions=True)
        
        # Report results
        successful = sum(1 for r in results if r is True)
        logger.info(f"Deployed {successful}/{len(tools)} tools successfully")
    
    def get_status(self) -> Dict[str, Any]:
        """Get status of all deployed tools"""
        status = {}
        
        for name, container in self.deployed_tools.items():
            try:
                container.reload()
                status[name] = {
                    "status": container.status,
                    "health": container.attrs.get("State", {}).get("Health", {}).get("Status", "unknown"),
                    "ports": container.attrs.get("NetworkSettings", {}).get("Ports", {}),
                    "created": container.attrs.get("Created"),
                    "image": container.image.tags[0] if container.image.tags else "unknown"
                }
            except Exception as e:
                status[name] = {"status": "error", "error": str(e)}
        
        return status
    
    async def stop_tool(self, tool_name: str):
        """Stop a deployed tool"""
        if tool_name not in self.deployed_tools:
            logger.error(f"Tool {tool_name} not deployed")
            return False
        
        try:
            container = self.deployed_tools[tool_name]
            container.stop()
            container.remove()
            del self.deployed_tools[tool_name]
            logger.info(f"Stopped {tool_name}")
            return True
        except Exception as e:
            logger.error(f"Failed to stop {tool_name}: {str(e)}")
            return False
    
    async def update_tool(self, tool_name: str):
        """Update a tool to latest version"""
        logger.info(f"Updating {tool_name}")
        
        # Stop existing
        await self.stop_tool(tool_name)
        
        # Pull latest image
        if tool_name in self.tool_configs:
            image = self.tool_configs[tool_name].image
            logger.info(f"Pulling latest {image}")
            self.docker_client.images.pull(image)
        
        # Redeploy
        return await self.deploy_tool(tool_name)


class SecurityToolManager:
    """High-level security tool management"""
    
    def __init__(self):
        self.deployment = SecurityToolDeployment()
        self.config_dir = Path("./security-configs")
        self.config_dir.mkdir(exist_ok=True)
    
    async def initialize_environment(self):
        """Initialize security environment"""
        logger.info("Initializing security environment")
        
        # Create necessary directories
        dirs = ["logs", "data", "configs", "reports"]
        for dir_name in dirs:
            (self.config_dir / dir_name).mkdir(exist_ok=True)
        
        # Generate default configurations
        await self._generate_default_configs()
        
        # Deploy basic monitoring
        await self.deployment.deploy_stack("basic")
    
    async def _generate_default_configs(self):
        """Generate default configuration files"""
        # Prometheus config
        prometheus_config = """
global:
  scrape_interval: 15s
  evaluation_interval: 15s

alerting:
  alertmanagers:
    - static_configs:
        - targets: []

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
  
  - job_name: 'node'
    static_configs:
      - targets: ['node-exporter:9100']
"""
        
        with open(self.config_dir / "configs" / "prometheus.yml", "w") as f:
            f.write(prometheus_config)
        
        # Suricata config (basic)
        suricata_config = """
%YAML 1.1
---
vars:
  address-groups:
    HOME_NET: "[192.168.0.0/16,10.0.0.0/8,172.16.0.0/12]"
    EXTERNAL_NET: "!$HOME_NET"

default-log-dir: /var/log/suricata/

stats:
  enabled: yes
  interval: 8

outputs:
  - fast:
      enabled: yes
      filename: fast.log
  - eve-log:
      enabled: yes
      filetype: regular
      filename: eve.json
      types:
        - alert
        - http
        - dns
        - tls
"""
        
        with open(self.config_dir / "configs" / "suricata.yaml", "w") as f:
            f.write(suricata_config)
    
    async def perform_security_scan(self):
        """Perform comprehensive security scan"""
        logger.info("Performing security scan")
        
        # Deploy scanner if needed
        await self.deployment.deploy_tool("trivy")
        
        # Scan all running containers
        containers = self.deployment.docker_client.containers.list()
        scan_results = []
        
        for container in containers:
            if container.image.tags:
                image_name = container.image.tags[0]
                logger.info(f"Scanning {image_name}")
                
                try:
                    result = subprocess.run(
                        ["docker", "run", "--rm", "-v", "/var/run/docker.sock:/var/run/docker.sock",
                         "aquasec/trivy:latest", "image", "--format", "json", image_name],
                        capture_output=True,
                        text=True
                    )
                    
                    if result.returncode == 0:
                        scan_results.append({
                            "image": image_name,
                            "vulnerabilities": json.loads(result.stdout)
                        })
                except Exception as e:
                    logger.error(f"Failed to scan {image_name}: {e}")
        
        # Save results
        report_file = self.config_dir / "reports" / f"security_scan_{Path.cwd().name}.json"
        with open(report_file, "w") as f:
            json.dump(scan_results, f, indent=2)
        
        logger.info(f"Scan complete. Results saved to {report_file}")
        return scan_results
    
    def generate_security_report(self):
        """Generate comprehensive security report"""
        report = {
            "timestamp": datetime.now().isoformat(),
            "deployed_tools": self.deployment.get_status(),
            "recommendations": []
        }
        
        # Check for missing critical tools
        critical_tools = ["suricata", "falco", "prometheus"]
        for tool in critical_tools:
            if tool not in self.deployment.deployed_tools:
                report["recommendations"].append(f"Deploy {tool} for better security coverage")
        
        # Save report
        report_file = self.config_dir / "reports" / f"security_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        with open(report_file, "w") as f:
            json.dump(report, f, indent=2)
        
        return report


async def main():
    """Main execution function"""
    manager = SecurityToolManager()
    
    # Initialize environment
    await manager.initialize_environment()
    
    # Deploy security stack
    print("\nDeploying security tools...")
    await manager.deployment.deploy_stack("advanced")
    
    # Check status
    print("\nTool Status:")
    status = manager.deployment.get_status()
    for tool, info in status.items():
        print(f"  {tool}: {info['status']}")
    
    # Perform security scan
    print("\nPerforming security scan...")
    await manager.perform_security_scan()
    
    # Generate report
    print("\nGenerating security report...")
    report = manager.generate_security_report()
    print(f"Report saved with {len(report['recommendations'])} recommendations")


if __name__ == "__main__":
    print("Security Tool Deployment Framework")
    print("==================================")
    asyncio.run(main())