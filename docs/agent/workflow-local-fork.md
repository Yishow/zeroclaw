# Local Fork Workflow (Repository-Specific)

For this local workspace, use a fork-first workflow by default.

- Integration target is `origin/main` (personal fork), not `upstream/main`.
- Do not open PRs to upstream unless explicitly requested by the user.
- Keep `upstream` only as sync source and `origin` as publish target.
- Never develop directly on `main`; create/switch to `feat/*` first.

## Preferred Commands

- `git zc start <branch>`: sync base then create/switch feature branch.
- `git zc sync`: sync current branch with upstream (`main` fast-forward, feature branch rebase).
- `git zc build`: run release build and local install.
- `git zc publish`: push current feature branch to `origin`.
- `git zc doctor`: verify remotes and working tree state.

## Minimal Daily Loop

1. `git zc start feat/<name>`
2. Implement and commit changes
3. `git zc sync`
4. `git zc build`
5. `git zc publish`
