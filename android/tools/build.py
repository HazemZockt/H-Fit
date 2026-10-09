"""Build and sign a standalone Android test APK using the project-local SDK."""
from pathlib import Path
import json, subprocess, zipfile
ROOT=Path(__file__).resolve().parents[1]
paths=json.loads((ROOT/'.toolchain/paths.json').read_text())
build=ROOT/'build'
for name in ['generated','classes','dex']: (build/name).mkdir(parents=True,exist_ok=True)
bt=Path(paths['buildTools'])
def run(args):
    print('Running: '+Path(str(args[0])).name+' '+str(args[1]),flush=True)
    subprocess.run([str(x) for x in args],check=True,cwd=ROOT)
run([bt/'aapt2.exe','compile','--dir',ROOT/'res','-o',build/'resources.zip'])
run([bt/'aapt2.exe','link','-o',build/'base.apk','-I',paths['androidJar'],'--manifest',ROOT/'AndroidManifest.xml','--java',build/'generated','-A',ROOT/'assets',build/'resources.zip'])
sources=[*ROOT.joinpath('src').rglob('*.java'),*build.joinpath('generated').rglob('*.java')]
run([paths['javac'],'-encoding','UTF-8','-source','8','-target','8','-classpath',paths['androidJar'],'-d',build/'classes',*sources])
with zipfile.ZipFile(build/'classes.jar','w',zipfile.ZIP_DEFLATED) as z:
    for path in (build/'classes').rglob('*.class'): z.write(path,path.relative_to(build/'classes').as_posix())
run([paths['java'],'-cp',bt/'lib/d8.jar','com.android.tools.r8.D8','--release','--min-api','26','--lib',paths['androidJar'],'--output',build/'dex',build/'classes.jar'])
with zipfile.ZipFile(build/'base.apk') as source, zipfile.ZipFile(build/'unsigned.apk','w',zipfile.ZIP_DEFLATED) as out:
    for item in source.infolist(): out.writestr(item,source.read(item.filename))
    for dex in (build/'dex').glob('*.dex'): out.write(dex,dex.name)
run([bt/'zipalign.exe','-f','-p','4',build/'unsigned.apk',build/'aligned.apk'])
key=ROOT/'.toolchain/hfit-debug.jks'
if not key.exists():
    run([paths['keytool'],'-genkeypair','-keystore',key,'-storepass','android','-keypass','android','-alias','hfit-debug','-keyalg','RSA','-keysize','2048','-validity','10000','-dname','CN=H-Fit Local Test,O=HFit,C=DE','-noprompt'])
output=ROOT.parent/'HFit-Android-Test.apk'
run([paths['java'],'-jar',bt/'lib/apksigner.jar','sign','--ks',key,'--ks-key-alias','hfit-debug','--ks-pass','pass:android','--key-pass','pass:android','--out',output,build/'aligned.apk'])
run([paths['java'],'-jar',bt/'lib/apksigner.jar','verify','--verbose',output])
run([bt/'aapt2.exe','dump','badging',output])
print(f'APK ready: {output} ({output.stat().st_size:,} bytes)',flush=True)
