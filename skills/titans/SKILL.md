---
name: titans
description: >
  Three-lens code review using parallel subagents: Epimetheus (hindsight — bugs, debt, fragility),
  Metis (craft — clarity, idiom, fit-for-purpose), Prometheus (foresight — vision, extensibility, future-Claude).
  Triggers on /titans, /review, 'review this code', 'what did I miss', 'before I ship this'.
  Use after completing substantial work, before /close. (user)
---

# /titans — Code Review Triad

Three reviewers, three lenses. Dispatch in parallel, synthesize findings.

## When to Use

- **After substantial work** — Before /close, when a feature/fix/refactor is "done"
- **Before shipping** — Final quality gate
- **Periodic hygiene** — "What's rotting that I haven't noticed?"
- **After context switch** — Fresh eyes on code you haven't touched in a while

**Not for:** Quick fixes under 50 lines, exploratory spikes, throwaway scripts (unless they stopped being throwaway).

## The Triad

| Titan | Lens | Question | Focus |
|-------|------|----------|-------|
| **Epimetheus** | Hindsight | "What has already gone wrong, or will bite us?" | Bugs, debt, fragility, security |
| **Metis** | Craft | "Is this well-made, right now, for what it is?" | Clarity, idiom, structure, tests |
| **Prometheus** | Foresight | "Does this serve what we're building toward?" | Vision, extensibility, knowledge capture |

**Why these three?** Hindsight catches what's broken. Craft ensures current quality. Foresight protects future-you. Small overlaps are fine — they're perspectives, not partitions.

## Orchestration

### 1. Scope the review

Before dispatching, establish:
- **What to review** — specific files, directory, or "everything touched this session"
- **Context available** — CLAUDE.md, README, architecture docs
- **Goals if known** — roadmap items, intended consumers, lifespan

If scope is unclear, ask. Don't review the entire codebase by accident.

### 2. Dispatch reviewers

Launch three parallel subagents (Explore mode). Each receives:
- The **Reviewer Brief** for their lens (see [references/REVIEWERS.md](references/REVIEWERS.md))
- The scoped files/context
- Awareness of the other two reviewers (to minimize redundancy)

```
# Conceptual — actual invocation depends on your orchestration setup
For each reviewer in [EPIMETHEUS, METIS, PROMETHEUS]:
  Fork Explore agent with:
    - Reviewer brief
    - Scoped files
    - Output structure template
```

### 3. Collect outputs

Each reviewer returns structured findings. See [Output Structure](#output-structure) below.

### 4. Synthesize

Merge outputs into actionable summary:
- **High-priority findings** (multiple reviewers agree)
- **Conflicts reveal trade-offs** (disagreements worth surfacing)
- **"Could not assess" → documentation debt**
- **Critical path before shipping**

See [references/SYNTHESIS.md](references/SYNTHESIS.md) for synthesis patterns.

---

## Output Structure (All Reviewers)

Each reviewer uses this template:

```markdown
## [TITAN] Review

### Findings
Numbered list of issues, each with:
- What: the problem
- Where: file/line/function
- Severity: critical | warning | note
- Fix complexity: trivial | moderate | significant

### Assessed Under Assumptions
State the assumption, then the conditional finding:
- "Assuming this is a long-lived component: [concern]"
- "If throwaway prototype, this concern evaporates"

### Could Not Assess
What's missing that blocks review:
- "No visibility into intended consumers"
- "Can't evaluate against patterns — no access to rest of codebase"
- "Token refresh flow undocumented"

### Questions That Would Sharpen This Review
Specific, answerable questions:
- "Is this called by other agents or only orchestration?"
- "What's the expected lifespan?"
- "Who are the intended consumers?"
```

**"Could not assess" is itself diagnostic.** A codebase that leaves Prometheus constantly asking "what are we building toward?" has a documentation problem worth surfacing.

---

## Synthesis Output

After collecting all three reviews, produce:

```markdown
## Review Triad Synthesis

### High-Priority Findings (Multiple Reviewers)
| Finding | E | M | P | Action |
|---------|---|---|---|--------|
| [issue] | ✓ | ✓ | — | [fix]  |

### Conflicts Reveal Trade-offs
| Trade-off | Metis says | Prometheus says | Resolution |
|-----------|------------|-----------------|------------|
| [tension] | [position]| [position]      | [decision] |

### "Could Not Assess" → Documentation Debt
Repeated across reviewers:
- [gap] — [what's needed]

### Critical Path Before Shipping
| # | Issue | Risk | Fix Complexity |
|---|-------|------|----------------|

### Lower Priority (Track as Tech Debt)
- [items to track but not block on]

### Questions to Resolve
1. [question surfaced by review]
```

---

## Reference Files

| Reference | When to Read |
|-----------|--------------|
| [REVIEWERS.md](references/REVIEWERS.md) | Detailed briefs for each Titan |
| [SYNTHESIS.md](references/SYNTHESIS.md) | Patterns for merging outputs, handling conflicts |

---

## Token Budget Expectations

Based on observed runs:
- **Epimetheus:** 40-50 tool uses, 100-130k tokens (deepest spelunking)
- **Metis:** 30-35 tool uses, 100-120k tokens (structural analysis)
- **Prometheus:** 20-25 tool uses, 70-80k tokens (architectural assessment)

If a reviewer seems to be looping or consuming excessive tokens, it may indicate unclear scope or missing context. Consider interrupting and re-scoping.

---

## Integration with /open and /close

```
/open
  ↓
[substantial work]
  ↓
/titans  ← you are here
  ↓
[address critical findings]
  ↓
/close
```

**/titans findings can feed into /close:**
- Critical issues → "Now" bucket (fix before closing)
- Lower priority → "Next" bucket (create beads)
- Documentation debt → handoff Gotchas section
