#!/bin/zsh

set -u
set -o pipefail

repo_path="${0:A:h}"
exec "$repo_path/RUN_CURRENT_TXWZS.command" --isolated
