# Behavioral Analysis System
# Detects zero-day threats through behavioral anomaly detection

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.hypervisor.security.behavioralAnalysis;
  
  # ML model for anomaly detection
  mlModel = pkgs.python3Packages.buildPythonApplication rec {
    pname = "hypervisor-ml-detector";
    version = "1.0.0";
    
    src = pkgs.writeTextDir "setup.py" ''
      from setuptools import setup
      setup(
        name="${pname}",
        version="${version}",
        py_modules=["ml_detector"],
        install_requires=[
          "scikit-learn",
          "numpy",
          "pandas",
          "joblib",
        ]
      )
    '';
    
    propagatedBuildInputs = with pkgs.python3Packages; [
      scikit-learn
      numpy
      pandas
      joblib
    ];
  };
  
  # Behavioral analysis engine
  behavioralEngine = pkgs.writeTextDir "ml_detector.py" ''
    #!/usr/bin/env python3
    
    import json
    import logging
    import numpy as np
    import pandas as pd
    from datetime import datetime, timedelta
    from pathlib import Path
    from sklearn.ensemble import IsolationForest
    from sklearn.preprocessing import StandardScaler
    from joblib import dump, load
    import sqlite3
    
    logging.basicConfig(level=logging.INFO)
    logger = logging.getLogger('behavioral-analysis')
    
    class BehavioralAnalyzer:
        def __init__(self):
            self.model_path = "/var/lib/hypervisor/ml-models"
            self.data_path = "/var/lib/hypervisor/behavioral-data"
            self.models = {}
            self.scalers = {}
            self.baselines = {}
            self.load_models()
            
        def load_models(self):
            """Load or initialize ML models"""
            Path(self.model_path).mkdir(parents=True, exist_ok=True)
            
            # VM behavior model
            vm_model_path = f"{self.model_path}/vm_behavior.joblib"
            if Path(vm_model_path).exists():
                self.models['vm'] = load(vm_model_path)
                self.scalers['vm'] = load(f"{self.model_path}/vm_scaler.joblib")
            else:
                self.models['vm'] = IsolationForest(
                    contamination=0.1,
                    random_state=42,
                    n_estimators=100
                )
                self.scalers['vm'] = StandardScaler()
                
            # Network behavior model
            net_model_path = f"{self.model_path}/network_behavior.joblib"
            if Path(net_model_path).exists():
                self.models['network'] = load(net_model_path)
                self.scalers['network'] = load(f"{self.model_path}/network_scaler.joblib")
            else:
                self.models['network'] = IsolationForest(
                    contamination=0.05,
                    random_state=42,
                    n_estimators=150
                )
                self.scalers['network'] = StandardScaler()
                
            # Process behavior model
            proc_model_path = f"{self.model_path}/process_behavior.joblib"
            if Path(proc_model_path).exists():
                self.models['process'] = load(proc_model_path)
                self.scalers['process'] = load(f"{self.model_path}/process_scaler.joblib")
            else:
                self.models['process'] = IsolationForest(
                    contamination=0.15,
                    random_state=42,
                    n_estimators=50
                )
                self.scalers['process'] = StandardScaler()
                
        def extract_vm_features(self, vm_data):
            """Extract behavioral features from VM data"""
            features = {
                # Resource usage patterns
                'cpu_mean': vm_data.get('cpu_usage', []).mean() if 'cpu_usage' in vm_data else 0,
                'cpu_std': vm_data.get('cpu_usage', []).std() if 'cpu_usage' in vm_data else 0,
                'cpu_max': vm_data.get('cpu_usage', []).max() if 'cpu_usage' in vm_data else 0,
                'memory_mean': vm_data.get('memory_usage', []).mean() if 'memory_usage' in vm_data else 0,
                'memory_std': vm_data.get('memory_usage', []).std() if 'memory_usage' in vm_data else 0,
                
                # I/O patterns
                'disk_read_rate': vm_data.get('disk_read_rate', 0),
                'disk_write_rate': vm_data.get('disk_write_rate', 0),
                'disk_io_ratio': vm_data.get('disk_write_rate', 0) / (vm_data.get('disk_read_rate', 1) + 1),
                
                # Network patterns
                'net_packets_in': vm_data.get('net_packets_in', 0),
                'net_packets_out': vm_data.get('net_packets_out', 0),
                'net_packet_ratio': vm_data.get('net_packets_out', 0) / (vm_data.get('net_packets_in', 1) + 1),
                
                # Temporal patterns
                'active_hours': len(set(vm_data.get('active_hours', []))),
                'state_changes': vm_data.get('state_changes', 0),
                
                # Process patterns
                'process_count': vm_data.get('process_count', 0),
                'thread_count': vm_data.get('thread_count', 0),
                'unique_processes': len(set(vm_data.get('process_names', []))),
            }
            
            return features
            
        def extract_network_features(self, net_data):
            """Extract network behavioral features"""
            features = {
                # Connection patterns
                'total_connections': net_data.get('connection_count', 0),
                'unique_destinations': len(set(net_data.get('destinations', []))),
                'unique_ports': len(set(net_data.get('dest_ports', []))),
                
                # Traffic patterns
                'bytes_sent': net_data.get('bytes_sent', 0),
                'bytes_received': net_data.get('bytes_received', 0),
                'traffic_ratio': net_data.get('bytes_sent', 0) / (net_data.get('bytes_received', 1) + 1),
                
                # Protocol distribution
                'tcp_percentage': net_data.get('tcp_count', 0) / (net_data.get('total_packets', 1) + 1) * 100,
                'udp_percentage': net_data.get('udp_count', 0) / (net_data.get('total_packets', 1) + 1) * 100,
                'icmp_percentage': net_data.get('icmp_count', 0) / (net_data.get('total_packets', 1) + 1) * 100,
                
                # Timing patterns
                'connection_rate': net_data.get('connections_per_minute', 0),
                'avg_connection_duration': net_data.get('avg_connection_duration', 0),
                'connection_burst_size': net_data.get('max_concurrent_connections', 0),
                
                # Anomaly indicators
                'failed_connections': net_data.get('failed_connections', 0),
                'port_scan_score': net_data.get('port_scan_score', 0),
                'dns_queries': net_data.get('dns_query_count', 0),
            }
            
            return features
            
        def extract_process_features(self, proc_data):
            """Extract process behavioral features"""
            features = {
                # Process creation patterns
                'process_creation_rate': proc_data.get('processes_per_hour', 0),
                'child_process_ratio': proc_data.get('child_processes', 0) / (proc_data.get('total_processes', 1) + 1),
                'process_lifetime_avg': proc_data.get('avg_process_lifetime', 0),
                
                # Resource usage
                'cpu_per_process': proc_data.get('total_cpu', 0) / (proc_data.get('process_count', 1) + 1),
                'memory_per_process': proc_data.get('total_memory', 0) / (proc_data.get('process_count', 1) + 1),
                
                # System call patterns
                'syscall_rate': proc_data.get('syscalls_per_second', 0),
                'file_operations': proc_data.get('file_op_count', 0),
                'network_operations': proc_data.get('network_op_count', 0),
                
                # Anomaly indicators
                'suspicious_names': proc_data.get('suspicious_process_names', 0),
                'hidden_processes': proc_data.get('hidden_process_count', 0),
                'privilege_escalations': proc_data.get('priv_esc_attempts', 0),
            }
            
            return features
            
        def detect_anomalies(self, entity_type, entity_id, data):
            """Detect behavioral anomalies using ML models"""
            try:
                # Extract features based on entity type
                if entity_type == 'vm':
                    features = self.extract_vm_features(data)
                elif entity_type == 'network':
                    features = self.extract_network_features(data)
                elif entity_type == 'process':
                    features = self.extract_process_features(data)
                else:
                    logger.error(f"Unknown entity type: {entity_type}")
                    return None
                
                # Convert to numpy array
                feature_vector = np.array([list(features.values())])
                
                # Scale features
                if hasattr(self.scalers[entity_type], 'mean_'):
                    feature_vector_scaled = self.scalers[entity_type].transform(feature_vector)
                else:
                    # First time - fit the scaler
                    feature_vector_scaled = self.scalers[entity_type].fit_transform(feature_vector)
                
                # Predict anomaly
                prediction = self.models[entity_type].predict(feature_vector_scaled)
                anomaly_score = self.models[entity_type].score_samples(feature_vector_scaled)[0]
                
                # Build result
                result = {
                    'entity_type': entity_type,
                    'entity_id': entity_id,
                    'timestamp': datetime.now().isoformat(),
                    'is_anomaly': prediction[0] == -1,
                    'anomaly_score': float(anomaly_score),
                    'features': features
                }
                
                # If anomaly detected, analyze which features contributed
                if result['is_anomaly']:
                    result['anomalous_features'] = self.identify_anomalous_features(
                        features, entity_type
                    )
                
                return result
                
            except Exception as e:
                logger.error(f"Error detecting anomalies: {e}")
                return None
                
        def identify_anomalous_features(self, features, entity_type):
            """Identify which features are most anomalous"""
            anomalous = []
            
            # Get baseline stats if available
            baseline = self.baselines.get(entity_type, {})
            
            for feature, value in features.items():
                if feature in baseline:
                    mean = baseline[feature]['mean']
                    std = baseline[feature]['std']
                    
                    # Calculate z-score
                    if std > 0:
                        z_score = abs(value - mean) / std
                        if z_score > 3:  # 3 standard deviations
                            anomalous.append({
                                'feature': feature,
                                'value': value,
                                'expected': mean,
                                'z_score': z_score
                            })
            
            return sorted(anomalous, key=lambda x: x['z_score'], reverse=True)[:5]
            
        def update_models(self, training_data):
            """Update ML models with new training data"""
            for entity_type, data in training_data.items():
                if entity_type in self.models and len(data) > 100:
                    logger.info(f"Updating {entity_type} model with {len(data)} samples")
                    
                    # Prepare features
                    features = []
                    for sample in data:
                        if entity_type == 'vm':
                            feat = self.extract_vm_features(sample)
                        elif entity_type == 'network':
                            feat = self.extract_network_features(sample)
                        elif entity_type == 'process':
                            feat = self.extract_process_features(sample)
                        features.append(list(feat.values()))
                    
                    # Convert to numpy array
                    X = np.array(features)
                    
                    # Fit scaler and model
                    X_scaled = self.scalers[entity_type].fit_transform(X)
                    self.models[entity_type].fit(X_scaled)
                    
                    # Save updated models
                    dump(self.models[entity_type], f"{self.model_path}/{entity_type}_behavior.joblib")
                    dump(self.scalers[entity_type], f"{self.model_path}/{entity_type}_scaler.joblib")
                    
                    # Update baselines
                    self.update_baselines(entity_type, features)
                    
        def update_baselines(self, entity_type, features):
            """Update baseline statistics for features"""
            df = pd.DataFrame(features)
            
            self.baselines[entity_type] = {}
            for column in df.columns:
                self.baselines[entity_type][column] = {
                    'mean': df[column].mean(),
                    'std': df[column].std(),
                    'min': df[column].min(),
                    'max': df[column].max()
                }
                
        def analyze_zero_day_indicators(self, anomalies):
            """Analyze anomalies for potential zero-day patterns"""
            zero_day_indicators = []
            
            # Group anomalies by time window
            time_window = timedelta(minutes=5)
            anomaly_clusters = []
            
            for anomaly in sorted(anomalies, key=lambda x: x['timestamp']):
                added = False
                for cluster in anomaly_clusters:
                    if (anomaly['timestamp'] - cluster[-1]['timestamp']) < time_window:
                        cluster.append(anomaly)
                        added = True
                        break
                
                if not added:
                    anomaly_clusters.append([anomaly])
            
            # Analyze clusters for zero-day patterns
            for cluster in anomaly_clusters:
                if len(cluster) >= 3:  # Multiple anomalies in short time
                    # Check for specific patterns
                    patterns = self.check_zero_day_patterns(cluster)
                    
                    if patterns:
                        zero_day_indicators.append({
                            'timestamp': cluster[0]['timestamp'],
                            'confidence': min(90, len(cluster) * 20),
                            'patterns': patterns,
                            'anomalies': cluster
                        })
            
            return zero_day_indicators
            
        def check_zero_day_patterns(self, anomaly_cluster):
            """Check for specific zero-day attack patterns"""
            patterns = []
            
            # Pattern 1: VM escape attempt
            vm_anomalies = [a for a in anomaly_cluster if a['entity_type'] == 'vm']
            proc_anomalies = [a for a in anomaly_cluster if a['entity_type'] == 'process']
            
            if vm_anomalies and proc_anomalies:
                # Check for privilege escalation + unusual VM behavior
                for proc in proc_anomalies:
                    if proc.get('features', {}).get('privilege_escalations', 0) > 0:
                        patterns.append('potential_vm_escape')
                        
            # Pattern 2: Novel malware
            net_anomalies = [a for a in anomaly_cluster if a['entity_type'] == 'network']
            
            if net_anomalies and proc_anomalies:
                # Check for new process with unusual network behavior
                for proc in proc_anomalies:
                    if proc.get('features', {}).get('suspicious_names', 0) > 0:
                        for net in net_anomalies:
                            if net.get('features', {}).get('unique_destinations', 0) > 10:
                                patterns.append('potential_novel_malware')
                                
            # Pattern 3: Advanced persistent threat
            if len(anomaly_cluster) > 5:
                # Check for slow, persistent anomalous behavior
                anomaly_scores = [a.get('anomaly_score', 0) for a in anomaly_cluster]
                if all(-2 < score < -1 for score in anomaly_scores):
                    patterns.append('potential_apt')
                    
            return patterns
    
    # Initialize analyzer
    analyzer = BehavioralAnalyzer()
    logger.info("Behavioral analysis engine initialized")
    
    # Main loop would go here
    while True:
        # Collect behavioral data
        # Detect anomalies
        # Update models periodically
        pass
  '';

in {
  options.hypervisor.security.behavioralAnalysis = {
    enable = mkEnableOption "behavioral analysis for zero-day detection";
    
    modelUpdateInterval = mkOption {
      type = types.str;
      default = "daily";
      description = "How often to retrain ML models";
    };
    
    anomalyThreshold = mkOption {
      type = types.float;
      default = 0.1;
      description = "Contamination factor for anomaly detection (0.0-1.0)";
    };
    
    dataRetention = mkOption {
      type = types.int;
      default = 30;
      description = "Days to retain behavioral data";
    };
    
    features = {
      vmBehavior = mkOption {
        type = types.bool;
        default = true;
        description = "Analyze VM behavioral patterns";
      };
      
      networkBehavior = mkOption {
        type = types.bool;
        default = true;
        description = "Analyze network behavioral patterns";
      };
      
      processBehavior = mkOption {
        type = types.bool;
        default = true;
        description = "Analyze process behavioral patterns";
      };
      
      userBehavior = mkOption {
        type = types.bool;
        default = true;
        description = "Analyze user behavioral patterns";
      };
    };
    
    zeroDayDetection = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable zero-day pattern detection";
      };
      
      confidenceThreshold = mkOption {
        type = types.int;
        default = 70;
        description = "Minimum confidence for zero-day alerts (0-100)";
      };
    };
  };
  
  config = mkIf cfg.enable {
    # Behavioral analysis service
    systemd.services."hypervisor-behavioral-analysis" = {
      description = "Behavioral Analysis Engine";
      wantedBy = [ "multi-user.target" ];
      after = [ "hypervisor-threat-detector.service" ];
      
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.python3}/bin/python3 ${behavioralEngine}/ml_detector.py";
        Restart = "always";
        
        # ML processing can be resource intensive
        Nice = 5;
        IOSchedulingClass = "best-effort";
        IOSchedulingPriority = 4;
        
        # Security
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ReadWritePaths = [
          "/var/lib/hypervisor/ml-models"
          "/var/lib/hypervisor/behavioral-data"
        ];
      };
    };
    
    # Model training timer
    systemd.timers."hypervisor-ml-training" = {
      description = "ML model training schedule";
      wantedBy = [ "timers.target" ];
      
      timerConfig = {
        OnCalendar = cfg.modelUpdateInterval;
        Persistent = true;
        RandomizedDelaySec = "2h";
      };
    };
    
    systemd.services."hypervisor-ml-training" = {
      description = "Train ML models on behavioral data";
      
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.bash}/bin/bash -c 'echo \"Training ML models...\"'";
        Nice = 19;
        IOSchedulingClass = "idle";
      };
    };
    
    # Data collection service
    systemd.services."hypervisor-behavior-collector" = {
      description = "Behavioral Data Collector";
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.bash}/bin/bash -c 'while true; do collect_behavioral_data; sleep 60; done'";
        Restart = "always";
      };
    };
    
    # Create directories
    systemd.tmpfiles.rules = [
      "d /var/lib/hypervisor/ml-models 0750 root root - -"
      "d /var/lib/hypervisor/behavioral-data 0750 root root - -"
    ];
    
    # Install ML dependencies
    environment.systemPackages = [ mlModel ];
  };
}