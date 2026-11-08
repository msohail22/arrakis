# Grafana: it DRAWS graphs. It stores no metrics.
#
# Grafana and VictoriaMetrics are not alternatives - they do different jobs:
#   VictoriaMetrics   collects and stores numbers        (the electricity meter)
#   Grafana           draws pictures from stored numbers (the app on your phone)
#
# Everything here is provisioned from files rather than clicked in the UI, so the
# configuration lives in git and survives the pod being deleted.

resource "random_password" "grafana_admin" {
  length  = 24
  special = false
}

resource "kubernetes_secret_v1" "grafana_admin" {
  metadata {
    name      = "grafana-admin"
    namespace = kubernetes_namespace_v1.obs.metadata[0].name
  }
  data = {
    admin-user     = "admin"
    admin-password = random_password.grafana_admin.result
  }
  type = "Opaque"
}

# Provisioning: Grafana reads this directory at startup and creates the
# datasource itself. The alternative is clicking it in the UI, where the setting
# lives only in Grafana's own database and is lost if the pod is recreated.
resource "kubernetes_config_map_v1" "grafana_datasource" {
  metadata {
    name      = "grafana-datasources"
    namespace = kubernetes_namespace_v1.obs.metadata[0].name
  }

  data = {
    "datasources.yaml" = <<-EOT
      apiVersion: 1
      datasources:
        # type: prometheus, pointing at VictoriaMetrics. That works because
        # VictoriaMetrics speaks the Prometheus query API - which is the whole
        # reason it was chosen over Prometheus itself.
        - name: VictoriaMetrics
          type: prometheus
          access: proxy
          url: http://victoria-metrics.observability.svc.cluster.local:8428
          isDefault: true
          jsonData:
            timeInterval: 30s
    EOT
  }
}

resource "kubernetes_service_v1" "grafana" {
  metadata {
    name      = "grafana"
    namespace = kubernetes_namespace_v1.obs.metadata[0].name
    labels    = { app = "grafana" }
  }
  spec {
    # NodePort, for the same reason as Argo CD (D38/D39): a port-forward is a
    # process that must stay alive, a NodePort is a permanent property of the
    # Service. Reached from the PC over Tailscale at mentat:30300.
    type     = "NodePort"
    selector = { app = "grafana" }
    port {
      name        = "http"
      port        = 3000
      target_port = 3000
      node_port   = var.grafana_nodeport
    }
  }
}

resource "kubernetes_stateful_set_v1" "grafana" {
  metadata {
    name      = "grafana"
    namespace = kubernetes_namespace_v1.obs.metadata[0].name
    labels    = { app = "grafana" }
  }

  spec {
    service_name = kubernetes_service_v1.grafana.metadata[0].name
    replicas     = 1

    selector {
      match_labels = { app = "grafana" }
    }

    template {
      metadata {
        labels = { app = "grafana" }
        annotations = {
          "config-hash" = sha256(kubernetes_config_map_v1.grafana_datasource.data["datasources.yaml"])
        }
      }

      spec {
        node_selector = {
          "kubernetes.io/hostname" = var.obs_node
        }

        # The grafana image runs as uid 472.
        security_context {
          fs_group = 472
        }

        container {
          name  = "grafana"
          image = var.grafana_image

          port {
            name           = "http"
            container_port = 3000
          }

          env {
            name = "GF_SECURITY_ADMIN_USER"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.grafana_admin.metadata[0].name
                key  = "admin-user"
              }
            }
          }

          env {
            name = "GF_SECURITY_ADMIN_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.grafana_admin.metadata[0].name
                key  = "admin-password"
              }
            }
          }

          # Nobody signs up for this Grafana.
          env {
            name  = "GF_USERS_ALLOW_SIGN_UP"
            value = "false"
          }

          # Grafana phones home for plugin and version news by default. Off:
          # this cluster is private and the traffic is pointless.
          env {
            name  = "GF_ANALYTICS_REPORTING_ENABLED"
            value = "false"
          }
          env {
            name  = "GF_ANALYTICS_CHECK_FOR_UPDATES"
            value = "false"
          }

          volume_mount {
            name       = "datasources"
            mount_path = "/etc/grafana/provisioning/datasources"
          }

          volume_mount {
            name       = "data"
            mount_path = "/var/lib/grafana"
          }

          resources {
            requests = { cpu = "50m", memory = "96Mi" }
            limits   = { cpu = "500m", memory = "256Mi" }
          }

          # Grafana's own readiness endpoint. It reports healthy only once the
          # database migrations have finished, which a TCP check would not.
          readiness_probe {
            http_get {
              path = "/api/health"
              port = 3000
            }
            initial_delay_seconds = 15
            period_seconds        = 10
            failure_threshold     = 10
          }
        }

        volume {
          name = "datasources"
          config_map {
            name = kubernetes_config_map_v1.grafana_datasource.metadata[0].name
          }
        }
      }
    }

    # Grafana keeps dashboards and users in a local SQLite database. Small, but
    # it should survive a restart.
    volume_claim_template {
      metadata { name = "data" }
      spec {
        access_modes = ["ReadWriteOnce"]
        resources {
          requests = { storage = "1Gi" }
        }
      }
    }
  }

  timeouts { create = "10m" }
}

output "grafana_url" {
  description = "Reachable from the PC over Tailscale, no tunnel."
  value       = "http://mentat:${var.grafana_nodeport}"
}

output "grafana_secret" {
  description = "Where the generated admin password lives. Read it with kubectl."
  value       = "secret/${kubernetes_secret_v1.grafana_admin.metadata[0].name} in namespace ${kubernetes_namespace_v1.obs.metadata[0].name}"
}

output "vm_url_in_cluster" {
  value = "http://victoria-metrics.observability.svc.cluster.local:8428"
}
