# Campaign Area One Review Packet

**Date:** 2026-07-15

**Branch:** `codex/integrate-current-worktrees`

**Scope:** deterministic authored dungeon encounters for Levels 1 through 25, campaign presentation, enemy identity/stat profiles, production sprite selection, and procedural compatibility from Level 26 onward.

## Delivered

- Validated `CampaignCatalog.standard` content for The Forgotten Shallow Depths That Were Remembered.
- Deterministic campaign resolution and typed enemy construction for ordinary, elite, and Boss 25 encounters.
- Transient area/enemy presentation in the management UI and SpriteKit rail, including the area-title marquee.
- Authored sprite identity mapped to bundled production clips; the existing generic fallback remains available for missing artwork.
- Existing schema-v2 save shape, farming/frontier behavior, class actions, party progression, loot, and procedural Level 26+ behavior remain intact.

## Automated Evidence

| Check | Result |
|---|---|
| Focused campaign/rendering/catalog suite | PASS (2026-07-15): 111 tests, 0 failures |
| Full combined arm64 XCTest suite | PASS (2026-07-15): 543 tests, 0 failures (`** TEST SUCCEEDED **`) |
| Sprite-pipeline Python suite | PASS (2026-07-15): 16 tests, 0 failures |
| Clean unsigned Apple Silicon build | PASS (2026-07-15): `** BUILD SUCCEEDED **` |
| Context, whitespace, and merge checks | PASS (2026-07-15): context guard, `git diff --check`, and no unmerged entries |

## Integration Decisions

- Authored `CampaignPresentation.enemySpriteID` wins for Area One; procedural presentations continue through `EnemySpriteResolver`.
- Campaign enemy IDs map to production `SpriteToken` clips without changing save data.
- Rail actors remain 54x36 at normal widths and scale proportionally only when a narrow three-hero lane cannot fit.
- Explicit node metadata updates prevent a reused actor node from retaining a stale enemy identity.

## Live QA Status

Exact integration-bundle inspection is pending. Automated evidence is not being treated as proof of the area marquee, enemy labels, hero visibility, or light/dark contrast in the running app.
