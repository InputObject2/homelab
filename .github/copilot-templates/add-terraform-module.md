# Template: Create a new Terraform module

When requested, Copilot should:

1. Create a folder under `terraform/modules/<module-name>`
2. Generate:
   - `main.tf`
   - `variables.tf`
   - `outputs.tf` (if needed)
   - `providers.tf` (only when required)
3. Follow repository conventions:
   - Use logical separation of resources
   - Avoid locals unless necessary
   - Use explicit provider configuration when multiple providers might exist

Example skeleton:

```hcl
# main.tf
resource "<provider>_<resource>" "<name>" {
  # ...
}

# variables.tf
variable "<var>" {
  description = "..."
  type        = string
}

# outputs.tf
output "<out>" {
  description = "..."
  value       = <value>
}
```

Add an environment reference under:

```bash
terraform/environments/<env>/<module-name>.tf
```

When importing existing AWS resources:
- Generate import commands
- Avoid state drift