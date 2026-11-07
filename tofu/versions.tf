# Pinned exactly. The provider is pre-1.0 (v0.9.9), so its settings can change
# between releases. "=" prevents a surprise upgrade.
terraform {
  required_version = ">= 1.6"

  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "= 0.9.9"
    }
  }
}

# Talks to libvirt on arrakis over SSH, from your PC.
# qemu+ssh means: use the SSH transport. /system means the machine-wide VMs,
# not your user's private ones.
provider "libvirt" {
  uri = var.libvirt_uri
}
