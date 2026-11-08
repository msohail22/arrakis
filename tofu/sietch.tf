# sietch: a Kubernetes worker node.
#
# This provider (v0.9.9) follows libvirt's own domain XML schema closely, so the
# configuration is verbose and uses attribute syntax (`= { }`), not blocks.
# Every field here was taken from the provider's own docs, not from convention:
#   docs/resources/{domain,volume,cloudinit_disk}.md in dmacvicar/terraform-provider-libvirt
#
# Sizing: 2 GB. Measured 2026-11-08 with mentat and sietch both running: 5120 MB
# allocated, 2099 MB actually held, because QEMU hands memory over lazily. So the
# figure below is a ceiling, not a cost. See learning.md Q26.
#
# NOTE ON DUPLICATION: this file is a near-copy of windtrap.tf. That is deliberate
# for now - factoring both into one resource set with for_each would change their
# resource addresses, and OpenTofu would destroy and re-create two working VMs.
# The correct fix is `tofu state mv`, tracked as TODO T8.

locals {
  sietch = {
    name   = "sietch"
    memory = 2048                          # MiB
    vcpu   = 2
    disk   = 20 * 1024 * 1024 * 1024       # 20 GiB in bytes
    mac    = "52:54:00:10:10:13"           # pinned in arrakis-nat.xml -> 10.10.10.13
  }
}

# The disk. backing_store points at the Debian cloud image, so this volume is a
# copy-on-write overlay: it starts near zero bytes and only stores what changes.
# The base image is never written to, so it stays reusable for sietch.
resource "libvirt_volume" "sietch" {
  name     = "${local.sietch.name}.qcow2"
  pool     = var.image_pool
  capacity = local.sietch.disk

  target = {
    format = { type = "qcow2" }
  }

  backing_store = {
    path   = var.base_image
    format = { type = "qcow2" }
  }
}

# The cloud-init configuration disk. This is what cloud-localds built by hand.
#
# IMPORTANT: this resource builds the ISO on the MACHINE RUNNING TOFU (the PC),
# and its `path` is a local temporary file. arrakis cannot see it. Attaching
# that path directly fails with:
#   Cannot access storage file '/tmp/terraform-provider-libvirt-cloudinit/...'
# So it is uploaded into the pool as a volume below, and the VM uses that.
resource "libvirt_cloudinit_disk" "sietch" {
  name = "${local.sietch.name}-seed.iso"

  user_data = <<-EOT
    #cloud-config
    hostname: ${local.sietch.name}
    fqdn: ${local.sietch.name}.arrakis.local
    users:
      - name: muaddib
        sudo: ALL=(ALL) NOPASSWD:ALL
        shell: /bin/bash
        ssh_authorized_keys:
${join("\n", [for k in var.ssh_public_keys : "          - ${k}"])}
    package_update: true
  EOT

  meta_data = <<-EOT
    instance-id: ${local.sietch.name}-001
    local-hostname: ${local.sietch.name}
  EOT
}

# Uploads the locally-built ISO into the pool on arrakis. `create.content.url`
# accepts a local path as well as an http URL. This is the bridge between "built
# on the PC" and "readable by QEMU on arrakis".
resource "libvirt_volume" "sietch_seed" {
  name = "${local.sietch.name}-seed.iso"
  pool = var.image_pool

  target = {
    format = { type = "iso" }   # the provider detects iso and reports it back; declaring raw fails the consistency check
  }

  create = {
    content = {
      url = libvirt_cloudinit_disk.sietch.path
    }
  }
}

resource "libvirt_domain" "sietch" {
  name        = local.sietch.name
  type        = "kvm"
  memory      = local.sietch.memory
  memory_unit = "MiB"
  vcpu        = local.sietch.vcpu

  running   = true
  autostart = true # decision D16: mentat was missed and stayed off after a reboot

  cpu = {
    mode = "host-passthrough"
  }

  # UEFI refuses to start without ACPI: "unsupported configuration: UEFI
  # requires ACPI on this architecture". virt-install adds these silently; this
  # provider does not. apic is added for the same reason - an x86 guest needs an
  # interrupt controller.
  features = {
    acpi = true
    apic = {}
  }

  # UEFI. Without this the VM boot-loops in silence: `virsh list` says running
  # while nothing works, and the QEMU log shows no error. Debian's cloud image
  # expects UEFI; the default is BIOS. See learning.md Q14.
  # Paths verified on arrakis with `ls /usr/share/OVMF/`.
  os = {
    type            = "hvm"
    type_arch       = "x86_64"
    type_machine    = "q35"
    firmware        = "efi"
    loader          = "/usr/share/OVMF/OVMF_CODE_4M.fd"
    loader_readonly = "yes"   # String, not boolean: libvirt XML wants yes/no
    loader_type     = "pflash"
    nv_ram = {
      nv_ram   = "/var/lib/libvirt/qemu/nvram/${local.sietch.name}_VARS.fd"
      template = "/usr/share/OVMF/OVMF_VARS_4M.fd"
    }
    boot_devices    = [{ dev = "hd" }]
  }

  devices = {
    disks = [
      {
        # driver.type MUST be stated. The provider defaults to "raw", so QEMU
        # reads the qcow2 file as raw bytes: the guest then sees qcow2 header
        # metadata where the partition table should be, UEFI finds no
        # filesystem, and it drops to its own shell. The console log showed
        # "BLK0" with no "FS0:" alias. Found by diffing this XML against
        # mentat's working one. See learning.md Q25.
        driver = { name = "qemu", type = "qcow2" }
        source = { file = { file = libvirt_volume.sietch.path } }
        target = { dev = "vda", bus = "virtio" }
      },
      {
        device    = "cdrom"
        read_only = true
        driver    = { name = "qemu", type = "raw" } # an ISO really is raw
        source    = { file = { file = libvirt_volume.sietch_seed.path } }
        target    = { dev = "sda", bus = "sata" }
      },
    ]

    interfaces = [
      {
        model  = { type = "virtio" }
        mac    = { address = local.sietch.mac }
        source = { network = { network = var.network_name } }
      },
    ]

    # A serial console, so `virsh console sietch` works. Without it there is no
    # way to watch a failed boot, which is how Q14 was solved.
    #
    # `log` writes everything the console prints to a file on arrakis as well.
    # `virsh console` needs a controlling terminal, which a script does not have,
    # so without this a failed boot can only be diagnosed by a human sitting at a
    # prompt. The log file can be read by anything.
    consoles = [
      {
        target = { type = "serial", port = 0 }
        log    = { file = "/var/log/libvirt/qemu/${local.sietch.name}-console.log", append = "on" }
      },
    ]
  }
}

output "sietch_disk_path" {
  value = libvirt_volume.sietch.path
}

output "sietch_expected_ip" {
  description = "From the pinned MAC in arrakis-nat.xml."
  value       = "10.10.10.13"
}
