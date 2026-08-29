# Architecture contract

Pantanal separates source, build, artifact, deployment, and runtime authority.
The only build output allowed to cross into deployment is an immutable OCI
digest recorded in `sample-app/deploy/base/kustomization.yaml`.

```text
developer -> Gitea -> CEL-validated Tekton trigger
                         |
                         +-> Nix build -> Harbor digest -> Trivy gate
                                                        -> Cosign sign/verify
                         |
                         +-> Git digest commit
                                   |
                                   v
                              scoped Argo CD project
                                   |
                                   v
                         Argo Rollouts -> Kyverno/PSA -> Kubernetes
                                      -> Prometheus analysis gate
```

## Trust boundaries

| Boundary | Allowed authority | Explicitly absent |
| --- | --- | --- |
| Gitea webhook | Trigger a validated PipelineRun for one repository | Kubernetes deployment access |
| Tekton build | Read/write source repository; push/scan/sign one Harbor project | Application deployment access |
| Argo CD | Read one repository; reconcile one namespace | Registry push and signing key |
| Sample service | Receive HTTP and expose metrics | Kubernetes API token and writable root filesystem |

The Gitea and Harbor administrator credentials exist only for local bootstrap.
Tekton uses a repository-scoped non-admin identity and a Harbor robot account;
Argo CD uses a read-only repository identity.

## Guardrails

- CEL accepts only `platform/sample-app`, `main`, hexadecimal commit SHAs, and
  excludes digest-promotion commits.
- RBAC restricts the trigger controller to creating PipelineRuns and
  impersonating only `build-bot`.
- Trivy blocks high and critical image findings before signing.
- Cosign verification must succeed before the digest is committed.
- Pod Security and Kyverno reject privileged or mutable-tag sample workloads.
- NetworkPolicy limits control-plane listener and workload ingress.

## Production adoption

The local stack deliberately uses HTTP, an insecure registry mirror, ephemeral
storage, single replicas, and generated local identities. Production adoption
must replace these with managed TLS and DNS, external identity, persistent and
encrypted data stores, backups, high availability, external secret management,
auditing, and disaster-recovery procedures.
