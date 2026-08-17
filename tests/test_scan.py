"""Regression tests for the sharing scanner (skills/skill-forge/scripts/scan.py).

Every test here exists because the scanner once passed vacuously
(trousse-bujuta): it scanned 0 files and reported a clean bill. The tests
run the script as a subprocess with HOME pointed at the tmp dir, so the
machine's real ~/.claude/sharing-scan.json can never leak into a fixture.
"""

import json
import os
import subprocess
import sys
from pathlib import Path

SCAN = Path(__file__).parent.parent / "skills" / "skill-forge" / "scripts" / "scan.py"

# Constructed to match the GOCSPX- OAuth-secret pattern; not a real credential.
FAKE_SECRET = "GOCSPX-FAKEtest_1234abcd"


def run_scan(*args, home):
    env = {**os.environ, "HOME": str(home)}
    return subprocess.run(
        [sys.executable, str(SCAN), *args],
        capture_output=True, text=True, env=env,
    )


def test_planted_secret_fires(tmp_path):
    """The positive control: a scanner that cannot fire is not a scanner."""
    (tmp_path / "SKILL.md").write_text(f"the key {FAKE_SECRET} is planted\n")
    r = run_scan(str(tmp_path), home=tmp_path)
    assert r.returncode == 1
    assert "Files scanned: 1" in r.stdout
    assert "HIGH: 1" in r.stdout


def test_explicit_file_arg_scans_that_file(tmp_path):
    """rglob on a file path yields nothing — file args must scan directly."""
    f = tmp_path / "SKILL.md"
    f.write_text(f"key {FAKE_SECRET} here\n")
    r = run_scan(str(f), home=tmp_path)
    assert r.returncode == 1
    assert "Files scanned: 1" in r.stdout


def test_excluded_ancestor_does_not_blind_the_scan(tmp_path):
    """The bujuta mechanism: '.claude' in the path ABOVE the scan root must
    not exclude the tree (excludes are relative to the scan root)."""
    skill_dir = tmp_path / ".claude" / "skills" / "some-skill"
    skill_dir.mkdir(parents=True)
    (skill_dir / "SKILL.md").write_text(f"key {FAKE_SECRET} here\n")
    r = run_scan(str(skill_dir), home=tmp_path)
    assert "Files scanned: 1" in r.stdout
    assert r.returncode == 1


def test_zero_files_is_loud_failure_not_clean_bill(tmp_path):
    empty = tmp_path / "empty"
    empty.mkdir()
    r = run_scan(str(empty), home=tmp_path)
    assert r.returncode == 2
    assert "SCANNER FAILURE" in r.stderr


def test_clean_file_passes(tmp_path):
    (tmp_path / "SKILL.md").write_text("nothing sensitive here\n")
    r = run_scan(str(tmp_path), home=tmp_path)
    assert r.returncode == 0
    assert "Files scanned: 1" in r.stdout


def test_config_arms_personal_categories(tmp_path):
    """Personal-list categories are inert by default; a config arms them."""
    (tmp_path / "SKILL.md").write_text("logs live in /home/testuser/logs\n")
    cfg = tmp_path / "cfg.json"
    cfg.write_text(json.dumps({"path_usernames": ["testuser"]}))
    bare = run_scan(str(tmp_path / "SKILL.md"), home=tmp_path)
    armed = run_scan(str(tmp_path / "SKILL.md"), "--config", str(cfg), home=tmp_path)
    assert "Findings: 0" in bare.stdout          # inert without config
    assert "[path]" in armed.stdout               # fires with it
    assert "testuser" in armed.stdout


def test_default_config_discovered_from_home(tmp_path):
    """~/.claude/sharing-scan.json loads without --config."""
    claude_dir = tmp_path / ".claude"
    claude_dir.mkdir()
    (claude_dir / "sharing-scan.json").write_text(
        json.dumps({"path_usernames": ["testuser"]}))
    target = tmp_path / "work"
    target.mkdir()
    (target / "SKILL.md").write_text("logs live in /home/testuser/logs\n")
    r = run_scan(str(target), home=tmp_path)
    assert "sharing-scan.json" in r.stderr        # provenance line names it
    assert "[path]" in r.stdout


def test_inert_categories_warn(tmp_path):
    """Empty personal lists are named on stderr, never silent."""
    (tmp_path / "SKILL.md").write_text("nothing sensitive here\n")
    r = run_scan(str(tmp_path), home=tmp_path)
    assert "categories inert" in r.stderr
    assert "person_names" in r.stderr
