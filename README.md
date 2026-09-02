# proxmox-terragrunt

Terragrunt + Terraform project for managing Proxmox VE resources, using the
[bpg/proxmox](https://registry.terraform.io/providers/bpg/proxmox/latest/docs) provider.

## Layout

```
root.hcl               # root config: local backend + provider generation
modules/
  vm/                  # clones a VM from an existing template
  lxc/                 # creates an LXC container from a template
live/
  vm-example/          # example unit that instantiates modules/vm
  lxc-example/         # example unit that instantiates modules/lxc
```

Each directory under `live/` is a Terragrunt "unit" — a standalone set of
inputs for a module. Add more directories under `live/` (e.g. `live/web-01/`)
to create more resources; copy one of the examples as a starting point.

State is stored locally as `terraform.tfstate` next to each unit's
`terragrunt.hcl` (not in `.terragrunt-cache`, so it survives cache clears).
Swap the `remote_state` block in the root `terragrunt.hcl` for an `s3`/`azurerm`/etc.
backend if you want remote state and locking.

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/downloads) >= 1.6
- [Terragrunt](https://terragrunt.gruntwork.io/docs/getting-started/install/)
- A Proxmox VE API token (Datacenter → Permissions → API Tokens). Give the
  token's user the permissions it needs (e.g. `PVEVMAdmin` on the relevant
  pool/node), and if you use a **separate token privilege** make sure
  "Privilege Separation" is unchecked, or grant the token its own permissions.
- For `live/vm-example`: an existing cloud-init-enabled VM template to clone
  (its `vm_id` goes into `clone_vm_id`).
- For `live/lxc-example`: an LXC template downloaded on the target node
  (`pveam download local <template>`).

## Configuration

Credentials are read from environment variables (never commit them):

```bash
export PROXMOX_VE_ENDPOINT="https://proxmox.example.com:8006/"
export PROXMOX_VE_API_TOKEN="user@pve!tokenid=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
export PROXMOX_VE_INSECURE="true"   # only if using a self-signed cert
```

The provider block also enables the `ssh` transport (used for some
provider operations, e.g. importing/uploading files). It defaults to using
`root` over SSH agent auth — adjust the `generate "provider"` block in the
root `terragrunt.hcl` if your setup differs.

Before applying, edit the `inputs` in `live/vm-example/terragrunt.hcl` and
`live/lxc-example/terragrunt.hcl` (node name, template/clone ID, network,
SSH keys, etc.) to match your environment.

## Usage

```bash
# One unit at a time
cd live/vm-example
terragrunt init
terragrunt plan
terragrunt apply

# Or everything at once, from the repo root
terragrunt run-all init
terragrunt run-all plan
terragrunt run-all apply
```
