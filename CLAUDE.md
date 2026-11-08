# Working notes for Claude

## Documentation is part of every change

The owner needs everything done in this repo documented. A task is **not done**
until the docs are updated in the same commit (or the same push).

- **Docs site:** `dokploy/compose-files/projects/homelab/docs-zensical/docs/`
  (Zensical / MkDocs-style; nav lives in `../zensical.toml`).
- **Update the relevant page** (inventory, network, platforms, services,
  gotchas, open-items, issues). If no page fits, create one and **add it to the
  `nav` in `zensical.toml`**.
- **Append an entry to `docs/worklog.md`** for every working session:
  date, what was done, why, files touched, follow-ups. Newest entry on top.
- Record hard-won lessons in `gotchas.md`; unresolved problems / planned work
  in `open-items.md` (and remove them there once fixed).
- Write commands so they can be copied and re-run (fenced `bash` blocks).
- Use Mermaid for diagrams.
- Mark unknown or unverified facts with `TODO:`.

## Rules

- **No secrets** in the repo. Reference the Infisical path instead
  (e.g. `infisical:/homelab/forgejo/db-password`). Use `.env.sample` files.
- Develop on the assigned branch; commit with descriptive messages.

## Repo map

- `root.hcl`, `README.md` — Terragrunt/Terraform for Proxmox (bpg/proxmox).
- `docs/` — loose notes and config files (Proxmox install, Postgres, Caddy, etc.).
- `dokploy/compose-files/projects/homelab/<service>/` — compose files per service.
- `dokploy/compose-files/projects/homelab/docs-zensical/` — the documentation site.
