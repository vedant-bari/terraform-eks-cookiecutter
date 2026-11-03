Here is the complete, production-grade documentation for your observability stack packaged into a markdown file (`MONITORING_GUIDE.md`).

You can instantly create this file in your workspace root by running the terminal command block below:

```bash
cat << 'EOF' > MONITORING_GUIDE.md
# Production-Grade Monitoring & Logging Deployment Guide

This guide covers the deployment and configuration of a production-grade observability stack (**Prometheus, Grafana, Loki, and Grafana Alloy**) for your GKE clusters using Terragrunt. 

The setup automatically captures:
* **Infrastructure & Workload Metrics** (via Prometheus & `kube-state-metrics`).
* **Container & Deployment Logs** (via Grafana Alloy with rich metadata labels like `controller_name`).
* **Kubernetes Cluster & Namespace Events** (tracking pod crashes, scaling events, and warnings).

---

### Step 1: Enable Monitoring in Client Configuration
Ensure your environment YAML configuration (e.g., `gcp-gke/12-platform-config/clients/client-c/infra/prod.yaml`) has monitoring enabled:

```yaml
monitoring:
  enabled: true

```

---

### Step 2: Generate the Monitoring Layer Layout

Run your dedicated monitoring scaffolding script, passing your client's YAML configuration path. This automatically creates the `05-monitoring` folder and links it to your GKE cluster outputs (`03-gke`):

```bash
python3 gcp-gke/scripts/scaffold_monitoring.py gcp-gke/12-platform-config/clients/client-c/infra/prod.yaml

```

---

### Step 3: Configure Production-Grade `values.yaml`

Inside your monitoring module path (e.g., `gcp-gke/03-live/clients/client-c/prod/05-monitoring/`), ensure your Helm release configuration uses production resources, replica sizing, and the comprehensive Alloy pipeline configuration:

```yaml
monitoring:
  fullnameOverride: monitoring
  defaultRules:
    create: true
  
  alertmanager:
    enabled: true

  kube-state-metrics:
    enabled: true

  prometheus-node-exporter:
    enabled: true

  grafana:
    enabled: true
    replicas: 2
    defaultDashboardsEnabled: true
    defaultDashboardsEditable: false
    persistence:
      enabled: true
      storageClassName: "standard-rwo"
      size: 10Gi
    resources:
      requests:
        cpu: 100m
        memory: 256Mi
      limits:
        cpu: 500m
        memory: 512Mi

  prometheus:
    enabled: true
    prometheusSpec:
      replicas: 2
      retention: "7d"
      retentionSize: "15GB"
      scrapeInterval: "15s"
      storageSpec:
        volumeClaimTemplate:
          spec:
            storageClassName: "standard-rwo"
            accessModes:
              - ReadWriteOnce
            resources:
              requests:
                storage: 20Gi

loki:
  deploymentMode: SingleBinary
  loki:
    auth_enabled: false
    storage:
      type: filesystem
      bucketNames:
        chunks: loki-chunks
        ruler: loki-ruler
    commonConfig:
      replication_factor: 1
    schemaConfig:
      configs:
        - from: "2024-04-01"
          store: tsdb
          object_store: filesystem
          schema: v13
          index:
            prefix: loki_index_
            period: 24h
    limits_config:
      retention_period: 168h
    compactor:
      retention_enabled: true
      delete_request_store: filesystem
  singleBinary:
    replicas: 1
    persistence:
      enabled: true
      storageClass: "standard-rwo"
      accessModes:
        - ReadWriteOnce
      size: 50Gi

alloy:
  fullnameOverride: alloy-logs
  controller:
    type: daemonset
    replicas: 1
  rbac:
    create: true
    rules:
      - apiGroups: [""]
        resources: ["pods", "pods/log", "namespaces", "events", "services", "endpoints"]
        verbs: ["get", "list", "watch"]
      - apiGroups: ["events.k8s.io"]
        resources: ["events"]
        verbs: ["get", "list", "watch"]
      - apiGroups: ["apps"]
        resources: ["deployments", "replicasets", "statefulsets", "daemonsets"]
        verbs: ["get", "list", "watch"]
  alloy:
    configMap:
      content: |-
        logging {
          level  = "info"
          format = "logfmt"
        }

        discovery.kubernetes "pods" {
          role = "pod"
        }

        discovery.relabel "pod_logs" {
          targets = discovery.kubernetes.pods.targets

          rule {
            source_labels = ["__meta_kubernetes_namespace"]
            target_label  = "namespace"
          }
          rule {
            source_labels = ["__meta_kubernetes_pod_name"]
            target_label  = "pod"
          }
          rule {
            source_labels = ["__meta_kubernetes_pod_container_name"]
            target_label  = "container"
          }
          rule {
            source_labels = ["__meta_kubernetes_pod_controller_name"]
            target_label  = "controller_name"
          }
        }

        loki.source.kubernetes "pods" {
          targets    = discovery.relabel.pod_logs.output
          forward_to = [loki.write.default.receiver]
        }

        loki.source.kubernetes_events "cluster_events" {
          forward_to = [loki.write.default.receiver]
        }

        loki.write "default" {
          endpoint {
            url = "[http://loki.monitoring.svc.cluster.local:3100/loki/api/v1/push](http://loki.monitoring.svc.cluster.local:3100/loki/api/v1/push)"
          }
        }
EOF

```

---

### Step 4: Deploy the Monitoring Layer

Once your GKE cluster is up and running, navigate to the monitoring directory and apply the configuration via Terragrunt:

```bash
cd gcp-gke/03-live/clients/client-c/prod/05-monitoring

# Initialize providers and modules
terragrunt init

# Apply the observability stack
terragrunt apply

```

---

### Step 5: Querying Logs and Events in Grafana

Access your Grafana UI, navigate to **Explore**, and choose your **Loki** data source to run the following LogQL queries:

* **View Deployment-Specific Logs:**
```logql
{namespace="default", controller_name=~"my-deployment.*"}

```


* **View Kubernetes Namespace & Cluster Events:**
```logql
{job="loki.source.kubernetes_events"}

```


* **Filter for Warning Events:**
```logql
{job="loki.source.kubernetes_events"} |= "Warning"

```



EOF

```

```