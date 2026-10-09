"""Create project-local TLS identity and a QR pairing page, never a public endpoint."""
import argparse
import base64
import datetime
import hashlib
import html
import ipaddress
import json
import secrets
import sys
from pathlib import Path
from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.x509.oid import NameOID

LOCAL = Path(__file__).parent / '.local'
sys.path.insert(0, str(LOCAL / 'libs'))

def main():
    parser = argparse.ArgumentParser(); parser.add_argument('--host', required=True); parser.add_argument('--model', default='qwen3.5:4b')
    args = parser.parse_args(); address = ipaddress.IPv4Address(args.host)
    if not any(address in ipaddress.IPv4Network(n) for n in ('10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16')):
        raise ValueError('Bitte eine private WLAN-Adresse verwenden.')
    LOCAL.mkdir(parents=True, exist_ok=True)
    config_path = LOCAL / 'server.json'
    config = json.loads(config_path.read_text()) if config_path.exists() else {'token': secrets.token_urlsafe(32), 'port': 8787}
    config.update(host=str(address), model=args.model)
    cert_path, key_path = LOCAL / 'certificate.pem', LOCAL / 'private-key.pem'
    if not cert_path.exists():
        key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        name = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, 'H-Fit Personal PC')])
        now = datetime.datetime.now(datetime.timezone.utc)
        cert = (x509.CertificateBuilder().subject_name(name).issuer_name(name).public_key(key.public_key())
                .serial_number(x509.random_serial_number()).not_valid_before(now - datetime.timedelta(minutes=5))
                .not_valid_after(now + datetime.timedelta(days=365))
                .add_extension(x509.SubjectAlternativeName([x509.IPAddress(address)]), critical=False)
                .sign(key, hashes.SHA256()))
        key_path.write_bytes(key.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8, serialization.NoEncryption()))
        cert_path.write_bytes(cert.public_bytes(serialization.Encoding.PEM))
    cert = x509.load_pem_x509_certificate(cert_path.read_bytes())
    config_path.write_text(json.dumps(config, indent=2), encoding='utf-8')
    pairing = dict(url=f'https://{address}:{config["port"]}', token=config['token'], fingerprint=cert.fingerprint(hashes.SHA256()).hex())
    payload = base64.urlsafe_b64encode(json.dumps(pairing, separators=(',', ':')).encode()).decode().rstrip('=')
    code = 'hfit://pair?data=' + payload
    (LOCAL / 'pairing.txt').write_text(code, encoding='utf-8')
    import qrcode
    qr = qrcode.make(code); qr.save(LOCAL / 'pairing.png')
    image = base64.b64encode((LOCAL / 'pairing.png').read_bytes()).decode()
    page = f'''<!doctype html><html lang="de"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>H-Fit · PC koppeln</title>
<style>body{{background:#0e1217;color:#edf1f4;font:17px system-ui;max-width:700px;margin:40px auto;padding:24px}}h1{{color:#c7f54f}}img{{max-width:100%;width:420px;border-radius:16px}}textarea{{width:100%;height:100px}}p{{line-height:1.6}}</style>
<h1>Deine KI bleibt auf deinem PC.</h1><p>Auf dem iPhone in H-Fit: <b>Assistent → PC verbinden → QR-Code scannen</b>. Beide Geräte müssen im selben WLAN sein. Der PC muss eingeschaltet bleiben.</p><img alt="Privater Kopplungscode für diesen PC" src="data:image/png;base64,{image}">
<p><b>Privater Kopplungscode:</b> Nicht veröffentlichen oder ins GitHub-Repository hochladen. Die Verbindung ist TLS-verschlüsselt; die App prüft genau dieses PC-Zertifikat.</p><textarea readonly>{html.escape(code)}</textarea><p>Adresse: {address}:{config['port']} · Modell: {html.escape(args.model)}</p></html>'''
    (LOCAL / 'pairing.html').write_text(page, encoding='utf-8')
    print('Kopplungsseite gespeichert: ' + str(LOCAL / 'pairing.html'))

if __name__ == '__main__': main()
