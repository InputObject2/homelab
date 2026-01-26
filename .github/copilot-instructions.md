# Copilot Global Instructions for the Homelab Repository

**Repository Purpose:** Multi-cluster home infrastructure as code—Kubernetes via ArgoCD, infrastructure via Terraform, provisioning via cloud-init.

**Key Clusters:** `cluster-main-apps`, `cluster-observability-apps`, `cluster-omada-apps`, `cluster-cloud-apps` (each with separate ArgoCD apps).

---

## Directory Structure

```
kubernetes/
  cluster-*-apps/          ← ArgoCD Application manifests (one .yaml per app)
  umbrella-charts/         ← Custom Helm charts that wrap external charts + add templates
  overrides/               ← Values files for apps using external charts or argocd valueFiles reference
  bootstrap/               ← Initial cluster setup manifests
  
terraform/
  modules/                 ← Reusable infrastructure modules (headscale, microk8s, network, xen_vm)
  environments/<env>/      ← Environment-specific configs (home, vps, devlab, chalet)
  
scripts/
  common-utils/            ← Shared utilities
  installers/              ← Installation scripts
  
.github/copilot-templates/ ← Example patterns for adding apps and modules
```

---

## ArgoCD Application Patterns

**Pattern 1: External Chart + Inline Values**
```yaml
spec:
  sources:
    - repoURL: https://immich-app.github.io/immich-charts
      chart: immich
      targetRevision: 0.9.3
      helm:
        valueFiles:
          - $values/kubernetes/overrides/immich/values.yaml
    - repoURL: https://github.com/inputobject2/homelab.git
      targetRevision: main
      ref: values
```
Use when the external chart covers 90% of what you need; put only customizations in `kubernetes/overrides/<app>/values.yaml`.

**Pattern 2: Umbrella Chart (Custom + External Dependency)**
```yaml
spec:
  sources:
    - repoURL: https://github.com/inputobject2/homelab.git
      targetRevision: main
      path: kubernetes/umbrella-charts/certmanager
      helm:
        parameters:
          - name: extra.cloudflare.email
            value: maxime.lamarre@outlook.com
```
Use when you need to:
- Add ExternalSecrets for Vault integration
- Inject extra Kubernetes resources (CertificateIssuer, RBAC, etc.)
- Share common config across multiple apps

**Umbrella Chart Structure:**
- `Chart.yaml` declares dependency on external chart
- `values.yaml` passes through external chart values + defines extras (externalSecrets, rawResources, etc.)
- Files/templates/ can inject additional manifests

**Pattern 3: Helm Parameters in ArgoCD**
Use `parameters` when you need to override specific values without creating a values file (e.g., passing domain names from ArgoCD spec).

---

## Terraform Architecture

**Modules** (reusable, self-contained):
- `headscale/` — VPN server setup
- `microk8s/` — Kubernetes cluster provisioning on Xen Orchestra VMs
- `network/` — Network infrastructure
- `xen_vm/` — Single VM provisioning templates

**Environments**:
- Each folder under `terraform/environments/` represents a deployment target
- Standard layout: `variables.tf`, main resource files, `.tfvars` files
- Uses `terraform apply -var-file=*.tfvars` or environment variables for config

**Key Integration:**
- MicroK8s module calls `templatefile("${path.module}/cloud-config.tftpl")` to generate cloud-init
- Cloud-init handles VM setup (packages, kubelet config, networking)
- Output: kubeconfig exported for ArgoCD cluster registration

---

## Secrets & ExternalSecrets Pattern

**All credentials must use ExternalSecrets Operator** — never hardcode in values files.

**Standard Vault paths:**
```yaml
# In umbrella chart values.yaml or chart templates:
externalSecrets:
  - name: app-secret
    template:
      data:
        api-key: "{{ .apiKey }}"
    dataFrom:
      - key: secret/data/apps/myapp
        extract:
          key: vault-secret-name
        property:
          name: apiKey
```

Vault provider must be configured (typically via external-secrets-operator umbrella chart).

---

## Renovate Configuration

Renovate auto-updates:
- Helm chart versions in `kubernetes/umbrella-charts/*/Chart.yaml` (helmv3 manager)
- ArgoCD chart/image versions in `kubernetes/cluster-*-apps/*.yaml` (argocd manager)
- Kubernetes manifest image versions (kubernetes manager)

Keep `renovate.json` `managerFilePatterns` in sync with actual structure.

---

## Coding Conventions

| Language | Style | Notes |
|----------|-------|-------|
| YAML | 2 spaces, no tabs | Both k8s and Helm values |
| Terraform | 4 spaces, explicit providers | Group inputs logically; use `this` prefix for local resource names |
| Helm values | Mirror external chart structure | Only override what differs; don't duplicate defaults |

---

## Validation & Formatting Commands

Run these before committing changes:
```bash
# Terraform
terraform fmt -recursive terraform/

# YAML
yamllint kubernetes/cluster-*-apps/*.yaml
yamllint kubernetes/umbrella-charts/*/Chart.yaml
yamllint kubernetes/umbrella-charts/*/values.yaml
```

---

## Bootstrap Workflow (Cluster Setup)

When deploying a new cluster:
1. **Terraform Run:** `terraform apply -var-file=<env>.tfvars` in the environment folder
   - Generates secrets in Vault (e.g., ArgoCD bootstrap token)
2. **Create Bootstrap File:** Generate an ExternalSecret or Secret manifest that references Vault
   - Path typically: `kubernetes/bootstrap/<cluster-name>/secrets.yaml`
3. **Apply Bootstrap:** `kubectl apply -f kubernetes/bootstrap/<cluster-name>/` 
   - This pulls secrets from Vault and creates required cluster resources
4. **ArgoCD Sync:** Once bootstrap succeeds, ArgoCD Applications auto-sync all apps

---

## Common Tasks & Examples

**Add a New App:**
1. Choose pattern (1 = simple override, 2 = umbrella chart needed)
2. Create `kubernetes/cluster-*-apps/<name>.yaml` with Application spec
3. For Pattern 1: Create `kubernetes/overrides/<name>/values.yaml`
4. For Pattern 2: Create `kubernetes/umbrella-charts/<name>/` with Chart.yaml + values.yaml
5. Verify `syncPolicy.automated` is set to true
6. Test with `kubectl apply` in staging cluster first

**Create a Terraform Module:**
1. New folder under `terraform/modules/<name>/`
2. Include: `variables.tf`, `main.tf`, `outputs.tf`, `providers.tf`
3. Add `README.md` describing inputs/outputs
4. Reference in environment config: `module "thing" { source = "../modules/name" }`

**Add Environment-Specific Infrastructure:**
1. New subfolder under `terraform/environments/<env>/`
2. Create variables.tfvars with environment-specific values
3. Run: `terraform apply -var-file=<env>.tfvars`

---

## Do's and Don'ts

**Do:**
- Use `$values/` syntax in ArgoCD valueFiles to reference the values repo source
- Include `CreateNamespace=true` in syncOptions for new namespaces
- Group related Helm values under common sections (e.g., all ingress settings together)
- Use explicit Terraform provider blocks; avoid implicit defaults
- Keep umbrella chart values.yaml as a superset of external chart values
- Run `terraform fmt`, `terraform validate`, and `yamllint` before committing
- When using domain names, make sure to parameterize them via ArgoCD or values files and not include them directly in files that will be committed (read the .gitignore to be sure)

**Don't:**
- Embed secrets, passwords, tokens, or API keys in any file not covered by the .gitignore at the root of the repository
- Auto-create CRDs unless part of a Helm chart dependency
- Write files outside `kubernetes/`, `terraform/`, or `scripts/` without asking
- Restructure directories without explicit instruction
- Hardcode domain names, IP ranges, or environment-specific config in modules
- Use umbrella charts when the external chart alone suffices
- Manually manage Terraform state; only run `terraform import` if instructed

---

## Workflow Tips

**Before editing:**
- Check `renovate.json` `managerFilePatterns` if modifying directory paths
- Verify the cluster name in Application metadata and destination
- Confirm namespace exists or syncOptions includes `CreateNamespace=true`

**After editing:**
- Validate YAML syntax (ArgoCD will reject malformed specs)
- Check that all `$values/` references point to actual override files
- For Terraform: run `terraform init` and `terraform validate` in the environment folder

**Questions to ask:**
- Which cluster should this app deploy to? (main, observability, omada, cloud)
- Does this app need secrets (→ ExternalSecret required)?
- Is this app stateful? (→ needs persistent storage or database module)
- Should Renovate auto-update this? (→ verify managerFilePatterns)
