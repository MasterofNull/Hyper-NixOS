#!/usr/bin/env python3
"""
Hyper-NixOS Web Dashboard
Copyright (C) 2024-2025 MasterofNull
Licensed under GPL v3.0

Lightweight web dashboard for VM management
"""

from flask import Flask, render_template, jsonify, request, send_from_directory
import subprocess
import json
import os
from pathlib import Path

app = Flask(
    __name__,
    static_folder='/var/www/hypervisor/static',
    template_folder='/var/www/hypervisor/templates',
)

SCRIPT_DIR = '/etc/hypervisor/scripts'
STATE_DIR = '/var/lib/hypervisor'
CONFIG_PATH = '/etc/hypervisor/config.json'

def load_donate_config():
    default = {
        'enable': True,
        'github_sponsors': 'https://github.com/sponsors/MasterofNull',
        'stripe': 'https://buy.stripe.com/REPLACE_LINK',
        'ko_fi': 'https://ko-fi.com/masterofnull',
        'paypal': 'https://paypal.me/masterofnull',
        'readme': 'https://github.com/MasterofNull/Hyper-NixOS#-support--donations',
    }
    try:
        if os.path.exists(CONFIG_PATH):
            with open(CONFIG_PATH, 'r') as f:
                cfg = json.load(f)
            donate = cfg.get('donate', {}) or {}
            # merge defaults with provided
            default.update({k: donate.get(k, v) for k, v in default.items()})
    except Exception:
        pass
    return default

def run_command(cmd, capture_output=True):
    """Execute shell command and return result"""
    try:
        result = subprocess.run(cmd, shell=True, capture_output=capture_output,
                               text=True, timeout=30)
        return {
            'success': result.returncode == 0,
            'output': result.stdout,
            'error': result.stderr,
            'returncode': result.returncode
        }
    except subprocess.TimeoutExpired:
        return {'success': False, 'error': 'Command timed out'}
    except Exception as e:
        return {'success': False, 'error': str(e)}

@app.route('/')
def index():
    """Main dashboard page"""
    donate = load_donate_config()
    return render_template('dashboard.html', donate=donate)

@app.route('/api/system/info')
def system_info():
    """Get system information"""
    try:
        hostname = subprocess.check_output('hostname', shell=True).decode().strip()
        uptime = subprocess.check_output('uptime -p', shell=True).decode().strip()
        
        # CPU info
        cpu_count = subprocess.check_output('nproc', shell=True).decode().strip()
        
        # Memory info
        mem_info = subprocess.check_output(
            "free -m | awk 'NR==2{printf \"%s/%s MB (%.0f%%)\", $3,$2,$3*100/$2 }'",
            shell=True
        ).decode().strip()
        
        # Disk info
        disk_info = subprocess.check_output(
            "df -h / | awk 'NR==2{print $3\"/\"$2\" (\"$5\")\"}'",
            shell=True
        ).decode().strip()
        
        return jsonify({
            'success': True,
            'data': {
                'hostname': hostname,
                'uptime': uptime,
                'cpu_count': cpu_count,
                'memory': mem_info,
                'disk': disk_info
            }
        })
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/vms/list')
def list_vms():
    """List all VMs"""
    try:
        # Get VM list from virsh
        result = run_command('virsh list --all --name')
        
        if not result['success']:
            return jsonify({'success': False, 'error': result['error']}), 500
        
        vms = []
        for vm_name in result['output'].strip().split('\n'):
            if not vm_name:
                continue
            
            # Get VM state
            state_result = run_command(f'virsh domstate "{vm_name}"')
            state = state_result['output'].strip() if state_result['success'] else 'unknown'
            
            # Get VM info
            info_result = run_command(f'virsh dominfo "{vm_name}"')
            cpu_count = '1'
            memory = 'Unknown'
            
            if info_result['success']:
                for line in info_result['output'].split('\n'):
                    if 'CPU(s):' in line:
                        cpu_count = line.split(':')[1].strip()
                    elif 'Max memory:' in line:
                        memory = line.split(':')[1].strip()
            
            vms.append({
                'name': vm_name,
                'state': state,
                'cpu': cpu_count,
                'memory': memory
            })
        
        return jsonify({'success': True, 'data': vms})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/vms/<vm_name>/start', methods=['POST'])
def start_vm(vm_name):
    """Start a VM"""
    result = run_command(f'virsh start "{vm_name}"')
    return jsonify(result)

@app.route('/api/vms/<vm_name>/shutdown', methods=['POST'])
def shutdown_vm(vm_name):
    """Shutdown a VM"""
    result = run_command(f'virsh shutdown "{vm_name}"')
    return jsonify(result)

@app.route('/api/vms/<vm_name>/reboot', methods=['POST'])
def reboot_vm(vm_name):
    """Reboot a VM"""
    result = run_command(f'virsh reboot "{vm_name}"')
    return jsonify(result)

@app.route('/api/vms/<vm_name>/destroy', methods=['POST'])
def destroy_vm(vm_name):
    """Force stop a VM"""
    result = run_command(f'virsh destroy "{vm_name}"')
    return jsonify(result)

@app.route('/api/health/status')
def health_status():
    """Get latest health check status"""
    try:
        status_file = f'{STATE_DIR}/health-status.json'
        if os.path.exists(status_file):
            with open(status_file, 'r') as f:
                data = json.load(f)
            return jsonify({'success': True, 'data': data})
        else:
            return jsonify({'success': False, 'error': 'No health status available'})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/health/run', methods=['POST'])
def run_health_check():
    """Trigger health check"""
    result = run_command(f'{SCRIPT_DIR}/system_health_check.sh', capture_output=False)
    return jsonify(result)

@app.route('/api/alerts/recent')
def recent_alerts():
    """Get recent alerts"""
    try:
        alert_log = f'{STATE_DIR}/logs/alerts.log'
        if os.path.exists(alert_log):
            # Read last 50 lines
            result = run_command(f'tail -n 50 "{alert_log}"')
            if result['success']:
                alerts = []
                for line in result['output'].strip().split('\n'):
                    if line:
                        alerts.append(line)
                return jsonify({'success': True, 'data': alerts})
        return jsonify({'success': True, 'data': []})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/isos/list')
def list_isos():
    """List available ISOs"""
    try:
        iso_dir = f'{STATE_DIR}/isos'
        isos = []
        
        if os.path.exists(iso_dir):
            for iso_file in Path(iso_dir).glob('*.iso'):
                stat = iso_file.stat()
                size_mb = stat.st_size / (1024 * 1024)
                isos.append({
                    'name': iso_file.name,
                    'size': f'{size_mb:.1f} MB',
                    'path': str(iso_file)
                })
        
        return jsonify({'success': True, 'data': isos})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

if __name__ == '__main__':
    # Run on localhost only by default for security
    # Use nginx/apache reverse proxy for external access
    app.run(host='127.0.0.1', port=8080, debug=False)
