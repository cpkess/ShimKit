#!/usr/bin/env python3
"""Regenerate compiled defaults from the approved portable preferences file."""
import json
import os
from pathlib import Path
os.chdir(Path(__file__).resolve().parent.parent)
a = json.loads(Path('Resources/DefaultPreferences.json').read_text())
assert a['format'] == 'com.shimkit.preferences' and a['version'] == 1
s='import Foundation\n\n/// Generated from Resources/DefaultPreferences.json by scripts/generate-defaults.py.\nenum FactoryDefaults {\n    static let settings: [String: Any] = [\n'
for k,v in sorted(a['settings'].items()): s+=f'        "{k}": {str(v).lower()},\n'
s+=f'        "menuBarHideDelay": {a["menuBarHideDelay"]}.0,\n    ]\n    static let launchAtLogin = {str(a["launchAtLogin"]).lower()}\n    static let shortcuts: [WindowCommand: Shortcut] = [\n'
for k,v in sorted(a['shortcuts'].items()): s+=f'        .{k}: Shortcut(keyCodes: {v["keyCodes"]}, modifiers: {v["modifiers"]}),\n'
s+='    ]\n}\n'
Path('ShimKit/Core/Preferences/FactoryDefaults.swift').write_text(s)
