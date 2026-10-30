"""Local-only Android acceptance fixture. No real keys or external model calls."""
from http.server import ThreadingHTTPServer,BaseHTTPRequestHandler
import json,time
from pathlib import Path
events=[]
class Handler(BaseHTTPRequestHandler):
    def log_message(self,*args): pass
    def do_GET(self):
        self.reply({'data':[{'id':'model-a'},{'id':'model-b'}]})
    def reply(self,value,status=200):
        data=json.dumps(value,ensure_ascii=False).encode()
        self.send_response(status);self.send_header('Content-Type','application/json');self.send_header('Content-Length',str(len(data)));self.end_headers()
        try:self.wfile.write(data)
        except (BrokenPipeError,ConnectionResetError,ConnectionAbortedError):pass
    def do_POST(self):
        payload=json.loads(self.rfile.read(int(self.headers.get('Content-Length',0))))
        if payload.get('model')=='rate-limit-fixture':
            self.reply({'error':{'message':'Fixture request rate limit','type':'rate_limit_error'}},429);return
        if payload.get('model')=='slow-fixture':time.sleep(2)
        data=json.loads(payload['messages'][-1]['content'])
        obs=data.get('observation',{})
        if 'legal' in obs:
            answer={'action':'check' if obs['legal']['check'] else 'call','amount':0}
            kind='decision'
        elif obs:
            action=data.get('your_last_action',{}).get('action')
            answer={'text':'这注我跟了。' if action=='call' else '先过，看你敢不敢打。'}
            kind='speech'
            assert all('your_hole' not in s for s in obs['seats'])
        else:
            answer={'ok':True};kind='connection'
        auth=self.headers.get('Authorization','')
        assert auth in ['Bearer DUMMY_A','Bearer DUMMY_B','']
        events.append({'kind':kind,'model':payload.get('model'),'seat':obs.get('actor'),'credential_slot':'B' if auth.endswith('DUMMY_B') else 'A','phase':obs.get('phase')})
        Path('.local/android-audit/mock-requests.json').write_text(json.dumps(events,indent=2),encoding='utf-8')
        truncated=payload.get('model')=='reasoning-fixture' and payload.get('max_completion_tokens',payload.get('max_tokens',0))<16384
        self.reply({'choices':[{'finish_reason':'length' if truncated else 'stop','message':{'content':None if truncated else json.dumps(answer,ensure_ascii=False),'reasoning_content':'HIDDEN_REASONING_NOT_FOR_LOGS'}}], 'usage':{'prompt_tokens':240,'completion_tokens':4096 if truncated else 30,'completion_tokens_details':{'reasoning_tokens':4096 if truncated else 12}}})
print('ANDROID_MOCK_READY 127.0.0.1:18948',flush=True)
ThreadingHTTPServer(('127.0.0.1',18948),Handler).serve_forever()
