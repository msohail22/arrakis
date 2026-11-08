# PostgreSQL, as a StatefulSet pinned to one node.
#
# WHY A StatefulSet AND NOT A Deployment:
#   A Deployment treats its pods as interchangeable and gives them no storage of
#   their own. A StatefulSet gives each pod a stable name and its own volume,
#   created from volume_claim_template. A database needs both.
#
# WHY PINNED TO ONE NODE:
#   The storage class is `local-path`, which carves disk out of one node's own
#   filesystem. The data does NOT follow a pod to another node. So the pod is
#   pinned by its data whether we choose or not - choosing makes it deliberate.
#   If that node is down, PostgreSQL is down. That is the cost of one laptop.
#   See learning.md Q53.

resource "kubernetes_namespace_v1" "data" {
  metadata {
    name = "data"
  }
}

# Generated here rather than typed, so it is never in a shell history or a
# terminal. OpenTofu records it in STATE, which is why tofu/*.tfstate is
# gitignored (decision D13).
resource "random_password" "pg" {
  length  = 32
  special = false # avoids quoting problems in connection strings
}

resource "kubernetes_secret_v1" "pg" {
  metadata {
    name      = "postgres-credentials"
    namespace = kubernetes_namespace_v1.data.metadata[0].name
  }
  data = {
    POSTGRES_USER     = "quarantine"
    POSTGRES_PASSWORD = random_password.pg.result
    POSTGRES_DB       = "quarantine"
  }
  type = "Opaque"
}

# A headless Service: clusterIP = "None".
# It gives each pod a stable DNS name instead of load-balancing across them.
# A StatefulSet requires one. The docs: "StatefulSets currently require a
# Headless Service to be responsible for the network identity of the Pods."
resource "kubernetes_service_v1" "pg_headless" {
  metadata {
    name      = "postgres"
    namespace = kubernetes_namespace_v1.data.metadata[0].name
    labels    = { app = "postgres" }
  }
  spec {
    cluster_ip = "None"
    selector   = { app = "postgres" }
    port {
      name        = "postgres"
      port        = 5432
      target_port = 5432
    }
  }
}

resource "kubernetes_stateful_set_v1" "pg" {
  metadata {
    name      = "postgres"
    namespace = kubernetes_namespace_v1.data.metadata[0].name
    labels    = { app = "postgres" }
  }

  spec {
    service_name = kubernetes_service_v1.pg_headless.metadata[0].name
    replicas     = 1 # one laptop; replication is a later topic

    selector {
      match_labels = { app = "postgres" }
    }

    template {
      metadata {
        labels = { app = "postgres" }
      }

      spec {
        # The deliberate pinning. Without this the scheduler picks, and whichever
        # node it picks becomes permanent anyway once the volume exists there.
        node_selector = {
          "kubernetes.io/hostname" = var.pg_node
        }

        # postgres:17 runs as uid 999. fs_group makes the mounted volume
        # group-owned by 999 so the database can write to it. Without this the
        # container fails with a permission error on initdb.
        security_context {
          fs_group = 999
        }

        container {
          name  = "postgres"
          image = var.pg_image

          port {
            name           = "postgres"
            container_port = 5432
          }

          env_from {
            secret_ref {
              name = kubernetes_secret_v1.pg.metadata[0].name
            }
          }

          # The official image initialises into the mount root and fails if it
          # is not empty. local-path volumes are clean, but a subdirectory is the
          # documented-safe habit.
          env {
            name  = "PGDATA"
            value = "/var/lib/postgresql/data/pgdata"
          }

          volume_mount {
            name       = "data"
            mount_path = "/var/lib/postgresql/data"
          }

          # Measured room on windtrap was about 1475 MB. These leave headroom.
          resources {
            requests = { cpu = "100m", memory = "256Mi" }
            limits   = { cpu = "1000m", memory = "768Mi" }
          }

          # pg_isready asks the server whether it will accept connections.
          # A TCP check would pass while PostgreSQL was still recovering.
          readiness_probe {
            exec {
              command = ["pg_isready", "-U", "quarantine", "-d", "quarantine"]
            }
            initial_delay_seconds = 10
            period_seconds        = 5
            failure_threshold     = 6
          }

          liveness_probe {
            exec {
              command = ["pg_isready", "-U", "quarantine", "-d", "quarantine"]
            }
            initial_delay_seconds = 45
            period_seconds        = 20
            failure_threshold     = 3
          }
        }
      }
    }

    # This is what makes it a StatefulSet rather than a Deployment: the pod gets
    # its own volume, and the docs are explicit that it OUTLIVES the pod -
    # "Deleting and/or scaling a StatefulSet down will not delete the volumes".
    volume_claim_template {
      metadata {
        name = "data"
      }
      spec {
        access_modes = ["ReadWriteOnce"] # local-path supports only this
        resources {
          requests = {
            storage = var.pg_storage
          }
        }
      }
    }
  }

  # initdb on 1 vCPU is not fast.
  timeouts {
    create = "10m"
  }
}

output "pg_dns" {
  description = "How a pod inside the cluster reaches PostgreSQL."
  value       = "postgres-0.postgres.${kubernetes_namespace_v1.data.metadata[0].name}.svc.cluster.local:5432"
}

output "pg_secret" {
  description = "Where the generated credentials live. Read with kubectl, not here."
  value       = "secret/${kubernetes_secret_v1.pg.metadata[0].name} in namespace ${kubernetes_namespace_v1.data.metadata[0].name}"
}

output "pg_node" {
  description = "The node this database is pinned to. It cannot move."
  value       = var.pg_node
}
