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
