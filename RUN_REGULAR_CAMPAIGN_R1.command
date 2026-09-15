#!/bin/zsh
set -eu
repo_path="${0:A:h}"
exec /usr/bin/python3 "$repo_path/tools/launch_regular_campaign_r1.py" "$@"
