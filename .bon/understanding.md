# Understanding — trousse

*Seeded 2026-08-09 from the 2026-07-19 handoff's "For Claudes to come" (session 511191c5). No understanding.md existed before this.*

## What trousse is now

A **tight public knife-roll of 4 skills** — `skill-forge`, `titans` (+ `/review` alias), `deglacer`, `ardoise` — shipped via the Batterie suite marketplace. The 2026-07 slim-down (18 → 4, `trousse-pijuha`) established the frame: **public status is earned on stranger-appeal, not the default.** ITV-flavoured skills live in `ITV/mit-commons` under prosaic `mit-` names; Sameer-specific ones in `spm1001/trousse-personal`. The full rule is in CLAUDE.md ("Skill homes") and global memory (`skill-home-selection`).

## The migration lesson (durable)

**Migrating a skill to a shared repo is the moment its unstated dependencies surface.** `tamis` passed the audience test, installed green into mit-commons, and would have shipped broken — it silently drives `passe` plus a machine-specific ControlD/DoH rig only the author has. A green install is not a working skill for someone without the author's infra. The de-brand pass is the checkpoint: ask **"does this actually work for the new audience, or does it just compile?"** — enumerate the tools/infra the skill's recipes invoke and check the audience has them. When in doubt, the private drawer is the safe home. (Known milder instance of the same class: commons' `mit-bigquery-analysis` assumes mise + consommé MCP servers are configured — worth a prerequisites note if a teammate hits it.)

## Constraints that bite

- **Suite-managed versioning:** never hand-bump `plugin.json`; release via `/batterie:publish`. A `CLAUDE.md` / `instructions.md` / `skills/` edit is vendored content and must ride a suite bump to ship — the assembler quarantines otherwise. `docs/` and `.bon/` edits are free.
- **README skill table is generated** (between `GENERATED:SKILLS` markers) — regenerate with `render-skills.py`, never hand-edit; CI diffs it.
- The local `~/repos/spm1001/batterie` clone drifts behind after every publish (CI commits to origin) — don't read skill state from it; read the plugin cache or GitHub.

## Current board themes

Two clusters: **deglacer accuracy** (schema reference gaps found live — slash-command sessions, JSON serialization dragons, routing content search to deja, a smevals eval to adjudicate search approaches) and **skill-forge hardening** (bench-measured writing rules, attention-narrowing checks on recipes).
