# Setup and examples

## Dependency setup

Use an existing tested installation when available. For a new installation,
install Pi and Gondolin in a separate tools directory. Copy the bundled
`assets/gondolin.ts` beside its `node_modules` directory so imports resolve.
For the versions used during development, run these commands after setting
`trial_tools` and `skill_dir` to absolute paths.

```bash
mkdir -p "$trial_tools"
npm install --prefix "$trial_tools" @earendil-works/pi-coding-agent@1.5.2 @earendil-works/gondolin@0.14.0
cp "$skill_dir/assets/gondolin.ts" "$trial_tools/gondolin.ts"
```

Version 0.14.0 needed `qemu-img` and `qemu-system-x86_64` on the tested Linux
host. KVM required process access to `/dev/kvm`. Use the host's existing access
arrangement. The skill runner does not change permissions or elevate Pi.
Other hosts may need another backend. Resolve that before running trials.

Configure the model in a separate Pi directory. Set `PI_CODING_AGENT_DIR` to
that directory before invoking the runner. Use the installed Pi authentication
mechanism. Keep keys out of trial configuration, prompts, and project inputs.
Pin and record selected dependency versions for comparisons.

The extension is adapted from the upstream
[Pi example](https://github.com/earendil-works/gondolin/blob/main/host/examples/pi-gondolin.ts).
It adds an empty HTTP allowlist. Keep the upstream Apache-2.0 attribution in
`assets/LICENSE-gondolin` when distributing the extension. To test website
access, change the copied extension's `allowedHosts` to the needed hosts and
save that copy with the experiment protocol. Pi's model connection remains
on the host.

## One trial configuration

Copy `assets/trial.json` outside the input project and replace its absolute
paths. The runner expands only `{project}`, `{output}`, and `{prompt}` in
command arguments. Paths inside the configuration are absolute. It invokes
the evaluator from the configuration directory. Environment values are inherited
and are not copied into the manifest. Source snapshots support regular files
and directories. The runner rejects symlinks.

The evaluator writes one JSON object to standard output, for example
`{"valid": true, "score": 0.92, "details": {"errors": 0}}`.
Send diagnostic logs to standard error. Return a nonzero process exit for an
evaluator execution failure. Return `valid: false` for an invalid candidate.

Use a new output path for every attempt.

```bash
python3 "$skill_dir/scripts/run_trial.py" /absolute/experiment/trial.json --output /absolute/results/trial-001
```

Keep the configuration, evaluator, held-out cases, and output outside the guest
mount. The output contains the copied project, manifest, prompt, agent event
log, evaluation output, and result. Failed attempts retain their evidence.
The runner does not select a winner or silently resume an interrupted trial.
For a retry, use the same source snapshot and a new output directory.

## Example 1 — compare two note formats

Prepare two input snapshots with the same decision facts. Use metadata in one
and prose in the other. Use the same prompt, model, and evaluator for both.

Example prompt

> Read the decision history and configure the approved export format. Preserve
> its approver and approval date in report.json. Update the verification date
> to the supplied session date, 2026-11-18.

The evaluator checks the actual configuration and report against a host-side
answer key. It returns `valid` and individual check results. Record tool calls
and model usage from the event logs separately. Repeat from the saved inputs
when model variability matters. For a later session, use the previous trial's
project as the source and apply only the planned external changes. Start a
new Pi process and guest. Keep the answer key outside the project.

## Example 2 — shorten a maintained note

Save a selected starting note with its verified facts. The objective is fewer
words while retaining all required information. Define required facts and
allowed paraphrases before proposing changes.

Example prompt

> Shorten knowledge.md while preserving all recorded approvals, event dates,
> verification dates, and replacement relationships. Change only that file.

Use a trusted evaluator to check preservation and count words. A simple toy
case can require fixed factual lines and allow the agent to shorten the prose
around them. Use `valid` for factual preservation and `score` for word count,
with lower scores preferred. Evaluate the starting note with the same evaluator
to establish the baseline.

Run each proposal from a copy of the selected project. Keep its proposal,
score, and diff. Select it only if it stays valid and lowers word count.
An invalid or worse proposal leaves the saved selected project available for
the next attempt. For example, stop after five proposals or three consecutive
proposals without improvement. Check the selected note on separate reader
questions withheld from the editing prompt. Report the initial and selected
scores, failed proposals, and the reader-check results.
