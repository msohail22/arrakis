# windtrap: the database VM. PostgreSQL and Redis will live here.
#
# 2 GB, not 3 GB like mentat. A database node needs less than a Kubernetes node.
# Measured on 2026-11-08: a 3 GB VM held only 1023 MB of real host memory,
# because QEMU hands memory over lazily. So this is a ceiling, not a cost.

locals {
  windtrap = {
    name   = "windtrap"
    memory = 2048
    vcpu   = 2
    disk   = 20 * 1024 * 1024 * 1024 # 20 GiB, in bytes
    mac    = "52:54:00:10:10:12"     # pinned in arrakis-nat.xml -> 10.10.10.12
    ip     = "10.10.10.12"
  }
}

# The disk. Copied from the base image, so the base stays pristine.
resource "libvirt_volume" "windtrap" {
  name           = "${local.windtrap.name}.qcow2"
  pool           = var.image_pool
  base_volume_id = var.base_image
  size           = local.windtrap.disk
  format         = "qcow2"
}

# The cloud-init configuration disk. This replaces cloud-localds.
resource "libvirt_cloudinit_disk" "windtrap" {
  name = "${local.windtrap.name}-seed.iso"
  pool = var.image_pool

  user_data = <<-EOT
    #cloud-config
    hostname: ${local.windtrap.name}
    fqdn: ${local.windtrap.name}.arrakis.local
    users:
      - name: muaddib
        sudo: ALL=(ALL) NOPASSWD:ALL
        shell: /bin/bash
        ssh_authorized_keys:
${join("\n", [for k in var.ssh_public_keys : "          - ${k}"])}
    package_update: true
  EOT

  meta_data = <<-EOT
    instance-id: ${local.windtrap.name}-001
    local-hostname: ${local.windtrap.name}
  EOT
}

resource "libvirt_domain" "windtrap" {
  name   = local.windtrap.name
  memory = local.windtrap.memory
  vcpu   = local.windtrap.vcpu

  # The flag that cost four attempts on mentat. Debian's cloud image needs UEFI;
  # virt-install and this provider both default to BIOS, which gives a silent
  # boot loop. See learning.md Q14.
  firmware = "/usr/share/OVMF/OVMF_CODE_4M.fd"

  nvram {
    file = "/var/lib/libvirt/qemu/nvram/${local.windtrap.name}_VARS.fd"
  }

  cpu { mode = "host-passthrough" }

  disk { volume_id = libvirt_volume.windtrap.id }
  disk { volume_id = libvirt_cloudinit_disk.windtrap.id }

  network_interface {
    network_name = var.network_name
    mac          = local.windtrap.mac
    wait_for_lease = true
  }

  # A serial console, so `virsh console windtrap` works. Without this there is
  # no way to watch a failed boot.
  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  graphics { type = "none" }

  autostart = true
}

output "windtrap_ip" {
  description = "Should be 10.10.10.12, from the pinned MAC."
  value       = try(libvirt_domain.windtrap.network_interface[0].addresses[0], "pending")
}
