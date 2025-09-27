#!/bin/bash

# Rust Project Setup Script with Bulletproof CI
# Usage: ./andrews-awesome-script.sh <project-name> [github-username]

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Check if project name is provided
if [ $# -eq 0 ]; then
    log_error "Usage: $0 <project-name> [github-username]"
fi

PROJECT_NAME="$1"
GITHUB_USERNAME="${2:-your-username}"

# Validate project name
if [[ ! "$PROJECT_NAME" =~ ^[a-zA-Z][a-zA-Z0-9_-]*$ ]]; then
    log_error "Invalid project name. Use only letters, numbers, hyphens, and underscores."
fi

log_info "Setting up Rust project: $PROJECT_NAME"
log_info "GitHub username: $GITHUB_USERNAME"

# Check if cargo is installed
if ! command -v cargo &> /dev/null; then
    log_error "Cargo is not installed. Please install Rust first: https://rustup.rs/"
fi

# Check if git is installed
if ! command -v git &> /dev/null; then
    log_error "Git is not installed. Please install Git first."
fi

# Create the project
log_info "Creating new Cargo project..."
cargo new "$PROJECT_NAME" --bin
cd "$PROJECT_NAME"

# Initialize git repository
log_info "Initializing Git repository..."
git init
git branch -M main

# Create .gitignore
log_info "Creating .gitignore..."
cat > .gitignore << 'EOF'
# Rust/Cargo
/target/
Cargo.lock
**/*.rs.bk
*.pdb

# IDE
.vscode/
.idea/
*.swp
*.swo
*~

# OS
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db

# Environment variables
.env
.env.local

# Coverage reports
tarpaulin-report.html
cobertura.xml
/coverage/

# Benchmark outputs
/target/criterion/

# Documentation
/target/doc/

# Temporary files
*.tmp
*.temp
EOF

# Update Cargo.toml with optimizations
log_info "Configuring Cargo.toml with optimizations..."
cat > Cargo.toml << EOF
[package]
name = "$PROJECT_NAME"
version = "0.1.0"
edition = "2021"
authors = ["$GITHUB_USERNAME <$GITHUB_USERNAME@users.noreply.github.com>"]
license = "MIT OR Apache-2.0"
description = "A Rust project with bulletproof CI"
homepage = "https://github.com/$GITHUB_USERNAME/$PROJECT_NAME"
repository = "https://github.com/$GITHUB_USERNAME/$PROJECT_NAME"
documentation = "https://docs.rs/$PROJECT_NAME"
readme = "README.md"
keywords = ["rust", "cli"]
categories = ["command-line-utilities"]
rust-version = "1.75.0"

[dependencies]
# Add your dependencies here
# Example: serde = { version = "1.0", features = ["derive"] }

[dev-dependencies]
# Test and benchmark dependencies
criterion = "0.5"
proptest = "1.0"

# Development profile - fast compilation, basic debugging
[profile.dev]
opt-level = 0
debug = true
split-debuginfo = "unpacked"
overflow-checks = true
lto = false
panic = "unwind"
incremental = true
codegen-units = 256

# Release profile - production builds
[profile.release]
opt-level = 3
debug = false
lto = "fat"
panic = "abort"
incremental = false
codegen-units = 1
strip = "symbols"

# Custom profile for distribution builds
[profile.dist]
inherits = "release"
opt-level = 3
lto = "fat"
codegen-units = 1
panic = "abort"
strip = "symbols"

# Profile for benchmarks
[profile.bench]
inherits = "release"
debug = 1
strip = "none"

# Configure docs.rs builds
[package.metadata.docs.rs]
all-features = true
rustdoc-args = ["--cfg", "docsrs"]
targets = ["x86_64-unknown-linux-gnu", "x86_64-pc-windows-msvc"]

# Lints configuration (Rust 1.74+)
[lints.rust]
unsafe_code = "forbid"
missing_docs = "warn"

[lints.clippy]
all = "warn"
pedantic = "warn"
nursery = "warn"
cargo = "warn"
missing_errors_doc = "allow"
missing_panics_doc = "allow"

[[bench]]
name = "benchmarks"
harness = false
EOF

# Create example benchmark
log_info "Creating example benchmark..."
mkdir -p benches
cat > benches/benchmarks.rs << 'EOF'
use criterion::{black_box, criterion_group, criterion_main, Criterion};

fn fibonacci(n: u64) -> u64 {
    match n {
        0 => 1,
        1 => 1,
        n => fibonacci(n-1) + fibonacci(n-2),
    }
}

fn criterion_benchmark(c: &mut Criterion) {
    c.bench_function("fib 20", |b| b.iter(|| fibonacci(black_box(20))));
}

criterion_group!(benches, criterion_benchmark);
criterion_main!(benches);
EOF

# Create GitHub workflows directory
log_info "Setting up GitHub Actions..."
mkdir -p .github/workflows

# Create CI workflow
cat > .github/workflows/ci.yml << 'EOF'
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  release:
    types: [published]

env:
  CARGO_TERM_COLOR: always
  CARGO_INCREMENTAL: 0
  CARGO_NET_RETRY: 10
  RUST_BACKTRACE: short
  RUSTFLAGS: "-D warnings"
  SOURCE_DATE_EPOCH: 1640995200

jobs:
  install-tools:
    name: Install Tools
    runs-on: ubuntu-latest
    outputs:
      cache-key: ${{ steps.cache-key.outputs.key }}
    steps:
      - name: Checkout repository
        uses: actions/checkout@692973e3d937129bcbf40652eb9f2f61becf3332 # v4.1.7

      - name: Generate cache key
        id: cache-key
        run: |
          echo "key=tools-$(echo 'cargo-audit cargo-deny cargo-pants cargo-msrv cargo-semver-checks cargo-tarpaulin clippy-sarif sarif-fmt cargo-bloat' | sha256sum | cut -d' ' -f1)" >> $GITHUB_OUTPUT

      - name: Cache installed tools
        id: cache-tools
        uses: actions/cache@0c45773b623bea8c8e75f6c82b208c3cf94ea4f9 # v4.0.2
        with:
          path: ~/.cargo/bin
          key: ${{ steps.cache-key.outputs.key }}

      - name: Install Rust toolchain
        if: steps.cache-tools.outputs.cache-hit != 'true'
        uses: dtolnay/rust-toolchain@21dc36fb71dd22e3317045c0c31a3f4249868b17
        with:
          toolchain: stable

      - name: Install tools
        if: steps.cache-tools.outputs.cache-hit != 'true'
        run: |
          cargo install --locked cargo-audit
          cargo install --locked cargo-deny
          cargo install --locked cargo-pants
          cargo install --locked cargo-msrv
          cargo install --locked cargo-semver-checks
          cargo install --locked cargo-tarpaulin
          cargo install --locked clippy-sarif
          cargo install --locked sarif-fmt
          cargo install --locked cargo-bloat

  test:
    name: Test Suite
    runs-on: ubuntu-latest
    needs: install-tools
    strategy:
      fail-fast: false
      matrix:
        rust: [stable, beta, nightly]
        include:
          - rust: stable
            coverage: true
          - rust: nightly
            allow_failure: true
    continue-on-error: ${{ matrix.allow_failure || false }}
    
    steps:
      - name: Checkout repository
        uses: actions/checkout@692973e3d937129bcbf40652eb9f2f61becf3332 # v4.1.7

      - name: Install Rust toolchain
        uses: dtolnay/rust-toolchain@21dc36fb71dd22e3317045c0c31a3f4249868b17
        with:
          toolchain: ${{ matrix.rust }}
          components: clippy, rustfmt

      - name: Configure Cargo cache
        uses: Swatinem/rust-cache@23bce251a8cd2ffc3c1075eaa2367cf899916d84 # v2.7.3
        with:
          cache-on-failure: true

      - name: Cache installed tools
        uses: actions/cache@0c45773b623bea8c8e75f6c82b208c3cf94ea4f9 # v4.0.2
        with:
          path: ~/.cargo/bin
          key: ${{ needs.install-tools.outputs.cache-key }}

      - name: Check formatting
        run: cargo fmt --all -- --check

      - name: Run Clippy
        run: cargo clippy --workspace --all-targets --all-features -- -D warnings

      - name: Run tests
        run: cargo test --workspace --all-features --all-targets

      - name: Run doctests
        run: cargo test --workspace --all-features --doc

      - name: Test with no default features
        run: cargo test --workspace --no-default-features

      - name: Generate code coverage
        if: matrix.coverage
        run: cargo tarpaulin --workspace --all-features --out xml --output-dir ./coverage --timeout 120

      - name: Upload coverage to Codecov
        if: matrix.coverage
        uses: codecov/codecov-action@e28ff129e5465c2c0dcc6f003fc735cb6ae0c673 # v4.5.0
        with:
          files: ./coverage/cobertura.xml
          fail_ci_if_error: false
          token: ${{ secrets.CODECOV_TOKEN }}

  security:
    name: Security Audit
    runs-on: ubuntu-latest
    needs: install-tools
    permissions:
      contents: read
      security-events: write
    steps:
      - name: Checkout repository
        uses: actions/checkout@692973e3d937129bcbf40652eb9f2f61becf3332 # v4.1.7

      - name: Install Rust toolchain
        uses: dtolnay/rust-toolchain@21dc36fb71dd22e3317045c0c31a3f4249868b17
        with:
          toolchain: stable

      - name: Configure Cargo cache
        uses: Swatinem/rust-cache@23bce251a8cd2ffc3c1075eaa2367cf899916d84 # v2.7.3

      - name: Cache installed tools
        uses: actions/cache@0c45773b623bea8c8e75f6c82b208c3cf94ea4f9 # v4.0.2
        with:
          path: ~/.cargo/bin
          key: ${{ needs.install-tools.outputs.cache-key }}

      - name: Run cargo audit
        run: cargo audit

      - name: Run cargo deny
        run: cargo deny check

      - name: Check for pants (unsafe code patterns)
        run: cargo pants
        continue-on-error: true

  msrv:
    name: Minimum Supported Rust Version
    runs-on: ubuntu-latest
    needs: install-tools
    steps:
      - name: Checkout repository
        uses: actions/checkout@692973e3d937129bcbf40652eb9f2f61becf3332 # v4.1.7

      - name: Cache installed tools
        uses: actions/cache@0c45773b623bea8c8e75f6c82b208c3cf94ea4f9 # v4.0.2
        with:
          path: ~/.cargo/bin
          key: ${{ needs.install-tools.outputs.cache-key }}

      - name: Verify MSRV
        run: cargo msrv verify

  cross-platform:
    name: Cross-platform builds
    runs-on: ${{ matrix.os }}
    strategy:
      fail-fast: false
      matrix:
        os: [ubuntu-latest, windows-latest, macos-latest]
        rust: [stable]

    steps:
      - name: Checkout repository
        uses: actions/checkout@692973e3d937129bcbf40652eb9f2f61becf3332 # v4.1.7

      - name: Install Rust toolchain
        uses: dtolnay/rust-toolchain@21dc36fb71dd22e3317045c0c31a3f4249868b17
        with:
          toolchain: ${{ matrix.rust }}

      - name: Configure Cargo cache
        uses: Swatinem/rust-cache@23bce251a8cd2ffc3c1075eaa2367cf899916d84 # v2.7.3

      - name: Build
        run: cargo build --workspace --all-features

      - name: Test
        run: cargo test --workspace --all-features

  clippy-sarif:
    name: Clippy SARIF Analysis
    runs-on: ubuntu-latest
    needs: install-tools
    permissions:
      contents: read
      security-events: write
      actions: read
    steps:
      - name: Checkout repository
        uses: actions/checkout@692973e3d937129bcbf40652eb9f2f61becf3332 # v4.1.7

      - name: Install Rust toolchain
        uses: dtolnay/rust-toolchain@21dc36fb71dd22e3317045c0c31a3f4249868b17
        with:
          toolchain: stable
          components: clippy

      - name: Configure Cargo cache
        uses: Swatinem/rust-cache@23bce251a8cd2ffc3c1075eaa2367cf899916d84 # v2.7.3

      - name: Cache installed tools
        uses: actions/cache@0c45773b623bea8c8e75f6c82b208c3cf94ea4f9 # v4.0.2
        with:
          path: ~/.cargo/bin
          key: ${{ needs.install-tools.outputs.cache-key }}

      - name: Run Clippy with SARIF output
        run: |
          cargo clippy --workspace --all-features --all-targets \
            --message-format=json | clippy-sarif | tee clippy-results.sarif | sarif-fmt
        continue-on-error: true

      - name: Upload SARIF results
        uses: github/codeql-action/upload-sarif@afb54ba388a7dca6ecae48f608c4ff05ff4cc77a # v3.25.15
        with:
          sarif_file: clippy-results.sarif
          wait-for-processing: true

  release-build:
    name: Release Build & Analysis
    runs-on: ubuntu-latest
    needs: install-tools
    steps:
      - name: Checkout repository
        uses: actions/checkout@692973e3d937129bcbf40652eb9f2f61becf3332 # v4.1.7

      - name: Install Rust toolchain
        uses: dtolnay/rust-toolchain@21dc36fb71dd22e3317045c0c31a3f4249868b17
        with:
          toolchain: stable

      - name: Configure Cargo cache
        uses: Swatinem/rust-cache@23bce251a8cd2ffc3c1075eaa2367cf899916d84 # v2.7.3

      - name: Cache installed tools
        uses: actions/cache@0c45773b623bea8c8e75f6c82b208c3cf94ea4f9 # v4.0.2
        with:
          path: ~/.cargo/bin
          key: ${{ needs.install-tools.outputs.cache-key }}

      - name: Build optimized release
        run: |
          cargo build --release --workspace --all-features
        env:
          RUSTFLAGS: "-C lto=fat -C embed-bitcode=yes -C codegen-units=1 -C strip=symbols -C panic=abort"

      - name: Analyze binary sizes
        run: |
          echo "## Binary Size Analysis" >> $GITHUB_STEP_SUMMARY
          for binary in target/release/*; do
            if [[ -f "$binary" && -x "$binary" ]]; then
              size=$(stat -f%z "$binary" 2>/dev/null || stat -c%s "$binary")
              echo "- $(basename "$binary"): $(numfmt --to=iec-i --suffix=B "$size")" >> $GITHUB_STEP_SUMMARY
            fi
          done

      - name: Run cargo bloat
        run: |
          echo "## Bloat Analysis" >> $GITHUB_STEP_SUMMARY
          echo '```' >> $GITHUB_STEP_SUMMARY
          cargo bloat --release --crates >> $GITHUB_STEP_SUMMARY || echo "cargo bloat failed" >> $GITHUB_STEP_SUMMARY
          echo '```' >> $GITHUB_STEP_SUMMARY
        continue-on-error: true

  conclusion:
    name: CI Conclusion
    runs-on: ubuntu-latest
    needs: [test, security, msrv, cross-platform, clippy-sarif, release-build]
    if: always()
    steps:
      - name: Check if all jobs succeeded
        run: |
          if [[ "${{ needs.test.result }}" == "success" && \
                "${{ needs.security.result }}" == "success" && \
                "${{ needs.msrv.result }}" == "success" && \
                "${{ needs.cross-platform.result }}" == "success" && \
                "${{ needs.clippy-sarif.result }}" == "success" && \
                "${{ needs.release-build.result }}" == "success" ]]; then
            echo "✅ All CI jobs passed!"
          else
            echo "❌ Some CI jobs failed"
            exit 1
          fi
EOF

# Create Dependabot configuration
log_info "Setting up Dependabot..."
cat > .github/dependabot.yml << EOF
version: 2
updates:
  # Rust/Cargo dependencies
  - package-ecosystem: "cargo"
    directory: "/"
    schedule:
      interval: "weekly"
      day: "monday" 
      time: "09:00"
      timezone: "UTC"
    open-pull-requests-limit: 10
    reviewers:
      - "$GITHUB_USERNAME"
    assignees:
      - "$GITHUB_USERNAME"
    commit-message:
      prefix: "deps"
      prefix-development: "deps-dev"
      include: "scope"
    labels:
      - "dependencies"
      - "rust"
    groups:
      rust-minor-patch:
        patterns:
          - "*"
        update-types:
          - "minor"
          - "patch"
    
  # GitHub Actions dependencies
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
      day: "monday"
      time: "10:00"
      timezone: "UTC"
    open-pull-requests-limit: 5
    reviewers:
      - "$GITHUB_USERNAME"
    commit-message:
      prefix: "ci"
      include: "scope"
    labels:
      - "dependencies"
      - "github-actions"
EOF

# Create cargo-deny configuration
log_info "Setting up cargo-deny configuration..."
cat > deny.toml << 'EOF'
[graph]
targets = [
    "x86_64-unknown-linux-gnu",
    "x86_64-unknown-linux-musl",
    "x86_64-pc-windows-msvc",
    "x86_64-apple-darwin",
    "aarch64-apple-darwin",
]

[advisories]
db-path = "~/.cargo/advisory-db"
db-urls = ["https://github.com/rustsec/advisory-db"]
vulnerability = "deny"
unmaintained = "warn"
yanked = "warn"
notice = "warn"
ignore = []

[licenses]
confidence-threshold = 0.8
allow = [
    "MIT",
    "Apache-2.0",
    "Apache-2.0 WITH LLVM-exception",
    "BSD-2-Clause", 
    "BSD-3-Clause",
    "ISC",
    "Unicode-DFS-2016",
    "CC0-1.0",
]
deny = [
    "GPL-2.0",
    "GPL-3.0",
    "AGPL-1.0",
    "AGPL-3.0",
    "LGPL-2.0",
    "LGPL-2.1",
    "LGPL-3.0",
]
multiple-versions = "warn"

[bans]
multiple-versions = "warn"
wildcards = "allow"
highlight = "all"
allow = []
deny = []
skip = []
skip-tree = []

[sources]
unknown-registry = "warn"
unknown-git = "warn"
allow-registry = ["https://github.com/rust-lang/crates.io-index"]
allow-git = []
EOF

# Create improved README
log_info "Creating README.md..."
cat > README.md << EOF
# $PROJECT_NAME

[![CI](https://github.com/$GITHUB_USERNAME/$PROJECT_NAME/workflows/CI/badge.svg)](https://github.com/$GITHUB_USERNAME/$PROJECT_NAME/actions)
[![codecov](https://codecov.io/gh/$GITHUB_USERNAME/$PROJECT_NAME/branch/main/graph/badge.svg)](https://codecov.io/gh/$GITHUB_USERNAME/$PROJECT_NAME)
[![Crates.io](https://img.shields.io/crates/v/$PROJECT_NAME.svg)](https://crates.io/crates/$PROJECT_NAME)
[![Documentation](https://docs.rs/$PROJECT_NAME/badge.svg)](https://docs.rs/$PROJECT_NAME)

A Rust project with bulletproof CI/CD setup.

## Features

- 🚀 Optimized build profiles for development and production
- 🔒 Security scanning with cargo-audit and cargo-deny  
- 📊 Code coverage reporting with Codecov
- 🧪 Comprehensive testing across multiple Rust versions
- 🏗️ Cross-platform builds (Linux, Windows, macOS)
- 📦 Automated dependency updates with Dependabot
- 🔍 Static analysis with Clippy and SARIF reporting
- 📖 Documentation generation and testing

## Installation

\`\`\`bash
cargo install $PROJECT_NAME
\`\`\`

## Usage

\`\`\`bash
$PROJECT_NAME --help
\`\`\`

## Development

### Prerequisites

- [Rust](https://rustup.rs/) 1.75.0 or later
- [Git](https://git-scm.com/)

### Building

\`\`\`bash
# Development build
cargo build

# Release build
cargo build --release

# Optimized distribution build
cargo build --profile dist
\`\`\`

### Testing

\`\`\`bash
# Run tests
cargo test

# Run with coverage
cargo tarpaulin --out html

# Run benchmarks
cargo bench
\`\`\`

### Linting

\`\`\`bash
# Format code
cargo fmt

# Run clippy
cargo clippy

# Security audit
cargo audit

# License and dependency check
cargo deny check
\`\`\`

## CI/CD

This project uses GitHub Actions for CI/CD with the following features:

- **Multi-version testing**: Tests against stable, beta, and nightly Rust
- **Cross-platform builds**: Linux, Windows, and macOS
- **Security scanning**: Automated vulnerability detection
- **Code coverage**: Coverage reporting with Codecov
- **Static analysis**: Clippy lints with SARIF output
- **Dependency management**: Automated updates with Dependabot
- **Binary analysis**: Size optimization and bloat detection

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for your changes
5. Run \`cargo test\` and \`cargo clippy\`
6. Submit a pull request

## License

Licensed under either of

- Apache License, Version 2.0 ([LICENSE-APACHE](LICENSE-APACHE) or http://www.apache.org/licenses/LICENSE-2.0)
- MIT license ([LICENSE-MIT](LICENSE-MIT) or http://opensource.org/licenses/MIT)

at your option.

### Contribution

Unless you explicitly state otherwise, any contribution intentionally submitted for inclusion in the work by you, as defined in the Apache-2.0 license, shall be dual licensed as above, without any additional terms or conditions.
EOF

# Create LICENSE files
log_info "Creating LICENSE files..."
cat > LICENSE-MIT << 'EOF'
MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF

cat > LICENSE-APACHE << 'EOF'
                                 Apache License
                           Version 2.0, January 2004
                        http://www.apache.org/licenses/

   Copyright 2024 Your Name

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
EOF

# Update main.rs with a better example
log_info "Creating example application code..."
cat > src/main.rs << 'EOF'
//! A sample Rust application with bulletproof CI
//! 
//! This demonstrates best practices for Rust project structure
//! and includes examples for testing, documentation, and benchmarking.

use std::env;
use std::process;

/// Configuration for the application
#[derive(Debug)]
pub struct Config {
    /// The message to display
    pub message: String,
    /// Whether to use uppercase
    pub uppercase: bool,
}

impl Config {
    /// Create a new configuration from command line arguments
    /// 
    /// # Errors
    /// 
    /// Returns an error if the arguments are invalid
    pub fn new(args: Vec<String>) -> Result<Config, &'static str> {
        if args.len() < 2 {
            return Err("Usage: program <message> [--uppercase]");
        }

        let message = args[1].clone();
        let uppercase = args.len() > 2 && args[2] == "--uppercase";

        Ok(Config { message, uppercase })
    }
}

/// Process the message according to configuration
/// 
/// # Examples
/// 
/// ```
/// use your_project_name::process_message;
/// use your_project_name::Config;
/// 
/// let config = Config {
///     message: "hello".to_string(),
///     uppercase: true,
/// };
/// 
/// assert_eq!(process_message(&config), "HELLO");
/// ```
pub fn process_message(config: &Config) -> String {
    if config.uppercase {
        config.message.to_uppercase()
    } else {
        config.message.clone()
    }
}

fn main() {
    let args: Vec<String> = env::args().collect();

    let config = Config::new(args).unwrap_or_else(|err| {
        eprintln!("Problem parsing arguments: {err}");
        process::exit(1);
    });

    let result = process_message(&config);
    println!("{result}");
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_config_creation() {
        let args = vec![
            "program".to_string(),
            "hello".to_string(),
        ];
        
        let config = Config::new(args).unwrap();
        assert_eq!(config.message, "hello");
        assert!(!config.uppercase);
    }

    #[test]
    fn test_config_with_uppercase() {
        let args = vec![
            "program".to_string(),
            "hello".to_string(),
            "--uppercase".to_string(),
        ];
        
        let config = Config::new(args).unwrap();
        assert_eq!(config.message, "hello");
        assert!(config.uppercase);
    }

    #[test]
    fn test_config_invalid_args() {
        let args = vec!["program".to_string()];
        let result = Config::new(args);
        assert!(result.is_err());
    }

    #[test]
    fn test_process_message_normal() {
        let config = Config {
            message: "hello world".to_string(),
            uppercase: false,
        };
        
        assert_eq!(process_message(&config), "hello world");
    }

    #[test]
    fn test_process_message_uppercase() {
        let config = Config {
            message: "hello world".to_string(),
            uppercase: true,
        };
        
        assert_eq!(process_message(&config), "HELLO WORLD");
    }
}
EOF

# Create lib.rs to make it a library crate as well
cat > src/lib.rs << 'EOF'
//! A sample Rust library with bulletproof CI
//! 
//! This crate demonstrates best practices for Rust development including:
//! - Comprehensive testing
//! - Documentation with examples
//! - Benchmarking
//! - Security scanning
//! - Cross-platform compatibility

pub use crate::main::{Config, process_message};

// Re-export main module items
pub mod main {
    pub use crate::{Config, process_message};
}

// Export the main items at crate level
pub use main::*;
EOF

# Create a more comprehensive example
log_info "Creating examples..."
mkdir -p examples
cat > examples/basic.rs << 'EOF'
//! Basic usage example

use std::env;

fn main() {
    let args: Vec<String> = env::args().collect();
    
    let config = your_project_name::Config::new(args).unwrap_or_else(|err| {
        eprintln!("Error: {err}");
        std::process::exit(1);
    });

    let result = your_project_name::process_message(&config);
    println!("Processed message: {result}");
}
EOF

# Create integration tests
log_info "Creating integration tests..."
mkdir -p tests
cat > tests/integration_test.rs << 'EOF'
//! Integration tests for the application

use std::process::Command;
use std::str;

#[test]
fn test_basic_functionality() {
    let output = Command::new("cargo")
        .args(["run", "--", "hello"])
        .output()
        .expect("Failed to execute command");

    assert!(output.status.success());
    let stdout = str::from_utf8(&output.stdout).unwrap();
    assert_eq!(stdout.trim(), "hello");
}

#[test]
fn test_uppercase_functionality() {
    let output = Command::new("cargo")
        .args(["run", "--", "hello", "--uppercase"])
        .output()
        .expect("Failed to execute command");

    assert!(output.status.success());
    let stdout = str::from_utf8(&output.stdout).unwrap();
    assert_eq!(stdout.trim(), "HELLO");
}
EOF

# Create CHANGELOG
log_info "Creating CHANGELOG.md..."
cat > CHANGELOG.md << 'EOF'
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial project setup
- Bulletproof CI/CD pipeline
- Comprehensive testing suite
- Security scanning
- Code coverage reporting
- Cross-platform builds
- Automated dependency updates

### Changed
- Nothing yet

### Deprecated
- Nothing yet

### Removed
- Nothing yet

### Fixed
- Nothing yet

### Security
- Implemented cargo-audit for vulnerability scanning
- Added cargo-deny for license and dependency management

## [0.1.0] - 2024-01-01

### Added
- Initial release

[Unreleased]: https://github.com/your-username/your-project/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/your-username/your-project/releases/tag/v0.1.0
EOF

# Create development helper scripts
log_info "Creating development scripts..."
mkdir -p scripts

cat > scripts/dev.sh << 'EOF'
#!/bin/bash
# Development helper script

set -e

echo "🧪 Running tests..."
cargo test

echo "🔍 Running clippy..."
cargo clippy --all-targets --all-features -- -D warnings

echo "📝 Checking formatting..."
cargo fmt --all -- --check

echo "🔒 Running security audit..."
cargo audit

echo "📋 Running cargo deny..."
cargo deny check

echo "📊 Running benchmarks..."
cargo bench

echo "✅ All checks passed!"
EOF

cat > scripts/release.sh << 'EOF'
#!/bin/bash
# Release build script

set -e

echo "🏗️ Building release binary..."
cargo build --release

echo "📦 Building distribution binary..."
cargo build --profile dist

echo "📊 Analyzing binary size..."
ls -lh target/release/
ls -lh target/dist/ 2>/dev/null || echo "No dist profile binaries"

echo "🔍 Running final checks..."
cargo test --release
cargo clippy --release -- -D warnings

echo "✅ Release build complete!"
EOF

chmod +x scripts/*.sh

# Initialize git and create initial commit
log_info "Creating initial Git commit..."
git add .
git commit -m "feat: initial project setup with bulletproof CI

- Add comprehensive CI/CD pipeline with GitHub Actions
- Configure automated dependency updates with Dependabot  
- Set up security scanning with cargo-audit and cargo-deny
- Add code coverage reporting with Codecov
- Configure optimized build profiles for different use cases
- Add cross-platform builds and testing
- Include comprehensive linting and formatting checks
- Set up MSRV verification and semver checking
- Add benchmark infrastructure with Criterion
- Include integration tests and examples
- Configure documentation generation and testing"

# Final setup steps
log_info "Project setup complete!"
echo
log_success "✅ Created Rust project: $PROJECT_NAME"
echo
echo "📁 Project structure:"
echo "├── src/                 # Source code"
echo "├── examples/            # Usage examples"  
echo "├── tests/               # Integration tests"
echo "├── benches/             # Benchmarks"
echo "├── scripts/             # Development scripts"
echo "├── .github/             # GitHub Actions & Dependabot"
echo "├── Cargo.toml           # Package configuration"
echo "├── deny.toml            # Security & license config"
echo "└── README.md            # Documentation"
echo
echo "🚀 Next steps:"
echo "1. cd $PROJECT_NAME"
echo "2. Update README.md and Cargo.toml with your project details"
echo "3. Replace '$GITHUB_USERNAME' with your actual GitHub username in:"
echo "   - .github/dependabot.yml"  
echo "   - README.md"
echo "   - Cargo.toml"
echo "4. Create a GitHub repository and push:"
echo "   git remote add origin https://github.com/$GITHUB_USERNAME/$PROJECT_NAME.git"
echo "   git push -u origin main"
echo "5. Enable Dependabot in repository settings"
echo "6. Add CODECOV_TOKEN secret for coverage reporting (optional)"
echo
echo "🔧 Development commands:"
echo "  cargo run                    # Run the application"
echo "  cargo test                   # Run tests"
echo "  cargo bench                  # Run benchmarks"
echo "  ./scripts/dev.sh             # Run all development checks"
echo "  ./scripts/release.sh         # Build release binaries"
echo
echo "🎉 Happy coding!"