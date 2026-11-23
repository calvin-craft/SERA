# Generates the first version of chapter two's sector stage scenes (stages 2-1, 2-2, 2-4, 2-5, 2-7, 2-8)
# from the layout specs below. Boss stages are written by hand.
#
# WARNING: running this OVERWRITES the scene files it names. The .tscn files are the source of truth
# once they exist: anything moved in the Godot editor is lost if this is run again. Keep it as a
# readable record of the layout numbers and as a starting point for new stages.
#
# Usage: python tools/build_chapter2.py <project folder> [scene file names...]
import os
import sys

PROJ = sys.argv[1]

SCRIPTS = {
    'deck': 'res://scripts/sector_deck.gd', 'effects': 'res://scripts/effects.gd', 'hud': 'res://scripts/hud.gd',
    'relay': 'res://scripts/kinetic_relay.gd', 'timed': 'res://scripts/timed_relay.gd', 'valve': 'res://scripts/pulse_valve.gd',
    'belt': 'res://scripts/conveyor.gd', 'hazard': 'res://scripts/hazard_gate.gd', 'shuttle': 'res://scripts/shuttle.gd',
    'shutter': 'res://scripts/shutter.gd', 'ram': 'res://scripts/ram.gd', 'drone': 'res://scripts/drone.gd',
    'train': 'res://scripts/freight_train.gd', 'gust': 'res://scripts/gust.gd', 'hatch': 'res://scripts/hatch.gd',
    'turret': 'res://scripts/turret.gd', 'bomber': 'res://scripts/bomber.gd', 'skyline': 'res://scripts/skyline.gd',
}
SCENES = {'sera': 'res://scenes/sera.tscn', 'warden': 'res://scenes/warden.tscn', 'gate': 'res://scenes/bulkhead.tscn'}


def num(v):
    if isinstance(v, bool):
        return 'true' if v else 'false'
    if isinstance(v, float) and v == int(v):
        return str(int(v))
    return str(v)


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
        if kind == 'belt':      # left, top, length, speed
            node(name, 'StaticBody2D', 'World', None, {'position': vec(a[0], a[1]), 'script': res('Script', SCRIPTS['belt']),
                                                       'length': num(float(a[2])), 'speed': num(float(a[3]))})
        elif kind == 'shuttle':  # x, top, travel_x, travel_y, speed, opts
            opts = a[5] if len(a) > 5 else {}
            props = {'position': vec(a[0], a[1]), 'script': res('Script', SCRIPTS['shuttle']), 'travel': vec(a[2], a[3]), 'speed': num(float(a[4]))}
            for k, v in opts.items():
                props[k] = num(v)
            node(name, 'AnimatableBody2D', 'World', None, props)
        elif kind == 'valve':    # x, top
            node(name, 'Node2D', 'World', None, {'position': vec(a[0], a[1]), 'script': res('Script', SCRIPTS['valve'])})
        elif kind == 'relay':    # x, y
            node(name, 'Node2D', 'World', None, {'position': vec(a[0], a[1]), 'script': res('Script', SCRIPTS['relay'])})
        elif kind == 'timed':    # x, y, hold
            node(name, 'Node2D', 'World', None, {'position': vec(a[0], a[1]), 'script': res('Script', SCRIPTS['timed']), 'hold_time': num(float(a[2]))})
        elif kind == 'shutter':  # x, top
            node(name, 'StaticBody2D', 'World', None, {'position': vec(a[0], a[1]), 'script': res('Script', SCRIPTS['shutter'])})
        elif kind == 'gate':     # x, top
            node(name, None, 'World', res('PackedScene', SCENES['gate']), {'position': vec(a[0], a[1])})
        elif kind == 'train':    # trench left x, deck top, span, speed, cars, car length, gap time, phase
            node(name, 'AnimatableBody2D', 'World', None, {
                'position': vec(a[0], a[1]), 'script': res('Script', SCRIPTS['train']), 'span': num(float(a[2])),
                'speed': num(float(a[3])), 'cars': num(a[4]), 'car_length': num(float(a[5])), 'gap_time': num(float(a[6])),
                'phase': num(float(a[7]))})
        elif kind == 'gust':     # left x, bottom y, width, height, push, on, off, phase
            node(name, 'Node2D', 'World', None, {
                'position': vec(a[0], a[1]), 'script': res('Script', SCRIPTS['gust']), 'width': num(float(a[2])),
                'height': num(float(a[3])), 'push': num(float(a[4])), 'on_time': num(float(a[5])),
                'off_time': num(float(a[6])), 'phase': num(float(a[7]))})
        elif kind == 'hatch':    # centre x, top, half width
            node(name, 'StaticBody2D', 'World', None, {'position': vec(a[0], a[1]), 'script': res('Script', SCRIPTS['hatch']),
                                                       'half_width': num(float(a[2]))})
        elif kind == 'hazard':   # x, top, opts
            props = {'position': vec(a[0], a[1]), 'script': res('Script', SCRIPTS['hazard'])}
            for k, v in a[2].items():
                props[k] = ('"%s"' % v) if isinstance(v, str) else num(v)
            late.append((name, 'Node2D', None, props))
        elif kind == 'warden':   # x, top, opts
            props = {'position': vec(a[0], a[1] - 2)}
            for k, v in a[2].items():
                props[k] = num(v)
            late.append((name, None, res('PackedScene', SCENES['warden']), props))
        elif kind == 'ram':      # x, top, run_left, run_right
            late.append((name, 'Node2D', None, {'position': vec(a[0], a[1]), 'script': res('Script', SCRIPTS['ram']),
                                                'run_left': num(float(a[2])), 'run_right': num(float(a[3]))}))
        elif kind == 'drone':    # x, top, patrol_left, patrol_right
            late.append((name, 'Node2D', None, {'position': vec(a[0], a[1]), 'script': res('Script', SCRIPTS['drone']),
                                                'patrol_left': num(float(a[2])), 'patrol_right': num(float(a[3]))}))
        elif kind == 'turret':   # x, top, facing, muzzle height, burst, rest, reach
            late.append((name, 'Node2D', None, {'position': vec(a[0], a[1]), 'script': res('Script', SCRIPTS['turret']),
                                                'facing': num(float(a[2])), 'muzzle_height': num(float(a[3])), 'burst': num(a[4]),
                                                'rest': num(float(a[5])), 'reach': num(float(a[6]))}))
        elif kind == 'bomber':   # x, floor, patrol_left, patrol_right, pattern
            late.append((name, 'Node2D', None, {'position': vec(a[0], a[1]), 'script': res('Script', SCRIPTS['bomber']),
                                                'patrol_left': num(float(a[2])), 'patrol_right': num(float(a[3])),
                                                'pattern': '"%s"' % a[4]}))
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
COAST = {'iron': (0.12, 0.15, 0.17, 1), 'edge': (0.52, 0.58, 0.6, 1), 'seam': (0.24, 0.28, 0.3, 1),
         'dark': (0.05, 0.07, 0.09, 1), 'accent': (1.0, 0.7, 0.42, 1), 'live': (0.5, 0.9, 0.95, 1)}
HARBOUR = {'iron': (0.13, 0.14, 0.17, 1), 'edge': (0.55, 0.55, 0.6, 1), 'seam': (0.26, 0.26, 0.3, 1),
           'dark': (0.05, 0.06, 0.08, 1), 'accent': (1.0, 0.72, 0.45, 1), 'live': (0.55, 0.9, 1.0, 1)}

SPECS = []

# ---------------------------------------------------------------- 2-1 해안 선로 (trains, turrets)
SPECS.append({
    'file': 'coastal_line.tscn', 'name': 'CoastalLine', 'script': 'res://scripts/coastal_line.gd', 'skyline': 'coast',
    'palette': COAST,
    'root': root('res://scenes/cliff_bridge.tscn', (-70, 7050), 813, (576, 6540)),
    'start': (150, F), 'camera': (576, 342), 'exit': (6860, F),
    'decks': [('Platform', -100, 900, F, T), ('Siding', 1300, 1900, F, T), ('SignalYard', 2500, 3420, F, T),
              ('Junction', 3920, 5300, F, T), ('Terminal', 5700, 7100, F, T)],
    'checkpoints': [(2580, F), (4950, F)],
    'items': [
        ('train', 'TrainA', 900, F, 400, 300, 2, 180, 1.6, 0.0),
        ('train', 'TrainB', 1900, F, 600, 340, 3, 180, 1.5, 0.8),
        ('gate', 'SignalGate', 3330, F),
        ('train', 'TrainC', 3420, F, 500, 320, 2, 180, 1.6, 0.4),
        ('train', 'TrainD', 5300, F, 400, -380, 2, 180, 1.0, 0.2),
        ('gate', 'ExitGate', 6720, F),
        ('turret', 'TurretA', 3150, F, -1, 85, 2, 1.8, 640),
        ('turret', 'TurretB', 4180, F, -1, 85, 2, 1.7, 720),
        ('turret', 'TurretC', 4880, F, -1, 85, 3, 1.6, 640),
        ('ram', 'Ram', 5250, F, 5080, 5290),
        ('warden', 'Warden', 6450, F, {'reinforced': True, 'arena_start': 5800.0}),
    ],
})

# ---------------------------------------------------------------- 2-2 절벽 철교 (gusts, air absorb)
SPECS.append({
    'file': 'cliff_bridge.tscn', 'name': 'CliffBridge', 'script': 'res://scripts/cliff_bridge.gd', 'skyline': 'bridge',
    'palette': COAST,
    'root': root('res://scenes/armored_train.tscn', (-70, 7100), 813, (576, 6590)),
    'start': (150, F), 'camera': (576, 342), 'exit': (6980, F),
    'decks': [('Abutment', -100, 760, F, T), ('SpanA', 900, 1500, F, T), ('SpanB', 1720, 2300, F, T),
              ('PierA', 2440, 3300, F, T), ('PierB', 3700, 4300, F, T), ('SpanC', 4900, 5700, F, T),
              ('FarEnd', 6000, 7150, F, T)],
    'checkpoints': [(2520, F), (4980, F)],
    'items': [
        ('gust', 'GustA', 600, F, 700, 420, 220, 1.8, 1.6, 0.0),
        ('gust', 'GustB', 1300, F, 600, 420, 240, 1.6, 1.4, 0.5),
        ('gust', 'GustC', 2000, F, 600, 420, -260, 1.6, 1.6, 0.0),
        ('train', 'Train', 4300, F, 600, 340, 3, 180, 1.6, 0.0),
        ('gust', 'Headwind', 4200, F, 800, 420, -200, 1.0, 0.0, 0.0),
        ('gust', 'GustE', 5550, F, 600, 420, 240, 1.7, 1.5, 0.0),
        ('gate', 'ExitGate', 6850, F),
        ('turret', 'HighTurretA', 3200, F, -1, 140, 2, 1.9, 700),
        ('turret', 'LowTurret', 5350, F, -1, 85, 2, 1.8, 640),
        ('turret', 'HighTurretB', 5650, F, -1, 140, 2, 1.8, 700),
        ('drone', 'Drone', 6500, F, 6100, 6900),
        ('warden', 'Warden', 6600, F, {'reinforced': True, 'arena_start': 6050.0}),
    ],
})

# ---------------------------------------------------------------- 2-4 조차장 (down release, hatches)
L = 840
SPECS.append({
    'file': 'rail_yard.tscn', 'name': 'RailYard', 'script': 'res://scripts/rail_yard.gd', 'skyline': 'yard',
    'palette': HARBOUR,
    'root': root('res://scenes/container_wharf.tscn', (-70, 7150), 1133, (576, 6640), (342, 662)),
    'start': (150, F), 'camera': (576, 342), 'exit': (7080, F),
    'decks': [
        ('Yard', -100, 900, F, T),
        ('WallA', 900, 1300, 300, 220),
        ('Lane', 1300, 2630, F, T),
        ('HatchRim', 2770, 2900, F, T),
        ('Stack', 2900, 3700, -150, 670),
        ('Under', 2550, 3900, L, T),
        ('StepA', 3900, 4150, 680, 160),
        ('StepB', 4150, 4400, F, 320),
        ('Loading', 4400, 5200, F, T),
        ('Dock', 5800, 6400, F, T),
        ('WallB', 6400, 6650, 300, 220),
        ('Outbound', 6650, 7200, F, T),
    ],
    'checkpoints': [(2050, F), (4480, F)],
    'down_spots': [(860, F), (6360, F)],
    'items': [
        ('valve', 'ValveA', 700, F),
        ('valve', 'ValveB', 2400, F),
        ('hatch', 'Hatch', 2700, F, 70),
        ('valve', 'ValveC', 3300, L),
        ('train', 'Train', 5200, F, 600, 340, 3, 180, 1.6, 0.0),
        ('gate', 'ExitGate', 6980, F),
        ('turret', 'CorridorTurret', 3800, L, -1, 85, 2, 1.8, 640),
        ('turret', 'DockTurret', 6200, F, -1, 85, 2, 1.7, 720),
        ('warden', 'Warden', 6850, F, {'reinforced': True, 'arena_start': 6680.0}),
    ],
})

# ---------------------------------------------------------------- 2-5 컨테이너 부두 (shield guards)
SPECS.append({
    'file': 'container_wharf.tscn', 'name': 'ContainerWharf', 'script': 'res://scripts/container_wharf.gd', 'skyline': 'wharf',
    'palette': HARBOUR,
    'root': root('res://scenes/straddle_carrier.tscn', (-70, 6950), 813, (576, 6440)),
    'start': (150, F), 'camera': (576, 342), 'exit': (6780, F),
    'decks': [('Quay', -100, 1100, F, T), ('BoxA', 1100, 1350, 300, 220), ('Apron', 1350, 3800, F, T),
              ('Berth', 4300, 5100, F, T), ('Pier', 5350, 6950, F, T)],
    'checkpoints': [(2680, F), (4380, F)],
    'down_spots': [(1060, F)],
    'items': [
        ('valve', 'Valve', 1900, F),
        ('train', 'Train', 3800, F, 500, 320, 2, 180, 1.6, 0.0),
        ('gust', 'Tailwind', 4950, F, 600, 420, 240, 1.7, 1.5, 0.0),
        ('gate', 'ExitGate', 6650, F),
        ('warden', 'ShieldA', 800, F, {'front_guard': True, 'arena_start': 300.0}),
        ('warden', 'ShieldB', 2300, F, {'front_guard': True, 'arena_start': 1700.0}),
        ('warden', 'ShieldC', 3300, F, {'front_guard': True, 'reinforced': True, 'arena_start': 2750.0}),
        ('turret', 'ApronTurret', 3650, F, -1, 85, 2, 1.8, 640),
        ('drone', 'Drone', 4700, F, 4400, 5000),
        ('warden', 'ShieldD', 4800, F, {'front_guard': True, 'arena_start': 4420.0}),
        ('warden', 'ShieldE', 6200, F, {'front_guard': True, 'reinforced': True, 'arena_start': 5400.0}),
        ('turret', 'HighTurret', 6500, F, -1, 140, 2, 1.8, 700),
    ],
})

# ---------------------------------------------------------------- 2-7 방파제 (bombers)
SPECS.append({
    'file': 'breakwater.tscn', 'name': 'Breakwater', 'script': 'res://scripts/breakwater.gd', 'skyline': 'breakwater',
    'palette': COAST,
    'root': root('res://scenes/harbor_tower.tscn', (-70, 7050), 813, (576, 6540)),
    'start': (150, F), 'camera': (576, 342), 'exit': (6930, F),
    'decks': [('Mole', -100, 800, F, T), ('MoleB', 1000, 1700, F, T), ('Groyne', 2100, 3400, F, T),
              ('Causeway', 3900, 5400, F, T), ('Head', 5650, 7100, F, T)],
    'checkpoints': [(2180, F), (4900, F)],
    'items': [
        ('gust', 'WaveA', 650, F, 500, 420, 240, 1.6, 1.4, 0.0),
        ('train', 'Train', 3400, F, 500, 340, 2, 180, 1.4, 0.0),
        ('gust', 'WaveB', 5250, F, 550, 420, -240, 1.6, 1.6, 0.0),
        ('gate', 'ExitGate', 6800, F),
        ('turret', 'HighTurret', 1600, F, -1, 140, 2, 1.8, 700),
        ('bomber', 'BomberA', 2500, F, 2300, 2700, 'B'),
        ('bomber', 'BomberB', 3100, F, 2900, 3350, 'BR'),
        ('bomber', 'BomberC', 4300, F, 4000, 4700, 'RB'),
        ('warden', 'Shield', 4500, F, {'front_guard': True, 'arena_start': 3950.0}),
        ('bomber', 'BomberD', 6000, F, 5750, 6400, 'BRR'),
        ('turret', 'Turret', 6300, F, -1, 85, 2, 1.8, 640),
        ('warden', 'Keeper', 6600, F, {'front_guard': True, 'reinforced': True, 'arena_start': 5700.0}),
    ],
})

# ---------------------------------------------------------------- 2-8 항만 관제탑 (climb, everything)
L1, L2, L3 = 1160, 840, 520
SPECS.append({
    'file': 'harbor_tower.tscn', 'name': 'HarborTower', 'script': 'res://scripts/harbor_tower.gd', 'skyline': 'tower',
    'palette': HARBOUR,
    'root': root('res://scenes/dispatcher.tscn', (-70, 4650), 1460, (576, 4140), (342, 982)),
    'start': (150, L1), 'camera': (576, 982), 'exit': (4480, L3),
    'decks': [('Hold', -100, 1300, L1, T), ('Crates', 1300, 1500, 940, 220), ('Signal', 1600, 2200, L2, T),
              ('SignalB', 2600, 2900, L2, T), ('Bridge', 2900, 4700, L3, T)],
    'checkpoints': [(1700, L2), (3000, L3)],
    'down_spots': [(1260, L1)],
    'items': [
        ('train', 'Train', 2200, L2, 400, 300, 2, 170, 1.4, 0.0),
        ('shuttle', 'Lift', 2810, L2, 0, -320, 150, {'half_width': 90.0, 'wait': 1.2}),
        ('gate', 'ExitGate', 4350, L3),
        ('turret', 'HoldTurret', 700, L1, -1, 85, 2, 1.8, 640),
        ('warden', 'HoldShield', 1100, L1, {'front_guard': True, 'arena_start': 300.0}),
        ('bomber', 'SignalBomber', 1900, L2, 1650, 2150, 'BR'),
        ('bomber', 'BridgeBomber', 3600, L3, 3200, 4200, 'BRR'),
        ('warden', 'Keeper', 3700, L3, {'front_guard': True, 'reinforced': True, 'arena_start': 3050.0}),
        ('turret', 'BridgeTurret', 4000, L3, -1, 140, 2, 1.8, 700),
    ],
})

for spec in SPECS:
    if len(sys.argv) < 3 or spec['file'] in sys.argv[2:]:
        build(spec)
