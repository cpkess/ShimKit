#!/usr/bin/env python3
"""Package the original artwork into all standard macOS app icon sizes."""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parent.parent
source = root / "Resources/Branding/ShimKit.png"
with tempfile.TemporaryDirectory(prefix="shimkit-icon-") as temporary:
    iconset = Path(temporary) / "AppIcon.iconset"
    iconset.mkdir()
    for points in (16, 32, 128, 256, 512):
        for scale in (1, 2):
            pixels = str(points * scale)
            suffix = "@2x" if scale == 2 else ""
            destination = iconset / f"icon_{points}x{points}{suffix}.png"
            subprocess.run(["sips", "-z", pixels, pixels, str(source), "--out", str(destination)], check=True, stdout=subprocess.DEVNULL)
    subprocess.run(["iconutil", "-c", "icns", str(iconset), "-o", str(root / "Resources/AppIcon.icns")], check=True)
print("Generated Resources/AppIcon.icns")
