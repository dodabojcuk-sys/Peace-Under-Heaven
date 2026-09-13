#!/bin/zsh

set -u
set -o pipefail
umask 077

repo_path="${0:A:h}"
godot_bin="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
godot_app="${GODOT_APP:-/Applications/Godot.app}"
scene_path="res://scenes/title_shell.tscn"
scene_label="TITLE"

if [[ ! -x "$godot_bin" ]]; then
	print -u2 "Godot executable not found: $godot_bin"
	exit 1
fi
if [[ ! -d "$godot_app" ]]; then
	print -u2 "Godot application not found: $godot_app"
	exit 1
fi
if ! git -C "$repo_path" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
	print -u2 "Launcher is not inside a Git repository: $repo_path"
	exit 1
fi

repo_key=$(
	print -rn -- "$repo_path" |
		shasum -a 256 |
		awk '{ print substr($1, 1, 16) }'
)
runtime_dir="/tmp/txwzs-runtime-$repo_key"
lock_dir="$runtime_dir.lock"
lock_owner="$lock_dir/owner_pid"
state_file="$runtime_dir/current.state"
log_file="$runtime_dir/current.log"
mkdir -p "$runtime_dir"

release_lock() {
	rm -f "$lock_owner"
	rmdir "$lock_dir" 2>/dev/null || true
}

acquire_lock() {
	if mkdir "$lock_dir" 2>/dev/null; then
		print -r -- "$$" > "$lock_owner"
		return 0
	fi
	local owner_pid=""
	if [[ -f "$lock_owner" ]]; then
		owner_pid=$(<"$lock_owner")
	fi
	if [[ "$owner_pid" == <-> ]] && kill -0 "$owner_pid" 2>/dev/null; then
		print -u2 "Another TXWZS launcher is active: PID $owner_pid"
		return 1
	fi
	rm -f "$lock_owner"
	if ! rmdir "$lock_dir" 2>/dev/null || ! mkdir "$lock_dir" 2>/dev/null; then
		print -u2 "Cannot recover stale launcher lock: $lock_dir"
		return 1
	fi
	print -r -- "$$" > "$lock_owner"
	return 0
}

read_state_value() {
	local key="$1"
	[[ -f "$state_file" ]] || return 0
	awk -F= -v wanted="$key" '
		$1 == wanted {
			print substr($0, length($1) + 2)
			exit
		}
	' "$state_file"
}

is_registered_runtime() {
	local pid="$1"
	local launch_id="$2"
	[[ "$pid" == <-> ]] || return 1
	kill -0 "$pid" 2>/dev/null || return 1
	local command_line
	command_line=$(ps -ww -p "$pid" -o command=)
	[[ "$command_line" == "$godot_bin "* ]] || return 1
	[[ "$command_line" == *"--path $repo_path"* ]] || return 1
	[[ "$command_line" == *"--txwzs-launch-id=$launch_id"* ]] || return 1
	return 0
}

find_unregistered_runtime() {
	local registered_pid="$1"
	local found=0
	local pid
	local command_line
	while read -r pid command_line; do
		[[ "$pid" == <-> ]] || continue
		[[ "$pid" == "$registered_pid" ]] && continue
		[[ "$command_line" == "$godot_bin "* ]] || continue
		[[ "$command_line" == *"$repo_path"* ]] || continue
		[[ "$command_line" == *"--headless"* ]] && continue
		[[ "$command_line" == *"--editor"* ]] && continue
		[[ "$command_line" == *"--project-manager"* ]] && continue
		print -u2 "Unregistered TXWZS runtime blocks launch:"
		print -u2 "PID $pid  $command_line"
		found=1
	done < <(ps -ww -Ao pid=,command=)
	return "$found"
}

if ! acquire_lock; then
	exit 2
fi
trap release_lock EXIT INT TERM

previous_pid=$(read_state_value pid)
previous_launch_id=$(read_state_value launch_id)
if [[ -n "$previous_pid" && -n "$previous_launch_id" ]]; then
	if is_registered_runtime "$previous_pid" "$previous_launch_id"; then
		print -u2 "Existing TXWZS candidate remains open: PID $previous_pid"
		print -u2 "Close that window explicitly before launching another candidate."
		exit 3
	fi
fi

if ! find_unregistered_runtime "$previous_pid"; then
	exit 4
fi

branch=$(git -C "$repo_path" symbolic-ref --short -q HEAD)
[[ -n "$branch" ]] || branch="DETACHED"
commit=$(git -C "$repo_path" rev-parse --short=7 HEAD)
dirty="0"
if [[ -n "$(git -C "$repo_path" status --porcelain=v1)" ]]; then
	dirty="1"
fi
launch_id="$(date +%s)-$$-$RANDOM"
started_at=$(date '+%Y-%m-%dT%H:%M:%S%z')

print "Launching $scene_label from $branch@$commit dirty=$dirty"
rm -f "$log_file"
if ! open -na "$godot_app" --args \
	--path "$repo_path" \
	--resolution 1152x648 \
	--log-file "$log_file" \
	"$scene_path" \
	-- \
	"--txwzs-launcher=1" \
	"--txwzs-scene=$scene_label" \
	"--txwzs-branch=$branch" \
	"--txwzs-commit=$commit" \
	"--txwzs-dirty=$dirty" \
	"--txwzs-launch-id=$launch_id"
then
	print -u2 "LaunchServices failed to start Godot."
	exit 5
fi

runtime_pid=""
for _attempt in {1..20}; do
	while read -r candidate_pid command_line; do
		[[ "$candidate_pid" == <-> ]] || continue
		[[ "$command_line" == "$godot_bin "* ]] || continue
		[[ "$command_line" == *"--path $repo_path"* ]] || continue
		[[ "$command_line" == *"--txwzs-launch-id=$launch_id"* ]] || continue
		runtime_pid="$candidate_pid"
		break
	done < <(ps -ww -Ao pid=,command=)
	[[ -n "$runtime_pid" ]] && break
	sleep 0.25
done

if [[ -z "$runtime_pid" ]] || ! kill -0 "$runtime_pid" 2>/dev/null; then
	print -u2 "Cannot identify the launched TXWZS runtime. Log: $log_file"
	tail -n 80 "$log_file" >&2
	exit 5
fi

state_tmp="$state_file.$$"
{
	print -r -- "pid=$runtime_pid"
	print -r -- "repo=$repo_path"
	print -r -- "scene=$scene_label"
	print -r -- "branch=$branch"
	print -r -- "commit=$commit"
	print -r -- "dirty=$dirty"
	print -r -- "launch_id=$launch_id"
	print -r -- "started_at=$started_at"
	print -r -- "log=$log_file"
} > "$state_tmp"
mv "$state_tmp" "$state_file"

print "TXWZS runtime PID $runtime_pid"
print "State: $state_file"
print "Log: $log_file"
