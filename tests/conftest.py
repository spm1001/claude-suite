"""
Pytest configuration and fixtures for skill testing.
"""

import sys
from pathlib import Path

import pytest

# Add skills/skill-forge/scripts to path for lint_skill imports
REPO_ROOT = Path(__file__).parent.parent
LINTER_PATH = REPO_ROOT / "skills" / "skill-forge" / "scripts"
sys.path.insert(0, str(LINTER_PATH))

from lint_skill import lint_skill, LintResult


def discover_skills() -> list[Path]:
    """Find all skill directories in skills/."""
    skills_dir = REPO_ROOT / "skills"
    skills = []
    for item in sorted(skills_dir.iterdir()):
        if item.is_dir() and (item / "SKILL.md").exists():
            skills.append(item)
    return skills


# Discover skills once at collection time
ALL_SKILLS = discover_skills()
SKILL_NAMES = [s.name for s in ALL_SKILLS]


def pytest_generate_tests(metafunc):
    """Parametrize tests over all skills."""
    if "skill_path" in metafunc.fixturenames:
        metafunc.parametrize(
            "skill_path",
            ALL_SKILLS,
            ids=SKILL_NAMES,
        )


@pytest.fixture
def lint_result(skill_path: Path) -> LintResult:
    """Run the linter on a skill and return the result."""
    return lint_skill(skill_path, follow_aliases=True)
