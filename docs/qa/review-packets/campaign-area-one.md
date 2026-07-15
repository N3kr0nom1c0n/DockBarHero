# Campaign Area One Review Packet

**Date:** 2026-07-15

**Branch:** local `main` at merge `08542fe`

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
| Full combined arm64 XCTest suite | PASS final (2026-07-15): 544 tests, 0 failures (`** TEST SUCCEEDED **`) |
| Local `main` post-merge gate | PASS (2026-07-15): 544 tests, 16 Python tests, clean unsigned build, exact-root launch |
| Sprite-pipeline Python suite | PASS (2026-07-15): 16 tests, 0 failures |
| Clean unsigned Apple Silicon build | PASS (2026-07-15): `** BUILD SUCCEEDED **` |
| Context, whitespace, and merge checks | PASS (2026-07-15): context guard, `git diff --check`, and no unmerged entries |

## Integration Decisions

- Authored `CampaignPresentation.enemySpriteID` wins for Area One; procedural presentations continue through `EnemySpriteResolver`.
- Campaign enemy IDs map to production `SpriteToken` clips without changing save data.
- Rail actors remain 54x36 at normal widths and scale proportionally only when a narrow three-hero lane cannot fit.
- Explicit node metadata updates prevent a reused actor node from retaining a stale enemy identity.

## Live QA Status

PASS on the exact integration bundle. The farming selector exposed named authored enemies for Levels 1 through 25 and procedural labels from Level 26 onward. Selecting Level 1 showed the full area name and `Slime · Normal · Enemy Lv. 1` in management; the rail exposed the same identity, readable outlined labels, both hero sprites, the full scrolling title, and its settled `Shallow Depths` title. The original Level 85 frontier was restored and verified in Push mode after inspection.
