#!/usr/bin/env bash
# deploy.sh — sync the Transmission TUI to the remote host over SSH.
# Usage: ./deploy.sh
# Env overrides: REMOTE_USER, REMOTE_HOST, REMOTE_DIR, SSH_PORT
set -euo pipefail

REMOTE_USER="${REMOTE_USER:-ubuntu}"
REMOTE_HOST="${REMOTE_HOST:-100.99.216.18}"
REMOTE_DIR="${REMOTE_DIR:-/home/ubuntu/transmission-tui}"
SSH_PORT="${SSH_PORT:-22}"

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${REMOTE_USER}@${REMOTE_HOST}"

command -v rsync >/dev/null || { echo "rsync not installed locally"; exit 1; }
command -v ssh   >/dev/null || { echo "ssh not installed locally";   exit 1; }

echo "→ Deploying ${SRC_DIR} to ${TARGET}:${REMOTE_DIR} (port ${SSH_PORT})"

ssh -p "${SSH_PORT}" "${TARGET}" "mkdir -p '${REMOTE_DIR}'"

rsync -avz --delete \
    -e "ssh -p ${SSH_PORT}" \
    --exclude '.git/' \
    --exclude 'deploy.sh' \
    --chmod=F644,D755 \
    "${SRC_DIR}/" "${TARGET}:${REMOTE_DIR}/"

ssh -p "${SSH_PORT}" "${TARGET}" "chmod +x '${REMOTE_DIR}/transmission_manager.sh'"

echo "✓ Deployed. On the remote run:"
echo "    ssh ${TARGET} -p ${SSH_PORT}"
echo "    cd ${REMOTE_DIR} && ./transmission_manager.sh"
