# Creating a Proxmox user for Terraform

This sets up a dedicated Proxmox VE user + API token with the privileges
needed by the [bpg/proxmox](https://registry.terraform.io/providers/bpg/proxmox/latest/docs)
provider used in this repo (see `root.hcl`), instead of using `root@pam`.

Run all commands below **on the Proxmox host** (SSH in as root, or use the
Proxmox web UI Shell / a PVE cluster node).

## 1. Create the user

```bash
pveum user add terraform@pve
```

`terraform@pve` uses the built-in `pve` realm (no password needed since
auth will happen via API token, not password login).

## 2. Create a custom role with the required privileges

The provider needs more than the built-in `PVEVMAdmin` role — it also
touches datastores, pools, SDN, and (for some resources) user/permission
management. This is the role recommended by the provider's own docs:

```bash
pveum role add Terraform -privs "VM.Allocate VM.Audit VM.Clone VM.Config.CDROM \
VM.Config.Cloudinit VM.Config.CPU VM.Config.Disk VM.Config.HWType \
VM.Config.Memory VM.Config.Network VM.Config.Options VM.Console VM.Migrate \
VM.PowerMgmt VM.Snapshot VM.Snapshot.Rollback VM.Backup VM.Replicate \
VM.GuestAgent.Audit VM.GuestAgent.FileRead VM.GuestAgent.FileSystemMgmt \
VM.GuestAgent.FileWrite VM.GuestAgent.Unrestricted \
Datastore.Allocate Datastore.AllocateSpace Datastore.AllocateTemplate Datastore.Audit \
Pool.Allocate Pool.Audit Group.Allocate User.Modify Realm.Allocate Realm.AllocateUser \
Permissions.Modify SDN.Allocate SDN.Audit SDN.Use Mapping.Audit Mapping.Modify Mapping.Use \
Sys.Audit Sys.Console Sys.Incoming Sys.Modify Sys.PowerMgmt Sys.Syslog Sys.AccessNetwork"
```

> This is intentionally broad (it's the provider maintainers' own
> recommendation). If you only manage VMs/LXCs on specific
> nodes/pools/datastores, you can trim this down later — see
> [Least-privilege alternative](#least-privilege-alternative) below.

## 3. Assign the role

Grant the role on `/` (whole cluster) so Terraform can manage resources on
any node/pool/datastore:

```bash
pveum aclmod / -user terraform@pve -role Terraform
```

To scope it instead of granting cluster-wide, replace `/` with a narrower
path, e.g. a specific pool:

```bash
pveum aclmod /pool/terraform-pool -user terraform@pve -role Terraform
```

## 4. Create an API token

```bash
pveum user token add terraform@pve provider --privsep=0
```

- `provider` is the token ID (you can name it anything).
- `--privsep=0` means the token inherits the user's full permissions
  (no separate ACLs needed for the token itself). This matches the
  "separate token privilege... unchecked" note in this repo's README.
- **Copy the printed `value` immediately — it is only shown once.**

The output looks like:

```
┌──────────────┬──────────────────────────────────────┐
│ key          │ value                                  │
├──────────────┼──────────────────────────────────────┤
│ full-tokenid │ terraform@pve!provider                 │
│ info         │ {"privsep":"0"}                        │
│ value        │ xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx   │
└──────────────┴──────────────────────────────────────┘
```

## 5. Export credentials for Terragrunt/Terraform

Combine `full-tokenid` and `value` into `PROXMOX_VE_API_TOKEN` (this repo's
`root.hcl` reads these env vars, see README):

```bash
export PROXMOX_VE_ENDPOINT="https://<proxmox-host>:8006/"
export PROXMOX_VE_API_TOKEN="terraform@pve!provider=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
export PROXMOX_VE_INSECURE="true"   # only if using a self-signed cert
```

## 6. SSH access (only if you need it)

The provider block in `root.hcl` also configures an `ssh` transport, used
for operations the API doesn't cover (e.g. uploading files, some
import/clone flows). It currently authenticates as `root` over the SSH
agent:

```hcl
ssh {
  agent    = true
  username = "root"
}
```

The API token above does **not** cover this — SSH auth is separate. Options:

- **Keep using root** (simplest): make sure your SSH agent has a key
  authorized on the Proxmox host(s) for `root`.
- **Use a non-root SSH user**: create a normal Linux user on each Proxmox
  node, authorize your key, and grant it passwordless `sudo` for the
  commands the provider shells out to (mainly `pvesm`/`qm`/`pct` file
  operations). Then set `username = "<that user>"` in `root.hcl`'s
  provider block. This is more setup and not covered by the `pveum`
  commands above (those only control the API side).

## Verify

```bash
pveum user list
pveum acl list
pveum user token list terraform@pve
```

Then from a unit directory:

```bash
cd live/lxc-example
terragrunt init
terragrunt plan
```

## Least-privilege alternative

If step 2's role is more than you want, a narrower role for
**VM/LXC lifecycle management only** (no user/pool/SDN administration) is:

```bash
pveum role add TerraformVM -privs "VM.Allocate VM.Audit VM.Clone VM.Config.CDROM \
VM.Config.Cloudinit VM.Config.CPU VM.Config.Disk VM.Config.HWType VM.Config.Memory \
VM.Config.Network VM.Config.Options VM.Console VM.Migrate VM.PowerMgmt VM.Snapshot \
VM.Snapshot.Rollback Datastore.AllocateSpace Datastore.Audit Sys.Audit Sys.Console \
Sys.Modify SDN.Use"
```

Test with your actual modules (`modules/vm`, `modules/lxc`) before relying on
this in place of the full recommended role — some provider features (cloning
templates, cloud-init, snapshots) may need privileges trimmed here.

## Cleanup / rotation

```bash
# Revoke and remove a token
pveum user token remove terraform@pve provider

# Remove the user entirely
pveum acl delete / -user terraform@pve -role Terraform
pveum user delete terraform@pve
```
