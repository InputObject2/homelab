# Template: Add an ArgoCD Application

When asked to create a new app, follow this structure:

1. Create a new file under `kubernetes/argocd-apps/<name>.yaml`
2. The Application must reference:
   - The appropriate chart or umbrella chart
   - The override file at `kubernetes/overrides/<name>/values.yaml`
3. Example structure:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: archiveteam-warrior
  namespace: argocd-system
spec:
  project: default
  sources:
    - repoURL: "https://github.com/inputobject2/homelab.git"
      targetRevision: main
      path: kubernetes/umbrella-charts/archiveteam-warrior
  destination:
    server: https://kubernetes.default.svc
    namespace: archiveteam
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

Copilot should:

-Ensure directories exist.
-Generate a correct relative path for valueFiles.
- Avoid embedding secrets.