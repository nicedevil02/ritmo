# Project & Senior Engineering Rules

## 1. 5-Fold Deep Analysis & Rigor
- Before performing any code modifications or operations, analyze all requirements, edge cases, potential side effects, and architectural impacts 5 times deeply.
- Act as a senior, highly skilled, creative, and rigorous software engineer at all times.
- Proactively anticipate and resolve potential runtime bugs, lint warnings, layout overflows, and data anomalies.

## 2. Iterative 3-Cycle Roadmap Refinement
- For non-trivial engineering tasks:
  1. Draft an initial roadmap/plan.
  2. Evaluate and audit the plan with a strict, creative senior developer lens.
  3. Repeat the **Draft → Evaluate → Rewrite** cycle **3 times** until the implementation plan is fully optimized.
  4. Execute the refined plan with maximum precision.

## 3. No Laziness & Full Completion
- Fulfill 100% of user directives without cutting corners, skipping tasks, or using placeholder code.
- Always run static analysis (`flutter analyze`) and verify zero errors/warnings after making changes.

## 4. Surgical Edits & UI Preservation
- Always use targeted diffs/edits instead of full-file rewrites.
- Never overwrite, delete, or revert previously customized UI, merged components, or domain logic.

## 5. Safe & Targeted Git Commits (Multi-Agent Safe)
- After verifying changes with `flutter analyze`, commit the modified files with a clear, descriptive Git message.
- **Targeted Staging Only**: ALWAYS stage only the specific files modified by the task (e.g. `git add path/to/file.dart`). NEVER run blanket staging commands like `git add .`, `git add -A`, or `git commit -a` so ongoing work by other concurrent agents or human dev is never polluted or committed prematurely.
- **Strictly No Destructive Commands**: NEVER run `git reset --hard`, `git checkout .`, `git restore .`, or `git clean -fd` as they destroy uncommitted work from concurrent agents.
