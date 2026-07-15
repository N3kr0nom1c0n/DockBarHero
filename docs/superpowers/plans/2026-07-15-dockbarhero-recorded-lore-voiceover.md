# DockBarHero Recorded Lore Voiceover Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace lore runtime TTS with bundled ElevenLabs-generated character audio assets for every spoken dialogue cue.

**Architecture:** Keep the existing `LoreReaderController` and `LoreSpeechControlling` boundary. Add an offline asset-generation script that reads `SpokenDialogue.json`, a non-secret voice-cast manifest, and `ELEVENLABS_API_KEY`, then writes MP3 assets plus an audio manifest into `DockBarHero/Lore/Resources/Audio`. At runtime, replace `SystemLoreSpeechService` with an asset-backed AVFoundation player that resolves cue ID, language mode, and gain without calling ElevenLabs.

**Tech Stack:** Swift, AVFoundation, JSON bundled resources, Python 3 standard library for generation, ElevenLabs API for offline generation only.

## Global Constraints

- Do not store `ELEVENLABS_API_KEY` in the repo.
- Load the key from `ELEVENLABS_API_KEY`; local convenience file is `~/.config/dockbarhero/elevenlabs.env`.
- The locked voice cast is: Book `Vs5CmVCVJwW4odQS2pVf`, Kevin `GsfuR3Wo2BACoxELWyEF`, Brick `ROkSP7oeR0SRS2aHJXMo`, Mercy `0G7xjh2pNSLRvJSpklE4`, Kaizen `qXpMhyvQqiRxWQs4qSSB`, Editor `d5QgxQhvRNirnHGpRQdJ`.
- Runtime playback must remain silent unless the Book is open, spoken dialogue is enabled, and the application is active.
- Clean mode must never play unfiltered audio for text whose clean and unfiltered variants differ.
- Generated audio is a presentation asset and must not enter game-save state.
- Execute this plan against a checkout that contains `DockBarHero/Lore/*`, such as `codex/lore-manga-vertical-slice` or a later integration branch.

---

## File Structure

- Create `DockBarHero/Lore/Resources/LoreVoiceCast.json`: non-secret ElevenLabs voice IDs, model ID, output format, and per-speaker voice settings.
- Create `DockBarHero/Lore/Resources/Audio/LoreAudioManifest.json`: generated asset lookup from cue ID and language variant to bundled audio filename.
- Create generated MP3 files under `DockBarHero/Lore/Resources/Audio/`.
- Create `scripts/generate_lore_voice_assets.py`: offline generator; no runtime app dependency.
- Modify `DockBarHero/Lore/SpokenDialogueCatalog.swift`: expose resolved language variant metadata needed by audio lookup.
- Modify `DockBarHero/Lore/LoreSpeechService.swift`: add `RecordedLoreSpeechService`, `LoreAudioManifest`, and an `AVAudioPlayer` adapter.
- Modify `DockBarHero/App/AppDelegate.swift`: construct `RecordedLoreSpeechService` in production.
- Test with `DockBarHeroTests/SpokenDialogueCatalogTests.swift` and a new `DockBarHeroTests/LoreAudioManifestTests.swift`.

### Task 1: Add Voice Cast And Audio Manifest Schemas

**Files:**
- Create: `DockBarHero/Lore/Resources/LoreVoiceCast.json`
- Create: `DockBarHero/Lore/Resources/Audio/LoreAudioManifest.json`
- Create: `DockBarHeroTests/LoreAudioManifestTests.swift`
- Modify: `DockBarHero/Lore/LoreSpeechService.swift`

**Interfaces:**
- Produces: `LoreAudioManifest.assetName(cueID: String, languageMode: LoreLanguageMode) -> String?`
- Produces: `LoreAudioEntry { cueID: String, unfiltered: String, clean: String }`

- [ ] **Step 1: Write failing manifest decode tests**

Add `DockBarHeroTests/LoreAudioManifestTests.swift`:

```swift
import XCTest
@testable import DockBarHero

final class LoreAudioManifestTests: XCTestCase {
    func testManifestResolvesLanguageSpecificAssets() throws {
        let manifest = LoreAudioManifest(schemaVersion: 1, entries: [
            .init(cueID: "book.test", unfiltered: "book.test.unfiltered.mp3", clean: "book.test.clean.mp3")
        ])

        XCTAssertEqual(manifest.assetName(cueID: "book.test", languageMode: .unfiltered), "book.test.unfiltered.mp3")
        XCTAssertEqual(manifest.assetName(cueID: "book.test", languageMode: .clean), "book.test.clean.mp3")
        XCTAssertNil(manifest.assetName(cueID: "missing", languageMode: .clean))
    }

    func testBundledManifestRejectsDuplicateCueIDs() throws {
        let manifest = LoreAudioManifest(schemaVersion: 1, entries: [
            .init(cueID: "book.test", unfiltered: "a.mp3", clean: "a.mp3"),
            .init(cueID: "book.test", unfiltered: "b.mp3", clean: "b.mp3")
        ])

        XCTAssertThrowsError(try LoreAudioManifest.validated(manifest)) { error in
            XCTAssertEqual(error as? LoreAudioManifestError, .duplicateCueID("book.test"))
        }
    }
}
```

- [ ] **Step 2: Run the failing tests**

Run:

```bash
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -configuration Debug -destination 'platform=macOS,arch=arm64' -only-testing:DockBarHeroTests/LoreAudioManifestTests CODE_SIGNING_ALLOWED=NO
```

Expected: fails because `LoreAudioManifest` does not exist.

- [ ] **Step 3: Add manifest models**

Append focused types to `DockBarHero/Lore/LoreSpeechService.swift`:

```swift
struct LoreAudioManifest: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let entries: [LoreAudioEntry]
}

struct LoreAudioEntry: Codable, Equatable, Sendable {
    let cueID: String
    let unfiltered: String
    let clean: String
}

enum LoreAudioManifestError: Error, Equatable {
    case resourceMissing
    case unsupportedSchema(Int)
    case duplicateCueID(String)
    case missingRequiredValue(String)
}

extension LoreAudioManifest {
    static func bundled(bundle: Bundle = .main) throws -> LoreAudioManifest {
        guard let url = bundle.url(forResource: "LoreAudioManifest", withExtension: "json") else {
            throw LoreAudioManifestError.resourceMissing
        }
        let decoded = try JSONDecoder().decode(LoreAudioManifest.self, from: Data(contentsOf: url))
        return try validated(decoded)
    }

    static func validated(_ manifest: LoreAudioManifest) throws -> LoreAudioManifest {
        guard manifest.schemaVersion == 1 else {
            throw LoreAudioManifestError.unsupportedSchema(manifest.schemaVersion)
        }
        var cueIDs = Set<String>()
        for entry in manifest.entries {
            guard cueIDs.insert(entry.cueID).inserted else {
                throw LoreAudioManifestError.duplicateCueID(entry.cueID)
            }
            guard !entry.cueID.isEmpty, !entry.unfiltered.isEmpty, !entry.clean.isEmpty else {
                throw LoreAudioManifestError.missingRequiredValue(entry.cueID)
            }
        }
        return manifest
    }

    func assetName(cueID: String, languageMode: LoreLanguageMode) -> String? {
        guard let entry = entries.first(where: { $0.cueID == cueID }) else { return nil }
        return languageMode == .clean ? entry.clean : entry.unfiltered
    }
}
```

- [ ] **Step 4: Add placeholder resources**

Create `DockBarHero/Lore/Resources/LoreVoiceCast.json` with the approved non-secret cast:

```json
{
  "schemaVersion": 1,
  "provider": "elevenlabs",
  "modelID": "eleven_multilingual_v2",
  "outputFormat": "mp3_44100_128",
  "speakers": {
    "book": {"voiceName":"Branok - Evil & Villainous","voiceID":"Vs5CmVCVJwW4odQS2pVf","stability":0.34,"similarityBoost":0.82,"style":0.70,"speakerBoost":true},
    "kevin": {"voiceName":"Cooper - Nervous, Dramatic and Timid","voiceID":"GsfuR3Wo2BACoxELWyEF","stability":0.42,"similarityBoost":0.76,"style":0.55,"speakerBoost":true},
    "brick": {"voiceName":"Zoey - Sultry, confident, & luxury","voiceID":"ROkSP7oeR0SRS2aHJXMo","stability":0.68,"similarityBoost":0.80,"style":0.12,"speakerBoost":true},
    "mercy": {"voiceName":"Dr. Lauren - Warm therapist","voiceID":"0G7xjh2pNSLRvJSpklE4","stability":0.58,"similarityBoost":0.80,"style":0.35,"speakerBoost":true},
    "kaizen": {"voiceName":"Horatius - Energetic Character Voice","voiceID":"qXpMhyvQqiRxWQs4qSSB","stability":0.24,"similarityBoost":0.78,"style":0.90,"speakerBoost":true},
    "editor": {"voiceName":"Adam - Deep, Monotone and Commanding","voiceID":"d5QgxQhvRNirnHGpRQdJ","stability":0.72,"similarityBoost":0.78,"style":0.18,"speakerBoost":true}
  }
}
```

Create `DockBarHero/Lore/Resources/Audio/LoreAudioManifest.json`:

```json
{
  "schemaVersion": 1,
  "entries": []
}
```

- [ ] **Step 5: Run tests and commit**

Run the focused test command from Step 2. Expected: pass.

Commit:

```bash
git add DockBarHero/Lore/LoreSpeechService.swift DockBarHero/Lore/Resources/LoreVoiceCast.json DockBarHero/Lore/Resources/Audio/LoreAudioManifest.json DockBarHeroTests/LoreAudioManifestTests.swift
git commit -m "feat: add lore audio manifest schema"
```

### Task 2: Build Offline ElevenLabs Asset Generator

**Files:**
- Create: `scripts/generate_lore_voice_assets.py`
- Modify: `DockBarHero/Lore/Resources/Audio/LoreAudioManifest.json`
- Create: `DockBarHero/Lore/Resources/Audio/*.mp3`

**Interfaces:**
- Consumes: `DockBarHero/Lore/Resources/SpokenDialogue.json`
- Consumes: `DockBarHero/Lore/Resources/LoreVoiceCast.json`
- Produces: variant-specific MP3 assets and `LoreAudioManifest.json`

- [ ] **Step 1: Add generator script**

Create `scripts/generate_lore_voice_assets.py`:

```python
#!/usr/bin/env python3
import argparse
import hashlib
import json
import os
import re
import time
import urllib.error
import urllib.request
from pathlib import Path

def slug(value: str) -> str:
    return re.sub(r"[^A-Za-z0-9_.-]+", "-", value).strip("-")

def request_audio(api_key: str, voice_id: str, model_id: str, output_format: str, text: str, settings: dict) -> bytes:
    payload = {
        "text": text,
        "model_id": model_id,
        "voice_settings": {
            "stability": settings["stability"],
            "similarity_boost": settings["similarityBoost"],
            "style": settings["style"],
            "use_speaker_boost": settings["speakerBoost"],
        },
    }
    url = f"https://api.elevenlabs.io/v1/text-to-speech/{voice_id}?output_format={output_format}"
    request = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "xi-api-key": api_key,
            "Content-Type": "application/json",
            "Accept": "audio/mpeg",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=120) as response:
            return response.read()
    except urllib.error.HTTPError as error:
        body = error.read().decode("utf-8", "replace")
        raise RuntimeError(f"ElevenLabs request failed for voice {voice_id}: HTTP {error.code}: {body}") from error

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dialogue", default="DockBarHero/Lore/Resources/SpokenDialogue.json")
    parser.add_argument("--voice-cast", default="DockBarHero/Lore/Resources/LoreVoiceCast.json")
    parser.add_argument("--output-dir", default="DockBarHero/Lore/Resources/Audio")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    api_key = os.environ.get("ELEVENLABS_API_KEY", "").strip()
    if not api_key and not args.dry_run:
        raise SystemExit("ELEVENLABS_API_KEY is required. Do not store it in the repo.")

    dialogue = json.loads(Path(args.dialogue).read_text(encoding="utf-8"))
    voice_cast = json.loads(Path(args.voice_cast).read_text(encoding="utf-8"))
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    speakers = voice_cast["speakers"]
    entries = []
    total_chars = 0

    for cue in dialogue["cues"]:
        speaker_id = cue["speakerID"]
        speaker = speakers[speaker_id]
        variants = {"unfiltered": cue["unfiltered"], "clean": cue["clean"]}
        generated = {}
        seen_text_to_file = {}
        for variant, text in variants.items():
            total_chars += len(text)
            text_hash = hashlib.sha256(text.encode("utf-8")).hexdigest()[:12]
            filename = f"{slug(cue['id'])}.{variant}.{speaker_id}.{text_hash}.mp3"
            if text in seen_text_to_file:
                generated[variant] = seen_text_to_file[text]
                continue
            target = output_dir / filename
            if args.dry_run:
                print(f"DRY {cue['id']} {variant} {speaker_id} {len(text)} -> {filename}")
            elif not target.exists():
                audio = request_audio(
                    api_key=api_key,
                    voice_id=speaker["voiceID"],
                    model_id=voice_cast["modelID"],
                    output_format=voice_cast["outputFormat"],
                    text=text,
                    settings=speaker,
                )
                target.write_bytes(audio)
                print(f"WROTE {target} {len(audio)} bytes")
                time.sleep(0.15)
            else:
                print(f"SKIP {target}")
            generated[variant] = filename
            seen_text_to_file[text] = filename
        entries.append({"cueID": cue["id"], "unfiltered": generated["unfiltered"], "clean": generated["clean"]})

    manifest = {"schemaVersion": 1, "entries": entries}
    if args.dry_run:
        print(f"DRY total chars including clean variants: {total_chars}")
    else:
        (output_dir / "LoreAudioManifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
```

- [ ] **Step 2: Run dry-run**

Run:

```bash
python3 scripts/generate_lore_voice_assets.py --dry-run
```

Expected: prints every cue variant and total characters without requiring network writes.

- [ ] **Step 3: Generate assets**

Run:

```bash
set -a
source ~/.config/dockbarhero/elevenlabs.env
set +a
python3 scripts/generate_lore_voice_assets.py
```

Expected: writes MP3 files and a populated `DockBarHero/Lore/Resources/Audio/LoreAudioManifest.json`.

- [ ] **Step 4: Verify assets mechanically**

Run:

```bash
find DockBarHero/Lore/Resources/Audio -name '*.mp3' -print0 | xargs -0 file
python3 -m json.tool DockBarHero/Lore/Resources/Audio/LoreAudioManifest.json >/dev/null
```

Expected: every audio file is MPEG layer III audio and the manifest parses.

- [ ] **Step 5: Commit**

```bash
git add scripts/generate_lore_voice_assets.py DockBarHero/Lore/Resources/Audio
git commit -m "art: add recorded lore voiceover assets"
```

### Task 3: Play Bundled Audio Through LoreSpeechControlling

**Files:**
- Modify: `DockBarHero/Lore/LoreSpeechService.swift`
- Test: `DockBarHeroTests/LoreAudioManifestTests.swift`

**Interfaces:**
- Consumes: `LoreAudioManifest.assetName(cueID:languageMode:)`
- Produces: `RecordedLoreSpeechService: LoreSpeechControlling`

- [ ] **Step 1: Extend resolved cue with language mode**

Modify `ResolvedDialogueCue` in `DockBarHero/Lore/SpokenDialogueCatalog.swift`:

```swift
struct ResolvedDialogueCue: Equatable, Sendable {
    let id: String
    let speaker: DialogueSpeaker
    let text: String
    let delivery: String
    let languageMode: LoreLanguageMode
}
```

Modify `resolve(cueID:languageMode:)` to pass the mode:

```swift
return ResolvedDialogueCue(
    id: cue.id, speaker: speaker,
    text: languageMode == .clean ? cue.clean : cue.unfiltered,
    delivery: cue.delivery,
    languageMode: languageMode
)
```

- [ ] **Step 2: Update existing test fixtures**

Where tests construct `ResolvedDialogueCue` directly, add `languageMode: .unfiltered`.

- [ ] **Step 3: Add asset player protocol**

Add to `LoreSpeechService.swift`:

```swift
@MainActor
protocol LoreAudioPlaying: AnyObject {
    func play(resourceName: String, gain: Float)
    func stop()
}

@MainActor
final class AVFoundationLoreAudioPlayer: NSObject, LoreAudioPlaying {
    private var player: AVAudioPlayer?
    private let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    func play(resourceName: String, gain: Float) {
        stop()
        let name = (resourceName as NSString).deletingPathExtension
        let ext = (resourceName as NSString).pathExtension
        guard let url = bundle.url(forResource: name, withExtension: ext) else { return }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = gain
            player.prepareToPlay()
            player.play()
            self.player = player
        } catch {
            self.player = nil
        }
    }

    func stop() {
        player?.stop()
        player = nil
    }
}
```

- [ ] **Step 4: Add recorded service**

Add:

```swift
@MainActor
final class RecordedLoreSpeechService: LoreSpeechControlling {
    private let manifest: LoreAudioManifest
    private let player: LoreAudioPlaying
    private let previewPlayer: LoreAudioPlaying

    init(manifest: LoreAudioManifest, player: LoreAudioPlaying, previewPlayer: LoreAudioPlaying) {
        self.manifest = manifest
        self.player = player
        self.previewPlayer = previewPlayer
    }

    convenience init(bundle: Bundle = .main) throws {
        try self.init(
            manifest: .bundled(bundle: bundle),
            player: AVFoundationLoreAudioPlayer(bundle: bundle),
            previewPlayer: AVFoundationLoreAudioPlayer(bundle: bundle)
        )
    }

    func speak(_ cue: ResolvedDialogueCue, gain: Float) {
        guard let assetName = manifest.assetName(cueID: cue.id, languageMode: cue.languageMode) else { return }
        player.play(resourceName: assetName, gain: gain)
    }

    func stop() { player.stop() }
    func stopPreview() { previewPlayer.stop() }

    func previewGiggle(_ text: String, gain: Float) {
        let cueID: String
        switch text {
        case "Hehehehe.": cueID = "interaction.volume.giggle-02"
        case "Oh ho ho.": cueID = "interaction.volume.giggle-03"
        default: cueID = "interaction.volume.giggle-01"
        }
        guard let assetName = manifest.assetName(cueID: cueID, languageMode: .unfiltered) else { return }
        previewPlayer.play(resourceName: assetName, gain: gain)
    }
}
```

- [ ] **Step 5: Add fake-player tests**

Add to `LoreAudioManifestTests.swift`:

```swift
@MainActor
func testRecordedSpeechUsesCleanAssetWhenCueIsClean() throws {
    let manifest = LoreAudioManifest(schemaVersion: 1, entries: [
        .init(cueID: "book.test", unfiltered: "book.test.unfiltered.mp3", clean: "book.test.clean.mp3")
    ])
    let player = LoreAudioPlayerFake()
    let service = RecordedLoreSpeechService(manifest: manifest, player: player, previewPlayer: LoreAudioPlayerFake())
    let cue = ResolvedDialogueCue(id: "book.test", speaker: .fixture, text: "Clean", delivery: "flat", languageMode: .clean)

    service.speak(cue, gain: 0.4)

    XCTAssertEqual(player.played.map(\.resourceName), ["book.test.clean.mp3"])
    XCTAssertEqual(player.played.map(\.gain), [0.4])
}

@MainActor
private final class LoreAudioPlayerFake: LoreAudioPlaying {
    var played: [(resourceName: String, gain: Float)] = []
    var stopCount = 0
    func play(resourceName: String, gain: Float) { played.append((resourceName, gain)) }
    func stop() { stopCount += 1 }
}
```

- [ ] **Step 6: Run focused tests and commit**

Run:

```bash
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -configuration Debug -destination 'platform=macOS,arch=arm64' -only-testing:DockBarHeroTests/LoreAudioManifestTests -only-testing:DockBarHeroTests/LoreReaderControllerTests -only-testing:DockBarHeroTests/SpokenDialogueCatalogTests CODE_SIGNING_ALLOWED=NO
```

Expected: pass.

Commit:

```bash
git add DockBarHero/Lore/LoreSpeechService.swift DockBarHero/Lore/SpokenDialogueCatalog.swift DockBarHeroTests/LoreAudioManifestTests.swift DockBarHeroTests/LoreReaderControllerTests.swift DockBarHeroTests/SpokenDialogueCatalogTests.swift
git commit -m "feat: play recorded lore voiceover assets"
```

### Task 4: Wire Production To Recorded Speech And Verify

**Files:**
- Modify: `DockBarHero/App/AppDelegate.swift`
- Modify: `docs/qa/review-packets/lore-manga-vertical-slice.md`
- Modify: `PROJECT.md` only after verified milestone if parent orchestrator owns the update.

**Interfaces:**
- Consumes: `try RecordedLoreSpeechService(bundle: .main)`
- Produces: production app playback through bundled assets.

- [ ] **Step 1: Replace production speech construction**

In `AppDelegate.swift`, replace `SystemLoreSpeechService()` construction with:

```swift
let loreSpeech: LoreSpeechControlling
do {
    loreSpeech = try RecordedLoreSpeechService(bundle: .main)
} catch {
    loreSpeech = SystemLoreSpeechService()
}
```

Keep `SystemLoreSpeechService` as fallback so missing generated assets do not break launch.

- [ ] **Step 2: Run full focused lore suite**

Run:

```bash
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -configuration Debug -destination 'platform=macOS,arch=arm64' -only-testing:DockBarHeroTests/LoreCatalogTests -only-testing:DockBarHeroTests/SpokenDialogueCatalogTests -only-testing:DockBarHeroTests/LoreAudioManifestTests -only-testing:DockBarHeroTests/LoreReaderControllerTests CODE_SIGNING_ALLOWED=NO
```

Expected: pass.

- [ ] **Step 3: Run full test suite**

Run:

```bash
xcodebuild test -project DockBarHero.xcodeproj -scheme DockBarHero -configuration Debug -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO
```

Expected: pass.

- [ ] **Step 4: Run context guard**

Run:

```bash
python3 /Users/n3kr0/.codex/skills/maintaining-project-context/scripts/context_guard.py check --root .
```

Expected: pass; `AGENTS.md` and `PROJECT.md` remain within line budgets.

- [ ] **Step 5: Run live verify**

Run:

```bash
./script/build_and_run.sh --verify
```

Expected: app launches. If the Mac session is inspectable, open the Book, enable speech, replay the prologue, check Book/Keven/Brick/Mercy distinction, test volume giggles at detents `0`, `5`, and `10`, close the window, and confirm audio stops immediately.

- [ ] **Step 6: Update QA packet**

Add exact evidence to `docs/qa/review-packets/lore-manga-vertical-slice.md`:

```markdown
## Recorded Voiceover Evidence

- Voice provider: ElevenLabs offline generation only; no runtime network dependency.
- Cast: Book Branok, Kevin Cooper, Brick Zoey, Mercy Dr. Lauren, Kaizen Horatius, Editor Adam.
- Generated asset manifest: `DockBarHero/Lore/Resources/Audio/LoreAudioManifest.json`.
- Automated checks: [paste exact xcodebuild pass counts].
- Live audio QA: [record actual result or mark unchecked; do not infer from tests].
```

- [ ] **Step 7: Commit**

```bash
git add DockBarHero/App/AppDelegate.swift docs/qa/review-packets/lore-manga-vertical-slice.md
git commit -m "feat: wire recorded lore voiceover"
```

## Self-Review

- Spec coverage: This plan covers offline generation, locked cast, no runtime API key, clean/unfiltered variants, manifest validation, AVFoundation playback, Book-open gating preservation, and QA evidence.
- Placeholder scan: No TBD/TODO/fill-later language remains.
- Type consistency: `LoreAudioManifest`, `LoreAudioEntry`, `LoreAudioPlaying`, and `RecordedLoreSpeechService` names are consistent across tasks.
