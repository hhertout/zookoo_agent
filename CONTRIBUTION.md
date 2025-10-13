# Contribution Guide

Thanks for contributing to Zookoo! This document explains how to contribute, our Git workflow, protected branch rules, and the checklist to follow so a Pull Request can be accepted.

## Branch rules

- `main` is the production branch and is protected.
- `staging` is protected as well (pre-production).
- All Pull Requests must TARGET the `dev` branch (integration branch).

Do not push directly to `main` or `staging`. Create a branch from `dev` and open a PR targeting `dev`.

Recommended branch names

- feature: `feat/<short-description>`
- fix: `fix/<short-description>`
- chore: `chore/<description>`
- docs: `docs/<description>`

Examples:

```
feat/http-retry
fix/metrics-histogram-names
chore/update-deps
```

## Git workflow (quick)

1. Update your local `dev` branch:

```bash
git fetch origin
git checkout dev
git pull origin dev
```

2. Create your feature branch from `dev`:

```bash
git checkout -b feat/my-feature
```

3. Commit with clear messages (see convention below).

4. Push the branch and open a Pull Request targeting `dev`.

5. Fill the PR checklist (see section below).

6. After approval and passing checks, a maintainer will merge into `dev`. Merges to `staging`/`main` are handled by maintainers via releases.

## Commit message convention

Use a simple and explicit format, e.g.:

- `feat(<scope>): short description` — new feature
- `fix(<scope>): short description` — bug fix
- `chore: ...` — maintenance

Example: `feat(metrics): add http tls handshake histogram`

## Pull Request checklist (to be completed by the author)

- [ ] PR targets the `dev` branch.
- [ ] Unit tests pass locally (`cargo test`).
- [ ] Code builds (`cargo build`).
- [ ] `cargo fmt` has been run and `cargo clippy` reports no blocking issues.
- [ ] Any new dependencies are documented and justified.
- [ ] Non-functional changes (docs, formatting) are separated when possible.
- [ ] README / docs updated if needed.

## Local development commands

- Build: `cargo build`
- Tests: `cargo test`
- Format: `cargo fmt --all`
- Lint: `cargo clippy --all -- -D warnings`

## Docker / images

We publish multi-architecture images (amd64 + arm64). In CI, images are built with Buildx and pushed to Docker Hub.

To build and test locally (on Apple Silicon for example):

```bash
# Create builder if needed
docker buildx create --use --name mybuilder || true

# Build for arm64 and load into the local daemon
docker buildx build --platform linux/arm64 -f ./.docker/deb.dockerfile -t yourname/zookoo:local-arm64 --load .

# To push multi-arch manifests in CI, use buildx with --push
```

If you want an Alpine image compatible with musl, prefer cross-compiling statically for `x86_64-unknown-linux-musl` or `aarch64-unknown-linux-musl`.

## CI and PR checks

PRs must pass the following checks before merge:

- Build
- Unit tests
- Lint (clippy)
- Docker build in CI

## Tests and instrumentation

- Ensure new metrics use non-conflicting names (avoid exposing the same metric name as both a gauge and an histogram without clear suffixes).
- If you modify Prometheus-exposed metrics, update documentation in `documentation/`.

## Code review

Be receptive to feedback. Maintainers focus on:

- Code clarity and architecture
- Tests and edge cases
- Security and error handling

## Thank you

Thanks for contributing! If you'd like to improve this guide, open a PR targeting `dev`.
