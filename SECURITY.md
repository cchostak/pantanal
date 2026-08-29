# Security policy

## Supported versions

Pantanal is currently pre-1.0. Security fixes are applied to the latest commit
on `main`. Earlier commits and downstream forks are not maintained by this
project.

| Version | Supported |
| --- | --- |
| Latest `main` | Yes |
| Older commits | No |

## Reporting a vulnerability

Do not open a public issue for a suspected vulnerability. Submit a private
report through [GitHub Security Advisories][report]. Include the affected
revision, impact, reproduction steps, and any suggested mitigation. Remove
credentials, personal data, and production data from evidence.

The maintainer will acknowledge a complete report within three business days,
provide an initial assessment within seven business days, and coordinate a
fix and disclosure timeline based on severity. Good-faith research that avoids
privacy violations, service disruption, and data destruction is welcome.

## Scope

The Go service, build pipeline, Kubernetes manifests, bootstrap automation,
and dependency chain are in scope. Vulnerabilities in upstream projects should
also be reported to their maintainers. Local endpoints use plain HTTP by
design and must not be exposed outside the disposable development host.

[report]: https://github.com/cchostak/pantanal/security/advisories/new
