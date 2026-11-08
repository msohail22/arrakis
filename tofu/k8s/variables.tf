variable "kubeconfig" {
  description = "Path to the kubeconfig. Holds client certificates; never committed."
  type        = string
  default     = "~/.kube/arrakis.yaml"
}

variable "pg_node" {
  description = <<-EOT
    Which node PostgreSQL runs on. This is a real choice, not a preference.

    The storage class is `local-path`, which carves disk out of one node's own
    filesystem. The data does not follow a pod to another node, so the pod is
    pinned wherever its volume was first created. Choosing the node makes that
    pinning deliberate instead of accidental.
  EOT
  type        = string
  default     = "windtrap"
}

variable "pg_storage" {
  description = <<-EOT
    Volume size. The storage class has ALLOWVOLUMEEXPANSION=false, so this
    CANNOT be grown later. Verified 2026-11-08 with `kubectl get storageclass`.
  EOT
  type        = string
  default     = "5Gi"
}

variable "pg_image" {
  description = "Pinned. `latest` would silently change the major version on a restart."
  type        = string
  default     = "postgres:17.6-trixie"
}

variable "redis_node" {
  description = "Same pinning logic as pg_node. local-path storage cannot move."
  type        = string
  default     = "windtrap"
}

variable "redis_storage" {
  description = "Small: this holds a job queue and a cache, not a dataset."
  type        = string
  default     = "1Gi"
}

variable "redis_image" {
  description = "Pinned to a full version. Tag verified against Docker Hub 2026-11-08."
  type        = string
  default     = "redis:8.10.3-trixie"
}

variable "obs_node" {
  description = <<-EOT
    Observability runs on sietch. Measured 2026-11-08: sietch 564Mi of 1967 used
    (28%), the most free room. windtrap holds the databases, mentat is the
    control plane. Same local-path pinning reason as pg_node.
  EOT
  type        = string
  default     = "sietch"
}

variable "vm_image" {
  description = "Tag verified against Docker Hub 2026-11-08."
  type        = string
  default     = "victoriametrics/victoria-metrics:v1.154.1"
}

variable "vm_storage" {
  description = "Metrics storage. ALLOWVOLUMEEXPANSION is false, so size it now."
  type        = string
  default     = "4Gi"
}

variable "vm_retention" {
  description = <<-EOT
    How long metrics are kept. The documented default is 1 month; 14d is chosen
    because the volume cannot be grown later and this is a learning cluster.
  EOT
  type        = string
  default     = "14d"
}

variable "grafana_image" {
  description = "Tag verified against Docker Hub 2026-11-08."
  type        = string
  default     = "grafana/grafana:13.2.5"
}

variable "grafana_nodeport" {
  description = "Fixed, for the same reason as Argo CD's 30080 (D39)."
  type        = number
  default     = 30300
}
