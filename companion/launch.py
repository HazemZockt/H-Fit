"""Start the private companion without a permanent visible server console."""
import json
import os
from pathlib import Path
import ssl
import subprocess
import sys
import time
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parent
LOCAL = ROOT / '.local'

def health(config):
    context = ssl.create_default_context(cafile=str(LOCAL / 'certificate.pem'))
    context.check_hostname = False  # Trust only the local generated certificate, even after a DHCP address change.
    request = Request(f'https://{config["host"]}:{config["port"]}/health', headers={'Authorization': 'Bearer ' + config['token']})
    with urlopen(request, context=context, timeout=5) as response: return json.load(response)

def main():
    config = json.loads((LOCAL / 'server.json').read_text())
    flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
    ollama = Path(os.environ.get('LOCALAPPDATA', '')) / 'Programs/Ollama/ollama.exe'
    if ollama.exists():
        subprocess.run([str(ollama), 'list'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, creationflags=flags, timeout=40)
    try:
        result = health(config)
    except Exception:
        with (LOCAL / 'server.log').open('ab') as log:
            process = subprocess.Popen([sys.executable, str(ROOT / 'server.py')], cwd=str(ROOT.parent), stdout=log, stderr=log, creationflags=flags)
        (LOCAL / 'server.pid').write_text(str(process.pid))
        time.sleep(1)
        result = health(config)
    print('KI bereit: ' + result.get('model', '?'))
    print('Kopplungsseite: ' + str(LOCAL / 'pairing.html'))

if __name__ == '__main__': main()
