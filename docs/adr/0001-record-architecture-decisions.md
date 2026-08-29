# 0001: Record architecture decisions

- Status: Accepted
- Date: 2026-08-29
- Deciders: Pantanal maintainers

## Context

Platform decisions affect build reproducibility, trust boundaries, developer
workflows, and recovery. Without durable records, later changes can silently
invalidate the properties the platform is intended to demonstrate.

## Decision

Material architectural decisions are recorded as numbered Markdown files in
`docs/adr/`. Each record contains status, context, decision, consequences, and
references. Accepted records are immutable; a later ADR supersedes one whose
decision changes. Proposed records are reviewed with the implementation that
depends on them.

## Consequences

Reviewers can distinguish intentional constraints from accidental behavior.
Authors incur a small documentation cost when changing architecture.
