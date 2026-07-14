import hashlib
import json
import subprocess
import tempfile
import time
import unittest
from pathlib import Path

from scripts.build_sprite_assets import (
    AssetBuildError,
    _auto_frame_crops,
    _expanded_clips,
    _frame_crops,
    build_assets,
)


class BuildSpriteAssetsTests(unittest.TestCase):
    def setUp(self):
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary_directory.name)
        self.board = self.root / "board.png"
        subprocess.run(
            [
                "magick",
                "-size",
                "24x16",
                "xc:#101820",
                "-fill",
                "#ff3b30",
                "-draw",
                "rectangle 2,4 7,13",
                "-fill",
                "#34c759",
                "-draw",
                "rectangle 14,2 20,13",
                str(self.board),
            ],
            check=True,
        )
        self.manifest = self.root / "manifest.json"
        self.output = self.root / "output"

    def tearDown(self):
        self.temporary_directory.cleanup()

    def test_production_hero_sources_preserve_edge_connected_silhouettes(self):
        project_root = Path(__file__).resolve().parents[2]
        manifest = json.loads((project_root / "art/sprite-manifest.json").read_text())

        for source_id in ("dps", "tank", "healer"):
            with self.subTest(source_id=source_id):
                source = manifest["sources"][source_id]
                self.assertTrue(source.get("edgeConnectedBackground"))
                self.assertEqual(source.get("backgroundFuzz"), 2)

    def test_rejects_source_hash_mismatch_without_writing_output(self):
        self._write_manifest(source_hash="0" * 64)

        with self.assertRaisesRegex(AssetBuildError, "checksum mismatch"):
            build_assets(self.manifest, self.output)

        self.assertFalse(self.output.exists())

    def test_builds_transparent_equal_cell_strip_and_runtime_manifest(self):
        self._write_manifest(source_hash=self._sha256(self.board))

        runtime = build_assets(self.manifest, self.output)

        strip = self.output / "test-hero" / "idle.png"
        self.assertTrue(strip.is_file())
        identify = subprocess.run(
            [
                "magick",
                "identify",
                "-format",
                "%w|%h|%[channels]|%[fx:minima.a]|%[fx:maxima.a]",
                str(strip),
            ],
            check=True,
            capture_output=True,
            text=True,
        ).stdout.split("|")
        self.assertEqual(identify[:2], ["192", "64"])
        self.assertIn("a", identify[2].lower())
        self.assertEqual(float(identify[3]), 0)
        self.assertEqual(float(identify[4]), 1)

        self.assertEqual(runtime["version"], 1)
        self.assertEqual(runtime["cell"], {"width": 96, "height": 64})
        self.assertEqual(runtime["clips"], [{
            "action": "idle",
            "frameCount": 2,
            "repeats": True,
            "resource": "test-hero/idle.png",
            "secondsPerFrame": 0.125,
            "token": "test-hero",
        }])
        self.assertEqual(
            json.loads((self.output / "manifest.json").read_text()),
            runtime,
        )

    def test_preserves_enclosed_pixels_that_match_dark_board_background(self):
        dark_actor = self.root / "dark-actor.png"
        subprocess.run(
            [
                "magick",
                "-size",
                "16x16",
                "xc:#101820",
                "-fill",
                "#ff3b30",
                "-draw",
                "rectangle 3,3 12,14",
                "-fill",
                "#101820",
                "-draw",
                "rectangle 6,7 9,10",
                str(dark_actor),
            ],
            check=True,
        )
        payload = {
            "version": 1,
            "cell": {"width": 96, "height": 64},
            "sources": {
                "board": {
                    "path": str(dark_actor),
                    "sha256": self._sha256(dark_actor),
                    "background": "#101820",
                    "edgeConnectedBackground": True,
                }
            },
            "clips": [{
                "token": "test-hero",
                "action": "idle",
                "source": "board",
                "frames": [[0, 0, 16, 16]],
                "frameCount": 1,
                "scale": 1,
                "secondsPerFrame": 0.125,
                "repeats": True,
            }],
        }
        self.manifest.write_text(json.dumps(payload))

        build_assets(self.manifest, self.output)

        strip = self.output / "test-hero" / "idle.png"
        opaque_pixel_count = subprocess.run(
            [
                "magick",
                str(strip),
                "-alpha",
                "extract",
                "-format",
                "%[fx:mean*w*h]",
                "info:",
            ],
            check=True,
            capture_output=True,
            text=True,
        ).stdout
        self.assertEqual(float(opaque_pixel_count), 120)

    def test_edge_connected_background_uses_source_specific_fuzz(self):
        low_contrast_actor = self.root / "low-contrast-actor.png"
        subprocess.run(
            [
                "magick",
                "-size",
                "16x16",
                "xc:#101820",
                "-fill",
                "#303840",
                "-draw",
                "rectangle 3,3 12,14",
                "-fill",
                "#ffffff",
                "-draw",
                "rectangle 7,8 8,9",
                str(low_contrast_actor),
            ],
            check=True,
        )
        payload = {
            "version": 1,
            "cell": {"width": 96, "height": 64},
            "sources": {
                "board": {
                    "path": str(low_contrast_actor),
                    "sha256": self._sha256(low_contrast_actor),
                    "background": "#101820",
                    "edgeConnectedBackground": True,
                    "backgroundFuzz": 2,
                }
            },
            "clips": [{
                "token": "test-hero",
                "action": "idle",
                "source": "board",
                "frames": [[0, 0, 16, 16]],
                "frameCount": 1,
                "scale": 1,
                "secondsPerFrame": 0.125,
                "repeats": True,
            }],
        }
        self.manifest.write_text(json.dumps(payload))

        build_assets(self.manifest, self.output)

        strip = self.output / "test-hero" / "idle.png"
        opaque_pixel_count = subprocess.run(
            [
                "magick",
                str(strip),
                "-alpha",
                "extract",
                "-format",
                "%[fx:mean*w*h]",
                "info:",
            ],
            check=True,
            capture_output=True,
            text=True,
        ).stdout
        self.assertEqual(float(opaque_pixel_count), 120)

    def test_edge_connected_background_removes_tiny_disconnected_artifacts(self):
        actor_with_artifact = self.root / "actor-with-artifact.png"
        subprocess.run(
            [
                "magick",
                "-size",
                "16x16",
                "xc:#101820",
                "-fill",
                "#ff3b30",
                "-draw",
                "rectangle 3,3 12,14",
                "-fill",
                "#ffffff",
                "-draw",
                "point 14,1",
                str(actor_with_artifact),
            ],
            check=True,
        )
        payload = {
            "version": 1,
            "cell": {"width": 96, "height": 64},
            "sources": {
                "board": {
                    "path": str(actor_with_artifact),
                    "sha256": self._sha256(actor_with_artifact),
                    "background": "#101820",
                    "edgeConnectedBackground": True,
                    "backgroundFuzz": 2,
                    "componentAreaThreshold": 4,
                }
            },
            "clips": [{
                "token": "test-hero",
                "action": "idle",
                "source": "board",
                "frames": [[0, 0, 16, 16]],
                "frameCount": 1,
                "scale": 1,
                "secondsPerFrame": 0.125,
                "repeats": True,
            }],
        }
        self.manifest.write_text(json.dumps(payload))

        build_assets(self.manifest, self.output)

        strip = self.output / "test-hero" / "idle.png"
        opaque_pixel_count = subprocess.run(
            [
                "magick",
                str(strip),
                "-alpha",
                "extract",
                "-format",
                "%[fx:mean*w*h]",
                "info:",
            ],
            check=True,
            capture_output=True,
            text=True,
        ).stdout
        self.assertEqual(float(opaque_pixel_count), 120)

    def test_expands_actor_action_groups_into_clips(self):
        payload = {
            "version": 1,
            "cell": {"width": 96, "height": 64},
            "sources": {
                "board": {
                    "path": str(self.board),
                    "sha256": self._sha256(self.board),
                    "background": "#101820",
                }
            },
            "clipGroups": [{
                "source": "board",
                "scale": 1,
                "actors": [{"token": "test-hero", "origin": [0, 0]}],
                "actions": [{
                    "action": "idle",
                    "region": [0, 0, 24, 16],
                    "frameCount": 2,
                    "secondsPerFrame": 0.125,
                    "repeats": True,
                }],
            }],
        }
        self.manifest.write_text(json.dumps(payload))

        runtime = build_assets(self.manifest, self.output)

        self.assertEqual(len(runtime["clips"]), 1)
        self.assertEqual(runtime["clips"][0]["token"], "test-hero")
        self.assertEqual(runtime["clips"][0]["frameCount"], 2)

        expanded = _expanded_clips(payload)
        self.assertEqual(expanded[0]["topInsetRatio"], 0.20)

    def test_repeated_builds_are_byte_identical(self):
        self._write_manifest(source_hash=self._sha256(self.board))
        first = self.root / "first"
        second = self.root / "second"

        build_assets(self.manifest, first)
        time.sleep(1.1)
        build_assets(self.manifest, second)

        first_hashes = {
            path.relative_to(first): self._sha256(path)
            for path in first.rglob("*")
            if path.is_file()
        }
        second_hashes = {
            path.relative_to(second): self._sha256(path)
            for path in second.rglob("*")
            if path.is_file()
        }
        self.assertEqual(first_hashes, second_hashes)

    def test_auto_frames_separate_uneven_foreground_clusters(self):
        uneven = self.root / "uneven.png"
        subprocess.run(
            [
                "magick", "-size", "24x16", "xc:#101820",
                "-fill", "#ffffff", "-draw", "rectangle 0,0 23,1",
                "-fill", "#ff0000", "-draw", "rectangle 1,4 6,13",
                "-fill", "#00ff00", "-draw", "rectangle 9,2 21,13",
                "-fill", "#0000ff", "-draw", "rectangle 23,4 23,13",
                str(uneven),
            ],
            check=True,
        )
        payload = {
            "version": 1,
            "cell": {"width": 96, "height": 64},
            "sources": {"board": {
                "path": str(uneven),
                "sha256": self._sha256(uneven),
                "background": "#101820",
            }},
            "clips": [{
                "token": "test-hero",
                "action": "idle",
                "source": "board",
                "region": [0, 0, 24, 16],
                "frameCount": 2,
                "autoFrames": True,
                "secondsPerFrame": 0.125,
                "repeats": True,
            }],
        }
        self.manifest.write_text(json.dumps(payload))

        build_assets(self.manifest, self.output)

        strip = self.output / "test-hero" / "idle.png"
        first_green = subprocess.run(
            ["magick", str(strip), "-crop", "96x64+0+0", "+repage", "-format", "%[fx:maxima.g]", "info:"],
            check=True,
            capture_output=True,
            text=True,
        ).stdout
        second_red = subprocess.run(
            ["magick", str(strip), "-crop", "96x64+96+0", "+repage", "-format", "%[fx:maxima.r]", "info:"],
            check=True,
            capture_output=True,
            text=True,
        ).stdout
        second_blue = subprocess.run(
            ["magick", str(strip), "-crop", "96x64+96+0", "+repage", "-format", "%[fx:maxima.b]", "info:"],
            check=True,
            capture_output=True,
            text=True,
        ).stdout
        self.assertEqual(float(first_green), 0)
        self.assertEqual(float(second_red), 0)
        self.assertEqual(float(second_blue), 0)

    def test_grouped_action_can_override_actor_scale(self):
        manifest = {
            "clipGroups": [{
                "source": "board",
                "scale": 1,
                "actors": [{"token": "test-hero", "origin": [0, 0]}],
                "actions": [{
                    "action": "classAction",
                    "region": [0, 0, 24, 16],
                    "frameCount": 1,
                    "scale": 0.5,
                    "secondsPerFrame": 0.1,
                    "repeats": False,
                }],
            }],
        }

        clips = _expanded_clips(manifest)

        self.assertEqual(clips[0]["scale"], 0.5)

    def test_equal_regions_apply_declared_top_content_inset(self):
        crops = _frame_crops({
            "region": [0, 0, 24, 20],
            "frameCount": 2,
            "topInsetRatio": 0.25,
        })

        self.assertEqual(crops, [[0, 5, 12, 15], [12, 5, 12, 15]])

    def test_auto_regions_apply_declared_top_content_inset(self):
        crops = _auto_frame_crops(
            self.board,
            "#101820",
            [0, 0, 24, 16],
            2,
            top_inset_ratio=0.25,
        )

        self.assertEqual([crop[1:] for crop in crops], [[4, 6, 12], [4, 7, 12]])

    def test_grouped_actor_can_override_action_frame_count(self):
        manifest = {
            "clipGroups": [{
                "source": "board",
                "actors": [{
                    "token": "test-hero",
                    "origin": [0, 0],
                    "frameCounts": {"idle": 1},
                }],
                "actions": [{
                    "action": "idle",
                    "region": [0, 0, 24, 16],
                    "frameCount": 2,
                    "secondsPerFrame": 0.1,
                    "repeats": True,
                }],
            }],
        }

        clips = _expanded_clips(manifest)

        self.assertEqual(clips[0]["frameCount"], 1)

    def test_grouped_actor_frame_count_limits_explicit_frames(self):
        manifest = {
            "clipGroups": [{
                "source": "board",
                "actors": [{
                    "token": "test-hero",
                    "origin": [0, 0],
                    "frameCounts": {"idle": 1},
                }],
                "actions": [{
                    "action": "idle",
                    "region": [0, 0, 24, 16],
                    "frames": [[1, 2, 3, 4], [5, 6, 7, 8]],
                    "frameCount": 2,
                    "secondsPerFrame": 0.1,
                    "repeats": True,
                }],
            }],
        }

        clips = _expanded_clips(manifest)

        self.assertEqual(clips[0]["frames"], [[1, 2, 3, 4]])

    def test_grouped_actor_can_override_action_frames(self):
        manifest = {
            "clipGroups": [{
                "source": "board",
                "actors": [{
                    "token": "test-hero",
                    "origin": [100, 200],
                    "actionFrames": {"idle": [[1, 2, 3, 4]]},
                }],
                "actions": [{
                    "action": "idle",
                    "region": [0, 0, 24, 16],
                    "frameCount": 2,
                    "secondsPerFrame": 0.1,
                    "repeats": True,
                }],
            }],
        }

        clips = _expanded_clips(manifest)

        self.assertEqual(clips[0]["frameCount"], 1)
        self.assertEqual(clips[0]["frames"], [[101, 202, 3, 4]])

    def test_grouped_frames_are_relative_to_actor_origin(self):
        manifest = {
            "clipGroups": [{
                "source": "board",
                "actors": [{"token": "test-hero", "origin": [100, 200]}],
                "actions": [{
                    "action": "idle",
                    "region": [0, 0, 24, 16],
                    "frames": [[1, 2, 3, 4]],
                    "frameCount": 1,
                    "secondsPerFrame": 0.1,
                    "repeats": True,
                }],
            }],
        }

        clips = _expanded_clips(manifest)

        self.assertEqual(clips[0]["frames"], [[101, 202, 3, 4]])

    def _write_manifest(self, source_hash):
        payload = {
            "version": 1,
            "cell": {"width": 96, "height": 64},
            "sources": {
                "board": {
                    "path": str(self.board),
                    "sha256": source_hash,
                    "background": "#101820",
                }
            },
            "clips": [
                {
                    "token": "test-hero",
                    "action": "idle",
                    "source": "board",
                    "region": [0, 0, 24, 16],
                    "frameCount": 2,
                    "secondsPerFrame": 0.125,
                    "repeats": True,
                }
            ],
        }
        self.manifest.write_text(json.dumps(payload))

    @staticmethod
    def _sha256(path):
        return hashlib.sha256(path.read_bytes()).hexdigest()


if __name__ == "__main__":
    unittest.main()
