#!/usr/bin/env python3
"""
Test script for incident response system
Simulates various security events to test playbook execution
"""

import asyncio
import sys
from datetime import datetime
from playbook_executor import PlaybookExecutor, SecurityEvent

async def test_brute_force():
    """Test brute force response"""
    print("\n🔴 Testing SSH Brute Force Response...")
    
    event = SecurityEvent(
        event_type='brute_force',
        source_ip='10.10.10.10',
        user='testuser',
        details={
            'service': 'ssh',
            'failed_attempts': 10
        }
    )
    
    executor = PlaybookExecutor()
    await executor.execute_playbook('brute_force_ssh', event)
    
    print("✅ Brute force test completed")
    print("   - IP should be blocked in iptables")
    print("   - Evidence collected in /var/log/security/incidents/")
    print("   - Notification sent")


async def test_port_scan():
    """Test port scan response"""
    print("\n🔴 Testing Port Scan Response...")
    
    event = SecurityEvent(
        event_type='port_scan',
        source_ip='10.10.10.20',
        details={
            'ports_scanned': 1000,
            'scan_type': 'SYN'
        }
    )
    
    executor = PlaybookExecutor()
    await executor.execute_playbook('port_scan_detected', event)
    
    print("✅ Port scan test completed")
    print("   - Scanner IP should be blocked for 24 hours")
    print("   - Packet capture started")


async def test_malware():
    """Test malware detection response"""
    print("\n🔴 Testing Malware Detection Response...")
    
    event = SecurityEvent(
        event_type='malware',
        process_name='test-cryptominer',
        user='testuser',
        details={
            'pid': '99999',
            'cpu_percent': 95.5,
            'executable': '/tmp/test-cryptominer'
        }
    )
    
    executor = PlaybookExecutor()
    await executor.execute_playbook('malware_detected', event)
    
    print("✅ Malware test completed")
    print("   - System should be isolated")
    print("   - Process would be killed (if it existed)")
    print("   - Memory dump collected")


async def test_container_compromise():
    """Test container compromise response"""
    print("\n🔴 Testing Container Compromise Response...")
    
    event = SecurityEvent(
        event_type='container_compromise',
        container_id='test-container-123',
        details={
            'reason': 'privileged_container',
            'image': 'suspicious:latest'
        }
    )
    
    executor = PlaybookExecutor()
    await executor.execute_playbook('container_compromise', event)
    
    print("✅ Container test completed")
    print("   - Container would be paused (if it existed)")
    print("   - Container exported for analysis")


async def test_all():
    """Run all tests"""
    print("🧪 Running Incident Response System Tests")
    print("=========================================")
    
    await test_brute_force()
    await asyncio.sleep(2)
    
    await test_port_scan()
    await asyncio.sleep(2)
    
    await test_malware()
    await asyncio.sleep(2)
    
    await test_container_compromise()
    
    print("\n✅ All tests completed!")
    print("\n📋 Check the following:")
    print("   1. iptables rules: sudo iptables -L")
    print("   2. Incident logs: ls -la /var/log/security/incidents/")
    print("   3. Playbook history: cat /var/log/security/playbook_executions.json")
    print("   4. Notifications (if configured)")


async def test_specific(test_name: str):
    """Run specific test"""
    tests = {
        'brute_force': test_brute_force,
        'port_scan': test_port_scan,
        'malware': test_malware,
        'container': test_container_compromise
    }
    
    if test_name in tests:
        await tests[test_name]()
    else:
        print(f"Unknown test: {test_name}")
        print(f"Available tests: {', '.join(tests.keys())}")


if __name__ == "__main__":
    if len(sys.argv) > 1:
        # Run specific test
        asyncio.run(test_specific(sys.argv[1]))
    else:
        # Run all tests
        asyncio.run(test_all())