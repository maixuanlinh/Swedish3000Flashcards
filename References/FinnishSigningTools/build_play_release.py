#!/usr/bin/env python3
"""Sign the Play bundle with the owner-selected Essay King key, without logging secrets."""
import argparse
import getpass
import hashlib
import json
import os
import pathlib
import subprocess
import sys
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--version-code', type=int, required=True, help='New, unused Google Play version code')
parser.add_argument('--version-name', default='1.0')
parser.add_argument('--product-id', help='Verified Google Play one-time product ID')
parser.add_argument('--license-key-file', type=pathlib.Path, help='File containing this app’s public Play licensing key')
arguments = parser.parse_args()
if arguments.version_code < 1:
    parser.error('--version-code must be positive')
if bool(arguments.product_id) != bool(arguments.license_key_file):
    parser.error('Provide both --product-id and --license-key-file, or neither for a free-only test build')
root = pathlib.Path(__file__).resolve().parents[1]
private = pathlib.Path.home() / '.android/keys/3000-swedish-words'
original = pathlib.Path('/Users/linhmai/EssayKing-collapsingbar/keystore/essayking.jks')
keystore = private / 'essayking-upload.jks'
helper = private / 'essayking-keychain-helper'
java_home = pathlib.Path('/Applications/Android Studio.app/Contents/jbr/Contents/Home')
alias = 'myessaykingkey'
report = root / 'release-preparation'
private.mkdir(parents=True, exist_ok=True, mode=0o700)
os.chmod(private, 0o700)
if not helper.exists():
    subprocess.run(['swiftc', '-module-cache-path', '/private/tmp/yki-upload-key-swift-cache',
                    str(root / 'tools/essayking_keychain.swift'), '-o', str(helper)], check=True)
    os.chmod(helper, 0o700)

saved = subprocess.run([str(helper), 'get'], capture_output=True)
if saved.returncode == 0:
    credentials = json.loads(saved.stdout)
else:
    if not sys.stdin.isatty():
        raise SystemExit('Run in Android Studio Terminal to enter the existing keystore password privately.')
    print('Sign 3000 Swedish Words with the existing Essay King upload key.')
    print('Passwords are hidden and will be saved in this Mac’s Keychain. Do not paste them into chat.')
    credentials = {'storePassword': getpass.getpass('Essay King keystore password: ')}
    credentials['keyPassword'] = getpass.getpass('Key password (press Return if the same): ') or credentials['storePassword']

environment = os.environ.copy()
environment.update({
    'JAVA_HOME': str(java_home),
    'YKI_UPLOAD_STORE_FILE': str(keystore),
    'YKI_UPLOAD_KEY_ALIAS': alias,
    'YKI_UPLOAD_STORE_PASSWORD': credentials['storePassword'],
    'YKI_UPLOAD_KEY_PASSWORD': credentials['keyPassword'],
})
if keystore.exists():
    if hashlib.sha256(keystore.read_bytes()).digest() != hashlib.sha256(original.read_bytes()).digest():
        raise SystemExit('The protected key copy differs from the selected original. Both files were preserved.')
else:
    # Exclusive creation preserves an existing private key if another process created it.
    fd = os.open(keystore, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, 'wb') as destination:
        destination.write(original.read_bytes())
os.chmod(keystore, 0o600)

with tempfile.TemporaryDirectory(prefix='yki-upload-check-') as temporary:
    verify = subprocess.run([
        str(java_home / 'bin/keytool'), '-certreq', '-alias', alias,
        '-keystore', str(keystore), '-storepass:env', 'YKI_UPLOAD_STORE_PASSWORD',
        '-keypass:env', 'YKI_UPLOAD_KEY_PASSWORD', '-file', str(pathlib.Path(temporary) / 'request.csr'),
    ], env=environment, capture_output=True)
    if verify.returncode:
        raise SystemExit('The keystore or key password could not be verified. No credentials were saved; run again to retry.')

if saved.returncode != 0:
    result = subprocess.run([str(helper), 'put'], input=json.dumps(credentials).encode(), capture_output=True)
    if result.returncode:
        raise SystemExit('Could not save the verified credentials to Keychain. No build was started.')
credentials = None
certificate = report / 'essayking-upload-certificate.pem'
subprocess.run([
    str(java_home / 'bin/keytool'), '-exportcert', '-rfc', '-alias', alias,
    '-keystore', str(keystore), '-storepass:env', 'YKI_UPLOAD_STORE_PASSWORD', '-file', str(certificate),
], env=environment, check=True, capture_output=True)
(report / 'selected-upload-key.json').write_text(json.dumps({
    'selectedByOwner': 'Reuse Essay King keystore', 'originalKeystore': str(original),
    'protectedKeystore': str(keystore), 'alias': alias,
    'keychainService': 'com.linapps.swedish3000.essayking-upload', 'keychainAccount': alias,
    'publicCertificate': str(certificate),
}, indent=2) + '\n')
print('Key and passwords verified. Building the signed Google Play bundle…', flush=True)
log = report / 'signed-bundle-release.log'
command = [str(root / 'gradlew'), '--no-daemon', '-PplayDistribution=true',
           f'-PreleaseVersionCode={arguments.version_code}', f'-PreleaseVersionName={arguments.version_name}']
if arguments.product_id:
    environment['ORG_GRADLE_PROJECT_playProductId'] = arguments.product_id
    environment['ORG_GRADLE_PROJECT_playLicenseKey'] = arguments.license_key_file.read_text().strip()
command.append(':app:bundleRelease')
with log.open('w') as output:
    result = subprocess.run(command,
                            cwd=root, env=environment, stdout=output, stderr=subprocess.STDOUT)
if result.returncode:
    raise SystemExit('Build failed. See release-preparation/signed-bundle-release.log; credentials remain in Keychain.')
bundle = root / 'app/build/outputs/bundle/release/app-release.aab'
verification = subprocess.run([str(java_home / 'bin/jarsigner'), '-verify', str(bundle)], capture_output=True, text=True)
if verification.returncode or 'jar verified.' not in verification.stdout:
    raise SystemExit('Bundle signature verification failed. Do not upload.')
(report / 'signed-bundle-check.json').write_text(json.dumps({
    'bundle': str(bundle), 'bytes': bundle.stat().st_size,
    'sha256': hashlib.sha256(bundle.read_bytes()).hexdigest(),
    'signatureVerified': True, 'keyAlias': alias, 'versionCode': arguments.version_code,
    'versionName': arguments.version_name, 'playProductId': arguments.product_id,
}, indent=2) + '\n')
print('Signed bundle ready:', bundle)
print('The private key is protected outside the project; passwords are in this Mac’s Keychain.')
