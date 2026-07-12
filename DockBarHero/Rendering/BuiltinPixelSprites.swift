import Foundation

enum BuiltinPixelSprites {
    static let definitions: [SpriteToken: [SpriteAction: [PixelSpriteDefinition]]] = [
        .hero: actions(for: hero),
        .enemy: actions(for: enemy),
    ]

    private static func actions(
        for definition: PixelSpriteDefinition
    ) -> [SpriteAction: [PixelSpriteDefinition]] {
        [
            .idle: [definition],
            .attack: [definition],
            .hit: [definition],
            .defeated: [definition],
        ]
    }

    private static let hero = PixelSpriteDefinition(
        width: 12,
        height: 18,
        palette: [
            "H": 0x402B3CFF,
            "S": 0xF2B38BFF,
            "C": 0x2F80C9FF,
            "W": 0xE7EEF6FF,
            "B": 0x27344AFF,
            "K": 0x10151FFF,
        ],
        rows: [
            "............",
            "....HH......",
            "...HSSHH....",
            "...SSSS.....",
            "...HSSHH....",
            "....CC......",
            "...CCCCC....",
            "..CCCCC.W...",
            "..CCCCCWW...",
            "...CCCCCWW..",
            "...CCCCC.W..",
            "...C.C......",
            "..BB.BB.....",
            "..BB.BB.....",
            "..BB.BB.....",
            "..KK.KK.....",
            ".KK...KK....",
            "............",
        ]
    )

    private static let enemy = PixelSpriteDefinition(
        width: 12,
        height: 18,
        palette: [
            "H": 0x211B27FF,
            "S": 0x9AD5A5FF,
            "R": 0xB63D4DFF,
            "A": 0xC7A44AFF,
            "G": 0x384938FF,
            "K": 0x111511FF,
        ],
        rows: [
            "............",
            "......HH....",
            "....HHSSS...",
            ".....SSSS...",
            "....HHSSH...",
            "......RR....",
            "....RRRRR...",
            "...A.RRRRR..",
            "..AARRRRR...",
            ".AARRRRR....",
            "..A.RRRRR...",
            ".....R.R....",
            "....GG.GG...",
            "....GG.GG...",
            "....GG.GG...",
            "....KK.KK...",
            "...KK...KK..",
            "............",
        ]
    )
}
