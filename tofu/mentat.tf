# mentat: the Kubernetes control plane. IMPORTED, NOT CREATED.
#
# ============================= READ THIS FIRST =============================
#
# This VM already existed. It was built by hand with virt-install on 2026-11-08
# (learning.md Q14), before OpenTofu was introduced to this project.
#
# Its disk holds the k3s server, the SQLite datastore, every Argo CD object and
# the cluster's certificate authority. THERE IS NO BACKUP.
#
#   NEVER apply a plan that says this resource will be "replaced" or
#   "destroyed". A replacement deletes the disk and the cluster with it.
#
# Brought under management with an import block plus generated configuration:
#
#   import { to = libvirt_domain.mentat, id = "<uuid>" }
#   tofu plan -generate-config-out=mentat-generated.tf
#
# ============================ WHY SO VERBOSE ==============================
#
# Every attribute is listed, including hundreds of nulls. That is deliberate and
# it is not tidy-able without risk.
#
# A hand-written version of this file was tried first. `tofu plan` then wanted
# to REMOVE everything the file did not mention: the guest-agent channel, the
# clock timers (rtc/pit/hpet), the audio device, the memory balloon and more -
# all added by virt-install. OpenTofu treats an omitted attribute as "should not
# exist".
#
# So this file was GENERATED from the live object, which is the only way to get
# `0 to change`. Deleting a line here does not simplify the file; it schedules a
# device for removal from a running control plane.
#
# ========================== NOTABLE DIFFERENCES ===========================
#
# virt-install chose SECURE BOOT firmware - OVMF_CODE_4M.ms.fd with enrolled
# keys, which also requires `smm`. windtrap, sietch and shieldwall use the plain
# OVMF_CODE_4M.fd because the OpenTofu files ask for it. Both work. This is
# recorded rather than normalised: changing a running machine's firmware is not
# a cosmetic edit.
#
# See TODO T5 and decisions D20, D47.

# __generated__ by OpenTofu
# Please review these resources and move them into your main configuration files.

# __generated__ by OpenTofu from "26b20a4b-f903-4987-a06e-f63e4a94ae7b"
resource "libvirt_domain" "mentat" {
  autostart         = true
  bhyve_commandline = null
  block_io_tune     = null
  bootloader        = null
  bootloader_args   = null
  clock = {
    adjustment = null
    basis      = null
    offset     = "utc"
    start      = null
    time_zone  = null
    timer = [
      {
        catch_up    = null
        frequency   = null
        mode        = null
        name        = "rtc"
        present     = null
        tick_policy = "catchup"
        track       = null
      },
      {
        catch_up    = null
        frequency   = null
        mode        = null
        name        = "pit"
        present     = null
        tick_policy = "delay"
        track       = null
      },
      {
        catch_up    = null
        frequency   = null
        mode        = null
        name        = "hpet"
        present     = "no"
        tick_policy = null
        track       = null
      },
    ]
  }
  cpu = {
    cache               = null
    check               = "none"
    deprecated_features = null
    features            = null
    match               = null
    max_phys_addr       = null
    migratable          = false
    mode                = "host-passthrough"
    model               = null
    model_fallback      = null
    model_vendor_id     = null
    numa                = null
    topology            = null
    vendor              = null
  }
  cpu_tune            = null
  create              = null
  current_memory      = 3145728
  current_memory_unit = "KiB"
  default_io_thread   = null
  description         = null
  destroy             = null
  devices = {
    audios = [
      {
        alsa       = null
        core_audio = null
        dbus       = null
        file       = null
        id         = 1
        jack       = null
        none = {
          input  = null
          output = null
        }
        oss          = null
        pipe_wire    = null
        pulse_audio  = null
        sdl          = null
        spice        = null
        timer_period = null
      },
    ]
    channels = [
      {
        acpi = null
        address = {
        }
        alias = {
          name = "channel0"
        }
        log      = null
        protocol = null
        source = {
          dbus          = null
          dev           = null
          file          = null
          nmdm          = null
          null          = false
          pipe          = null
          pty           = null
          qemu_vd_agent = null
          spice_port    = null
          spice_vmc     = false
          std_io        = false
          tcp           = null
          udp           = null
          unix = {
            mode      = "bind"
            path      = "/run/libvirt/qemu/channel/1-mentat/org.qemu.guest_agent.0"
            reconnect = null
            sec_label = null
          }
          vc = false
        }
        target = {
          guest_fwd = null
          virt_io = {
            name  = "org.qemu.guest_agent.0"
            state = "disconnected"
          }
          xen = null
        }
      },
    ]
    consoles = [
      {
        acpi    = null
        address = null
        alias = {
          name = "serial0"
        }
        log      = null
        protocol = null
        source = {
          dbus = null
          dev  = null
          file = null
          nmdm = null
          null = false
          pipe = null
          pty = {
            path      = "/dev/pts/0"
            sec_label = null
          }
          qemu_vd_agent = null
          spice_port    = null
          spice_vmc     = false
          std_io        = false
          tcp           = null
          udp           = null
          unix          = null
          vc            = false
        }
        target = {
          port = 0
          type = "serial"
        }
        tty = "/dev/pts/0"
      },
    ]
    controllers = [
      {
        acpi = null
        address = {
        }
        alias = {
          name = "usb"
        }
        driver = null
        index  = 0
        model  = "qemu-xhci"
        nvme   = null
        pci    = null
        type   = "usb"
        usb = {
          master = null
          port   = 15
        }
        virt_io_serial = null
        xen_bus        = null
      },
      {
        acpi    = null
        address = null
        alias = {
          name = "pcie.0"
        }
        driver = null
        index  = 0
        model  = "pcie-root"
        nvme   = null
        pci = {
          hole64      = null
          hole64_unit = null
          model       = null
          target      = null
        }
        type           = "pci"
        usb            = null
        virt_io_serial = null
        xen_bus        = null
      },
      {
        acpi = null
        address = {
        }
        alias = {
          name = "pci.1"
        }
        driver = null
        index  = 1
        model  = "pcie-root-port"
        nvme   = null
        pci = {
          hole64      = null
          hole64_unit = null
          model = {
            name = "pcie-root-port"
          }
          target = {
          }
        }
        type           = "pci"
        usb            = null
        virt_io_serial = null
        xen_bus        = null
      },
      {
        acpi = null
        address = {
        }
        alias = {
          name = "pci.2"
        }
        driver = null
        index  = 2
        model  = "pcie-root-port"
        nvme   = null
        pci = {
          hole64      = null
          hole64_unit = null
          model = {
            name = "pcie-root-port"
          }
          target = {
          }
        }
        type           = "pci"
        usb            = null
        virt_io_serial = null
        xen_bus        = null
      },
      {
        acpi = null
        address = {
        }
        alias = {
          name = "pci.3"
        }
        driver = null
        index  = 3
        model  = "pcie-root-port"
        nvme   = null
        pci = {
          hole64      = null
          hole64_unit = null
          model = {
            name = "pcie-root-port"
          }
          target = {
          }
        }
        type           = "pci"
        usb            = null
        virt_io_serial = null
        xen_bus        = null
      },
      {
        acpi = null
        address = {
        }
        alias = {
          name = "pci.4"
        }
        driver = null
        index  = 4
        model  = "pcie-root-port"
        nvme   = null
        pci = {
          hole64      = null
          hole64_unit = null
          model = {
            name = "pcie-root-port"
          }
          target = {
          }
        }
        type           = "pci"
        usb            = null
        virt_io_serial = null
        xen_bus        = null
      },
      {
        acpi = null
        address = {
        }
        alias = {
          name = "pci.5"
        }
        driver = null
        index  = 5
        model  = "pcie-root-port"
        nvme   = null
        pci = {
          hole64      = null
          hole64_unit = null
          model = {
            name = "pcie-root-port"
          }
          target = {
          }
        }
        type           = "pci"
        usb            = null
        virt_io_serial = null
        xen_bus        = null
      },
      {
        acpi = null
        address = {
        }
        alias = {
          name = "pci.6"
        }
        driver = null
        index  = 6
        model  = "pcie-root-port"
        nvme   = null
        pci = {
          hole64      = null
          hole64_unit = null
          model = {
            name = "pcie-root-port"
          }
          target = {
          }
        }
        type           = "pci"
        usb            = null
        virt_io_serial = null
        xen_bus        = null
      },
      {
        acpi = null
        address = {
        }
        alias = {
          name = "pci.7"
        }
        driver = null
        index  = 7
        model  = "pcie-root-port"
        nvme   = null
        pci = {
          hole64      = null
          hole64_unit = null
          model = {
            name = "pcie-root-port"
          }
          target = {
          }
        }
        type           = "pci"
        usb            = null
        virt_io_serial = null
        xen_bus        = null
      },
      {
        acpi = null
        address = {
        }
        alias = {
          name = "pci.8"
        }
        driver = null
        index  = 8
        model  = "pcie-root-port"
        nvme   = null
        pci = {
          hole64      = null
          hole64_unit = null
          model = {
            name = "pcie-root-port"
          }
          target = {
          }
        }
        type           = "pci"
        usb            = null
        virt_io_serial = null
        xen_bus        = null
      },
      {
        acpi = null
        address = {
        }
        alias = {
          name = "pci.9"
        }
        driver = null
        index  = 9
        model  = "pcie-root-port"
        nvme   = null
        pci = {
          hole64      = null
          hole64_unit = null
          model = {
            name = "pcie-root-port"
          }
          target = {
          }
        }
        type           = "pci"
        usb            = null
        virt_io_serial = null
        xen_bus        = null
      },
      {
        acpi = null
        address = {
        }
        alias = {
          name = "pci.10"
        }
        driver = null
        index  = 10
        model  = "pcie-root-port"
        nvme   = null
        pci = {
          hole64      = null
          hole64_unit = null
          model = {
            name = "pcie-root-port"
          }
          target = {
          }
        }
        type           = "pci"
        usb            = null
        virt_io_serial = null
        xen_bus        = null
      },
      {
        acpi = null
        address = {
        }
        alias = {
          name = "pci.11"
        }
        driver = null
        index  = 11
        model  = "pcie-root-port"
        nvme   = null
        pci = {
          hole64      = null
          hole64_unit = null
          model = {
            name = "pcie-root-port"
          }
          target = {
          }
        }
        type           = "pci"
        usb            = null
        virt_io_serial = null
        xen_bus        = null
      },
      {
        acpi = null
        address = {
        }
        alias = {
          name = "pci.12"
        }
        driver = null
        index  = 12
        model  = "pcie-root-port"
        nvme   = null
        pci = {
          hole64      = null
          hole64_unit = null
          model = {
            name = "pcie-root-port"
          }
          target = {
          }
        }
        type           = "pci"
        usb            = null
        virt_io_serial = null
        xen_bus        = null
      },
      {
        acpi = null
        address = {
        }
        alias = {
          name = "pci.13"
        }
        driver = null
        index  = 13
        model  = "pcie-root-port"
        nvme   = null
        pci = {
          hole64      = null
          hole64_unit = null
          model = {
            name = "pcie-root-port"
          }
          target = {
          }
        }
        type           = "pci"
        usb            = null
        virt_io_serial = null
        xen_bus        = null
      },
      {
        acpi = null
        address = {
        }
        alias = {
          name = "pci.14"
        }
        driver = null
        index  = 14
        model  = "pcie-root-port"
        nvme   = null
        pci = {
          hole64      = null
          hole64_unit = null
          model = {
            name = "pcie-root-port"
          }
          target = {
          }
        }
        type           = "pci"
        usb            = null
        virt_io_serial = null
        xen_bus        = null
      },
      {
        acpi = null
        address = {
        }
        alias = {
          name = "ide"
        }
        driver         = null
        index          = 0
        model          = null
        nvme           = null
        pci            = null
        type           = "sata"
        usb            = null
        virt_io_serial = null
        xen_bus        = null
      },
      {
        acpi = null
        address = {
        }
        alias = {
          name = "virtio-serial0"
        }
        driver = null
        index  = 0
        model  = null
        nvme   = null
        pci    = null
        type   = "virtio-serial"
        usb    = null
        virt_io_serial = {
          ports   = null
          vectors = null
        }
        xen_bus = null
      },
    ]
    crypto = null
    disks = [
      {
        acpi = null
        address = {
        }
        alias = {
          name = "virtio-disk0"
        }
        auth           = null
        backend_domain = null
        backing_store = {
          format = null
          index  = null
          source = {
            block          = null
            cookies        = null
            ctl            = null
            data_store     = null
            dir            = null
            encryption     = null
            file           = null
            index          = null
            network        = null
            nvme           = null
            readahead      = null
            reservations   = null
            slices         = null
            ssl            = null
            startup_policy = null
            timeout        = null
            vhost_user     = null
            vhost_vdpa     = null
            volume         = null
          }
        }
        block_io = null
        boot     = null
        device   = "disk"
        driver = {
          ats              = null
          cache            = null
          copy_on_read     = null
          detect_zeros     = null
          discard          = null
          discard_no_unref = null
          error_policy     = null
          event_idx        = null
          io               = null
          io_event_fd      = null
          io_thread        = null
          io_threads       = null
          iommu            = null
          metadata_cache   = null
          name             = "qemu"
          packed           = null
          page_per_vq      = null
          queue_size       = null
          queues           = null
          rerror_policy    = null
          statistics       = null
          type             = "qcow2"
        }
        encryption = null
        geometry   = null
        io_tune    = null
        mirror     = null
        model      = null
        product    = null
        raw_io     = null
        read_only  = false
        serial     = null
        sgio       = null
        shareable  = false
        snapshot   = null
        source = {
          block      = null
          cookies    = null
          ctl        = null
          data_store = null
          dir        = null
          encryption = null
          file = {
            fd_group  = null
            file      = "/var/lib/libvirt/images/mentat.qcow2"
            sec_label = null
          }
          index          = 2
          network        = null
          nvme           = null
          readahead      = null
          reservations   = null
          slices         = null
          ssl            = null
          startup_policy = null
          timeout        = null
          vhost_user     = null
          vhost_vdpa     = null
          volume         = null
        }
        target = {
          bus           = "virtio"
          dev           = "vda"
          dpofua        = null
          removable     = null
          rotation_rate = null
          tray          = null
        }
        throttle_filters = null
        transient        = null
        vendor           = null
        wwn              = null
      },
      {
        acpi = null
        address = {
        }
        alias = {
          name = "sata0-0-0"
        }
        auth           = null
        backend_domain = null
        backing_store = {
          format = null
          index  = null
          source = {
            block          = null
            cookies        = null
            ctl            = null
            data_store     = null
            dir            = null
            encryption     = null
            file           = null
            index          = null
            network        = null
            nvme           = null
            readahead      = null
            reservations   = null
            slices         = null
            ssl            = null
            startup_policy = null
            timeout        = null
            vhost_user     = null
            vhost_vdpa     = null
            volume         = null
          }
        }
        block_io = null
        boot     = null
        device   = "cdrom"
        driver = {
          ats              = null
          cache            = null
          copy_on_read     = null
          detect_zeros     = null
          discard          = null
          discard_no_unref = null
          error_policy     = null
          event_idx        = null
          io               = null
          io_event_fd      = null
          io_thread        = null
          io_threads       = null
          iommu            = null
          metadata_cache   = null
          name             = "qemu"
          packed           = null
          page_per_vq      = null
          queue_size       = null
          queues           = null
          rerror_policy    = null
          statistics       = null
          type             = "raw"
        }
        encryption = null
        geometry   = null
        io_tune    = null
        mirror     = null
        model      = null
        product    = null
        raw_io     = null
        read_only  = true
        serial     = null
        sgio       = null
        shareable  = false
        snapshot   = null
        source = {
          block      = null
          cookies    = null
          ctl        = null
          data_store = null
          dir        = null
          encryption = null
          file = {
            fd_group  = null
            file      = "/var/lib/libvirt/images/mentat-seed.iso"
            sec_label = null
          }
          index          = 1
          network        = null
          nvme           = null
          readahead      = null
          reservations   = null
          slices         = null
          ssl            = null
          startup_policy = null
          timeout        = null
          vhost_user     = null
          vhost_vdpa     = null
          volume         = null
        }
        target = {
          bus           = "sata"
          dev           = "sda"
          dpofua        = null
          removable     = null
          rotation_rate = null
          tray          = null
        }
        throttle_filters = null
        transient        = null
        vendor           = null
        wwn              = null
      },
    ]
    emulator    = "/usr/bin/qemu-system-x86_64"
    filesystems = null
    graphics    = null
    hostdevs    = null
    hubs        = null
    inputs = [
      {
        acpi    = null
        address = null
        alias = {
          name = "input0"
        }
        bus    = "ps2"
        driver = null
        model  = null
        source = {
          ev_dev      = null
          passthrough = null
        }
        type = "mouse"
      },
      {
        acpi    = null
        address = null
        alias = {
          name = "input1"
        }
        bus    = "ps2"
        driver = null
        model  = null
        source = {
          ev_dev      = null
          passthrough = null
        }
        type = "keyboard"
      },
    ]
    interfaces = [
      {
        acpi = null
        address = {
        }
        alias = {
          name = "net0"
        }
        backend        = null
        backend_domain = null
        bandwidth      = null
        boot           = null
        coalesce       = null
        down_script    = null
        driver         = null
        filter_ref     = null
        guest          = null
        ip             = null
        link           = null
        mac = {
          address = "52:54:00:10:10:11"
          check   = null
          type    = null
        }
        managed = null
        model = {
          type = "virtio"
        }
        mtu          = null
        port_forward = null
        port_options = null
        rom          = null
        route        = null
        script       = null
        source = {
          bridge   = null
          client   = null
          direct   = null
          ethernet = null
          hostdev  = null
          internal = null
          mcast    = null
          network = {
            bridge     = "virbr-arrakis"
            network    = "arrakis-nat"
            port_group = null
            port_id    = "01195bce-f767-4fea-9b89-06c1eea3c8bb"
          }
          null       = false
          server     = null
          udp        = null
          user       = null
          vdpa       = null
          vds        = null
          vhost_user = null
        }
        target = {
          dev     = "vnet0"
          managed = null
        }
        teaming                = null
        trust_guest_rx_filters = null
        tune                   = null
        virtual_port           = null
        vlan                   = null
        wait_for_ip            = null
      },
    ]
    iomm_us = null
    iommu   = null
    leases  = null
    mem_balloon = {
      acpi = null
      address = {
      }
      alias = {
        name = "balloon0"
      }
      auto_deflate        = null
      driver              = null
      free_page_reporting = null
      model               = "virtio"
      stats               = null
    }
    memorydevs    = null
    nvram         = null
    panics        = null
    parallels     = null
    pstore        = null
    redir_devs    = null
    redir_filters = null
    rngs = [
      {
        acpi = null
        address = {
        }
        alias = {
          name = "rng0"
        }
        backend = {
          built_in = false
          egd      = null
          random   = "/dev/urandom"
        }
        driver = null
        model  = "virtio"
        rate   = null
      },
    ]
    serials = [
      {
        acpi    = null
        address = null
        alias = {
          name = "serial0"
        }
        log      = null
        protocol = null
        source = {
          dbus = null
          dev  = null
          file = null
          nmdm = null
          null = false
          pipe = null
          pty = {
            path      = "/dev/pts/0"
            sec_label = null
          }
          qemu_vd_agent = null
          spice_port    = null
          spice_vmc     = false
          std_io        = false
          tcp           = null
          udp           = null
          unix          = null
          vc            = false
        }
        target = {
          model = {
            name = "isa-serial"
          }
          port = 0
          type = "isa-serial"
        }
      },
    ]
    shmems     = null
    smartcards = null
    sounds     = null
    tpms = [
      {
        acpi    = null
        address = null
        alias = {
          name = "tpm0"
        }
        backend = {
          emulator = {
            active_pcr_banks = null
            debug            = null
            encryption       = null
            persistent_state = null
            profile          = null
            source           = null
            version          = "2.0"
          }
          external    = null
          passthrough = null
        }
        model = "tpm-crb"
      },
    ]
    videos = null
    vsock  = null
    watchdogs = [
      {
        acpi    = null
        action  = "reset"
        address = null
        alias = {
          name = "watchdog0"
        }
        model = "itco"
      },
    ]
  }
  features = {
    acpi = true
    aia  = null
    apic = {
      eoi = null
    }
    async_teardown = null
    capabilities   = null
    ccf_assist     = null
    cfpc           = null
    gic            = null
    hap            = null
    hpt            = null
    htm            = null
    hyper_v        = null
    ibs            = null
    ioapic         = null
    kvm            = null
    msrs           = null
    nested_hv      = null
    pae            = false
    pmu            = null
    priv_net       = false
    ps2            = null
    pv_spinlock    = null
    ras            = null
    sbbc           = null
    smm = {
      state     = "on"
      tseg      = null
      tseg_unit = null
    }
    tcg            = null
    viridian       = false
    virtualization = false
    vm_core_info   = null
    vm_port        = null
    xen            = null
  }
  gen_id               = null
  hwuuid               = null
  id_map               = null
  io_thread_i_ds       = null
  io_threads           = null
  iommufd              = null
  key_wrap             = null
  launch_security      = null
  lxc_namespace        = null
  maximum_memory       = null
  maximum_memory_slots = null
  maximum_memory_unit  = null
  memory               = 3145728
  memory_backing       = null
  memory_dump_core     = null
  memory_tune          = null
  memory_unit          = "KiB"
  metadata = {
    xml = "\n    <libosinfo:libosinfo xmlns:libosinfo=\"http://libosinfo.org/xmlns/libvirt/domain/1.0\">\n      <libosinfo:os id=\"http://debian.org/debian/13\"/>\n    </libosinfo:libosinfo>\n  "
  }
  name        = "mentat"
  numa_tune   = null
  on_crash    = "destroy"
  on_poweroff = "destroy"
  on_reboot   = "restart"
  os = {
    acpi = null
    bios = null
    boot_devices = [
      {
        dev = "hd"
      },
    ]
    boot_menu = null
    cmdline   = null
    dtb       = null
    firmware  = "efi"
    firmware_info = {
      features = [
        {
          enabled = "yes"
          name    = "enrolled-keys"
        },
        {
          enabled = "yes"
          name    = "secure-boot"
        },
      ]
    }
    init             = null
    init_args        = null
    init_dir         = null
    init_env         = null
    init_group       = null
    init_user        = null
    initrd           = null
    kernel           = null
    loader           = "/usr/share/OVMF/OVMF_CODE_4M.ms.fd"
    loader_format    = "raw"
    loader_readonly  = "yes"
    loader_secure    = "yes"
    loader_stateless = null
    loader_type      = "pflash"
    nv_ram = {
      format          = "raw"
      nv_ram          = "/var/lib/libvirt/qemu/nvram/mentat_VARS.fd"
      source          = null
      template        = "/usr/share/OVMF/OVMF_VARS_4M.ms.fd"
      template_format = "raw"
    }
    shim         = null
    sm_bios      = null
    type         = "hvm"
    type_arch    = "x86_64"
    type_machine = "pc-q35-10.0"
    var_store    = null
  }
  perf = null
  pm = {
    suspend_to_disk = {
      enabled = "no"
    }
    suspend_to_mem = {
      enabled = "no"
    }
  }
  qemu_capabilities = null
  qemu_commandline  = null
  qemu_deprecation  = null
  qemu_override     = null
  resource = {
    fibre_channel = null
    partition     = "/machine"
  }
  running = true
  sec_label = [
    {
      base_label  = null
      image_label = "libvirt-26b20a4b-f903-4987-a06e-f63e4a94ae7b"
      label       = "libvirt-26b20a4b-f903-4987-a06e-f63e4a94ae7b"
      model       = "apparmor"
      relabel     = "yes"
      type        = "dynamic"
    },
    {
      base_label  = null
      image_label = "+64055:+64055"
      label       = "+64055:+64055"
      model       = "dac"
      relabel     = "yes"
      type        = "dynamic"
    },
  ]
  sys_info                = null
  throttle_groups         = null
  title                   = null
  type                    = "kvm"
  update                  = null
  vcpu                    = 2
  vcpu_cpuset             = null
  vcpu_current            = null
  vcpu_placement          = "static"
  vcpus                   = null
  vmware_data_center_path = null
  xen_commandline         = null
}
