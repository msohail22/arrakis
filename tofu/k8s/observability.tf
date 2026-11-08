# Observability: VictoriaMetrics + Grafana.
#
# WHY VictoriaMetrics AND NOT PROMETHEUS:
#   They do the same job - collect and store numbers over time. VictoriaMetrics
#   accepts Prometheus scrape configs and PromQL queries, so the knowledge
#   transfers, but uses less memory. On a node with about 1.4 GB free that is
#   the deciding factor.
#
# WHY ONE POD AND NOT TWO:
#   Single-node VictoriaMetrics scrapes AND stores. Its own docs: "If you use
#   single-node VictoriaMetrics, then you can discover and scrape
#   Prometheus-compatible targets directly from VictoriaMetrics without the need
#   to use vmagent." vmagent is only needed for buffering, relabelling or
#   fanning out to several backends. None apply here.
#
# WHY NOT THE HELM CHART:
#   Decision D48 keeps Kubernetes resources in OpenTofu. Adding the Helm
#   provider would mean a third thing that manages cluster state.
#
# Grafana DRAWS; VictoriaMetrics STORES. They are not alternatives - Grafana
# holds no data at all.

resource "kubernetes_namespace_v1" "obs" {
  metadata {
    name = "observability"
  }
}

# ---------------------------------------------------------------------------
# Permission to discover what to scrape.
#
# VictoriaMetrics finds targets by ASKING the Kubernetes API what exists. That
# needs read access. Without this the pod starts fine and scrapes nothing, which
# looks like a config problem and is not.
# ---------------------------------------------------------------------------

resource "kubernetes_service_account_v1" "vm" {
  metadata {
    name      = "victoria-metrics"
    namespace = kubernetes_namespace_v1.obs.metadata[0].name
  }
}

resource "kubernetes_cluster_role_v1" "vm" {
  metadata {
    name = "victoria-metrics-discovery"
  }

  # Read-only, and only the object kinds needed for discovery.
  rule {
    api_groups = [""]
    resources  = ["nodes", "nodes/metrics", "nodes/proxy", "services", "endpoints", "pods"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    non_resource_urls = ["/metrics", "/metrics/cadvisor"]
    verbs             = ["get"]
  }
}

resource "kubernetes_cluster_role_binding_v1" "vm" {
  metadata {
    name = "victoria-metrics-discovery"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.vm.metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.vm.metadata[0].name
    namespace = kubernetes_namespace_v1.obs.metadata[0].name
  }
}

# ---------------------------------------------------------------------------
# What to scrape. This is an ordinary Prometheus scrape config - the format is
# unchanged, which is the point of choosing VictoriaMetrics.
# ---------------------------------------------------------------------------

resource "kubernetes_config_map_v1" "vm_scrape" {
  metadata {
    name      = "vm-scrape-config"
    namespace = kubernetes_namespace_v1.obs.metadata[0].name
  }

  data = {
    "scrape.yml" = <<-EOT
      global:
        scrape_interval: 30s
        scrape_timeout: 10s

      scrape_configs:
        # VictoriaMetrics scraping itself. Always monitor the monitor: if this
        # series stops, the gap in every other graph is explained.
        - job_name: victoria-metrics
          static_configs:
            - targets: ["localhost:8428"]

        # The kubelet on each node: per-node CPU, memory, disk, pod counts.
        - job_name: kubelet
          scheme: https
          tls_config:
            ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
            insecure_skip_verify: true
          bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
          kubernetes_sd_configs:
            - role: node
          relabel_configs:
            - action: labelmap
              regex: __meta_kubernetes_node_label_(.+)
            - target_label: __address__
              replacement: kubernetes.default.svc:443
            - source_labels: [__meta_kubernetes_node_name]
              regex: (.+)
              target_label: __metrics_path__
              replacement: /api/v1/nodes/$1/proxy/metrics

        # cAdvisor, also via the kubelet: PER-CONTAINER cpu and memory. This is
        # the job that answers "which pod is using the memory".
        - job_name: cadvisor
          scheme: https
          tls_config:
            ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
            insecure_skip_verify: true
          bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
          kubernetes_sd_configs:
            - role: node
          relabel_configs:
            - action: labelmap
              regex: __meta_kubernetes_node_label_(.+)
            - target_label: __address__
              replacement: kubernetes.default.svc:443
            - source_labels: [__meta_kubernetes_node_name]
              regex: (.+)
              target_label: __metrics_path__
              replacement: /api/v1/nodes/$1/proxy/metrics/cadvisor

        # Any pod that asks to be scraped, by annotation. This is how the judge
        # API will be picked up later with no change here.
        - job_name: annotated-pods
          kubernetes_sd_configs:
            - role: pod
          relabel_configs:
            - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
              action: keep
              regex: "true"
            - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
              action: replace
              target_label: __metrics_path__
              regex: (.+)
            - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
              action: replace
              regex: ([^:]+)(?::\d+)?;(\d+)
              replacement: $1:$2
              target_label: __address__
            - source_labels: [__meta_kubernetes_namespace]
              target_label: namespace
            - source_labels: [__meta_kubernetes_pod_name]
              target_label: pod
    EOT
  }
}

resource "kubernetes_service_v1" "vm" {
  metadata {
    name      = "victoria-metrics"
    namespace = kubernetes_namespace_v1.obs.metadata[0].name
    labels    = { app = "victoria-metrics" }
  }
  spec {
    cluster_ip = "None"
    selector   = { app = "victoria-metrics" }
    port {
      name        = "http"
      port        = 8428
      target_port = 8428
    }
  }
}

resource "kubernetes_stateful_set_v1" "vm" {
  metadata {
    name      = "victoria-metrics"
    namespace = kubernetes_namespace_v1.obs.metadata[0].name
    labels    = { app = "victoria-metrics" }
  }

  spec {
    service_name = kubernetes_service_v1.vm.metadata[0].name
    replicas     = 1

    selector {
      match_labels = { app = "victoria-metrics" }
    }

    template {
      metadata {
        labels = { app = "victoria-metrics" }
        annotations = {
          "config-hash" = sha256(kubernetes_config_map_v1.vm_scrape.data["scrape.yml"])
        }
      }

      spec {
        service_account_name = kubernetes_service_account_v1.vm.metadata[0].name

        node_selector = {
          "kubernetes.io/hostname" = var.obs_node
        }

        security_context {
          fs_group = 1000
        }

        container {
          name  = "victoria-metrics"
          image = var.vm_image

          args = [
            "-storageDataPath=/storage",
            "-retentionPeriod=${var.vm_retention}",
            "-promscrape.config=/config/scrape.yml",
            # Unknown or unsupported Prometheus config sections are ignored
            # rather than refusing to start. Without this a single unsupported
            # key stops the whole service.
            "-promscrape.config.strictParse=false",
            # Caps memory used for internal CACHES. The docs recommend leaving
            # 50% of free RAM spare; this is the lever that enforces it. Without
            # it VictoriaMetrics sizes caches from total system memory, which in
            # a container means the NODE's memory, not the pod's limit - and it
            # gets OOM-killed.
            "-memory.allowedBytes=192MB",
            "-httpListenAddr=:8428",
          ]

          port {
            name           = "http"
            container_port = 8428
          }

          volume_mount {
            name       = "config"
            mount_path = "/config"
          }

          volume_mount {
            name       = "storage"
            mount_path = "/storage"
          }

          resources {
            requests = { cpu = "100m", memory = "192Mi" }
            limits   = { cpu = "1000m", memory = "448Mi" }
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = 8428
            }
            initial_delay_seconds = 10
            period_seconds        = 10
            failure_threshold     = 6
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = 8428
            }
            initial_delay_seconds = 30
            period_seconds        = 30
            failure_threshold     = 3
          }
        }

        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map_v1.vm_scrape.metadata[0].name
          }
        }
      }
    }

    volume_claim_template {
      metadata { name = "storage" }
      spec {
        access_modes = ["ReadWriteOnce"]
        resources {
          requests = { storage = var.vm_storage }
        }
      }
    }
  }

  timeouts { create = "10m" }
}
