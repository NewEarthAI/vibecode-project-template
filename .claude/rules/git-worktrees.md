# Git Worktree Rules (MANDATORY for all feature/fix work)

## Why
Multiple Claude Code sessions running in parallel cause `.git/index.lock` contention, stale file overwrites, and silent regressions. Worktrees give each session its own isolated working directory.

## How

### Starting work
```bash
cd /Users/justin/Documents/GitHub/BuyBox-AI
git fetch origin main
git worktree add ../buybox-<short-name> -b <branch-name> origin/main
cd ../buybox-<short-name>
npm install
```

### During work
- ALL edits happen in the worktree directory (`../buybox-<short-name>/`)
- NEVER `cd` back to the main repo to edit files
- Each worktree has its own `node_modules`, its own file state, its own index
- No `.git/index.lock` contention — each worktree has its own index file

### Committing
```bash
cd ../buybox-<short-name>
pkill -9 -f "vite" 2>/dev/null
pkill -9 -f "esbuild" 2>/dev/null
source ~/.nvm/nvm.sh && nvm use 24
npm run build
git add <files>
git commit -m "<message>"
git push origin <branch-name>
```

### Cleanup (after PR merged)
```bash
cd /Users/justin/Documents/GitHub/BuyBox-AI
git worktree remove ../buybox-<short-name>
```

### Listing active worktrees
```bash
git worktree list
```

## When NOT to use worktrees
- Quick config-only changes (CLAUDE.md, memory files, rules) — these can be done on main
- Research/investigation sessions that don't edit code
- Sessions that only read files and run queries

## Anti-Patterns
| Wrong | Right |
|-------|-------|
| `git checkout -b feature/x` in main repo | `git worktree add ../buybox-x -b feature/x origin/main` |
| Editing files in main repo while on feature branch | All edits in worktree directory |
| Leaving worktrees after PR merge | `git worktree remove` after merge |
| Running `npm run dev` in main repo while worktree sessions are active | Each worktree runs its own dev server on different ports |
| `npm install` fresh in every worktree | Symlink `node_modules` from primary clone for same-tip branches |

## node_modules in worktrees

`git worktree add` does NOT populate `node_modules`. Fresh worktrees need the dep tree before `npm run test` / `npx tsc` / `npm run build` work.

**Fast path** — symlink from the primary clone (same branch-tip deps):

```bash
ln -sfn /path/to/primary-clone/node_modules ./node_modules
```

- Instant, zero download, zero disk cost
- Works for feature branches descended from primary tip with identical `package-lock.json`
- Symlink survives branch switches within the worktree

**Fresh-install path** — when deps diverge (rebase onto older main, added/removed a package):

```bash
cd ./worktree-path && npm install
```

**Gotcha — `git stash -u` with symlinked `node_modules`**: `stash -u` stashes ALL untracked including the symlink itself. After unstash, the symlink is gone. Solution: re-create the symlink (cheap). Alternative: `.gitignore` the worktree locally if the stash-cycle is frequent.

**Cleanup**: `rm` the symlink BEFORE `git worktree remove`, or the remove command may hang on the external reference.
