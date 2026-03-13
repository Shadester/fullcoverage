# fullcoverage

A Swift CLI tool that reads an Xcode `.xcresult` bundle and generates a multi-file static HTML coverage report — similar to [Slather](https://github.com/SlatherOrg/slather) or [Kover](https://kotlin.github.io/kover/), but with no extra toolchain required.

Coverage data is sourced entirely from `xcrun xccov`, which means it works with modern Xcode xcresult bundles out of the box. Branch coverage is derived from xccov's per-line `subranges`, which encode sub-expression hit counts.

![Index page](docs/screenshots/index.png)

![File coverage page](docs/screenshots/file.png)

## Features

- **Lines, branches, and functions** coverage per file and in aggregate
- Partial branch detection (yellow highlighting) from sub-expression subranges
- Parallel per-file xccov calls for fast report generation
- Single-file static HTML output — no server, no JavaScript framework
- Dark-mode stylesheet

## Requirements

- macOS 13+
- Xcode or the Xcode command-line tools

## Installation

### Homebrew (recommended)

```bash
brew tap Shadester/tap
brew install fullcoverage
```

### Mint

If you use [Mint](https://github.com/yonaskolb/Mint) for Swift CLI tools (builds from source, requires Xcode):

```bash
mint install Shadester/fullcoverage
```

### curl

```bash
curl -L https://github.com/Shadester/fullcoverage/releases/latest/download/fullcoverage-macos.tar.gz \
  | tar xz -C /usr/local/bin
```

### Build from source

Requires the Swift toolchain (included with Xcode):

```bash
git clone https://github.com/Shadester/fullcoverage
cd fullcoverage
swift build -c release
cp .build/release/fullcoverage /usr/local/bin/
```

## Usage

### 1. Run your tests with coverage enabled

```bash
xcodebuild test \
  -workspace MyApp.xcworkspace \
  -scheme MyApp \
  -destination "platform=iOS Simulator,name=iPhone 16" \
  -enableCodeCoverage YES \
  -resultBundlePath /tmp/MyApp.xcresult
```

Alternatively, enable coverage permanently in your scheme or test plan:

**Xcode UI:** Product → Scheme → Edit Scheme → Test → Options → Code Coverage → check *Gather coverage*

**`.xctestplan` file:**
```json
{
  "defaultOptions": {
    "codeCoverageEnabled": true
  }
}
```

### 2. Generate the report

```bash
fullcoverage /tmp/MyApp.xcresult -o ./coverage
open ./coverage/index.html
```

### Options

```
fullcoverage <xcresult> [-o DIR] [-j N] [--ignore PATTERN ...] [--config FILE]

arguments:
  xcresult          Path to the .xcresult bundle

options:
  -o, --output      Output directory (default: ./coverage)
  -j, --jobs        Parallel workers for xccov calls (default: 8)
  --ignore PATTERN  Glob pattern for files to exclude (repeatable)
  --config FILE     Path to config file (default: .fullcoverage.yml)
```

### Ignoring files

Use a `.fullcoverage.yml` config file committed to your repo to exclude files from the report:

```yaml
# .fullcoverage.yml
ignore:
  - "*Tests*"
  - "*.generated.swift"
  - "*/Pods/*"
```

The config file is looked up from the current working directory by default. You can point to a different file with `--config`.

CLI `--ignore` flags are merged with (and extend) the config file patterns:

```bash
# Via config file
fullcoverage App.xcresult -o coverage

# Via CLI flags (one-off, no config file needed)
fullcoverage App.xcresult -o coverage --ignore '*Tests*' --ignore '*/Pods/*'

# Custom config path
fullcoverage App.xcresult --config ci/coverage.yml
```

Patterns are matched against the full file path using glob syntax (`*` matches any sequence of characters, `?` matches a single character).

## How it works

```
xcresult
  │
  ├─ xcrun xccov view --report --json
  │    → file list, line/function summaries per target
  │
  └─ xcrun xccov view --archive --file <path> --json   (one call per file, parallelized)
       → per-line executionCount + subranges
```

**A note on branch coverage:** Xcode doesn't expose a direct "branch taken / not taken" count, so fullcoverage approximates it using *subranges* — the sub-expression hit counts that xccov embeds in each line. Think of a line like `a && b || c`: each operand that can be short-circuited is tracked separately. If any of those sub-expressions was never reached, the line is counted as a partially-covered branch.

This is a good approximation, but it isn't identical to a traditional branch coverage metric (like what you'd get from LLVM's instrumented profiling). It may over- or under-count in some cases — treat it as a useful signal rather than a precise measurement.

No instrumented binary or `.profdata` extraction is needed — everything is read directly from the xcresult bundle.

## Project layout

```
fullcoverage/
├── Package.swift
└── Sources/fullcoverage/
    ├── CLI.swift           # ArgumentParser entry point
    ├── Models.swift        # LineInfo, FileSummary, FileReport
    ├── Parser.swift        # xccov subprocess calls + JSON parsing
    ├── Config.swift        # .fullcoverage.yml loading
    ├── Ignore.swift        # glob-pattern matching for --ignore
    ├── Resources/
    │   └── style.css
    └── HTML/
        ├── Generator.swift     # orchestrates multi-file output
        ├── IndexPage.swift     # renders index.html
        └── FilePage.swift      # renders per-file source viewer
```
