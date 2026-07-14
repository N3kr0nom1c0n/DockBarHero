# Farming Status Indicator Review Packet

- Branch: `feature/class-actions-and-loot`
- Scope: read-only farming/frontier rail status
- Exclusions: campaign behavior changes, click actions, merge, and release

## TDD and Automated Evidence

- RED: the focused rendering suite failed at the new assertions because `//farmingStatus` did not exist.
- GREEN: all 16 `PrototypeSceneHostTests` passed with zero failures; `** TEST SUCCEEDED **`.
- Full arm64 suite: 345 tests passed with zero failures or unexpected results; `** TEST SUCCEEDED **`.
- Clean unsigned arm64 build: `** BUILD SUCCEEDED **`.

## Exact-Bundle and Live Evidence

- `./script/build_and_run.sh --verify` rebuilt and launched PID 62249 from `/Users/n3kr0/Projects/TBH/.worktrees/heroes-and-party/.build/RunDerivedData/Build/Products/Debug/DockBarHero.app/Contents/MacOS/DockBarHero`.
- Process inspection found exactly one DockBarHero executable at that path.
- In farming mode at selected level 174 and frontier 194, the rail showed orange `FARMING • FRONTIER 194` above `Normal • Enemy Lv. 174`; all three pixel heroes and the centered DPS scale remained unobstructed.
- Selecting the existing `Return to Frontier` control queued level 194 while the persisted mode remained farming. The farming status remained visible until encounter resolution, preserving existing destination precedence.
- Push mode was captured after the boundary committed. The persisted state showed selected level 199, frontier 199, and no queued destination; the farming status was hidden while `Normal • Enemy Lv. 199`, the party sprites, and the DPS scale remained visible.
- The QA build was briefly paused at the process level only to capture the short-lived push presentation before the overpowered party advanced or retreated; it was resumed afterward without editing saves or settings.
- Both settings files retained SHA-256 `1bd458308cf46a91b10dfe45093bf41993bdd24477626ca80278cf6e981a61a9`.

## Final State

- The project context guard reported `project context is valid`; `AGENTS.md` is 28 lines and `PROJECT.md` remains below 150 lines.
- The exact worktree app is running normally after the temporary QA pause.
- The feature branch was pushed with local and remote SHAs matching; it remains isolated, unmerged, and unreleased.
