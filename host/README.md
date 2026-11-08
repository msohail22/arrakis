# Host configuration for arrakis

Files that belong on arrakis itself, outside Kubernetes and outside libvirt.

**These are the source of truth.** Change the file here first, then copy it to
the machine. A change made only on the machine will be lost and will not be
reviewable.

| File | Goes to | Purpose |
|---|---|---|
| `zram-generator.conf` | `/etc/systemd/zram-generator.conf` | Compressed swap in RAM |
| `10-server-no-sleep.conf` | `/etc/systemd/logind.conf.d/` | Ignore the laptop lid |

## Applying zram-generator.conf

```bash
scp host/zram-generator.conf arrakis:/tmp/
ssh -t arrakis 'sudo install -m644 /tmp/zram-generator.conf /etc/systemd/zram-generator.conf'
ssh -t arrakis 'sudo apt install -y systemd-zram-generator'
ssh -t arrakis 'sudo systemctl daemon-reload && sudo systemctl start systemd-zram-setup@zram0.service'
```

Verify:

```bash
ssh arrakis 'zramctl; swapon --show; free -m'
```

**`swapon --show` must show zram0 with a HIGHER priority than the disk swap**, or
the kernel will keep preferring the SSD. The disk partition sits at priority -2.

## Why these are not in Ansible yet

`ansible/` is empty. Two files copied by hand is not yet worth a playbook, but
the moment there is a third, it is. Tracked as a future task rather than
pretended away.
