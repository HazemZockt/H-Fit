from pathlib import Path
import json
from PIL import Image
root=Path(__file__).resolve().parents[2]
assets=root/'android/assets'
foods=[]
for line in (root/'Sources/HFitCore/FoodCatalog.swift').read_text(encoding='utf-8').splitlines():
    line=line.strip().rstrip(',')
    if not line.startswith('f('): continue
    values=json.loads('['+line[2:-1]+']')
    name, aliases, k, p, c, fat, portion=values[:7]
    foods.append(dict(id=aliases.split('|')[0],name=name,aliases=aliases.split('|'),k=k,p=p,c=c,f=fat,portion=portion,unit=values[7] if len(values)>7 else 'g'))
(assets/'catalog.js').write_text('globalThis.HFIT_CATALOG = '+json.dumps(foods,ensure_ascii=False)+';\nif (typeof module !== "undefined") module.exports = globalThis.HFIT_CATALOG;\n',encoding='utf-8')
icon=Image.open(root/'App/Assets.xcassets/AppIcon.appiconset/AppIcon.png')
folder=root/'android/res/drawable'
folder.mkdir(parents=True,exist_ok=True)
icon.resize((192,192)).save(folder/'icon.png')
icon.resize((128,128)).save(assets/'icon.png')
print(f'Prepared {len(foods)} foods and Android app icons.')
