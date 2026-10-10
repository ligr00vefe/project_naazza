"""Regenerate launcher assets from the approved sprout-notebook icon (Pillow)."""
from pathlib import Path
import json
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'assets/branding/naazza-icon-sprout-note.png'
image = Image.open(SOURCE).convert('RGB')
assert image.width == image.height, 'Launcher icon must be square'
image = image.resize((1024, 1024), Image.Resampling.LANCZOS)
image.save(SOURCE)
written = []

def save(relative, pixels):
    path = ROOT / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    image.resize((pixels, pixels), Image.Resampling.LANCZOS).save(path)
    written.append((path, pixels))

for density, legacy, adaptive in [
    ('mdpi', 48, 108), ('hdpi', 72, 162), ('xhdpi', 96, 216),
    ('xxhdpi', 144, 324), ('xxxhdpi', 192, 432),
]:
    save(f'android/app/src/main/res/mipmap-{density}/ic_launcher.png', legacy)
    save(f'android/app/src/main/res/mipmap-{density}/ic_launcher_foreground.png', adaptive)

adaptive_dir = ROOT / 'android/app/src/main/res/mipmap-anydpi-v26'
adaptive_dir.mkdir(parents=True, exist_ok=True)
(adaptive_dir / 'ic_launcher.xml').write_text('''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/launcher_icon_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
''', encoding='utf-8')
(ROOT / 'android/app/src/main/res/values/launcher_icon.xml').write_text('''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="launcher_icon_background">#164C38</color>
</resources>
''', encoding='utf-8')

for folder in ['ios/Runner/Assets.xcassets/AppIcon.appiconset', 'macos/Runner/Assets.xcassets/AppIcon.appiconset']:
    spec = json.loads((ROOT / folder / 'Contents.json').read_text(encoding='utf-8'))
    for entry in spec['images']:
        if not entry.get('filename'):
            continue
        pixels = round(float(entry['size'].split('x')[0]) * float(entry['scale'].rstrip('x')))
        save(f"{folder}/{entry['filename']}", pixels)

for name, pixels in [('Icon-192.png', 192), ('Icon-512.png', 512), ('Icon-maskable-192.png', 192), ('Icon-maskable-512.png', 512)]:
    save(f'web/icons/{name}', pixels)
save('web/favicon.png', 32)
image.save(ROOT / 'windows/runner/resources/app_icon.ico', sizes=[(s,s) for s in [16,24,32,48,64,128,256]])
for path, size in written:
    with Image.open(path) as output:
        assert output.size == (size,size) and output.mode == 'RGB', path
print(f'Validated {len(written)} opaque PNG launcher assets and Windows ICO')