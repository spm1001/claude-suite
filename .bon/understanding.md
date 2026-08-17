# Understanding — trousse

*Seeded 2026-08-09 from the 2026-07-19 handoff (session 511191c5); last synthesis 2026-08-17 from the wunule-night handoff (session b324fa3e).*

## What trousse is now

A **tight public knife-roll of 5 skills** — `skill-forge`, `titans` (+ `/review` alias), `deglacer`, `ardoise`, `hublot` — shipped via the Batterie suite marketplace. The 2026-07 slim-down (18 → 4, `trousse-pijuha`) established the frame: **public status is earned on stranger-appeal, not the default.** ITV-flavoured skills live in `ITV/mit-commons` under prosaic `mit-` names; Sameer-specific ones in `spm1001/trousse-personal`. The full rule is in CLAUDE.md ("Skill homes") and global memory (`skill-home-selection`). (hublot joined the drawer 2026-08; CLAUDE.md's count was corrected 4→5 on 2026-08-09.)

## The migration lesson (durable)

**Migrating a skill to a shared repo is the moment its unstated dependencies surface.** `tamis` passed the audience test, installed green into mit-commons, and would have shipped broken — it silently drives `passe` plus a machine-specific ControlD/DoH rig only the author has. A green install is not a working skill for someone without the author's infra. The de-brand pass is the checkpoint: ask **"does this actually work for the new audience, or does it just compile?"** — enumerate the tools/infra the skill's recipes invoke and check the audience has them. When in doubt, the private drawer is the safe home. (Known milder instance of the same class: commons' `mit-bigquery-analysis` assumes mise + consommé MCP servers are configured — worth a prerequisites note if a teammate hits it.)

## Evidence classes for third-party tools (durable, 2026-08-09)

**A tool's measured behaviour and its documented surface are different evidence classes — sample the first, fetch the second, never generalise one into the other.** The deja session verified `--help` performs a literal search (true, measured) and shipped "no flags, no subcommands" (false — one `gh api .../readme` call would have shown `--re`, `--since`, `show`, `blame`). The subagent test passed because it exercised *routing to* the tool, not the *accuracy of claims about* it — an unearned green orthogonal to the failure. Prevention costs one API call before writing any interface claim about third-party code.

**And the classes compose** (wunule night, 2026-08-09): a matched pair already measured live + the walk code read from pinned source = mechanism confirmed with zero additional risk. **Read the pinned source before designing a workaround for a third-party tool** — the Go module cache (`~/.local/share/go/pkg/mod/...@v0.16.9`) is on disk and sumdb-verified, and 90 seconds of grep found `DEJA_CLAUDE_ROOT`, a purpose-built escape hatch no amount of black-box probing would have surfaced.

## Ordering a destructive verification so the cost pays twice (durable, 2026-08-09)

When confirming a destructive repro looks "too expensive" (another index wipe, another rebuild), check whether a bill you already owe can be routed through the same run. The wunule index was already wiped, so the 5-minute re-index was sunk cost — running the *fix-condition* probe first made one run pay for mechanism proof, fix proof, and estate repair. Companion deflator for hazard-class worries: **classify by discriminator, not by resemblance** — the deja class needed all three of config-following + symlink-blind walker + shared mutable artifact, and only deja had them.

## External code in a key pipeline (durable, 2026-08-09)

Three composable guards, all built for deja and reusable: a **leash** (the `banc/session-search` bench re-scores any new version in ~2 min), a **doorbell** (tube's weekly dev-tools timer files an infra bon on stable-tag drift — check-and-file, never auto-update), and a **ritual** (`banc/session-search/README.md`, 9 steps: pin → sumdb-verified module-proxy build → dep+strace audit → bench). Go specifics: `go version -m` is the identity oracle (the binary's own `version` output lies on proxy builds); a sudden dep tree appearing is itself the alarm; check `go env GOBIN` before `go install` — on tube it points at `~/.local/bin` and overwrites the live binary in place, so back up BEFORE. `deja install --auto` and `deja sync ssh` are deliberately OFF (ritual step 9) — enabling either is a separate decision, not an upgrade side-effect.

## Benching the session-search corpus (durable, 2026-08-09)

**The corpus is alive, and benches on it are echo-confounded within a day** — the eval-authoring session's own probes salt the transcript with every query term, and echo mass pushes original sessions below deja's result cap. Same-day before/after comparisons measure corpus drift as much as version drift; a presence-drop on common-term tasks is a cap artefact until a `--limit 40` probe shows the expected id absent as a *header* (not as quoted excerpt inside someone else's result). Measured routing verdict (in deglacer SKILL.md): deja with 2–3 rare terms (85% recall, ranked, ~2s); rg fixed-string as 100%-recall backstop; `--find` only inside its 200-most-recent-sessions window; hit@1 is 8–15% everywhere.

## Constraints that bite

- **Suite-managed versioning:** never hand-bump `plugin.json`; release via `/batterie:publish`. A `CLAUDE.md` / `instructions.md` / `skills/` edit is vendored content and must ride a suite bump to ship — the assembler quarantines otherwise. `docs/` and `.bon/` edits are free.
- **Suite versions move under us between publishes** (1.43 → 1.45 → 1.46.2 in one day, 2026-08-09) — never predict a version number; read it from the publish output.
- **README skill table is generated** (between `GENERATED:SKILLS` markers) — regenerate with `render-skills.py`, never hand-edit; CI diffs it.
- The local `~/repos/spm1001/batterie` clone drifts behind after every publish (CI commits to origin) — don't read skill state from it; read the plugin cache or GitHub.
- **Skill frontmatter is session-cached** — a session that edits a SKILL.md cannot verify the harness's own read of it; verify the render in a fresh session. (Three rounds of deglacer edits shipped 2026-08-09 with this check outstanding.)

## Current board themes

Wunule closed end-to-end 2026-08-09 (mechanism confirmed from pinned source, `DEJA_CLAUDE_ROOT` fix wired into `_claude_commis`, index repaired, quirk bullet published in 1.48.1). Remaining clusters: **deglacer accuracy** (trousse-guriku/jejozo: slash-command schema errors to verify against live JSONL) — but note **deglacer is leaving trousse** (trousse-wazula, waiting on bds-numeri, the deglacer plugin shipping): hold deglacer edits until the move lands. **skill-forge hardening** (trousse-muhejo/vamawu: bench-measured writing rules; trousse-ferupi: attention-narrowing checks; trousse-bujuta: scan.py vacuous green; trousse-wowujo: provenance flags; trousse-susoni: cowork-cloud reference). **Field-report piles** on hublot (nibajo: types-but-doesn't-submit; vurojo: teardown ghost-text; pezogu: key-verb recipe) and ardoise (jiluru/rozoso: stale cache sibling via lexicographic version sort; fawufi: print mode hardcodes cwd=/tmp). Eval v2 shapes (echo-probe, tool-result-only) are deferred, raised on the banc board (banc-bizeko). The deja upstream issue is parked **by decision** — don't post it, don't re-litigate.
