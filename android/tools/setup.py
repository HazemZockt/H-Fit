"""Download project-local Android build tools and JDK from official distributors."""
import concurrent.futures, hashlib, json, pathlib, urllib.request, xml.etree.ElementTree as ET, zipfile
ROOT = pathlib.Path(__file__).resolve().parents[1]
TOOLS = ROOT / '.toolchain'
TOOLS.mkdir(exist_ok=True)
def get(url):
    with urllib.request.urlopen(urllib.request.Request(url, headers={'User-Agent':'HFit-build/1.0'}), timeout=90) as response:
        return response.read()
def obtain(label, url, digest, algorithm):
    archive = TOOLS / (label + '.zip')
    if not archive.exists() or hashlib.new(algorithm, archive.read_bytes()).hexdigest() != digest:
        print('Downloading ' + label, flush=True)
        data = get(url)
        if hashlib.new(algorithm, data).hexdigest() != digest: raise RuntimeError('Checksum mismatch: ' + label)
        archive.write_bytes(data)
    destination = TOOLS / label
    if not (destination / '.ready').exists():
        destination.mkdir(exist_ok=True)
        with zipfile.ZipFile(archive) as z:
            for entry in z.infolist():
                resolved = (destination / entry.filename).resolve()
                if not resolved.is_relative_to(destination.resolve()): raise RuntimeError('Invalid ZIP path')
            z.extractall(destination)
        (destination / '.ready').write_text('verified')
    print('Ready: ' + label, flush=True)
    return destination
releases = json.loads(get('https://api.adoptium.net/v3/assets/latest/17/hotspot?architecture=x64&image_type=jdk&os=windows&vendor=eclipse'))
package = releases[0]['binary']['package']
repo = ET.fromstring(get('https://dl.google.com/android/repository/repository2-1.xml'))
jobs = [('jdk', package['link'], package['checksum'], 'sha256')]
for name, wanted in [('platform', 'platforms;android-35'), ('build-tools', 'build-tools;35.0.0'), ('platform-tools', 'platform-tools')]:
    remote = next(p for p in repo.findall('remotePackage') if p.attrib.get('path') == wanted)
    archive = next(a for a in remote.findall('./archives/archive') if a.findtext('host-os') in (None, 'windows'))
    complete = archive.find('complete')
    jobs.append((name, 'https://dl.google.com/android/repository/' + complete.findtext('url'), complete.findtext('checksum'), 'sha1'))
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
    for result in pool.map(lambda args: obtain(*args), jobs): pass
config = {
    'java': str(next((TOOLS/'jdk').rglob('bin/java.exe'))),
    'javac': str(next((TOOLS/'jdk').rglob('bin/javac.exe'))),
    'keytool': str(next((TOOLS/'jdk').rglob('bin/keytool.exe'))),
    'androidJar': str(next((TOOLS/'platform').rglob('android.jar'))),
    'buildTools': str(next((TOOLS/'build-tools').rglob('aapt2.exe')).parent),
    'adb': str(next((TOOLS/'platform-tools').rglob('adb.exe')))
}
(TOOLS/'paths.json').write_text(json.dumps(config, indent=2))
print('Local toolchain prepared.', flush=True)
