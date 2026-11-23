# Generates the first version of chapter three's sector stage scenes (stages 3-1, 3-2, 3-4, 3-5, 3-7, 3-8)
# from the layout specs below. Boss stages (3-3, 3-6, 3-9) are written by hand.
#
# WARNING: running this OVERWRITES the scene files it names. The .tscn files are the source of truth
# once they exist: anything moved in the Godot editor is lost if this is run again. Keep it as a
# readable record of the layout numbers and as a starting point for new stages.
#
# Usage: python tools/build_chapter3.py <project folder> [scene file names...]
import os
import sys

PROJ = sys.argv[1]

SCRIPTS = {
    'deck': 'res://scripts/sector_deck.gd', 'effects': 'res://scripts/effects.gd', 'hud': 'res://scripts/hud.gd',
    'relay': 'res://scripts/kinetic_relay.gd', 'shuttle': 'res://scripts/shuttle.gd', 'drone': 'res://scripts/drone.gd',
    'train': 'res://scripts/freight_train.gd', 'gust': 'res://scripts/gust.gd', 'hatch': 'res://scripts/hatch.gd',
    'turret': 'res://scripts/turret.gd', 'bomber': 'res://scripts/bomber.gd', 'skyline': 'res://scripts/skyline.gd',
    'launcher': 'res://scripts/launcher.gd', 'absorber': 'res://scripts/absorber.gd', 'sway': 'res://scripts/ship_sway.gd',
    'rack': 'res://scripts/barrel_rack.gd', 'target': 'res://scripts/reflect_target.gd', 'field': 'res://scripts/low_gravity.gd',
}
SCENES = {'sera': 'res://scenes/sera.tscn', 'warden': 'res://scenes/warden.tscn', 'gate': 'res://scenes/bulkhead.tscn'}


def num(v):
    if isinstance(v, bool):
        return 'true' if v else 'false'
    if isinstance(v, float) and v == int(v):
        return str(int(v))
    return str(v)


def val(v):
    return ('"%s"' % v) if isinstance(v, str) else num(v)


def vec(x, y):
    return 'Vector2(%s, %s)' % (num(x), num(y))


def color(c):
    return 'Color(%s, %s, %s, %s)' % tuple(c)


def build(spec):
    ext = []
    ids = {}

    def res(kind, path):
        if path not in ids:
            ids[path] = str(len(ext) + 1)
            ext.append((kind, path, ids[path]))
        return 'ExtResource("%s")' % ids[path]

    subs = []
    nodes = []

    def node(name, type_=None, parent='World', instance=None, props=None):
        head = '[node name="%s"' % name
        if type_:
            head += ' type="%s"' % type_
        if parent is not None:
            head += ' parent="%s"' % parent
        if instance:
            head += ' instance=%s' % instance
        head += ']'
        lines = [head]
        for k, v in (props or {}).items():
            lines.append('%s = %s' % (k, v))
        nodes.append('\n'.join(lines))

    root_props = {'process_mode': '3', 'script': res('Script', spec['script'])}
    root_props.update(spec['root'])
    node(spec['name'], 'Node2D', None, None, root_props)

    # No painting yet: an empty backdrop sprite (a painting added later goes here)
    # and the code-drawn skyline in front of it.
    node('FarBackground', 'CanvasLayer', '.', None, {'layer': '-2'})
    node('Backdrop', 'Sprite2D', 'FarBackground', None, {'position': vec(-40, -30), 'scale': vec(0.82, 0.82), 'centered': 'false'})
    node('Skyline', 'Node2D', 'FarBackground', None, {'script': res('Script', SCRIPTS['skyline']), 'theme_name': '"%s"' % spec['skyline']})
    node('World', 'Node2D', '.', None, {'process_mode': '1'})
    deck_props = {'script': res('Script', SCRIPTS['deck'])}
    for k, v in spec.get('palette', {}).items():
        deck_props[k] = color(v)
    node('DeckArt', 'Node2D', 'World', None, deck_props)
    node('Walkways', 'StaticBody2D', 'World', None, {'collision_layer': '1', 'collision_mask': '0'})
    for i, (name, left, right, top, thick) in enumerate(spec['decks']):
        sid = 'Deck%d' % i
        subs.append('[sub_resource type="RectangleShape2D" id="%s"]\nsize = %s' % (sid, vec(right - left, thick)))
        node(name, 'CollisionShape2D', 'World/Walkways', None, {
            'position': vec((left + right) / 2.0, top + thick / 2.0), 'shape': 'SubResource("%s")' % sid})
    node('Checkpoints', 'Node2D', 'World')
    for i, (x, top) in enumerate(spec['checkpoints']):
        node('Checkpoint%d' % (i + 1), 'Marker2D', 'World/Checkpoints', None, {'position': vec(x, top - 1)})
    if spec.get('aim_pads'):
        node('AimPads', 'Node2D', 'World')
        for i, (x, top) in enumerate(spec['aim_pads']):
            node('AimPad%d' % (i + 1), 'Marker2D', 'World/AimPads', None, {'position': vec(x, top)})
    if spec.get('down_spots'):
        node('DownSpots', 'Node2D', 'World')
        for i, (x, top) in enumerate(spec['down_spots']):
            node('DownSpot%d' % (i + 1), 'Marker2D', 'World/DownSpots', None, {'position': vec(x, top)})
    ex = spec['exit']
    node('Exit', 'Marker2D', 'World', None, {'position': vec(ex[0], ex[1])})

    late = []   # drawn in front of Sera
    for item in spec['items']:
        kind, name = item[0], item[1]
        a = item[2:]
        if kind == 'gate':       # x, top
            node(name, None, 'World', res('PackedScene', SCENES['gate']), {'position': vec(a[0], a[1])})
        elif kind == 'shuttle':  # x, top, travel_x, travel_y, speed, opts
            opts = a[5] if len(a) > 5 else {}
            props = {'position': vec(a[0], a[1]), 'script': res('Script', SCRIPTS['shuttle']), 'travel': vec(a[2], a[3]), 'speed': num(float(a[4]))}
            for k, v in opts.items():
                props[k] = num(v)
            node(name, 'AnimatableBody2D', 'World', None, props)
        elif kind == 'sway':     # opts
            props = {'script': res('Script', SCRIPTS['sway'])}
            for k, v in a[0].items():
                props[k] = val(v)
            node(name, 'Node', 'World', None, props)
        elif kind == 'field':    # left x, bottom y, width, height, opts
            props = {'position': vec(a[0], a[1]), 'script': res('Script', SCRIPTS['field']), 'width': num(float(a[2])),
                     'height': num(float(a[3]))}
            for k, v in (a[4] if len(a) > 4 else {}).items():
                props[k] = val(v)
            node(name, 'Node2D', 'World', None, props)
        elif kind == 'rack':     # left x, deck top, length, pattern
            node(name, 'Node2D', 'World', None, {'position': vec(a[0], a[1]), 'script': res('Script', SCRIPTS['rack']),
                                                 'length': num(float(a[2])), 'pattern': '"%s"' % a[3]})
        elif kind == 'target':   # centre x, centre y, opts
            props = {'position': vec(a[0], a[1]), 'script': res('Script', SCRIPTS['target'])}
            for k, v in (a[2] if len(a) > 2 else {}).items():
                props[k] = val(v)
            node(name, 'Node2D', 'World', None, props)
        elif kind == 'warden':   # x, top, opts
            props = {'position': vec(a[0], a[1] - 2)}
            for k, v in a[2].items():
                props[k] = num(v)
            late.append((name, None, res('PackedScene', SCENES['warden']), props))
        elif kind == 'drone':    # x, top, patrol_left, patrol_right
            late.append((name, 'Node2D', None, {'position': vec(a[0], a[1]), 'script': res('Script', SCRIPTS['drone']),
                                                'patrol_left': num(float(a[2])), 'patrol_right': num(float(a[3]))}))
        elif kind in ('turret', 'mirror'):   # x, top, facing, muzzle height, burst, rest, reach
            props = {'position': vec(a[0], a[1]), 'script': res('Script', SCRIPTS['turret']),
                     'facing': num(float(a[2])), 'muzzle_height': num(float(a[3])), 'burst': num(a[4]),
                     'rest': num(float(a[5])), 'reach': num(float(a[6]))}
            if kind == 'mirror':
                props['mirror'] = 'true'
            late.append((name, 'Node2D', None, props))
        elif kind == 'launcher':  # x, top, facing, rest, reach
            late.append((name, 'Node2D', None, {'position': vec(a[0], a[1]), 'script': res('Script', SCRIPTS['launcher']),
                                                'facing': num(float(a[2])), 'rest': num(float(a[3])), 'reach': num(float(a[4]))}))
        elif kind == 'absorber':  # x, top, opts
            props = {'position': vec(a[0], a[1]), 'script': res('Script', SCRIPTS['absorber'])}
            for k, v in a[2].items():
                props[k] = num(v)
            late.append((name, 'Node2D', None, props))
        else:
            raise ValueError(kind)

    sx, stop = spec['start']
    node('Sera', None, 'World', res('PackedScene', SCENES['sera']), {'position': vec(sx, stop - 1), 'collision_mask': '5'})
    for name, type_, inst, props in late:
        node(name, type_, 'World', inst, props)
    node('Projectiles', 'Node2D', 'World', None, {'z_index': '3'})
    subs.append('[sub_resource type="CanvasItemMaterial" id="AdditiveEffects"]\nblend_mode = 1')
    node('Effects', 'Node2D', 'World', None, {'z_index': '4', 'material': 'SubResource("AdditiveEffects")', 'script': res('Script', SCRIPTS['effects'])})
    cam = spec['camera']
    node('Camera2D', 'Camera2D', '.', None, {'position': vec(cam[0], cam[1])})
    node('Sound', 'AudioStreamPlayer', '.')
    node('HUDLayer', 'CanvasLayer', '.', None, {'layer': '5'})
    node('HUD', 'Control', 'HUDLayer', None, {'layout_mode': '3', 'anchors_preset': '15', 'anchor_right': '1.0', 'anchor_bottom': '1.0',
                                                'mouse_filter': '2', 'script': res('Script', SCRIPTS['hud'])})

    out = ['[gd_scene load_steps=%d format=3]' % (len(ext) + len(subs) + 1), '']
    for kind, path, rid in ext:
        out.append('[ext_resource type="%s" path="%s" id="%s"]' % (kind, path, rid))
    out.append('')
    out.append('\n\n'.join(subs))
    out.append('')
    out.append('\n\n'.join(nodes))
    out.append('')
    path = os.path.join(PROJ, 'scenes', spec['file'])
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        f.write('\n'.join(out))
    print('wrote', path)


def root(next_scene, bounds, fall, cam_x, cam_y=(342, 342)):
    return {
        'next_scene': '"%s"' % next_scene, 'carry_charge': 'true',
        'horizontal_bounds': vec(bounds[0], bounds[1]), 'fall_limit': num(float(fall)),
        'camera_x': vec(cam_x[0], cam_x[1]), 'camera_y': vec(cam_y[0], cam_y[1]),
    }


F = 520  # the usual floor
T = 116  # deck thickness
SHIP = {'iron': (0.14, 0.16, 0.18, 1), 'edge': (0.58, 0.6, 0.6, 1), 'seam': (0.28, 0.3, 0.31, 1),
        'dark': (0.05, 0.07, 0.09, 1), 'accent': (1.0, 0.74, 0.45, 1), 'live': (0.55, 0.9, 1.0, 1)}
HOLD = {'iron': (0.12, 0.13, 0.15, 1), 'edge': (0.5, 0.52, 0.55, 1), 'seam': (0.24, 0.25, 0.27, 1),
        'dark': (0.04, 0.05, 0.07, 1), 'accent': (1.0, 0.84, 0.55, 1), 'live': (0.55, 0.9, 1.0, 1)}
KELDER = {'iron': (0.13, 0.15, 0.17, 1), 'edge': (0.6, 0.6, 0.62, 1), 'seam': (0.27, 0.28, 0.3, 1),
          'dark': (0.05, 0.06, 0.08, 1), 'accent': (1.0, 0.62, 0.38, 1), 'live': (0.55, 0.9, 1.0, 1)}
LAB = {'iron': (0.13, 0.12, 0.18, 1), 'edge': (0.62, 0.58, 0.74, 1), 'seam': (0.27, 0.25, 0.34, 1),
       'dark': (0.05, 0.05, 0.09, 1), 'accent': (1.0, 0.82, 0.55, 1), 'live': (0.72, 0.62, 1.0, 1)}

SPECS = []

# ---------------------------------------------------------------- 3-1 화물선 갑판 (rolling deck, barrels, reflect)
SPECS.append({
    'file': 'cargo_deck.tscn', 'name': 'CargoDeck', 'script': 'res://scripts/cargo_deck.gd', 'skyline': 'ship',
    'palette': SHIP,
    'root': root('res://scenes/cargo_hold.tscn', (-70, 6950), 813, (576, 6440)),
    'start': (150, F), 'camera': (576, 342), 'exit': (6880, F),
    'decks': [('Stern', -100, 1500, F, T), ('MidA', 1620, 3300, F, T), ('HatchCover', 2300, 2560, 460, 60),
              ('MidB', 3420, 5000, F, T), ('Bow', 5120, 7050, F, T)],
    'checkpoints': [(1700, F), (5200, F)],
    'items': [
        ('sway', 'Swell', {'calm_time': 3.0, 'lean_time': 2.6, 'slide': 150.0, 'max_angle': 3.5, 'pattern': 'LR'}),
        ('rack', 'RackA', 400, F, 900, 'B'),
        ('gate', 'GateA', 1460, F),
        ('rack', 'RackB', 1700, F, 560, 'B'),
        ('rack', 'RackC', 2600, F, 600, 'RB'),
        ('rack', 'RackD', 3500, F, 1380, 'BRB'),
        ('rack', 'RackE', 5250, F, 1000, 'RB'),
        ('gate', 'ExitGate', 6780, F),
        ('turret', 'TurretA', 1350, F, -1, 85, 1, 2.4, 700),
        ('warden', 'GuardA', 3000, F, {'arena_start': 2500.0}),
        ('turret', 'TurretB', 3250, F, -1, 85, 2, 1.9, 700),
        ('turret', 'HighTurret', 4800, F, -1, 140, 2, 2.0, 700),
        ('turret', 'TurretC', 6250, F, -1, 85, 3, 1.7, 700),
        ('warden', 'Keeper', 6550, F, {'reinforced': True, 'arena_start': 5600.0}),
    ],
})

# ---------------------------------------------------------------- 3-2 선창 (mirror turrets, reflect targets)
SPECS.append({
    'file': 'cargo_hold.tscn', 'name': 'CargoHold', 'script': 'res://scripts/cargo_hold.gd', 'skyline': 'hold',
    'palette': HOLD,
    'root': root('res://scenes/helmsman.tscn', (-70, 6950), 813, (576, 6440)),
    'start': (150, F), 'camera': (576, 342), 'exit': (6860, F),
    'decks': [('HoldFloor', -100, 4500, F, T), ('CrateStep', 1100, 1300, 460, 60), ('Reefer', 4500, 4750, 300, 220),
              ('HoldAft', 4750, 7000, F, T)],
    'checkpoints': [(3450, F), (4850, F)],
    'aim_pads': [(2560, F), (5530, F)],
    'down_spots': [(4460, F)],
    'items': [
        ('sway', 'Swell', {'calm_time': 3.4, 'lean_time': 2.2, 'slide': 90.0, 'max_angle': 2.5, 'pattern': 'RL'}),
        ('gate', 'GateA', 1760, F),
        ('target', 'TargetA', 2730, 300, {'post': 220.0}),
        ('gate', 'GateB', 3300, F),
        ('target', 'TargetB', 5720, 280, {'post': 240.0}),
        ('gate', 'GateC', 6300, F),
        ('gate', 'ExitGate', 6760, F),
        ('mirror', 'MirrorA', 1650, F, -1, 85, 1, 2.2, 700),
        ('mirror', 'MirrorB', 3100, F, -1, 85, 2, 2.0, 760),
        ('warden', 'ShieldA', 4100, F, {'front_guard': True, 'arena_start': 3600.0}),
        ('turret', 'TurretC', 4400, F, -1, 85, 2, 1.8, 640),
        ('mirror', 'MirrorC', 5400, F, -1, 140, 2, 2.0, 700),
        ('mirror', 'MirrorD', 6100, F, -1, 85, 2, 1.9, 760),
        ('warden', 'Keeper', 6550, F, {'reinforced': True, 'arena_start': 6320.0}),
    ],
})

# ---------------------------------------------------------------- 3-4 계류 데크 (homing launchers)
SPECS.append({
    'file': 'mooring_deck.tscn', 'name': 'MooringDeck', 'script': 'res://scripts/mooring_deck.gd', 'skyline': 'kelder',
    'palette': KELDER,
    'root': root('res://scenes/pipe_rack.tscn', (-70, 7000), 813, (576, 6490), (122, 342)),
    'start': (150, F), 'camera': (576, 342), 'exit': (6930, 300),
    'decks': [('DockA', -100, 1400, F, T), ('DockB', 1540, 3200, F, T), ('DockC', 3460, 5400, F, T),
              ('Bollard', 5400, 5700, 300, 220), ('Upper', 5700, 7050, 300, T)],
    'checkpoints': [(1640, F), (3560, F)],
    'down_spots': [(5360, F)],
    'items': [
        ('gate', 'GateA', 1380, F),
        ('gate', 'ExitGate', 6820, 300),
        ('launcher', 'LauncherA', 1230, F, -1, 2.8, 820),
        ('turret', 'TurretB', 2300, F, -1, 85, 2, 1.9, 700),
        ('launcher', 'LauncherB', 3050, F, -1, 2.6, 900),
        ('mirror', 'MirrorC', 4200, F, -1, 85, 2, 2.0, 700),
        ('launcher', 'LauncherC', 5000, F, -1, 2.6, 800),
        ('launcher', 'LauncherD', 6300, 300, -1, 2.4, 800),
        ('mirror', 'MirrorE', 6650, 300, -1, 85, 2, 1.8, 700),
    ],
})

# ---------------------------------------------------------------- 3-5 파이프 랙 (absorber guards)
SPECS.append({
    'file': 'pipe_rack.tscn', 'name': 'PipeRack', 'script': 'res://scripts/pipe_rack.gd', 'skyline': 'pipes',
    'palette': KELDER,
    'root': root('res://scenes/drill_rig.tscn', (-70, 7050), 813, (576, 6540)),
    'start': (150, F), 'camera': (576, 342), 'exit': (6950, F),
    'decks': [('WalkA', -100, 3600, F, T), ('Trestle', 3150, 3450, 380, 40), ('WalkC', 3750, 5400, F, T),
              ('WalkD', 5600, 7100, F, T)],
    'checkpoints': [(2100, F), (3850, F)],
    'items': [
        ('gate', 'GateA', 1700, F),
        ('gate', 'GateC', 5300, F),
        ('gate', 'ExitGate', 6820, F),
        ('absorber', 'AbsorberA', 1500, F, {'arena_start': 900.0}),
        ('mirror', 'MirrorB', 2800, F, -1, 85, 2, 1.9, 700),
        ('launcher', 'LauncherB', 3300, 380, -1, 2.6, 900),
        ('absorber', 'AbsorberC', 4400, F, {'arena_start': 3800.0}),
        ('absorber', 'AbsorberD', 5000, F, {'reinforced': True, 'arena_start': 4300.0}),
        ('launcher', 'LauncherE', 6200, F, -1, 2.4, 800),
        ('absorber', 'Keeper', 6500, F, {'reinforced': True, 'arena_start': 5650.0}),
    ],
})

# ---------------------------------------------------------------- 3-7 중력 시험동 (low gravity)
LEDGE = 160
SPECS.append({
    'file': 'gravity_lab.tscn', 'name': 'GravityLab', 'script': 'res://scripts/gravity_lab.gd', 'skyline': 'lab',
    'palette': LAB,
    'root': root('res://scenes/echo_chamber.tscn', (-70, 6700), 900, (576, 6190), (-18, 342)),
    'start': (150, F), 'camera': (576, 342), 'exit': (6600, F),
    'decks': [('Airlock', -100, 1200, F, T), ('LabFloor', 1200, 2400, F, T), ('StepA', 1300, 1480, 400, 30),
              ('StepB', 1580, 1760, 280, 30), ('StepC', 1860, 2040, LEDGE, 30), ('Ledge', 2100, 3400, LEDGE, 60),
              ('PadB', 3660, 3880, LEDGE, 60), ('PadC', 4140, 4400, LEDGE, 60), ('LedgeD', 4660, 5200, LEDGE, 60),
              ('FloorE', 5200, 6800, F, T)],
    'checkpoints': [(2200, LEDGE), (4750, LEDGE)],
    'aim_pads': [(5560, F)],
    'items': [
        ('field', 'FieldA', 1200, F, 1200, 700),
        ('field', 'FieldB', 3300, LEDGE, 1400, 500, {'on_time': 3.2, 'off_time': 1.8}),
        ('field', 'FieldC', 5300, F, 1300, 600),
        ('target', 'TargetE', 5780, 250, {'post': 270.0}),
        ('gate', 'ExitGate', 6450, F),
        ('mirror', 'MirrorA', 3200, LEDGE, -1, 85, 2, 2.0, 700),
        ('launcher', 'LauncherB', 4300, LEDGE, -1, 2.8, 900),
        ('absorber', 'AbsorberE', 5900, F, {'arena_start': 5250.0}),
    ],
})

# ---------------------------------------------------------------- 3-8 반향실 (three floors, everything)
L1, L2, L3 = 1160, 840, 520
SPECS.append({
    'file': 'echo_chamber.tscn', 'name': 'EchoChamber', 'script': 'res://scripts/echo_chamber.gd', 'skyline': 'chamber',
    'palette': LAB,
    'root': root('res://scenes/echo.tscn', (-70, 4700), 1460, (576, 4190), (342, 982)),
    'start': (150, L1), 'camera': (576, 982), 'exit': (4620, L3),
    # Each field room has a floor under its steps, so a missed jump drops back down instead of out.
    'decks': [('Floor1', -100, 1900, L1, T), ('Step1', 1450, 1600, 1040, 30), ('Step2', 1640, 1740, 920, 30),
              ('Floor2', 1750, 3150, L2, T), ('Step3', 2850, 3000, 720, 30), ('Step4', 3020, 3140, 600, 30),
              ('Floor3', 3150, 4750, L3, T)],
    'checkpoints': [(1850, L2), (3250, L3)],
    'aim_pads': [(2070, L2)],
    'items': [
        ('field', 'FieldA', 1250, L1, 650, 500),
        ('field', 'FieldB', 2750, L2, 500, 500, {'on_time': 3.0, 'off_time': 1.5}),
        ('gate', 'GateA', 1300, L1),
        ('target', 'TargetB', 2300, 560, {'post': 280.0}),
        ('gate', 'GateB', 2740, L2),
        ('gate', 'ExitGate', 4500, L3),
        ('mirror', 'MirrorA', 600, L1, -1, 85, 2, 2.0, 700),
        ('absorber', 'AbsorberA', 1150, L1, {'arena_start': 500.0}),
        ('mirror', 'MirrorB', 2620, L2, -1, 85, 2, 1.9, 700),
        ('launcher', 'LauncherB', 2460, L2, -1, 2.8, 900),
        ('absorber', 'Keeper', 3900, L3, {'reinforced': True, 'arena_start': 3300.0}),
        ('mirror', 'MirrorC', 4100, L3, -1, 140, 2, 1.9, 700),
        ('launcher', 'LauncherC', 4300, L3, -1, 2.4, 800),
    ],
})

for spec in SPECS:
    if len(sys.argv) < 3 or spec['file'] in sys.argv[2:]:
        build(spec)
