#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154,SC1091
# Deploy complete security stack

source "$(dirname "$0")/../automation/parallel-framework.sh"

echo "Deploying security stack..."

# Define deployment tasks
tasks=(
    "docker run -d --name prometheus -p 9090:9090 -v $(pwd)/monitoring/prometheus.yml:/etc/prometheus/prometheus.yml prom/prometheus"
    "docker run -d --name grafana -p 3000:3000 -e GF_SECURITY_ADMIN_PASSWORD=admin grafana/grafana"
    "docker run -d --name node-exporter -p 9100:9100 prom/node-exporter"
    "docker run -d --name cadvisor -p 8080:8080 -v /var/run/docker.sock:/var/run/docker.sock gcr.io/cadvisor/cadvisor"
    "docker run -d --name trivy-server -p 8081:8081 aquasec/trivy:latest server"
)

# Deploy in parallel
parallel_execute tasks 3

echo "Security stack deployed!"
echo "Access points:"
echo "  Prometheus: http://localhost:9090"
echo "  Grafana: http://localhost:3000 (admin/admin)"
echo "  Node Exporter: http://localhost:9100"
echo "  cAdvisor: http://localhost:8080"
echo "  Trivy: http://localhost:8081"
