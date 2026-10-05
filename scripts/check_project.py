"""Windows-friendly configuration checks; NOT a Swift syntax check or Xcode build."""
from pathlib import Path
import json
import plistlib
import sys

root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root / '.tools'))
import yaml
from PIL import Image

files = [root / 'Package.swift', *sorted((root / 'App').glob('*.swift')), *sorted((root / 'Sources').rglob('*.swift')), *sorted((root / 'Tests').rglob('*.swift'))]
for path in files:
    content = path.read_text(encoding='utf-8')
    assert content.strip(), path
    assert '<<<<<<<' not in content, path
print(f'Source inventory: {len(files)} nonempty UTF-8 Swift files. Swift syntax/typing NOT checked.')
with (root / 'App/Info.plist').open('rb') as f:
    info = plistlib.load(f)
for key in ['NSMicrophoneUsageDescription', 'NSSpeechRecognitionUsageDescription', 'NSMotionUsageDescription', 'NSCameraUsageDescription']:
    assert info.get(key), key
assert info['CFBundleExecutable'] == '$(EXECUTABLE_NAME)'
project = yaml.safe_load((root / 'project.yml').read_text())
assert project['targets']['HFit']['platform'] == 'iOS'
assert project['packages']['HFitCore']['path'] == '.'
# BaseLoader avoids YAML 1.1 interpreting GitHub's 'on' key as a boolean.
workflow = yaml.load((root / '.github/workflows/ios-build.yml').read_text(encoding='utf-8'), Loader=yaml.BaseLoader)
assert 'workflow_dispatch' in workflow['on']
steps = workflow['jobs']['build']['steps']
assert any(s.get('run') == 'swift test' for s in steps)
assert any('CODE_SIGNING_ALLOWED=NO' in s.get('run', '') for s in steps)
for contents in (root / 'App/Assets.xcassets').rglob('Contents.json'):
    for item in json.loads(contents.read_text()).get('images', []):
        assert (contents.parent / item['filename']).is_file()
image = Image.open(root / 'App/Assets.xcassets/AppIcon.appiconset/AppIcon.png')
assert image.size == (1024, 1024) and image.mode == 'RGB'
print('Info.plist, four privacy descriptions, project, CI workflow and icon references: OK.')
print('Required next: swift test, Xcode build, and physical iPhone permission/UI checks.')
