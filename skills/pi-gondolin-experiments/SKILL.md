---
name: pi-gondolin-experiments
description: Run controlled experiments or iterative improvement trials with unattended Pi and Gondolin guest tools. Use for fresh trials, agent handoffs, candidate comparisons, or hill climbing with saved evidence.
---

# Run Pi experiments with Gondolin

Keep Pi on the host. Run its project tools in a fresh Gondolin guest for each
session. Use the existing arrangement when it works. Read
[examples and setup](references/examples.md) for dependency setup, configuration,
and comparison or hill-climbing examples.

## Define the trial

Agree on the objective, correctness checks, score direction, budget, and stop
condition from the task. Distinguish the candidate being improved from the
agent doing the improving. Fix the inputs, prompts, model settings, tool access,
and evaluator for comparisons unless that item is the intended variable.

Define what persists. Independent candidates start from the same saved input.
A multi-session trajectory carries only the intended project state forward.
A hill-climbing proposal starts from a saved selected candidate. Keep the best
candidate separately from the latest trial.

## Execute

1. Check Pi, Node.js, Gondolin, QEMU tools, and usable KVM access or the chosen
   fallback. Verify one guest boot, one project edit, and one blocked access
   before scaling a new setup. Select the model explicitly.
2. Prepare a minimal Pi configuration. Disable unrelated extensions, skills,
   MCP servers, and context discovery when they are outside the experiment.
   Keep credentials in host configuration or environment variables.
3. Put only the trial inputs in the guest-mounted project. Keep answer keys,
   trusted evaluators, logs, and result files outside it. Set guest network
   policy explicitly. The bundled extension blocks guest HTTP access.
4. Run `scripts/run_trial.py CONFIG --output NEW_DIRECTORY`. It copies the
   source, hashes inputs, runs the configured command without a shell, saves
   logs and elapsed times, and invokes the evaluator. Each invocation is one
   trial. The output directory must be new.
5. Review behavior and scoring mismatches. Record failed and interrupted
   trials. Retry from the same saved input in a new directory. A nonzero agent
   exit needs diagnosis before calling it an infrastructure or candidate error.
6. Compare candidates on the same cases. Repeat noisy measurements. Select a
   candidate only when it meets correctness checks and the improvement rule.
   For hill climbing, propose the next change from the selected candidate.
7. Stop at the agreed budget or success condition. Check selected candidates
   on held-out cases when tuning can overfit. Export the selected files and
   report results, costs, uncertainty, and remaining failures.

## Preserve the meaning of results

The evaluator returns JSON with a boolean `valid`, plus task-specific metrics
such as `score` and diagnostic details. Define what these mean before trials.
Specify accepted task-state values and the scope of terms such as conflict.
Inspect representative successes and failures. Keep frozen scores if a scorer
has a defect. Label any corrected or manual analysis separately.

Use whole trajectories as independent units for multi-session studies. Keep
agent execution cost separate from the candidate's measured performance.
The runner records timing, not a universal agent-cost metric. Derive tool and
usage counts from Pi event logs for the installed version.

Gondolin controls guest tools and traffic. Host Pi configuration and provider
features remain outside that boundary. The bundled extension covers read,
write, edit, and bash. Review any additional tools before enabling them.
The runner invokes a trusted evaluator on the host. Evaluate untrusted candidate
code inside a sandbox through that evaluator.
