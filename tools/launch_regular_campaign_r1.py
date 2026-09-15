#!/usr/bin/env python3
"""Launch only the isolated Regular Campaign R1A spatial-city candidate."""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import subprocess
import uuid

BASE = "d50682b189fac3174b3c869094fe6443bb67844f"
VERSION = "4.5.1.stable.official.f62fdbde1"
REPO = Path(__file__).resolve().parents[1]
GODOT = Path("/Users/m4-zhi/Documents/codex-tools/godot/4.5.1-stable-standard/Godot.app/Contents/MacOS/Godot")
MARKER = ".regular-campaign-r1a-spatial-fix-isolated.json"


def git(*args):
    return subprocess.check_output(["git", "-C", str(REPO), *args], text=True).strip()


def digest(text):
    return hashlib.sha256(text.encode()).hexdigest()


def runtime_digest():
    files = [REPO / "project.godot"]
    for folder in ("scripts", "resources", "scenes"):
        files.extend(path for path in (REPO / folder).rglob("*") if path.is_file() and not path.name.endswith((".import", ".uid")))
    entries = {str(path.relative_to(REPO)): hashlib.sha256(path.read_bytes()).hexdigest() for path in sorted(files)}
    return digest(json.dumps(entries, sort_keys=True)), entries


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--save-dir", type=Path, help="Reopen an exact directory created by this launcher")
    parser.add_argument("--inspect", action="store_true", help="Print verified code/runtime provenance without launching")
    args = parser.parse_args()
    version = subprocess.check_output([str(GODOT), "--version"], text=True).strip()
    if version != VERSION:
        raise SystemExit(f"Unexpected Godot version: {version}")
    subprocess.run(["git", "-C", str(REPO), "merge-base", "--is-ancestor", BASE, "HEAD"], check=True)
    head, branch, tree = git("rev-parse", "HEAD"), git("branch", "--show-current"), git("rev-parse", "HEAD^{tree}")
    if branch != "codex/txwzs-regular-campaign-r1a-spatial-fix":
        raise SystemExit("This launcher is restricted to the isolated R1A spatial-fix branch")
    runtime_sha, files = runtime_digest()
    provenance = {"base_commit": BASE, "head": head, "tree": tree, "branch": branch, "status": git("status", "--porcelain=v1"), "project": str(REPO), "godot": str(GODOT), "godot_version": version, "godot_sha256": hashlib.sha256(GODOT.read_bytes()).hexdigest(), "runtime_sha256": runtime_sha, "runtime_files": files}
    if args.inspect:
        print(json.dumps(provenance, ensure_ascii=False, indent=2))
        return
    launch_id = datetime.datetime.now().strftime("%Y%m%d-%H%M%S-") + uuid.uuid4().hex[:8]
    if args.save_dir:
        save_dir = args.save_dir.expanduser().resolve()
        marker = save_dir.parent / MARKER
        if not marker.is_file():
            raise SystemExit("Refusing an unmarked save directory; use the exact directory from this launcher")
        previous = json.loads(marker.read_text())
        if previous.get("project") != str(REPO) or previous.get("save_directory") != str(save_dir):
            raise SystemExit("Candidate save provenance does not match this worktree")
        if previous.get("runtime_sha256") != runtime_sha:
            raise SystemExit("Candidate runtime differs from the saved candidate; use a fresh launch")
        pid = previous.get("pid")
        if pid:
            try:
                os.kill(pid, 0)
            except ProcessLookupError:
                pass
            else:
                raise SystemExit(f"This candidate already has a live process ({pid}); no second writer launched")
    else:
        save_dir = Path.home() / "Documents" / "TXWZS-Regular-Campaign-R1A-Spatial-Fix-Runs" / launch_id / "saves"
        save_dir.mkdir(parents=True, exist_ok=False)
    provenance.update({"launch_id": launch_id, "save_directory": str(save_dir), "candidate": "REGULAR-CAMPAIGN-R1A"})
    args = [str(GODOT), "--path", str(REPO), "res://scenes/title_shell.tscn", "--", "--txwzs-launcher=1", "--txwzs-scene=TITLE", "--txwzs-candidate=REGULAR-CAMPAIGN-R1A", f"--txwzs-branch={branch}", f"--txwzs-commit={head}", f"--txwzs-dirty={int(bool(provenance['status']))}", f"--txwzs-launch-id={launch_id}", f"--txwzs-project-key={digest(str(REPO))[:16]}", f"--txwzs-save-key={digest(str(save_dir))[:16]}", f"--txwzs-project-path={REPO}", f"--txwzs-v5-save-dir={save_dir}"]
    with (save_dir.parent / "runtime.log").open("w") as log:
        process = subprocess.Popen(args, cwd=REPO, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
    provenance["pid"] = process.pid
    (save_dir.parent / MARKER).write_text(json.dumps(provenance, ensure_ascii=False, indent=2))
    print(json.dumps({key: provenance[key] for key in ("pid", "head", "branch", "runtime_sha256", "save_directory", "launch_id")}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
