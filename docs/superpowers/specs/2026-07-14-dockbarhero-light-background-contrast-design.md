# DockBarHero Light-Background Contrast Design

## Goal

Keep rail text and pixel actors readable over pale desktops without changing their accepted appearance over dark desktops.

## Accepted Treatment

- Rail labels retain their existing white or semantic foreground color and gain a crisp black outline approximately one display point wide.
- Every actor retains the exact source texture colors and binary alpha. Character pixels remain fully opaque; only pixels outside the source silhouette remain transparent.
- Every actor gains a crisp one-source-texel black contour outside the existing silhouette. The contour follows animated frames and respects nearest-neighbor filtering.
- The transparent rail, actor dimensions, positions, animation timing, health bars, and ground line do not change.

## Rendering Design

`PrototypeScene` will keep each existing foreground `SKLabelNode` as plain white or semantic-colored text. Eight black child labels, offset by one point around that foreground node and rendered behind it, form the outline without changing or obscuring the fill. All dynamic label updates will pass through one helper so the foreground and outline layers stay synchronized during level, cooldown, DPS, and farming-status changes.

Actor nodes will share a small SpriteKit fragment shader. For an opaque source texel the shader returns the original sampled RGBA unchanged. For a transparent texel adjacent to an opaque texel it returns opaque black; otherwise it remains transparent. Because the catalog already crops every animation frame to a 96x64 texture and uses `.nearest` filtering, a one-texel sample step produces a stable pixel contour without regenerating assets.

The DPS, Tank, and Healer boards will use edge-connected background removal with 2% fuzz. Only board-colored pixels reachable from the crop edge become transparent; enclosed dark costume and body pixels remain opaque. All hero strips will be regenerated deterministically from the checksum-locked source boards.

## Asset Contract

Source boards and character colors do not change. Generated hero PNGs change only through the existing deterministic pipeline. Alpha remains binary, but the extraction contract must also preserve dark interior silhouette pixels instead of globally keying every board-colored pixel.

## Rejected Alternatives

- A soft shadow or dark backplate changes the accepted dark-background appearance and does not match the selected crisp treatment.
- An attributed-string stroke is unsuitable at these small font sizes because SpriteKit can visually swallow the foreground fill and leave the label effectively black.
- Runtime dark fills are rejected because they would guess at missing artwork; the source extraction pipeline must preserve the real dark pixels instead.
- Duplicating eight shadow sprites complicates texture-animation synchronization and actor identity compared with one shared shader.

## Verification

- A regression test proves every rail label keeps a plain foreground node in its intended color above eight synchronized black outline layers.
- A regression test proves hero and enemy actors use the outline shader and its one-texel sampling step while retaining their original texture, size, scale, and opacity.
- A pipeline regression test proves all three production hero sources use edge-connected background removal with 2% fuzz, and the generated asset check proves every shipped strip matches that manifest.
- Focused scene tests, the full arm64 suite, clean unsigned build, context guard, and live launch verification must pass.
- Live visual acceptance must cover both a pale desktop and a dark desktop. Automated checks are not a substitute for that visual evidence.
