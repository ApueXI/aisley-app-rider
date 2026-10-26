"""Synthetic Courier screen checks against the local Flutter fixture at :8765."""
import base64
import json
from pathlib import Path
import shutil
import socket
import subprocess
import time
import urllib.error
import urllib.request


def main():
    out = Path('build/verification/platform-sync')
    out.mkdir(parents=True, exist_ok=True)
    with socket.socket() as listener:
        listener.bind(('127.0.0.1', 0))
        port = listener.getsockname()[1]
    driver = subprocess.Popen([shutil.which('chromedriver'), '--port=' + str(port), '--allowed-ips=127.0.0.1'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    session = None

    def call(path, body=None, method=None):
        request = urllib.request.Request('http://127.0.0.1:' + str(port) + path,
            data=None if body is None else json.dumps(body).encode(),
            headers={'Content-Type':'application/json'}, method=method)
        with urllib.request.urlopen(request, timeout=60) as response:
            return json.load(response)['value']

    try:
        for _ in range(100):
            try:
                call('/status')
                break
            except urllib.error.URLError:
                time.sleep(.1)
        session = call('/session', {'capabilities':{'alwaysMatch':{
            'browserName':'chrome', 'goog:loggingPrefs':{'browser':'ALL'},
            'goog:chromeOptions':{'binary':shutil.which('chromium'), 'args':[
                '--headless=new','--no-sandbox','--disable-dev-shm-usage',
                '--user-data-dir=' + str((out/'profile').resolve())]}}}})['sessionId']
        prefix = '/session/' + session
        def script(source):
            return call(prefix+'/execute/sync', {'script':source,'args':[]})
        def labels():
            script("document.querySelector('flt-semantics-placeholder')?.click();")
            return script("return document.body.innerText + '\\n' + [...document.querySelectorAll('[aria-label]')].map(e => e.getAttribute('aria-label')).join('\\n');")
        def capture(name):
            (out/(name+'.png')).write_bytes(base64.b64decode(call(prefix+'/screenshot')))
        def wait(label):
            for attempt in range(600):
                if label in labels(): return
                if attempt > 10 and attempt % 6 == 0:
                    size = script('return {w:innerWidth,h:innerHeight};')
                    call(prefix+'/goog/cdp/execute', {'cmd':'Input.dispatchMouseEvent','params':{
                        'type':'mouseWheel','x':size['w']/2,'y':size['h']*.65,'deltaX':0,
                        'deltaY':-10000 if attempt % 90 == 0 else 300}})
                time.sleep(.15)
            capture('failure')
            (out/'failure-browser-log.json').write_text(json.dumps(call(prefix+'/log', {'type':'browser'}), indent=2))
            (out/'failure-labels.txt').write_text(labels())
            raise AssertionError('Missing UI: '+label)
        def click(label, last=False):
            wait(label)
            found = script("""
                const nodes=[...document.querySelectorAll('[role=button],[role=checkbox],button')];
                const name=e => e.getAttribute('aria-label') || e.innerText || '';
                const matches=nodes.filter(e => name(e).trim()===%s || name(e).split(String.fromCharCode(10)).map(x=>x.trim()).includes(%s));
                const target=matches[%s ? matches.length-1 : 0];
                if(!target || target.getAttribute('aria-disabled')==='true') return false;
                target.click();return true;
            """ % (json.dumps(label),json.dumps(label),json.dumps(last)))
            assert found, 'Missing action: '+label
            time.sleep(.35)
        def load(feature, width=390, height=844, large=False, dark=False):
            call(prefix+'/goog/cdp/execute', {'cmd':'Emulation.setDeviceMetricsOverride','params':{
                'width':width,'height':height,'deviceScaleFactor':1,'mobile':False}})
            call(prefix+'/url', {'url':'http://localhost:8765/?feature='+feature+('&text=large' if large else '')+('&theme=dark' if dark else '')})
            wait({'linehaul':'Assigned hub transfers','batch':'DSP-100','delivery':'Deliver order'}[feature])
            time.sleep(.5)
        results=[]
        for feature in ['linehaul','batch','delivery']:
            load(feature,320,640)
            for width,height in [(320,640),(390,844),(800,900),(1440,1000)]:
                call(prefix+'/goog/cdp/execute', {'cmd':'Emulation.setDeviceMetricsOverride','params':{
                    'width':width,'height':height,'deviceScaleFactor':1,'mobile':False}})
                time.sleep(.5)
                assert script('return document.documentElement.scrollWidth <= innerWidth;'), 'Page overflow'
                capture(feature+'-'+str(width))
                results.append(feature+' mounted layout '+str(width))
            load(feature,320,640,True,True)
            capture(feature+'-320-large-dark')
            results.append(feature+' doubled text/dark layout')
        load('linehaul')
        click('Depart');wait('Confirm departure?');capture('linehaul-depart-confirmation');click('Cancel')
        click('Depart');click('Depart',True);wait('Arrived at hub')
        click('Arrived at hub');wait('Confirm arrival at hub?');click('Arrived at hub',True);wait('Arrival reported');capture('linehaul-arrival-reported')
        assert 'Unloading closed:' not in labels()
        results.append('linehaul explicit depart/cancel/arrival and Logistics custody preserved')
        load('batch')
        click('Accept parcel');wait('Accept parcel?');click('Accept parcel',True);wait('delivery accepted');capture('parcel-independent-acceptance')
        assert 'delivery assigned' in labels(), 'Sibling was changed by acceptance'
        click('Reject parcel');wait('Reject parcel?')
        elements=call(prefix+'/elements', {'using':'css selector','value':'textarea,input'})
        assert elements, 'Reason field unavailable'
        element=elements[-1]['element-6066-11e4-a52e-4f735466cecf']
        call(prefix+'/element/'+element+'/click', {})
        call(prefix+'/goog/cdp/execute', {'cmd':'Input.insertText','params':{'text':'Cannot carry this parcel'}})
        time.sleep(.5);click('Reject parcel',True);wait('1 parcel');capture('parcel-independent-rejection')
        assert 'ORD-101' not in labels(), 'Rejected membership still exposed'
        results.append('independent accept/reasoned reject preserve accepted sibling')
        load('delivery')
        click('Open camera for POD');wait('Retake photo');capture('delivery-photo-preview')
        click('Delivered');wait('Confirm COD collection');capture('delivery-cod-confirmation')
        assert script("return [...document.querySelectorAll('[role=button]')].some(e => (e.getAttribute('aria-label')||e.innerText||'').trim()==='Delivered' && e.getAttribute('aria-disabled')==='true');"), 'COD confirmation must start disabled'
        click('I collected PHP 115.00 in full.');click('Delivered',True);wait('Completion intent accepted by the server.');capture('delivery-pending-logistics')
        assert 'Delivery completed by the server.' not in labels()
        assert 'The verified image bytes could not be displayed.' not in labels(), 'Synthetic submitted proof must decode'
        results.append('accepted parcel camera preview/COD/Delivered remains pending Logistics')
        logs=call(prefix+'/log', {'type':'browser'})
        errors=[entry['message'] for entry in logs if entry.get('level')=='SEVERE' and 'favicon' not in entry['message']]
        (out/'report.json').write_text(json.dumps({'transport':'synthetic repositories only','results':results,'browser_errors':errors},indent=2)+'\n')
        assert not errors, errors
        print('PASS:',len(results),'synthetic browser checks')
    finally:
        if session:
            try: call('/session/'+session,method='DELETE')
            except (urllib.error.URLError,ValueError): pass
        driver.terminate();driver.wait(timeout=10)

if __name__=='__main__': main()
