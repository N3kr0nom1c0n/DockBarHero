# Foundation Upgrade Review Packet

- Accepted base SHA source: `git rev-parse origin/feature/phase-1-playable-slice`
- Candidate SHA source: `git rev-parse HEAD`
- Implementation candidate before evidence: `adeacc97a94a89ec702e5d39c3ceb9795fead5ab`
- Changed contracts: `CombatResolver`, `EncounterDirector`, `RewardResolver`, `SaveMigrationRegistry`, `AppSettings`/`SettingsStore`, `ManagementRoute`, `SpriteCatalog`
- Scope: Foundation Tasks 1-6 only; no party, class, ability, offline progression, Steam, cloud, or economy behavior

## Production Paths

```text
DockBarHero/App/AppDelegate.swift
DockBarHero/App/AppModel.swift
DockBarHero/App/DockBarHeroApp.swift
DockBarHero/App/InventoryView.swift
DockBarHero/App/ManagementRootView.swift
DockBarHero/App/ManagementRoute.swift
DockBarHero/App/ManagementSupport.swift
DockBarHero/App/ManagementView.swift (deleted)
DockBarHero/App/OverviewView.swift
DockBarHero/App/SettingsView.swift
DockBarHero/Core/OverlayState.swift
DockBarHero/Game/CombatResolver.swift
DockBarHero/Game/EncounterDirector.swift
DockBarHero/Game/GameSimulation.swift
DockBarHero/Game/RewardResolver.swift
DockBarHero/Persistence/SaveDocument.swift
DockBarHero/Persistence/SaveMigrationRegistry.swift
DockBarHero/Rendering/BuiltinPixelSprites.swift
DockBarHero/Rendering/PixelSpriteDefinition.swift
DockBarHero/Rendering/PrototypeScene.swift
DockBarHero/Rendering/PrototypeSceneHost.swift
DockBarHero/Rendering/SpriteCatalog.swift
DockBarHero/Settings/AppSettings.swift
DockBarHero/Settings/SettingsSession.swift
DockBarHero/Settings/SettingsStore.swift
```

## Evidence

- Resolver extraction: 56 focused tests, 0 failures.
- Migration registry: 43 focused tests, 0 failures.
- Settings persistence: 54 focused tests, 0 failures.
- Management navigation: 33 focused tests, 0 failures.
- Pixel sprites: 36 focused tests, 0 failures.
- Full gate: 208 tests passed, 0 failed, 0 skipped.
- Build: clean Debug arm64 build succeeded with `CODE_SIGNING_ALLOWED=NO`.
- Context/diff: context valid; Phase 1-to-candidate `git diff --check` clean.
- Live: sprite silhouettes visible; management routes usable while combat advanced; paused setting survived clean relaunch and was restored; passive launch left ChatGPT active.

## Review Decision

- Inline parent review: `APPROVE` for Critical/Important scope.
- Unresolved Critical/Important findings: none.
- External review dispatch: intentionally omitted under the approved 288,699-token budget stop.
- Known risks: first SpriteKit texture upload remains platform-managed; fullscreen behavior relies on unchanged accepted Phase 1 paths plus passing regression tests rather than a repeated live fullscreen cycle.
