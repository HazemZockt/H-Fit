"""Create a source-only handoff. Excludes tools, build products and personal data."""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

root = Path(__file__).resolve().parents[1]
paths = [root / name for name in ['Package.swift', 'project.yml', '.gitignore', 'README.md', 'INSTALLIEREN.md', 'PRUEFSTATUS.md']]
for folder in ['App', 'Sources', 'Tests', '.github', 'scripts']:
    paths.extend(p for p in (root / folder).rglob('*') if p.is_file() and '__pycache__' not in p.parts)
output = root / 'HFit-Quellcode.zip'
with ZipFile(output, 'w', ZIP_DEFLATED) as archive:
    for path in sorted(paths):
        archive.write(path, path.relative_to(root).as_posix())
with ZipFile(output) as archive:
    assert archive.testzip() is None
    assert '.github/workflows/ios-build.yml' in archive.namelist()
    assert 'App/Assets.xcassets/AppIcon.appiconset/AppIcon.png' in archive.namelist()
    print(f'Validated source archive: {len(archive.namelist())} files; {output.stat().st_size:,} bytes')
    print(output)
