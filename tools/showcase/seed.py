#!/usr/bin/env python3
# seed.py SHELL_JSON [KEY=JSON ...]: the showcase bar for README captures, of
# stock Omarchy widgets only (a box shows other plugins as placeholders, and
# the captures stay free of anyone's own setup). KEY=JSON sets bar keys.
import json, os, sys
p = sys.argv[1]; cfg = json.load(open(p)); bar = cfg.setdefault('bar', {})
n = [0]
def w(i, vis=None):
    n[0] += 1; e = {'id': i, 'powerbarInstance': 'pw-show%02d-%s' % (n[0], i.split('.')[-1])}
    if vis: e['powerbarVisibility'] = vis
    return e
left = [w('omarchy.workspaces'), w('omarchy.monitor'), w('omarchy.tailscale'), w('omarchy.dropbox'),
        w('omarchy.system-update'), w('omarchy.indicators')]
center = [w('omarchy.clock')]
right = [w('omarchy.weather'), w('omarchy.elsewhen', 'managed'), w('omarchy.media', 'managed'), w('omarchy.tray', 'managed'),
         w('omarchy.wifiqr', 'managed'), w('omarchy.speedtest', 'managed'),
         w('omarchy.audio'), w('omarchy.microphone'), w('omarchy.bluetooth'), w('omarchy.network'), w('omarchy.keyboard-layout'), w('omarchy.power')]
I = {e['id']: e['powerbarInstance'] for e in left + center + right}
bar['layout'] = {'left': left, 'center': center, 'right': right}
bar['powerbarGroups'] = [
 {'id': 'g-show-system', 'label': 'System', 'icon': '', 'section': 'left', 'before': I['omarchy.system-update'], 'visibility': 'shown',
  'face': 'both', 'tooltip': False, 'badge': True, 'badgeMode': 'sum', 'memberDisplay': 'both',
  'items': [I['omarchy.monitor'], I['omarchy.tailscale'], I['omarchy.dropbox']]},
 {'id': 'g-show-audio', 'label': 'Audio', 'icon': '', 'section': 'right', 'before': I['omarchy.bluetooth'], 'visibility': 'shown',
  'face': 'icon', 'badge': True, 'badgeMode': 'sum', 'memberDisplay': 'native',
  'items': [I['omarchy.audio'], I['omarchy.microphone']]}]
bar.update({'id': 'p0werj0int.powerbar', 'position': 'top', 'centerAnchor': 'omarchy.clock', 'powerbarAutoHide': False,
            'powerbarStyle': 'islands', 'powerbarLargeBar': True, 'powerbarOnDemand': 'drawer', 'powerbarZones': 'three'})
for kv in sys.argv[2:]:
    k, v = kv.split('=', 1)
    try: v = json.loads(v)
    except ValueError: pass
    bar[k] = v
tmp = p + '.tmp'; json.dump(cfg, open(tmp, 'w'), indent=1); os.replace(tmp, p)
