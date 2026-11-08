#!/usr/bin/env python3
"""Build using the dedicated Swedish upload key; never print or copy credentials."""
import argparse,base64,hashlib,json,os,pathlib,subprocess
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--version-code',type=int,required=True)
p.add_argument('--version-name',default='1.0')
p.add_argument('--product-id',required=True)
p.add_argument('--license-key-file',type=pathlib.Path,required=True)
a=p.parse_args()
if a.version_code<1:p.error('Version code must be positive')
if not a.product_id or not all(c.islower() or c.isdigit() or c in '._' for c in a.product_id):p.error('Invalid one-time product ID')
root=pathlib.Path(__file__).resolve().parents[1]
private=pathlib.Path.home()/'.android/keys/3000-swedish-words'
key=private/'upload.jks';helper=private/'keychain-helper'
if not key.is_file() or not helper.is_file():raise SystemExit('Create the dedicated Swedish upload key first.')
license_key=''.join(a.license_key_file.read_text().split())
if len(base64.b64decode(license_key,validate=True))<128:raise SystemExit('Invalid public Play license key.')
secret=subprocess.run([str(helper),'get'],capture_output=True,check=True).stdout.decode()
env=os.environ.copy();java=pathlib.Path('/Applications/Android Studio.app/Contents/jbr/Contents/Home')
env.update(JAVA_HOME=str(java),SWEDISH_UPLOAD_STORE_FILE=str(key),SWEDISH_UPLOAD_KEY_ALIAS='upload',SWEDISH_UPLOAD_STORE_PASSWORD=secret,SWEDISH_UPLOAD_KEY_PASSWORD=secret)
env['ORG_GRADLE_PROJECT_playLicenseKey']=license_key
env['ANDROID_HOME']=env.get('ANDROID_HOME',str(pathlib.Path.home()/'Library/Android/sdk'))
subprocess.run([str(root/'gradlew'),'-PplayDistribution=true',f'-PreleaseVersionCode={a.version_code}',f'-PreleaseVersionName={a.version_name}',f'-PplayProductId={a.product_id}',':app:bundleRelease','--console=plain'],cwd=root,env=env,check=True)
bundle=root/'app/build/outputs/bundle/release/app-release.aab'
verify=subprocess.run([str(java/'bin/jarsigner'),'-verify',str(bundle)],capture_output=True,text=True,check=True)
if 'jar verified' not in verify.stdout:raise SystemExit('Bundle signature was not verified')
report={'applicationId':'com.linapps.swedish3000','versionCode':a.version_code,'versionName':a.version_name,'productId':a.product_id,'bytes':bundle.stat().st_size,'sha256':hashlib.sha256(bundle.read_bytes()).hexdigest(),'signature':'verified','uploadKey':'dedicated Swedish upload key; no Finnish identity reused','billingStatus':'Verify the matching one-time product is active in Console before release'}
(root/'release-preparation/signed-bundle-check.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
