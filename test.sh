#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build
echo "Compiling ScheduleMath tests..."
swiftc -swift-version 5 -parse-as-library -o build/schedmath_tests \
  Sources/EyeBreak/ScheduleMath.swift Tests/ScheduleMathTests.swift
echo "Running..."
./build/schedmath_tests
