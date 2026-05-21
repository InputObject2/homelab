# secrets-templates

Dummy env files containing the correct variable names but **no values** for every
service across all three always-on servers.

## Why these exist

`srv-26` runs the Portainer server and is the managing node for the whole cluster.
When a stack is added or updated in the Portainer web UI, Portainer validates the
`docker-compose.yml` **locally on srv-26** — including checking that every file
referenced in `env_file:` entries actually exists on disk.

This applies to stacks that run on `srv-27` and `srv-28` too: Portainer manages
them from `srv-26`, so it looks for their env files on `srv-26`'s filesystem even
though those services never run there.  Without the files present, Portainer
refuses to deploy the stack.

These dummy files satisfy that check.  They have the right keys so the structure
is clear, but no values — the real secrets live in Vault and are written to
`/opt/secrets/` at runtime by vault-agent on the host that actually runs the
service.

The Ansible seeding task uses `force: no`, so it will never overwrite a file that
vault-agent has already populated with real values.

## Adding a new service

1. Create `secrets-templates/<service>/<service>.env` with the expected variable
   names and empty values (e.g. `MY_VAR=`).
2. Add the service name to `all_stacks` in
   `ansible/inventory/group_vars/all.yml`.
3. Add the service to the relevant host's `host_stacks` in
   `ansible/inventory/host_vars/<host>.yml`.
4. Create the corresponding vault-agent template in
   `vault-agent/templates/<host>/<service>.tpl`.
