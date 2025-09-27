# My project template for rust

A minimal, production-focused Rust project template with batteries-included CI, security scanning, testing, benchmarking and examples. Use this repository as a starting point for CLI tools and small services.

## Highlights
- CI: GitHub Actions with fmt, clippy, tests, coverage, cross-platform builds, MSRV and release analysis
- Security: cargo-audit and cargo-deny configured
- Quality: cargo-fmt, clippy (deny warnings), doctests and integration tests
- Performance: Criterion benchmarks and release/dist build profiles
- Developer tools: helper scripts for dev and release, Dependabot config for automated dependency updates

## Quick start
1. Clone:
   git clone git@github.com:<your-user>/<repo>.git
2. Open:
   cd <repo>
3. Run development checks:
   ./scripts/dev.sh
4. Build:
   cargo build
5. Run tests:
   cargo test
6. Run benchmarks:
   cargo bench

Replace placeholders (project name, repository URL, author) in Cargo.toml and README.md.

## CI & Security
- CI workflow: .github/workflows/ci.yml — runs formatting, linting, tests (stable/beta/nightly), coverage, MSRV verification and release-size analysis.
- Security: deny.toml and cargo-audit/cargo-deny are used to block vulnerable or disallowed packages.
- Dependabot: .github/dependabot.yml configured to keep dependencies up to date.

## Recommended developer commands
- Format: cargo fmt --all
- Lint: cargo clippy --workspace --all-targets --all-features
- Tests: cargo test --workspace --all-features
- Coverage: cargo tarpaulin --out html
- Audit: cargo audit && cargo deny check

## Contributing
- Fork → branch → implement → add tests → run ./scripts/dev.sh → open PR.
- Keep commits small and tests green.

## License
Dual licensed: MIT OR Apache-2.0. See LICENSE-MIT and LICENSE-APACHE.

For customization or to add release signing, reproducible builds, or advanced fuzzing, extend the CI workflows
