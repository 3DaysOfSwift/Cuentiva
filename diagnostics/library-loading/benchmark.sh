#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
binary_path="$(mktemp -d)/library-benchmark"
trap 'rm -rf "$(dirname "$binary_path")"' EXIT
swiftc -O -swift-version 6 -module-cache-path /tmp/cuentiva-module-cache \
  'Cuentiva/2 - AppModel/Features/Library/Book.swift' \
  'Cuentiva/2 - AppModel/Features/Library/Author.swift' \
  'Cuentiva/2 - AppModel/Features/Learning/WordComparison.swift' \
  'Cuentiva/2 - AppModel/Features/Nearby/StoryLocation.swift' \
  'Cuentiva/2 - AppModel/User Data Storage/Local/BinaryLibrary.swift' \
  diagnostics/library-loading/Benchmark.swift -o "$binary_path"
"$binary_path" "${1:-Cuentiva/3 - App Resources/Books.json}" "${2:-Cuentiva/3 - App Resources/Library.dat}" 'Cuentiva/3 - App Resources/Introduction.dat'
