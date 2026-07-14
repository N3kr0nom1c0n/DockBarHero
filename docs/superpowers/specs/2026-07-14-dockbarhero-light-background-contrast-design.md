# DockBarHero Light-Background Contrast Design

## Goal

Keep rail text and pixel actors readable over pale desktops without changing their accepted appearance over dark desktops.

## Accepted Treatment

- Rail labels retain their existing white or semantic foreground color and gain a crisp black outline approximately one display point wide.
- Every actor retains the exact source texture colors and binary alpha. Character pixels remain fully opaque; only pixels outside the source silhouette remain transparent.
- Every actor gains a crisp one-source-texel black contour outside the existing silhouette. The contour follows animated frames and respects nearest-neighbor filtering.
- The transparent rail, actor dimensions, positions, animation timing, health bars, and ground line do not change.

## Rendering Design

`PrototypeScene` will format label text as an attributed string with foreground color, font, black stroke color, and a negative stroke width so SpriteKit draws both fill and outline. All dynamic label updates will pass through one helper to keep the outline applied during level, cooldown, DPS, and farming-status changes.

Actor nodes will share a small SpriteKit fragment shader. For an opaque source texel the shader returns the original sampled RGBA unchanged. For a transparent texel adjacent to an opaque texel it returns opaque black; otherwise it remains transparent. Because the catalog already crops every animation frame to a 96x64 texture and uses `.nearest` filtering, a one-texel sample step produces a stable pixel contour without regenerating assets.

## Asset Contract

No sprite PNG, source board, manifest, or asset-build rule changes. The current production hero strips contain only alpha 0 and alpha 255, which already satisfies the requirement that the character itself has no partial transparency.

## Rejected Alternatives

- A soft shadow or dark backplate changes the accepted dark-background appearance and does not match the selected crisp treatment.
- Regenerating sprite assets risks recoloring or erasing interior pixels and is unnecessary because their alpha is already binary.
- Duplicating eight shadow sprites complicates texture-animation synchronization and actor identity compared with one shared shader.

## Verification

- A regression test proves every rail label carries a black stroke while preserving its intended foreground color.
- A regression test proves hero and enemy actors use the outline shader and its one-texel sampling step while retaining their original texture, size, scale, and opacity.
- Focused scene tests, the full arm64 suite, clean unsigned build, context guard, and live launch verification must pass.
- Live visual acceptance must cover both a pale desktop and a dark desktop. Automated checks are not a substitute for that visual evidence.
