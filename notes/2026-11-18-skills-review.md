# Skills review

Research date: 2026-11-18. Reviewed commit: `51a99b29edf258bcad02aad48ebf745299a9bf83`.

Scope: repository structure, every skill entry point, manifests, documentation, evaluation assets, and selected helpers. This is not a complete security audit. No live publishing, customer-data access, or model evaluation runs were performed.

## Recommendation

Reduce duplicate maintenance first. Fix release helper defects. Then measure which instructions improve actual task results. Do not expand the collection or add a general evaluation framework before a small paired pilot.

## Current research

- [Agent Skills specification](https://agentskills.io/specification): a skill needs a `SKILL.md`; supporting scripts and references are optional. Standard metadata includes `compatibility`. Keep standard requirements separate from runtime extensions.
- [Authoring guidance](https://agentskills.io/skill-creation/best-practices): retain domain knowledge the model needs, refine against execution traces, and load detail on demand. The 500-line recommendation is a ceiling, not a target.
- [Evaluation guidance](https://agentskills.io/skill-creation/evaluating-skills): compare realistic tasks with and without the skill. Start with two or three cases and expand after observing results.
- [SkillsBench, revision 4, June 14](https://arxiv.org/abs/2602.12670): matched evaluation reports a 16.6 percentage-point average improvement across 18 configurations. Focused skills with at most three modules perform better than larger bundles in that benchmark. This does not prove a universal module limit.
- [WebDev-Skills-Bench, August 24](https://arxiv.org/abs/2608.23067): injected skills reduce average performance in its web development setting and increase token cost. Effects vary by model and project. Its injection protocol differs from automatic discovery, so do not transfer effect sizes directly to this collection.
- [SkillBuffBench, November 17](https://arxiv.org/abs/2611.22017): proposes separate no-skill, curated-skill, and automatic-library conditions, with memory controlled. Results are pending. Use its experimental distinction, not an unreported performance claim.
- [Claude skills documentation](https://code.claude.com/docs/en/skills): bodies load on invocation. `allowed-tools` pre-approves listed tools; it does not restrict the available tool set. Runtime permission settings still apply. `disable-model-invocation` supports explicit invocation for workflows with side effects.
- [Claude plugin reference](https://code.claude.com/docs/en/plugins-reference): root-level skills are supported. A plugin manifest is optional in the default layout. Consequently, missing nested trees or a manifest alone do not establish an installation defect.

These are primary sources checked on the research date. Papers provide setting-specific evidence, not proof that this repository's skills help or harm.

## Findings and proposed changes

### 1. High: repair the release helper before extending it

File: `skills/release-runbook/skills/release-runbook/scripts/release.sh`.

- Line 323 uses `((patch++))` with `set -e`. A patch bump from `0.0.0` exits with status 1. The major and minor branches use the same pattern. Use assignment arithmetic and test zero components.
- Line 428 replaces every line beginning `version =` in `Cargo.toml`. A disposable fixture confirms that it changes a dependency version from `2.0.0` to the package's new version. Use a parser or an ecosystem command that targets the package field. Cover workspace inheritance explicitly.
- Line 524 selects only the first discovered test command. This conflicts with the multi-language workflow's promise to run each language's tests. Execute all required checks or narrow the advertised behavior.
- The main workflow creates the new tag before generating release notes. The notes function then finds the nearest tag, which can be the new tag. Capture the prior tag before creating the new one.
- The documentation promises builds and binary uploads, but the main workflow has no build stage or artifact upload arguments. Implement these operations or remove the claims.

Proposed interface: prepare a local release plan and diff first; publish through an explicit action. Existing publication authorization should remain sufficient. Do not add repeated confirmation prompts.

### 2. High: remove parallel source trees

The repository has 12 skill directories and 20 `SKILL.md` files. Eight skills have both root and nested entry points. Five pairs differ; three are identical. Across these eight trees, 51 additional files are byte-identical copies. Path substitutions account for some differences; those differences are still maintenance work.

Keep one root skill per directory, consistent with the README's skillctl example. Preserve the plugin manifest as a distribution adapter. Current Claude documentation supports this layout. Alternatively, choose nested sources and generate portable artifacts. Do not maintain both by hand.

Before removing copies, reconcile all five differing entry points. Resolve helpers from the loaded skill's directory. Test the actual installed artifact from an unrelated working directory, including a path with spaces. Runtime-specific variables belong in adapters or clearly marked instructions.

### 3. High: correct the permission and loading model

`CLAUDE.md:40` says `SKILL.md` is always loaded. It loads on invocation. `CLAUDE.md:132` describes `allowed-tools` as a restriction. It grants approval for listed tools; it is not an isolation boundary.

Correct these statements in `CLAUDE.md`, contribution instructions, and the three guides. Distinguish the portable specification from Claude extensions. Prefer links to upstream runtime documentation over copied explanations that become stale.

### 4. Medium: evaluate selection and results separately

Only `git-xray` has an `evals/evals.json`. It contains three positive prompts with expected report descriptions. It has no bundled repository fixtures or executable assertions. Steel has a live smoke test, so the blanket claim that there are no automated tests is also inaccurate. No tracked continuous integration configuration was found.

Pilot evaluation with `yt-transcript`, `release-runbook`, and `steel-org-recon`:

1. Choose two or three realistic tasks per skill, including a boundary case.
2. Add nearby requests that must not select the skill.
3. Compare no skill, explicitly supplied skill, and automatic selection from the full library.
4. Compare the current body with a reduced body on the same fixtures.
5. Record task success, selection errors, tokens, elapsed time, retries, model, runtime version, and skill commit.

Keep memory and tool access equal between conditions. Repeat runs before making strong claims. Use deterministic checks for artifacts and commands; use review for report quality. Keep customer data and live publication out of fixtures. Start with existing tools and JSON results rather than building an evaluation platform.

### 5. Medium: reduce instruction and documentation overhead

All inspected entry points are below 500 lines. That does not mean they contain only necessary content.

- `release-runbook`: 387 lines. Move ecosystem tables, tutorials, and repeated examples into existing references. Keep project detection, required checks, version targets, failure behavior, and publication scope in the entry point.
- `marimo`: 333 lines. Retain reactive execution constraints and common failure recovery. Move ordinary API examples to references and verify guidance against supported versions.
- `pentest-toolkit`: 451 lines. Keep selection rules, authorized scope, script choice, and result interpretation. Move command catalogs and output samples into references.
- `skill-creator`: 230 lines. Replace the mandatory wizard with task extraction, a minimal draft, example tasks, and paired evaluation. Ask only for missing requirements. Generate manifests, README files, and troubleshooting documents only when distribution needs them. Its standalone layout example also conflicts with the repository's stated nested-layout requirement.
- `git-xray`: distinguish observations from hypotheses. Commit counts do not establish project health, and churn does not prove unresolved defects. Preserve the commands but remove categorical diagnoses and claims that five commands must precede all code reading. Add `HEAD` to `git shortlog` for predictable noninteractive execution.
- `antinote`: narrow the description so a generic note request does not select a specific application without established user context. Its body already asks which application is intended when uncertain.
- `tmux`: clarify the helper's plugin-root path. Its entry point is nested, while `tmuxctl.sh` is at the plugin root. Also align the directory name `tmux` with the portable skill name `cli-tmux`, or document this as a runtime-specific alias.
- `steel-org-recon`: preserve its evidence collection, bounded sampling, and outcome analysis. Replace project-relative installation paths with paths resolved from the installed skill. Declare access and tool prerequisites under compatibility information.

The three guides plus `CONTRIBUTING.md` contain 3,311 lines. Consolidate them into a short contribution procedure, a layout reference, and evaluation instructions. Remove duplicated upstream tutorials. This reduces maintenance; those guides do not all load automatically into model context.

Suggested line counts are experiments, not acceptance criteria. Retain instructions that prevent observed errors even when they add length.

## Implementation order

1. Fix the reproduced release defects and add focused fixture tests.
2. Reconcile duplicate trees and choose one source layout.
3. Add static validation for metadata, catalog consistency, helper paths, and packaged files.
4. Correct permission/loading documentation and remove unsupported feature claims.
5. Run the paired pilot before shortening more skills or removing useful capabilities.

Keep `git-xray`'s distribution intent explicit: it exists on disk but is absent from the marketplace catalog. Do not add it automatically if it is intended as a direct-install skill.

## Verified checks and open questions

Verified locally: tracked inventory, manifests, entry-point lengths, duplicate byte comparisons, evaluation assets, and the two disposable release reproductions. The Cargo reproduction executed only the existing updater function. The patch reproduction used dry-run mode with pushing and release creation disabled.

Open: plugin installation behavior on supported runtime versions; skillctl installation behavior; activation precision; quality and cost changes after reduction; supported ecosystem versions; whether uncataloged skills are intentionally direct-install only. No live runtime installation or end-to-end skill evaluation was performed.
