# fullcoverage — project notes for Claude

## Releasing

**Always tag releases with a `v` prefix** (e.g. `v0.4.0`, not `0.4.0`).

The GitHub Actions release workflow (`release.yml`) triggers on `v*` tags. A bare version tag silently skips CI — no binary is built, no Homebrew formula is updated, and the GitHub release is empty.

If a bare tag was pushed by mistake:
```bash
gh release delete <version> --yes
git tag -d <version>
git push origin :refs/tags/<version>
git tag -a v<version> -m "v<version>"
git push origin v<version>
```

## Distribution pipeline

The release CI (triggered by `v*` tags) does three things automatically:

1. Builds a universal binary (arm64 + x86_64 via `lipo`)
2. Uploads `fullcoverage-<version>-macos.tar.gz` to the GitHub release
3. Updates `Shadester/homebrew-tap` → `Formula/fullcoverage.rb` (requires `HOMEBREW_TAP_TOKEN` secret)

**Mint** builds from source via SPM directly off the git tag — no extra steps needed.

**Homebrew** depends on the pre-built binary from CI. The formula is updated automatically; do not edit it manually unless CI is broken.
