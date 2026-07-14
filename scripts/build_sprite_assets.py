#!/usr/bin/env python3
"""Build deterministic transparent sprite strips from checksum-locked boards."""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import subprocess
import tempfile
from pathlib import Path


class AssetBuildError(RuntimeError):
    """Raised when a sprite source or generated artifact violates the contract."""


def _run(*arguments: str) -> subprocess.CompletedProcess[str]:
    try:
        return subprocess.run(
            ["magick", *arguments],
            check=True,
            capture_output=True,
            text=True,
        )
    except FileNotFoundError as error:
        raise AssetBuildError("ImageMagick executable 'magick' is required") from error
    except subprocess.CalledProcessError as error:
        detail = error.stderr.strip() or error.stdout.strip() or "unknown ImageMagick failure"
        raise AssetBuildError(detail) from error


def _run_bytes(*arguments: str) -> bytes:
    try:
        return subprocess.run(
            ["magick", *arguments],
            check=True,
            capture_output=True,
        ).stdout
    except FileNotFoundError as error:
        raise AssetBuildError("ImageMagick executable 'magick' is required") from error
    except subprocess.CalledProcessError as error:
        detail = error.stderr.decode(errors="replace").strip() or "unknown ImageMagick failure"
        raise AssetBuildError(detail) from error


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def _load_manifest(path: Path) -> dict:
    try:
        payload = json.loads(path.read_text())
    except (OSError, json.JSONDecodeError) as error:
        raise AssetBuildError(f"invalid manifest: {error}") from error
    if payload.get("version") != 1:
        raise AssetBuildError("manifest version must be 1")
    cell = payload.get("cell", {})
    if cell.get("width") != 96 or cell.get("height") != 64:
        raise AssetBuildError("cell dimensions must be 96x64")
    return payload


def _resolve_source(manifest_path: Path, source: dict) -> Path:
    path = Path(source["path"]).expanduser()
    if not path.is_absolute():
        path = manifest_path.parent / path
    return path.resolve()


def _validate_sources(manifest_path: Path, manifest: dict) -> dict[str, Path]:
    resolved: dict[str, Path] = {}
    for source_id, source in sorted(manifest.get("sources", {}).items()):
        path = _resolve_source(manifest_path, source)
        if not path.is_file():
            raise AssetBuildError(f"missing source {source_id}: {path}")
        actual = _sha256(path)
        expected = source.get("sha256")
        if actual != expected:
            raise AssetBuildError(
                f"checksum mismatch for {source_id}: expected {expected}, found {actual}"
            )
        resolved[source_id] = path
    return resolved


def _dimensions(path: Path) -> tuple[int, int]:
    output = _run("identify", "-format", "%w %h", str(path)).stdout.split()
    if len(output) != 2:
        raise AssetBuildError(f"could not read dimensions for {path}")
    return int(output[0]), int(output[1])


def _alpha_extrema(path: Path) -> tuple[float, float]:
    output = _run(
        "identify",
        "-format",
        "%[fx:minima.a] %[fx:maxima.a]",
        str(path),
    ).stdout.split()
    if len(output) != 2:
        raise AssetBuildError(f"could not read alpha for {path}")
    return float(output[0]), float(output[1])


def _build_frame(
    source_path: Path,
    background: str,
    edge_connected_background: bool,
    background_fuzz: float,
    component_area_threshold: int,
    crop: list[int],
    scale: float,
    destination: Path,
) -> None:
    if len(crop) != 4 or any(not isinstance(value, int) for value in crop):
        raise AssetBuildError(f"invalid crop rectangle: {crop}")
    x, y, width, height = crop
    if x < 0 or y < 0 or width <= 0 or height <= 0:
        raise AssetBuildError(f"invalid crop rectangle: {crop}")
    percent = max(1, round(scale * 100))
    trimmed = destination.with_suffix(".trimmed.png")
    if edge_connected_background:
        background_removal = [
            "-bordercolor",
            background,
            "-border",
            "1",
            "-fill",
            "none",
            "-draw",
            "color 0,0 floodfill",
        ]
    else:
        background_removal = ["-transparent", background]
    crop_arguments = [
        str(source_path),
        "-crop",
        f"{width}x{height}+{x}+{y}",
        "+repage",
        "-alpha",
        "on",
        "-fuzz",
        f"{background_fuzz}%",
        *background_removal,
    ]
    cleanup_paths: list[Path] = []
    if component_area_threshold > 0:
        extracted = destination.with_suffix(".extracted.png")
        mask = destination.with_suffix(".mask.png")
        cleaned = destination.with_suffix(".cleaned.png")
        cleanup_paths = [extracted, mask, cleaned]
        _run(*crop_arguments, str(extracted))
        _run(
            str(extracted),
            "-alpha",
            "extract",
            "-threshold",
            "0",
            "-define",
            f"connected-components:area-threshold={component_area_threshold}",
            "-define",
            "connected-components:mean-color=true",
            "-connected-components",
            "8",
            str(mask),
        )
        _run(
            str(extracted),
            "(",
            str(mask),
            "-alpha",
            "copy",
            ")",
            "-compose",
            "DstIn",
            "-composite",
            str(cleaned),
        )
        frame_input = [str(cleaned)]
    else:
        frame_input = crop_arguments
    _run(
        *frame_input,
        "-bordercolor",
        "none",
        "-border",
        "1",
        "-trim",
        "+repage",
        "-filter",
        "point",
        "-resize",
        f"{percent}%",
        str(trimmed),
    )
    frame_width, frame_height = _dimensions(trimmed)
    if frame_width > 96 or frame_height > 64:
        raise AssetBuildError(
            f"normalized frame {crop} is {frame_width}x{frame_height}, exceeding 96x64"
        )
    _, maximum_alpha = _alpha_extrema(trimmed)
    if maximum_alpha == 0:
        raise AssetBuildError(f"empty normalized frame: {crop}")
    _run(
        "-size",
        "96x64",
        "xc:none",
        str(trimmed),
        "-gravity",
        "south",
        "-composite",
        str(destination),
    )
    trimmed.unlink(missing_ok=True)
    for cleanup_path in cleanup_paths:
        cleanup_path.unlink(missing_ok=True)


def _frame_crops(clip: dict) -> list[list[int]]:
    if "frames" in clip:
        return clip["frames"]
    region = clip.get("region")
    count = clip.get("frameCount")
    if (
        not isinstance(region, list)
        or len(region) != 4
        or any(not isinstance(value, int) for value in region)
        or not isinstance(count, int)
        or count <= 0
    ):
        return []
    x, y, width, height = region
    top_inset = round(height * float(clip.get("topInsetRatio", 0)))
    y += top_inset
    height -= top_inset
    if width < count:
        return []
    crops: list[list[int]] = []
    for index in range(count):
        left = x + round(width * index / count)
        right = x + round(width * (index + 1) / count)
        crops.append([left, y, right - left, height])
    return crops


def _auto_frame_crops(
    source_path: Path,
    background: str,
    region: list[int],
    count: int,
    top_inset_ratio: float = 0.20,
) -> list[list[int]]:
    if len(region) != 4 or count <= 0:
        return []
    x, y, width, height = region
    top_inset = round(height * top_inset_ratio)
    content_y = y + top_inset
    content_height = height - top_inset
    alpha = _run_bytes(
        str(source_path),
        "-crop",
        f"{width}x{content_height}+{x}+{content_y}",
        "+repage",
        "-alpha",
        "on",
        "-fuzz",
        "18%",
        "-transparent",
        background,
        "-alpha",
        "extract",
        "-depth",
        "8",
        "gray:-",
    )
    if len(alpha) != width * content_height:
        raise AssetBuildError("unexpected alpha payload while detecting frames")
    active = [
        any(alpha[row * width + column] > 8 for row in range(content_height))
        for column in range(width)
    ]
    ranges: list[list[int]] = []
    start: int | None = None
    for column, is_active in enumerate(active + [False]):
        if is_active and start is None:
            start = column
        elif not is_active and start is not None:
            ranges.append([start, column - 1])
            start = None
    minimum_width = max(2, round(width * 0.03))
    ranges = [
        bounds for bounds in ranges
        if bounds[1] - bounds[0] + 1 >= minimum_width
    ]
    while len(ranges) > count:
        merge_index = min(
            range(len(ranges) - 1),
            key=lambda index: ranges[index + 1][0] - ranges[index][1],
        )
        ranges[merge_index:merge_index + 2] = [[
            ranges[merge_index][0],
            ranges[merge_index + 1][1],
        ]]
    if len(ranges) != count:
        raise AssetBuildError(
            f"detected {len(ranges)} foreground groups, expected {count}, in region {region}"
        )
    crops: list[list[int]] = []
    for index, (left, right) in enumerate(ranges):
        crop_left = left
        crop_right = right + 1
        if index > 0:
            previous_right = ranges[index - 1][1]
            crop_left = max(crop_left, (previous_right + left) // 2 + 1)
        if index + 1 < len(ranges):
            next_left = ranges[index + 1][0]
            crop_right = min(crop_right, (right + next_left) // 2 + 1)
        crops.append([x + crop_left, content_y, crop_right - crop_left, content_height])
    return crops


def _expanded_clips(manifest: dict) -> list[dict]:
    clips = [dict(clip) for clip in manifest.get("clips", [])]
    for group in manifest.get("clipGroups", []):
        for actor in group.get("actors", []):
            origin = actor.get("origin", [0, 0])
            if (
                not isinstance(origin, list)
                or len(origin) != 2
                or any(not isinstance(value, int) for value in origin)
            ):
                raise AssetBuildError(f"invalid actor origin: {origin}")
            for action in group.get("actions", []):
                region = action.get("region")
                if (
                    not isinstance(region, list)
                    or len(region) != 4
                    or any(not isinstance(value, int) for value in region)
                ):
                    raise AssetBuildError(f"invalid grouped region: {region}")
                clip = dict(action)
                clip["token"] = actor["token"]
                clip["source"] = group["source"]
                clip["frameCount"] = actor.get("frameCounts", {}).get(
                    action["action"],
                    action["frameCount"],
                )
                clip["scale"] = action.get(
                    "scale",
                    actor.get("scale", group.get("scale", 1.0)),
                )
                clip["autoFrames"] = action.get(
                    "autoFrames",
                    group.get("autoFrames", True),
                )
                clip["topInsetRatio"] = action.get(
                    "topInsetRatio",
                    group.get("topInsetRatio", 0.20),
                )
                clip["region"] = [
                    origin[0] + region[0],
                    origin[1] + region[1],
                    region[2],
                    region[3],
                ]
                actor_frames = actor.get("actionFrames", {}).get(action["action"])
                if actor_frames:
                    clip["frameCount"] = len(actor_frames)
                    clip["autoFrames"] = False
                    clip["frames"] = [
                        [origin[0] + frame[0], origin[1] + frame[1], frame[2], frame[3]]
                        for frame in actor_frames
                    ]
                elif "frames" in action:
                    clip["frames"] = [
                        [origin[0] + frame[0], origin[1] + frame[1], frame[2], frame[3]]
                        for frame in action["frames"]
                    ][:clip["frameCount"]]
                clips.append(clip)
    return clips


def build_assets(manifest_path: Path, output_root: Path) -> dict:
    manifest_path = Path(manifest_path).resolve()
    output_root = Path(output_root).resolve()
    manifest = _load_manifest(manifest_path)
    sources = _validate_sources(manifest_path, manifest)
    clips = _expanded_clips(manifest)
    if not clips:
        raise AssetBuildError("manifest must contain at least one clip")

    runtime_clips: list[dict] = []
    with tempfile.TemporaryDirectory(prefix="dockbarhero-sprites-") as temporary:
        build_root = Path(temporary) / "output"
        for clip_index, clip in enumerate(
            sorted(clips, key=lambda item: (item["token"], item["action"]))
        ):
            token = clip["token"]
            action = clip["action"]
            source_id = clip["source"]
            if source_id not in sources:
                raise AssetBuildError(f"unknown source {source_id} for {token}/{action}")
            source = manifest["sources"][source_id]
            frames = _frame_crops(clip)
            if clip.get("autoFrames"):
                frames = _auto_frame_crops(
                    sources[source_id],
                    source["background"],
                    clip["region"],
                    clip["frameCount"],
                    float(clip.get("topInsetRatio", 0.20)),
                )
            if not frames:
                raise AssetBuildError(f"clip {token}/{action} has no frames")
            frame_paths: list[Path] = []
            clip_root = Path(temporary) / f"clip-{clip_index}"
            clip_root.mkdir(parents=True)
            scale = float(clip.get("scale", 1.0))
            if scale <= 0:
                raise AssetBuildError(f"clip {token}/{action} has invalid scale")
            for frame_index, crop in enumerate(frames):
                frame_path = clip_root / f"{frame_index:03d}.png"
                _build_frame(
                    sources[source_id],
                    source["background"],
                    bool(source.get("edgeConnectedBackground", False)),
                    float(source.get("backgroundFuzz", 18)),
                    int(source.get("componentAreaThreshold", 0)),
                    crop,
                    scale,
                    frame_path,
                )
                frame_paths.append(frame_path)

            relative_resource = Path(token) / f"{action}.png"
            strip = build_root / relative_resource
            strip.parent.mkdir(parents=True, exist_ok=True)
            _run(*(str(path) for path in frame_paths), "+append", "-strip", str(strip))
            width, height = _dimensions(strip)
            if width != 96 * len(frame_paths) or height != 64:
                raise AssetBuildError(f"invalid strip dimensions for {token}/{action}")
            minimum_alpha, maximum_alpha = _alpha_extrema(strip)
            if minimum_alpha != 0 or maximum_alpha != 1:
                raise AssetBuildError(
                    f"strip {token}/{action} must contain transparent and opaque pixels"
                )
            runtime_clips.append({
                "action": action,
                "frameCount": len(frame_paths),
                "repeats": bool(clip["repeats"]),
                "resource": relative_resource.as_posix(),
                "secondsPerFrame": float(clip["secondsPerFrame"]),
                "token": token,
            })

        runtime = {
            "cell": {"height": 64, "width": 96},
            "clips": runtime_clips,
            "version": 1,
        }
        build_root.mkdir(parents=True, exist_ok=True)
        (build_root / "manifest.json").write_text(
            json.dumps(runtime, indent=2, sort_keys=True) + "\n"
        )
        if output_root.exists():
            shutil.rmtree(output_root)
        shutil.copytree(build_root, output_root)
    return runtime


def _directory_hashes(root: Path) -> dict[str, str]:
    return {
        path.relative_to(root).as_posix(): _sha256(path)
        for path in sorted(root.rglob("*"))
        if path.is_file()
    }


def check_assets(manifest_path: Path, output_root: Path) -> None:
    if not output_root.is_dir():
        raise AssetBuildError(f"missing output directory: {output_root}")
    with tempfile.TemporaryDirectory(prefix="dockbarhero-sprites-check-") as temporary:
        candidate = Path(temporary) / "output"
        build_assets(manifest_path, candidate)
        if _directory_hashes(candidate) != _directory_hashes(output_root):
            raise AssetBuildError("generated sprite assets are stale")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--check", action="store_true")
    arguments = parser.parse_args()
    try:
        if arguments.check:
            check_assets(arguments.manifest, arguments.output)
        else:
            build_assets(arguments.manifest, arguments.output)
    except AssetBuildError as error:
        parser.error(str(error))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
