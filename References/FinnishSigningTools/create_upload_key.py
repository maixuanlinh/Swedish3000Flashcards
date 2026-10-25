#!/usr/bin/env python3
"""Create the owner-authorized Play upload key and keep its password in macOS Keychain."""
import hashlib,json,os,pathlib,secrets,subprocess,sys

root=pathlib.Path(__file__).resolve().parents[1]
folder=pathlib.Path.home()/'.android/keys/3000-swedish-words'
key=folder/'upload.jks'
helper=folder/'keychain-helper'
java=pathlib.Path('/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin')
folder.mkdir(parents=True,exist_ok=True,mode=0o700)
os.chmod(folder,0o700)
if not helper.exists():
    subprocess.run(['swiftc','-module-cache-path','/private/tmp/yki-upload-key-swift-cache',str(root/'tools/upload_keychain.swift'),'-o',str(helper)],check=True)
    os.chmod(helper,0o700)
if key.exists():
    raise SystemExit('The upload key already exists. It was kept unchanged; use the release signing helper.')
password=secrets.token_urlsafe(48)
subprocess.run([str(helper),'put'],input=password.encode(),check=True)
environment=os.environ.copy()
environment['YKI_UPLOAD_STORE_PASSWORD']=password
environment['YKI_UPLOAD_KEY_PASSWORD']=password
try:
    result=subprocess.run([str(java/'keytool'),'-genkeypair','-keystore',str(key),'-storetype','JKS','-alias','upload','-keyalg','RSA','-keysize','3072','-validity','10000','-dname','CN=3000 Swedish Words Upload,O=Linapps Technology','-storepass:env','YKI_UPLOAD_STORE_PASSWORD','-keypass:env','YKI_UPLOAD_KEY_PASSWORD'],env=environment,capture_output=True,text=True)
    if result.returncode:
        subprocess.run([str(helper),'delete-new-unused-password'],check=False,capture_output=True)
        raise SystemExit('Key generation failed; the unused password entry was removed. '+result.stderr)
    os.chmod(key,0o600)
finally:
    password=None
certificate=root/'release-preparation/upload-certificate.pem'
subprocess.run([str(java/'keytool'),'-exportcert','-rfc','-keystore',str(key),'-alias','upload','-storepass:env','YKI_UPLOAD_STORE_PASSWORD','-file',str(certificate)],env=environment,check=True,capture_output=True)
result={'keystore':str(key),'alias':'upload','keychainService':'com.linapps.swedish3000.play-upload','keychainAccount':'upload','algorithm':'RSA-3072','validityDays':10000,'privateKeyMode':'0600','publicCertificate':str(certificate),'publicCertificateFileSha256':hashlib.sha256(certificate.read_bytes()).hexdigest()}
(root/'release-preparation/upload-key-location.json').write_text(json.dumps(result,indent=2)+'\n')
(folder/'README.txt').write_text('3000 Swedish Words — Google Play upload key\n\nPrivate keystore: '+str(key)+'\nAlias: upload\nPassword: macOS Keychain, service com.linapps.swedish3000.play-upload, account upload.\nKeep an encrypted backup of upload.jks and a separate secure recovery copy of its password. Never upload or email the private keystore. Only upload the public certificate when Play Console requests it.\n')
print(json.dumps(result,indent=2))
