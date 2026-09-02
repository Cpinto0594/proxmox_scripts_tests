locals {
  proxmox_endpoint  = get_env("PROXMOX_VE_ENDPOINT", "")
  proxmox_api_token = get_env("PROXMOX_VE_API_TOKEN", "")
  proxmox_insecure  = tobool(get_env("PROXMOX_VE_INSECURE", "false"))
}

# Local backend, but pointed at the real unit directory (not the .terragrunt-cache
# copy) so state survives cache clears. Swap this block for an `s3`/`azurerm`/etc.
# backend later if you need remote state / locking.
remote_state {
  backend = "local"

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }

  config = {
    path = "${get_terragrunt_dir()}/terraform.tfstate"
  }
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite"
  contents  = <<EOF
terraform {
  required_version = ">= 1.6"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.66"
    }
  }
}

provider "proxmox" {
  endpoint  = "${local.proxmox_endpoint}"
  api_token = "${local.proxmox_api_token}"
  insecure  = ${local.proxmox_insecure}

  ssh {
    agent    = true
    username = "root"
  }
}
EOF
}
