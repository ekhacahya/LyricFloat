#!/usr/bin/env python3
"""Validate downloadable archives without running the application."""
import json
import plistlib
import sys
import zipfile

app_zip, extension_zip = sys.argv[1:]
with zipfile.ZipFile(app_zip) as archive:
    archive.testzip() is None or sys.exit('Corrupt app archive')
    base = 'LyricFloat.app/Contents/'
    info = plistlib.loads(archive.read(base + 'Info.plist'))
    executable = archive.getinfo(base + 'MacOS/' + info['CFBundleExecutable'])
    assert executable.file_size > 0, 'Missing executable'
    assert (executable.external_attr >> 16) & 0o111, 'Executable permissions lost'
    assert archive.getinfo(base + 'Resources/AppIcon.icns').file_size > 0
    archive.read(base + 'Resources/BrowserExtension/manifest.json')
with zipfile.ZipFile(extension_zip) as archive:
    archive.testzip() is None or sys.exit('Corrupt extension archive')
    manifest = json.loads(archive.read('manifest.json'))
    assert manifest['manifest_version'] == 3
    resources = [manifest['background']['service_worker'], manifest['action']['default_popup']]
    for content in manifest['content_scripts']:
        resources.extend(content.get('js', []))
        resources.extend(content.get('css', []))
    resources.extend(manifest.get('icons', {}).values())
    resources.extend(manifest['action'].get('default_icon', {}).values())
    resources.extend(['popup.js', 'popup.css'])
    for resource in resources:
        assert archive.getinfo(resource).file_size > 0, f'Missing {resource}'
print('Validated app bundle, executable permissions, icon, and extension resources.')
