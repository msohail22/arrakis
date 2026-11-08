# Redis: cache and job queue.
#
# WHY A StatefulSet AND NOT A Deployment, even though Redis is "just a cache":
#   The original design uses Redis STREAMS as the job queue. A queue that loses
#   its contents on restart is a different thing from one that does not - it
#   loses submitted jobs. So this gets persistence from the start, rather than a
#   migration later when it turns out to matter.
#
#   Cost of the decision: 1 GiB of a 410 GiB disk. Cost of the alternative:
#   recreating the resource later, under a name something already depends on.
#
# Pinned to the same node as PostgreSQL for the same reason (D47): local-path
# storage lives on one node's disk, so the pod is pinned either way.

locals {
  redis_port = 6379
}

# Redis configuration, supplied as a file rather than command-line flags so it
# is readable and diffable.
resource "kubernetes_config_map_v1" "redis" {
  metadata {
    name      = "redis-config"
    namespace = kubernetes_namespace_v1.data.metadata[0].name
  }

  data = {
    "redis.conf" = <<-EOT
      # Append-only file: every write is also journalled, so a restart replays
      # them. Without this, Redis only snapshots periodically and a crash loses
      # everything since the last snapshot - which for a job queue means losing
      # jobs.
      appendonly yes
      appendfsync everysec

      # A hard ceiling, so Redis cannot grow until the node runs out of memory
      # and the kernel kills something at random. Lower than the pod's limit on
      # purpose, so Redis evicts before Kubernetes kills it.
      maxmemory 192mb

      # What to do when that ceiling is reached. allkeys-lru discards the least
      # recently used key.
      #
      # WARNING, and the reason this is written down: eviction can discard
      # stream entries, which for a job queue means silently dropping jobs. If
      # this Redis ever becomes the real queue, change this to `noeviction` so
      # that writes FAIL LOUDLY instead of data disappearing quietly.
      maxmemory-policy allkeys-lru

      # Protected mode is for Redis exposed to a network with no auth. Here the
      # pod is only reachable inside the cluster. Left on; no password yet.
      # TODO: a password, from OpenBao, once T24 is done.
      save 900 1
      save 300 10
      save 60 10000
    EOT
  }
}

resource "kubernetes_service_v1" "redis" {
  metadata {
    name      = "redis"
    namespace = kubernetes_namespace_v1.data.metadata[0].name
    labels    = { app = "redis" }
  }
  spec {
    cluster_ip = "None" # headless, required by a StatefulSet
    selector   = { app = "redis" }
    port {
      name        = "redis"
      port        = local.redis_port
      target_port = local.redis_port
    }
  }
}

resource "kubernetes_stateful_set_v1" "redis" {
  metadata {
    name      = "redis"
    namespace = kubernetes_namespace_v1.data.metadata[0].name
    labels    = { app = "redis" }
  }

  spec {
    service_name = kubernetes_service_v1.redis.metadata[0].name
    replicas     = 1

    selector {
      match_labels = { app = "redis" }
    }

    template {
      metadata {
        labels = { app = "redis" }
        # Changing the ConfigMap does not restart a pod by itself. This
        # annotation changes when the config changes, which makes the
        # StatefulSet roll the pod. Without it, a config edit appears to do
        # nothing.
        annotations = {
          "config-hash" = sha256(kubernetes_config_map_v1.redis.data["redis.conf"])
        }
      }

      spec {
        node_selector = {
          "kubernetes.io/hostname" = var.redis_node
        }

        # The redis image runs as uid 999, like postgres. A fresh volume is
        # owned by root, so without this the append-only file cannot be written.
        security_context {
          fs_group = 999
        }

        container {
          name    = "redis"
          image   = var.redis_image
          command = ["redis-server", "/etc/redis/redis.conf"]

          port {
            name           = "redis"
            container_port = local.redis_port
          }

          volume_mount {
            name       = "config"
            mount_path = "/etc/redis"
          }

          volume_mount {
            name       = "data"
            mount_path = "/data"
          }

          # The limit is above `maxmemory` on purpose, so Redis hits its own
          # ceiling and evicts before Kubernetes decides to kill the container.
          resources {
            requests = { cpu = "50m", memory = "64Mi" }
            limits   = { cpu = "500m", memory = "256Mi" }
          }

          # redis-cli PING asks the server. A TCP check would pass while Redis
          # was still loading the append-only file into memory, which on a large
          # file takes a while and during which it rejects commands.
          readiness_probe {
            exec { command = ["redis-cli", "ping"] }
            initial_delay_seconds = 5
            period_seconds        = 5
            failure_threshold     = 6
          }

          liveness_probe {
            exec { command = ["redis-cli", "ping"] }
            initial_delay_seconds = 30
            period_seconds        = 20
            failure_threshold     = 3
          }
        }

        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map_v1.redis.metadata[0].name
          }
        }
      }
    }

    volume_claim_template {
      metadata {
        name = "data"
      }
      spec {
        access_modes = ["ReadWriteOnce"]
        resources {
          requests = {
            storage = var.redis_storage
          }
        }
      }
    }
  }

  timeouts {
    create = "5m"
  }
}

output "redis_dns" {
  description = "How a pod inside the cluster reaches Redis."
  value       = "redis-0.redis.${kubernetes_namespace_v1.data.metadata[0].name}.svc.cluster.local:${local.redis_port}"
}
