#!/usr/bin/env python3
"""Check the running app's loopback bridge using synthetic playback, without printing its pairing code."""
import json
import pathlib
import plistlib
import urllib.error
import urllib.request

prefs = pathlib.Path.home() / 'Library/Preferences/com.ecbn.lyricfloat.plist'
with prefs.open('rb') as file:
    token = plistlib.load(file)['browserToken']
payload = json.dumps(dict(id='youtube:lyricfloat-smoke-test', title='LyricFloat connection check', artist='Test playback', position=12.5, duration=42, playing=False, rate=1, advertisement=False)).encode()
for secret, expected in [('invalid', 403), (token, 200)]:
    request = urllib.request.Request('http://127.0.0.1:18473/playback', data=payload, headers={'Content-Type': 'application/json', 'X-LyricFloat-Token': secret}, method='POST')
    try:
        with urllib.request.urlopen(request, timeout=3) as response:
            actual = response.status
    except urllib.error.HTTPError as error:
        actual = error.code
    assert actual == expected, (actual, expected)
    print('PASS: bridge returned', expected)
