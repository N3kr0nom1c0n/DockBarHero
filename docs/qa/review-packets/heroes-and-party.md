# Heroes and Party Review Packet

- Base: `main` at `8acdec4`
- Candidate branch: `feature/heroes-and-party`
- Scope: party state, unlocks, deterministic party combat/rewards, shared inventory with exclusive equipment, management and rail presentation
- Explicit exclusions: merge, release, Class Actions, party-size enemy scaling, retroactive development-save migration

## Automated Evidence

- Party state and persistence: 33 focused tests passed.
- Unlock lifecycle and durability gate: 134 combined tests passed.
- Party combat and proportional rewards: full arm64 suite passed at 275 tests.
- Shared inventory and exclusive equipment: 84 focused tests passed.
- Management and rail presentation: full arm64 suite passed at 285 tests.
- Integrated milestone scenarios: five focused tests passed for solo Boss 25 balance, queued destination precedence, Boss 100 final addition, two-hero partition determinism, and party-size-invariant enemy stats.
- Final full arm64 suite: 290 tests passed with zero failures or unexpected results; `** TEST SUCCEEDED **`.

## Save Isolation

- Existing save files were archived before clean QA under `~/Library/Application Support/com.n3kr0nom1c0n.DockBarHero/heroes-and-party-pre-qa-20260712-204002/`.
- The archive was retained for diagnostics; application and overlay settings remained in place.
- Archived SHA-256 values: `save-v1.backup.json` `889f40d6a4f29f8825974aed77a02619a94268774486e4bf9ab638324ae6f213`; `save-v1.json` `4e9edfdb0eb8f7635d359ff096f090a93b544e8c4ddc53ffb333a469593226f5`; `save-v2.backup.json` `4f406ca23ff1614b32effd3138ca5ac57fb4ab8b49c02eff32fe2636918f9470`; `save-v2.json` `38f8769210ece7f793641d0aca8f80b45da3882a32ad6a139bd42a84373ed50c`.
- Clean QA created a new schema-v2 save and selected DPS as the first hero.

## Live QA Evidence

- The exact worktree executable path was verified from the running process before interaction.
- The clean save opened the first-hero chooser; the DPS click created an active run.
- Boss 25 rewards and `pendingSecond` were present on disk with encounter phase `awaitingPartyChoice` before the second-hero chooser appeared.
- Relaunching the exact worktree bundle reopened the persisted Tank/Healer chooser without resuming combat.
- Choosing Healer resumed combat with two heroes, two equipment owners, exclusive item IDs, two rail sprites, and two health bars.
- Boss 100 added the remaining Tank automatically; no choice phase appeared and combat continued beyond level 101 with three heroes.
- Management showed three ordered hero summaries and shared inventory ownership labels such as `Hero 1 · DPS`, `Hero 2 · Healer`, and `Hero 3 · Tank`.
- With auto-equip temporarily disabled, an unused shared weapon was selected and equipped to Hero 1; the row changed from `No` to `Hero 1 · DPS`. Auto-equip was then restored.
- The rail showed three class-distinct pixel sprites, three health bars and level labels, one enemy, and a centered unobstructed rolling DPS readout.
- A stale app-name QA attachment initially displayed square placeholders without the DPS readout. Relaunching through `./script/build_and_run.sh --verify` removed every prior DockBarHero process; the only running executable was the absolute worktree bundle, which displayed the pixel sprites and DPS readout correctly. No production rendering change was justified by the verified bundle.
- Down/revival visuals, queued destination precedence, and remedial retreat were not forced in the clean live run; deterministic focused tests cover those behaviors and they are not claimed here as visual evidence.

## Safety and Review

- Gameplay continues to use signed integer nanosecond timing; party XP multiplication and state transitions are checked and transactional.
- Equipment validation rejects cross-hero sharing and unlock construction rolls back as one candidate state.
- Existing queued-destination precedence remains ahead of automatic remedial retreat.
- Self-review found no unresolved Critical or Important issue in milestone scope.
- The branch is not merged, released, or extended into Class Actions.

## Final Gate

- `xcodegen generate` succeeded and `git diff --check` was clean.
- `xcodebuild test` with `platform=macOS,arch=arm64` and `.build/HeroesFull` passed 290 tests with zero failures.
- `xcodebuild clean build` with `platform=macOS,arch=arm64`, `.build/HeroesBuild`, and `CODE_SIGNING_ALLOWED=NO` reported both `** CLEAN SUCCEEDED **` and `** BUILD SUCCEEDED **`.
- The project context guard reported `project context is valid`; `AGENTS.md` is 28 lines and `PROJECT.md` remains below 150 lines.
- `./script/build_and_run.sh --verify` built and launched PID 23405 from `.worktrees/heroes-and-party/.build/RunDerivedData/Build/Products/Debug/DockBarHero.app`.
