"""Short-lived loopback-only TLS tests. No firewall or background service changes."""
import json
import ssl
import threading
import unittest
from http.server import ThreadingHTTPServer
from pathlib import Path
from unittest.mock import patch
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen
import server

LOCAL=Path(__file__).parent/'.local'

class HTTPTests(unittest.TestCase):
    def setUp(self):
        self.http=ThreadingHTTPServer(('127.0.0.1',0),server.Handler)
        self.http.config={'token':'test-token-only','model':'test-local'}
        context=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.load_cert_chain(LOCAL/'certificate.pem',LOCAL/'private-key.pem')
        self.http.socket=context.wrap_socket(self.http.socket,server_side=True)
        self.thread=threading.Thread(target=self.http.serve_forever,daemon=True);self.thread.start()
        self.base='https://127.0.0.1:'+str(self.http.server_port)
        self.context=ssl.create_default_context(cafile=str(LOCAL/'certificate.pem'));self.context.check_hostname=False
    def tearDown(self):
        self.http.shutdown();self.http.server_close();self.thread.join()
    def request(self,path='/health',token='test-token-only',body=None,origin=None):
        headers={'Authorization':'Bearer '+token}
        if origin:headers['Origin']=origin
        request=Request(self.base+path,data=None if body is None else json.dumps(body).encode(),headers=headers)
        return urlopen(request,context=self.context,timeout=10)
    def test_wrong_token_and_browser_origin_rejected(self):
        for kwargs in ({'token':'wrong'},{'origin':'https://example.com'}):
            with self.assertRaises(HTTPError) as error:self.request(**kwargs)
            self.assertEqual(error.exception.code,401)
    def test_health_checks_installed_model(self):
        with patch.object(server,'request_json',return_value={'models':[{'name':'test-local'}]}):
            with self.request() as response:self.assertTrue(json.load(response)['ready'])
    def test_bad_body_and_unknown_endpoint_rejected(self):
        for path,body,code in [('/chat',{'question':''},400),('/not-a-tool',{'question':'x'},404)]:
            with self.assertRaises(HTTPError) as error:self.request(path,body=body)
            self.assertEqual(error.exception.code,code)
    def test_valid_request_and_no_cache(self):
        expected=dict(reply='Test',model='test-local',intent='chat',items=[],dayOffset=0,hour=None,minute=None)
        with patch.object(server,'answer',return_value=expected):
            with self.request('/chat',body={'question':'Hallo'}) as response:
                self.assertEqual(response.headers['Cache-Control'],'no-store');self.assertEqual(json.load(response),expected)
    def test_server_not_trusted_without_pairing_certificate(self):
        with self.assertRaises(URLError):urlopen(self.base+'/health',timeout=5)

if __name__=='__main__':unittest.main()
