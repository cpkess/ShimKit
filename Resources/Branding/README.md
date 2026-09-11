# ShimKit icon

`ShimKit.png` is the original transparent artwork generated with the built-in OpenAI image-generation tool. Two fitted panes create a simple mark on a blue macOS icon tile.

Run `python3 scripts/build-icon.py` from the repository root to regenerate `Resources/AppIcon.icns`. Native macOS `sips` and `iconutil` package standard 16–1024 pixel representations while preserving transparency. The app bundle includes this icon, so Finder, the Dock, and the app inside the DMG use the same artwork.

## Generation prompt

Use case: logo-brand. Asset type: production macOS application icon for ShimKit, a lightweight native utility for arranging windows, switching between windows, and organizing menu-bar icons. Create one elegant, distinctive finished app icon, not a presentation or mockup. Subject: a bold geometric mark suggesting two precisely fitted window panes, with clever negative space subtly suggesting an S or a shim fitting between surfaces. Keep the geometry extremely simple and readable at small sizes. Style: polished contemporary macOS icon, restrained dimensional depth, softly beveled edges, balanced negative space and a strong silhouette. Coherent restrained colors with enough contrast for light and dark desktops. Composition: straight-on centered rounded-square macOS icon tile occupying approximately 82% of a square 1024 by 1024 canvas, with a gentle short shadow. Outside the rounded-square tile must be genuinely transparent alpha, not white and not a checkerboard. No words, no labels, no extra icons, no device mockup, no decorative tiny details, no watermark. The central mark should remain recognizable at 32 pixels.
