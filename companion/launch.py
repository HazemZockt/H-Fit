"""Start the private companion without a permanent visible server console."""
import json
import os
from pathlib import Path
import ssl
import subprocess
import sys
import time
from urllib.request import Request, urlopen
from urllib.error import HTTPError

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
    try:
        with urlopen('http://127.0.0.1:11434/api/tags', timeout=3) as response: json.load(response)
    except OSError:
        if not ollama.exists(): raise RuntimeError('Bitte Ollama am PC installieren und das lokale Modell laden.')
        with (LOCAL / 'ollama-start.log').open('ab') as log:
            subprocess.Popen([str(ollama), 'serve'], stdin=subprocess.DEVNULL, stdout=log, stderr=log, creationflags=flags)
        for attempt in range(30):
            try:
                with urlopen('http://127.0.0.1:11434/api/tags', timeout=2) as response: json.load(response)
                break
            except OSError:
                if attempt == 29: raise RuntimeError('Ollama startet nicht. Bitte Ollama am PC öffnen.')
                time.sleep(1)
    try:
        result = health(config)
    except HTTPError:
        # An existing H-Fit server must not be duplicated if its model is missing.
        raise RuntimeError('H-Fit läuft, aber das konfigurierte Ollama-Modell ist noch nicht bereit.')
    except Exception:
        with (LOCAL / 'server.log').open('ab') as log:
            process = subprocess.Popen([sys.executable, str(ROOT / 'server.py')], cwd=str(ROOT.parent), stdin=subprocess.DEVNULL, stdout=log, stderr=log, creationflags=flags)
        (LOCAL / 'server.pid').write_text(str(process.pid))
        time.sleep(1)
        result = health(config)
    print('KI bereit: ' + result.get('model', '?'))
    print('Kopplungsseite: ' + str(LOCAL / 'pairing.html'))

if __name__ == '__main__': main()
