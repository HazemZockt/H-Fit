"""Reproducible, original geometric H-Fit app icon (requires Pillow)."""
from pathlib import Path
import json
from PIL import Image, ImageDraw

root = Path(__file__).resolve().parents[1]
assets = root / 'App' / 'Assets.xcassets'
icons = assets / 'AppIcon.appiconset'
icons.mkdir(parents=True, exist_ok=True)
image = Image.new('RGB', (1024, 1024), '#0e1217')
draw = ImageDraw.Draw(image)
draw.rounded_rectangle((192, 180, 370, 844), 70, fill='#c7f54f')
draw.rounded_rectangle((654, 180, 832, 844), 70, fill='#c7f54f')
draw.rounded_rectangle((305, 426, 719, 598), 55, fill='#c7f54f')
image.save(icons / 'AppIcon.png')
(assets / 'Contents.json').write_text(json.dumps({'info': {'author': 'xcode', 'version': 1}}, indent=2))
(icons / 'Contents.json').write_text(json.dumps({'images': [{'filename': 'AppIcon.png', 'idiom': 'universal', 'platform': 'ios', 'size': '1024x1024'}], 'info': {'author': 'xcode', 'version': 1}}, indent=2))
print('App icon generated: 1024 x 1024 RGB')
