# OpenTofu on arrakis

Decision **D10**: build `windtrap` with OpenTofu. See learning.md Q16.

## What this manages, and what it does not

**Managed here:** the `windtrap` VM, its disk, and its cloud-init disk.

**NOT managed here**, because they were created by hand and work:

- the storage pool `arrakis-images`
- the network `arrakis-nat`
- the VM `mentat`
- the base image download

**Decision D11: a resource is managed by OpenTofu or by hand, never both.**
OpenTofu keeps a state file of what it believes exists. Change a managed VM with
`virsh` and the next `apply` behaves confusingly. `mentat` stays by hand; if it
is ever converted, it must be imported, not re-created.

## Files

```
versions.tf    provider pinned to exactly 0.9.9 (pre-1.0, so it can break)
variables.tf   inputs, with defaults for this machine
windtrap.tf    the VM itself
```

## Running it

From your PC. It reaches arrakis over SSH using your ssh-agent key.

```bash
cd tofu

# 1. download the provider. Writes .terraform/ and a lock file.
tofu init

# 2. pass your keys in. Never hardcode a key in a .tf file.
cat > terraform.tfvars <<EOF
ssh_public_keys = [
  "$(cat ~/.ssh/id_ed25519.pub)",
]
EOF

# 3. see what it WOULD do. Changes nothing.
tofu plan

# 4. do it.
tofu apply
```

`tofu plan` is the step that has no equivalent in the by-hand path. It is the
main thing OpenTofu buys you: a dry run before anything changes.

## Verify afterwards

```bash
ssh arrakis 'virsh --connect qemu:///system list --all'
ssh -J arrakis muaddib@10.10.10.12 'hostname; free -m | head -2'
```

## Undoing it

```bash
tofu destroy
```

This removes the VM **and its disk**. There is no confirmation beyond the
prompt, and no backup. Never run it once `windtrap` holds a real database.

## The UEFI trap

`firmware` and `nvram` are set explicitly in `windtrap.tf`. Without them the
provider defaults to BIOS, and Debian's cloud image boot-loops in silence —
`virsh list` says `running` while nothing works. That cost four attempts on
`mentat`. See learning.md Q14.
