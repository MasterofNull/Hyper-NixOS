# Security Framework Quick Start Guide

## 🚀 Overview
This security framework implements comprehensive security measures inspired by advanced penetration testing distributions. It provides automated deployment, monitoring, and incident response capabilities.

## 📋 What's Included

### 1. **Security Scripts**
- `security-aliases.sh` - Security-focused command aliases
- `defensive-validation.sh` - Validates security defenses
- `security-monitoring-setup.sh` - Sets up monitoring stack
- `incident-response-automation.py` - Automated incident response
- `security-tool-deployment.py` - Deploy security tools via Docker
- `setup-security-framework.sh` - Master setup script

### 2. **Documentation**
- `AI-Development-Best-Practices.md` - Security-first development patterns
- `security-countermeasures-analysis.md` - Defense mapping against attacks
- `system-improvement-implementation.md` - Implementation roadmap
- `defensive-validation-checklist.md` - Validation procedures

## 🏃 Quick Start

### Step 1: Run Master Setup
```bash
./setup-security-framework.sh
```
This will:
- Check prerequisites
- Create directory structure
- Install dependencies
- Setup monitoring
- Configure aliases

### Step 2: Source Aliases
```bash
source ~/.bashrc  # or ~/.zshrc
```

### Step 3: Run Security Validation
```bash
./defensive-validation.sh
```
Review the generated report to identify security gaps.

### Step 4: Deploy Security Stack
```bash
# Basic monitoring
cd security-monitoring
./start-monitoring.sh

# Advanced security tools
python3 security-tool-deployment.py
```

## 🔧 Key Commands

### Security Status
```bash
security-status          # Quick security overview
harden-check            # Security hardening checklist
security-report         # Generate detailed report
```

### Network Security
```bash
net-scan-local          # Scan local network
net-connections         # View active connections
net-monitor            # Real-time network monitoring
```

### Incident Response
```bash
ir-snapshot            # Collect forensic snapshot
ir-block-ip <IP>      # Block malicious IP
ir-kill <PID>         # Kill suspicious process
```

### Docker Security
```bash
docker-scan <image>    # Scan for vulnerabilities
docker-bench          # Run security benchmark
docker-secrets        # Check for exposed secrets
```

## 📊 Monitoring Access Points

After deployment, access:
- **Prometheus**: http://localhost:9090
- **Grafana**: http://localhost:3000 (admin/SecurePass123!)
- **Node Exporter**: http://localhost:9100/metrics
- **Alertmanager**: http://localhost:9093

## 🛡️ Security Tools Available

### Deployed via Docker
- **Prometheus** - Metrics collection
- **Grafana** - Visualization
- **Suricata** - IDS/IPS
- **Falco** - Runtime security
- **Trivy** - Vulnerability scanning
- **OpenVAS** - Vulnerability assessment
- **Wazuh** - SIEM
- **Honeypot** - Deception system

### Quick Deployment
```bash
# Deploy specific tool
python3 -c "
import asyncio
from security_tool_deployment import SecurityToolDeployment
d = SecurityToolDeployment()
asyncio.run(d.deploy_tool('suricata'))
"

# Deploy security stack
python3 -c "
import asyncio
from security_tool_deployment import SecurityToolDeployment
d = SecurityToolDeployment()
asyncio.run(d.deploy_stack('advanced'))
"
```

## 🚨 Incident Response

### Automated Playbooks
The system includes automated responses for:
- Brute force attacks
- Port scanning
- Malware detection
- Data exfiltration
- Privilege escalation
- DoS attacks

### Manual Response
```python
# Trigger incident response
from incident_response_automation import *
import asyncio

incident = Incident(
    id="INC001",
    type=IncidentType.BRUTE_FORCE,
    severity=IncidentSeverity.HIGH,
    source_ip="192.168.1.100",
    description="SSH brute force detected"
)

orchestrator = IncidentResponseOrchestrator()
asyncio.run(orchestrator.respond_to_incident(incident))
```

## 📈 Security Metrics

Monitor key security metrics:
- Failed authentication attempts
- Network anomalies
- System resource usage
- Open connections
- Process behavior
- File integrity

## 🔍 Regular Tasks

### Daily
1. Check security alerts
2. Review authentication logs
3. Monitor system resources

### Weekly
1. Run security validation
2. Update security tools
3. Review incident reports
4. Patch systems

### Monthly
1. Comprehensive security audit
2. Update security policies
3. Test incident response
4. Security training

## 🆘 Troubleshooting

### Docker Issues
```bash
# Check Docker status
systemctl status docker

# View container logs
docker logs security_<tool_name>

# Restart tool
docker restart security_<tool_name>
```

### Monitoring Issues
```bash
# Check Prometheus targets
curl http://localhost:9090/api/v1/targets

# Verify metrics
curl http://localhost:9100/metrics | grep -i cpu
```

### Permission Issues
```bash
# Fix Docker permissions
sudo usermod -aG docker $USER

# Fix log permissions
sudo chmod 644 /var/log/auth.log
```

## 📚 Further Reading

1. Review `AI-Development-Best-Practices.md` for development guidelines
2. Check `security-countermeasures-analysis.md` for defense strategies
3. Follow `system-improvement-implementation.md` for roadmap
4. Use `defensive-validation-checklist.md` for regular audits

## 🎯 Next Steps

1. **Immediate**: Run validation and fix critical issues
2. **Week 1**: Deploy monitoring and core security tools
3. **Month 1**: Implement automated responses
4. **Ongoing**: Regular validation and improvement

---

Remember: Security is a journey, not a destination. Regular validation and continuous improvement are key to maintaining a strong security posture.