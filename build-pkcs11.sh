#!/usr/bin/env bash
# Copyright IBM Corp. 2014, 2025
# SPDX-License-Identifier: MPL-2.0
#
# Extract envconsul-piv binary from Docker build.
#
# Usage:
#   ./build-pkcs11.sh                          # extract to ./envconsul-piv
#   ./build-pkcs11.sh /usr/local/bin/envconsul # extract to custom path

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT="${1:-$SCRIPT_DIR/envconsul-piv}"

echo "==> Removing Container if available..."
docker rm -f envconsul-extract 2>/dev/null || true

echo "==> Building Docker image..."
docker build -f "$SCRIPT_DIR/Dockerfile.pkcs11" -t envconsul-piv-builder "$SCRIPT_DIR"

echo "==> Extracting binary to ${OUTPUT}..."
docker rm -f envconsul-extract 2>/dev/null || true
docker create --name envconsul-extract envconsul-piv-builder
docker cp envconsul-extract:/bin/envconsul-piv "${OUTPUT}"
docker rm envconsul-extract

echo ""
echo "==> Done!"
echo "    Binary: ${OUTPUT}"
echo "    Size:   $(du -h "${OUTPUT}" | cut -f1)"
