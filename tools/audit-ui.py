"""Render the actual game in portrait for acceptance review, without user data or AI calls."""
from pathlib import Path
import os, shutil, subprocess, time
import sys
root=Path(__file__).resolve().parent.parent
godot=Path(os.environ.get('SOMNICARD_GODOT', str(Path(os.environ['LOCALAPPDATA'])/'Programs/Godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe')))
output=root/'.local/audit-ui'
output.mkdir(parents=True,exist_ok=True)
cases=[
    ('academy','360x640',['--home','--academy']),
    ('academy-question','360x640',['--home','--academy','--academy-question']),
    ('academy-answer','390x844',['--home','--academy','--academy-question','--academy-answer']),
    ('product-help','360x640',['--home','--product-help']),
    ('model-selector','360x640',['--model-selector']),
    ('speech-six','360x640',['--players=6','--ai-demo']),
    ('speech-nine','390x844',['--players=9','--ai-demo']),
    ('request-inspector','360x640',['--players=6','--request-inspector']),
    ('request-locked','360x640',['--players=6','--request-inspector','--request-detail']),
    ('request-detail','390x844',['--players=6','--capture-state=complete','--request-inspector','--request-detail']),
    ('home','360x640',['--home']),
    ('six-seats','360x640',['--players=6']),
    ('nine-seats','360x640',['--players=9','--capture-state=flop']),
    ('showdown','390x844',['--players=9','--capture-state=complete']),
    ('betting','360x640',['--players=6','--bet']),
    ('history','360x640',['--history-demo']),
    ('review','390x844',['--players=6','--review','--analysis','--detail']),
    ('ranges','360x640',['--players=6','--teach','--ranges','--range-selected']),
    ('ai-coach','360x640',['--ai-coach','--coach-answer-demo']),
    ('models','360x640',['--model-bank']),
    ('opponents','390x844',['--players=9','--ai-demo','--ai-opponents']),
    ('arena','360x640',['--arena','--arena-evidence']),
    ('training','390x844',['--players=9','--training','--lesson','--answer']),
    ('training-seven-flop','360x640',['--players=7','--training','--lesson','--lesson-flop','--all-wagers']),
    ('training-eight-flop','360x640',['--players=8','--training','--lesson','--lesson-flop','--all-wagers']),
    ('training-nine-flop','390x844',['--players=9','--training','--lesson','--lesson-flop','--all-wagers']),
]
if len(sys.argv)>1: cases=[case for case in cases if case[0] in sys.argv[1:]]
for name,resolution,flags in cases:
    before={p:p.stat().st_mtime_ns for p in (root/'.local').glob('*-preview.png')}
    with (output/(name+'.log')).open('wb') as log:
        process=subprocess.Popen([str(godot),'--path',str(root),'--resolution',resolution,'--script','tools/capture.gd','--','--capture-test',*flags],cwd=root,stdin=subprocess.DEVNULL,stdout=log,stderr=subprocess.STDOUT)
        try: code=process.wait(timeout=60)
        except subprocess.TimeoutExpired:
            process.kill();process.wait();raise RuntimeError(name+' capture timed out')
    text=(output/(name+'.log')).read_text(encoding='utf-8',errors='replace')
    assert code==0 and 'ERROR:' not in text and 'SCRIPT ERROR:' not in text,(name,text)
    changed=[p for p in (root/'.local').glob('*-preview.png') if p.stat().st_mtime_ns!=before.get(p)]
    assert len(changed)==1,(name,changed)
    shutil.copyfile(changed[0],output/(name+'.png'))
    print('CAPTURE_OK',name,resolution,flush=True)
print('AUDIT_UI_COMPLETE',len(cases),flush=True)
