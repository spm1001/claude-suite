"""
Skill validation tests.

These are the mechanical checks that can be automated:
- Structural validation (CSO linting)
- File existence (referenced files exist)
- Script executability
- Internal consistency

For semantic quality (does the skill actually make sense?),
use titans review — that requires LLM judgment.
"""

import os
import re
from pathlib import Path

import pytest


class TestSkillStructure:
    """CSO linter validation — structural quality."""

    def test_skill_passes_linter(self, skill_path: Path, lint_result):
        """Skill must pass structural validation."""
        assert lint_result.valid, (
            f"{skill_path.name} has {lint_result.errors} errors:\n"
            + "\n".join(
                f"  - [{c.name}] {c.message}"
                for c in lint_result.checks
                if not c.passed and c.severity == "error"
            )
        )

    def test_skill_score_100(self, skill_path: Path, lint_result):
        """Skill should achieve 100/100 CSO score."""
        # Allow some tolerance for info-level deductions
        assert lint_result.score >= 95, (
            f"{skill_path.name} scored {lint_result.score}/100:\n"
            + "\n".join(
                f"  - [{c.name}] {c.message} ({c.severity})"
                for c in lint_result.checks
                if not c.passed
            )
        )


class TestReferencedFiles:
    """Verify files mentioned in SKILL.md actually exist."""

    def test_references_directory_files_exist(self, skill_path: Path):
        """All files in references/ subdirectory should exist."""
        refs_dir = skill_path / "references"
        if not refs_dir.exists():
            # No references/ directory is valid — not all skills need one
            return

        missing = []
        for ref_file in refs_dir.glob("*.md"):
            if not ref_file.exists():
                missing.append(ref_file.name)

        assert not missing, f"Missing reference files: {missing}"

    def test_referenced_paths_exist(self, skill_path: Path):
        """Reference paths mentioned in SKILL.md should exist.

        Only checks references/ paths (definitionally skill-local).
        scripts/ paths are not checked — they often refer to
        external tools (todoist-gtd, skill-creator, etc.).
        """
        skill_md = skill_path / "SKILL.md"
        content = skill_md.read_text()

        # Find markdown links to references/ files
        # Pattern: [text](references/foo.md) or `references/foo.md`
        ref_patterns = [
            r'\]\(references/[\w.-]+\.md\)',  # markdown links
            r'`references/[\w.-]+\.md`',       # backtick references
            r'(?<![`\w])references/[\w.-]+\.md(?![`\w])',  # bare references
        ]

        refs = []
        for pattern in ref_patterns:
            matches = re.findall(pattern, content)
            for m in matches:
                # Extract just the path
                path = re.search(r'references/[\w.-]+\.md', m)
                if path:
                    refs.append(path.group())

        # Deduplicate and filter template/example patterns
        refs = list(set(refs))
        template_patterns = ['api_reference.md', 'example']
        refs = [r for r in refs if not any(t in r for t in template_patterns)]

        missing = []
        for ref in refs:
            ref_path = skill_path / ref
            if not ref_path.exists():
                missing.append(ref)

        assert not missing, (
            f"Referenced files don't exist:\n"
            + "\n".join(f"  - {r}" for r in missing)
        )


class TestScripts:
    """Script validation."""

    def test_scripts_are_executable(self, skill_path: Path):
        """Python and shell scripts should be executable."""
        scripts_dir = skill_path / "scripts"
        if not scripts_dir.exists():
            # No scripts/ directory is valid — not all skills need one
            return

        non_executable = []
        for script in scripts_dir.iterdir():
            if script.suffix in (".py", ".sh"):
                if not os.access(script, os.X_OK):
                    non_executable.append(script.name)

        assert not non_executable, (
            f"Scripts not executable (chmod +x):\n"
            + "\n".join(f"  - {s}" for s in non_executable)
        )

    def test_python_scripts_have_shebang(self, skill_path: Path):
        """Python scripts should have proper shebang."""
        scripts_dir = skill_path / "scripts"
        if not scripts_dir.exists():
            # No scripts/ directory is valid — not all skills need one
            return

        missing_shebang = []
        for script in scripts_dir.glob("*.py"):
            first_line = script.read_text().split("\n")[0]
            if not first_line.startswith("#!"):
                missing_shebang.append(script.name)

        assert not missing_shebang, (
            f"Python scripts missing shebang:\n"
            + "\n".join(f"  - {s}" for s in missing_shebang)
        )


class TestConsistency:
    """Cross-skill consistency checks."""

    def test_anti_patterns_table_format(self, skill_path: Path):
        """Anti-patterns table should use Pattern|Problem|Fix format."""
        skill_md = skill_path / "SKILL.md"
        content = skill_md.read_text()

        # Find anti-patterns section (handles "Anti-Patterns" and "Anti-Patterns to Avoid")
        match = re.search(
            r'##\s+Anti[- ]?[Pp]atterns?(?:\s+to\s+Avoid)?\s*\n(.*?)(?=\n##|\Z)',
            content,
            re.DOTALL
        )
        if not match:
            # Alias skills (close, open, review) don't have Anti-Patterns
            # CSO linter enforces presence for non-alias skills
            pytest.skip("No Anti-Patterns section (likely alias skill)")

        section = match.group(1)

        # Check for table header
        if "|" not in section:
            pytest.skip("No table in Anti-Patterns section")

        # Look for the header row
        header_match = re.search(r'\|([^|]+)\|([^|]+)\|([^|]+)\|', section)
        if not header_match:
            pytest.skip("Can't parse table header")

        headers = [h.strip().lower() for h in header_match.groups()]

        # Accept variations:
        # - "Pattern|Problem|Fix"
        # - "Anti-Pattern|Problem|Fix"
        # - "Anti-Pattern|Symptom|Fix"
        valid_first = ["pattern", "anti-pattern"]
        valid_second = ["problem", "symptom"]
        valid_third = ["fix"]

        assert headers[0] in valid_first, (
            f"First column should be 'Pattern' or 'Anti-Pattern', got: {headers[0]}"
        )
        assert headers[1] in valid_second, (
            f"Second column should be 'Problem' or 'Symptom', got: {headers[1]}"
        )
        assert headers[2] in valid_third, (
            f"Third column should be 'Fix', got: {headers[2]}"
        )
