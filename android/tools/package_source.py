from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
root=Path(__file__).resolve().parents[1]
output=root.parent/'HFit-Android-Quellcode.zip'
files=[root/'AndroidManifest.xml',root/'.gitignore']
for name in ['assets','src','res','tools','tests']:
    files.extend(p for p in (root/name).rglob('*') if p.is_file() and '__pycache__' not in p.parts)
with ZipFile(output,'w',ZIP_DEFLATED) as z:
    for p in files:z.write(p,'android/'+p.relative_to(root).as_posix())
    z.write(root.parent/'ANDROID-TESTEN.md','ANDROID-TESTEN.md')
    z.write(root.parent/'package.json','package.json')
with ZipFile(output) as z:
    assert z.testzip() is None
    assert not any('.jks' in name or '.toolchain' in name for name in z.namelist())
print(f'Android source archive: {output.stat().st_size:,} bytes')
