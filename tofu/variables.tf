variable "libvirt_uri" {
  description = "How to reach libvirt on arrakis. Uses your ssh-agent key."
  type        = string
  default     = "qemu+ssh://muaddib@arrakis/system?sshauth=agent"
}

variable "image_pool" {
  description = "The libvirt storage pool created by hand earlier."
  type        = string
  default     = "arrakis-images"
}

variable "network_name" {
  description = "The NAT network created by hand earlier. Not managed here."
  type        = string
  default     = "arrakis-nat"
}

variable "base_image" {
  description = "The Debian cloud image already downloaded on arrakis."
  type        = string
  default     = "/var/lib/libvirt/images/debian-13-generic-amd64.qcow2"
}

variable "ssh_public_keys" {
  description = "Keys allowed to log into the VMs. Read from disk, never hardcoded."
  type        = list(string)
}
