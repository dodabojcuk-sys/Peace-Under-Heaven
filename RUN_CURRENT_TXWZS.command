#!/bin/zsh

set -u
set -o pipefail
umask 077

repo_path="${0:A:h}"
godot_app="${GODOT_APP:-/Applications/Godot.app}"
workspace_godot_app="${repo_path:h:h}/codex-tools/godot/4.5.1-stable-standard/Godot.app"
if [[ -z "${GODOT_APP:-}" && ! -d "$godot_app" && -d "$workspace_godot_app" ]]; then
	godot_app="$workspace_godot_app"
fi
godot_bin="${GODOT_BIN:-$godot_app/Contents/MacOS/Godot}"
godot_app="${godot_app:A}"
godot_bin="${godot_bin:A}"
scene_path="res://scenes/title_shell.tscn"
scene_label="TITLE"
candidate_version="FORMAL-CANDIDATE-R1"
default_save_dir="$HOME/Library/Application Support/Godot/app_userdata/天下无战事/saves/v5_campaign/blackstone_city"

isolated="0"
requested_save_dir=""
while (( $# > 0 )); do
	case "$1" in
		--isolated)
			isolated="1"
			shift
			;;
		--save-dir)
			if (( $# < 2 )) || [[ -z "$2" ]]; then
				print -u2 "--save-dir requires a directory path."
				exit 1
			fi
			requested_save_dir="$2"
			shift 2
			;;
		--help|-h)
			print "Usage: ${0:t} [--isolated | --save-dir DIRECTORY]"
			print "  no option     Use the player's normal Blackstone save."
			print "  --isolated    Create and use a new temporary save directory."
			print "  --save-dir    Reopen one explicit isolated save directory."
			exit 0
			;;
		*)
			print -u2 "Unknown launcher option: $1"
			exit 1
			;;
	esac
done

if [[ "$isolated" == "1" && -n "$requested_save_dir" ]]; then
	print -u2 "Choose either --isolated or --save-dir, not both."
	exit 1
fi
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

branch=$(git -C "$repo_path" symbolic-ref --short -q HEAD)
[[ -n "$branch" ]] || branch="DETACHED"
commit=$(git -C "$repo_path" rev-parse HEAD)
short_commit=${commit[1,12]}
dirty="0"
if [[ -n "$(git -C "$repo_path" status --porcelain=v1)" ]]; then
	dirty="1"
fi

if [[ "$isolated" == "1" ]]; then
	isolation_root=$(mktemp -d "/tmp/txwzs-formal-candidate-${short_commit}.XXXXXXXX") || exit 1
	requested_save_dir="$isolation_root/saves"
fi
save_dir="${requested_save_dir:-$default_save_dir}"
save_dir="${save_dir:A}"
repo_path="${repo_path:A}"
mkdir -p "$save_dir"

hash_text() {
	print -rn -- "$1" | shasum -a 256 | awk '{ print substr($1, 1, 16) }'
}

repo_key=$(hash_text "$repo_path")
save_key=$(hash_text "$save_dir")
runtime_dir="/tmp/txwzs-runtime-$repo_key"
launch_lock_dir="/tmp/txwzs-save-$save_key.launch.lock"
lock_owner="$launch_lock_dir/owner_pid"
state_file="$runtime_dir/save-$save_key.state"
log_file="$runtime_dir/save-$save_key.log"
mkdir -p "$runtime_dir"

release_launch_lock() {
	rm -f "$lock_owner"
	rmdir "$launch_lock_dir" 2>/dev/null || true
}

acquire_launch_lock() {
	if mkdir "$launch_lock_dir" 2>/dev/null; then
		print -r -- "$$" > "$lock_owner"
		return 0
	fi
	local owner_pid=""
	[[ -f "$lock_owner" ]] && owner_pid=$(<"$lock_owner")
	if [[ "$owner_pid" == <-> ]] && kill -0 "$owner_pid" 2>/dev/null; then
		print -u2 "Another launcher is checking this save directory: PID $owner_pid"
		return 1
	fi
	rm -f "$lock_owner"
	if ! rmdir "$launch_lock_dir" 2>/dev/null || ! mkdir "$launch_lock_dir" 2>/dev/null; then
		print -u2 "Cannot recover stale save-directory launch lock: $launch_lock_dir"
		return 1
	fi
	print -r -- "$$" > "$lock_owner"
}

focus_runtime() {
	local runtime_pid="$1"
	if /usr/bin/osascript \
		-e "tell application \"System Events\" to set frontmost of first application process whose unix id is $runtime_pid to true" \
		>/dev/null 2>&1; then
		print "Focused existing candidate window (PID $runtime_pid)."
		return 0
	fi
	print "Existing candidate is running (PID $runtime_pid); automatic focus is unavailable."
	return 1
}

runtime_value() {
	local command_line="$1"
	local marker="$2"
	local remainder="${command_line#*${marker}}"
	[[ "$remainder" != "$command_line" ]] || return 1
	print -r -- "${remainder%% *}"
}

if ! acquire_launch_lock; then
	exit 2
fi
trap release_launch_lock EXIT INT TERM

while read -r runtime_pid command_line; do
	[[ "$runtime_pid" == <-> ]] || continue
	[[ "${command_line%% --path *}" == */Godot ]] || continue
	[[ "$command_line" == *"--txwzs-launcher=1"* ]] || continue
	[[ "$command_line" == *"--headless"* ]] && continue
	[[ "$command_line" == *"--editor"* ]] && continue
	[[ "$command_line" == *"--project-manager"* ]] && continue

	runtime_save_key=""
	if [[ "$command_line" == *"--txwzs-save-key="* ]]; then
		runtime_save_key=$(runtime_value "$command_line" "--txwzs-save-key=")
	elif [[ "$command_line" == *"--txwzs-v5-save-dir=$save_dir"* ]]; then
		runtime_save_key="$save_key"
	elif [[ "$command_line" == *"--path $repo_path"* && "$command_line" != *"--txwzs-v5-save-dir="* ]]; then
		runtime_save_key=$(hash_text "$default_save_dir")
	fi
	[[ "$runtime_save_key" == "$save_key" ]] || continue

	runtime_repo_key=""
	runtime_commit=""
	runtime_dirty=""
	[[ "$command_line" == *"--txwzs-project-key="* ]] && runtime_repo_key=$(runtime_value "$command_line" "--txwzs-project-key=")
	[[ "$command_line" == *"--txwzs-commit="* ]] && runtime_commit=$(runtime_value "$command_line" "--txwzs-commit=")
	[[ "$command_line" == *"--txwzs-dirty="* ]] && runtime_dirty=$(runtime_value "$command_line" "--txwzs-dirty=")
	# A clean commit is reproducible. Two launches that merely share the same
	# dirty checkout cannot prove they contain identical working-tree bytes, so
	# treat that case as a save-writer collision instead of claiming a match.
	if [[ "$dirty" == "0" && "$runtime_repo_key" == "$repo_key" && "$runtime_commit" == "$commit" && "$runtime_dirty" == "0" ]]; then
		print "The same TXWZS candidate is already running: $short_commit, save $save_dir"
		focus_runtime "$runtime_pid" || true
		exit 0
	fi
	print -u2 "Save directory is already open for writing by TXWZS PID $runtime_pid."
	print -u2 "Save: $save_dir"
	print -u2 "Existing version: ${runtime_commit:-UNKNOWN}"
	print -u2 "Requested version: $commit"
	exit 3
done < <(ps -ww -Ao pid=,command=)

launch_id="$(date +%s)-$$-$RANDOM"
started_at=$(date '+%Y-%m-%dT%H:%M:%S%z')

print "Launching $candidate_version from $branch@$short_commit dirty=$dirty"
print "Project: $repo_path"
print "Save: $save_dir"
if [[ "$isolated" == "1" ]]; then
	print "Reopen this isolated session with:"
	print "  ${0:A} --save-dir ${(q)save_dir}"
fi
rm -f "$log_file"
if ! open -na "$godot_app" --args \
	--path "$repo_path" \
	--resolution 1152x648 \
	--log-file "$log_file" \
	"$scene_path" \
	-- \
	"--txwzs-launcher=1" \
	"--txwzs-scene=$scene_label" \
	"--txwzs-candidate=$candidate_version" \
	"--txwzs-branch=$branch" \
	"--txwzs-commit=$commit" \
	"--txwzs-dirty=$dirty" \
	"--txwzs-launch-id=$launch_id" \
	"--txwzs-project-key=$repo_key" \
	"--txwzs-save-key=$save_key" \
	"--txwzs-project-path=$repo_path" \
	"--txwzs-v5-save-dir=$save_dir"
then
	print -u2 "LaunchServices failed to start Godot."
	exit 5
fi

runtime_pid=""
for _attempt in {1..24}; do
	while read -r candidate_pid command_line; do
		[[ "$candidate_pid" == <-> ]] || continue
		[[ "$command_line" == "$godot_bin "* ]] || continue
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
	print -r -- "repo_key=$repo_key"
	print -r -- "save=$save_dir"
	print -r -- "save_key=$save_key"
	print -r -- "scene=$scene_label"
	print -r -- "candidate=$candidate_version"
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
