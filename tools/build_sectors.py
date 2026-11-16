# Generated the first version of the sector stage scenes (stages 4, 5, 7, 8) from the layout specs below.
#
# WARNING: running this OVERWRITES scenes/rolling_mill.tscn, steam_works.tscn, outer_ring.tscn and
# control_spine.tscn. The .tscn files are the source of truth now: anything moved in the Godot editor
# is lost if this is run again. It is kept only as a readable record of the original layout numbers
# and as a starting point for generating a brand-new stage.
#
# Usage: python tools/build_sectors.py <project folder> [scene file names...]
import os, sys

PROJ = sys.argv[1]

SCRIPTS = {
    'deck': 'res://scripts/sector_deck.gd', 'effects': 'res://scripts/effects.gd', 'hud': 'res://scripts/hud.gd',
    'relay': 'res://scripts/kinetic_relay.gd', 'timed': 'res://scripts/timed_relay.gd', 'valve': 'res://scripts/pulse_valve.gd',
    'belt': 'res://scripts/conveyor.gd', 'hazard': 'res://scripts/hazard_gate.gd', 'shuttle': 'res://scripts/shuttle.gd',
    'shutter': 'res://scripts/shutter.gd', 'ram': 'res://scripts/ram.gd', 'drone': 'res://scripts/drone.gd',
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
    ext = []      # (type, path, id)
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

    root = spec['root']
    root_props = {'process_mode': '3', 'script': res('Script', spec['script'])}
    root_props.update(root)
    node(spec['name'], 'Node2D', None, None, root_props)

    node('FarBackground', 'CanvasLayer', '.', None, {'layer': '-2'})
    node('Backdrop', 'Sprite2D', 'FarBackground', None, {
        'position': vec(-40, -30), 'scale': vec(0.82, 0.82), 'texture': res('Texture2D', spec['backdrop']),
        'centered': 'false', 'modulate': color(spec['tint'])})
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


def root(next_scene, caption, clear_title, clear_note, title, sections, bounds, fall, cam_x, cam_y=(342, 342)):
    # The words (caption, clear_title, clear_note, title, sections) now live in texts.gd and are no
    # longer written into the scene; they stay in the specs below only as a record.
    return {
        'next_scene': '"%s"' % next_scene, 'carry_charge': 'true',
        'horizontal_bounds': vec(bounds[0], bounds[1]), 'fall_limit': num(float(fall)),
        'camera_x': vec(cam_x[0], cam_x[1]), 'camera_y': vec(cam_y[0], cam_y[1]),
    }


F = 520  # the usual floor
T = 116  # deck thickness

SPECS = []

# ---------------------------------------------------------------- Stage 4 압연 라인
SPECS.append({
    'file': 'rolling_mill.tscn', 'name': 'RollingMill', 'script': 'res://scripts/rolling_mill.gd',
    'backdrop': 'res://assets/environment/furnace.jpg', 'tint': (1.0, 0.82, 0.7, 1),
    'palette': {'iron': (0.13, 0.13, 0.15, 1), 'edge': (0.55, 0.47, 0.42, 1), 'seam': (0.27, 0.23, 0.22, 1),
                'dark': (0.06, 0.07, 0.09, 1), 'accent': (1.0, 0.66, 0.38, 1)},
    'root': root('res://scenes/steam_works.tscn', '증기 배관로로', '압연 라인 돌파', '화물 통로 아래에서 뜨거운 김이 올라온다.',
                 '압연 라인', ['이송 벨트', '프레스 열', '출하 벨트'], (-70, 6850), 813, (576, 6340)),
    'start': (150, F), 'camera': (576, 342), 'exit': (6740, F),
    'decks': [
        ('Intake', -100, 700, F, T), ('Landing', 1380, 2150, F, T), ('PressApproach', 2650, 3050, F, T),
        ('RamFloor', 3850, 5000, F, T), ('Dispatch', 5800, 6900, F, T),
    ],
    'checkpoints': [(2720, F), (4780, F)],
    'items': [
        ('belt', 'FeedBelt', 700, F, 480, 300),
        ('valve', 'LandingValve', 2000, F),
        ('belt', 'ReturnBelt', 2150, F, 500, -300),
        ('belt', 'PressBelt', 3050, F, 800, 200),
        ('hazard', 'PressA', 3250, F, {'kind': 'press', 'off_time': 1.5, 'on_time': 0.3, 'phase': 0.0, 'half_width': 56.0}),
        ('hazard', 'PressB', 3500, F, {'kind': 'press', 'off_time': 1.5, 'on_time': 0.3, 'phase': 1.25, 'half_width': 56.0}),
        ('hazard', 'PressC', 3750, F, {'kind': 'press', 'off_time': 1.5, 'on_time': 0.3, 'phase': 0.7, 'half_width': 56.0}),
        ('ram', 'RamA', 4500, F, 3950, 4610),
        ('gate', 'RamGate', 4680, F),
        ('belt', 'DispatchBelt', 5000, F, 800, -220),
        ('ram', 'RamB', 5700, F, 4950, 5760),
        ('warden', 'Warden', 6380, F, {'reinforced': True, 'arena_start': 5830.0}),
        ('gate', 'ExitGate', 6620, F),
    ],
})

# ---------------------------------------------------------------- Stage 5 증기 배관로
SPECS.append({
    'file': 'steam_works.tscn', 'name': 'SteamWorks', 'script': 'res://scripts/steam_works.gd',
    'backdrop': 'res://assets/environment/cooling_tower.jpg', 'tint': (0.78, 0.86, 0.84, 1),
    'palette': {'iron': (0.1, 0.17, 0.19, 1), 'edge': (0.45, 0.6, 0.6, 1), 'seam': (0.2, 0.3, 0.31, 1),
                'dark': (0.04, 0.08, 0.1, 1), 'accent': (0.96, 0.75, 0.48, 1), 'live': (0.47, 0.92, 0.84, 1)},
    'root': root('res://scenes/loading_yard.tscn', '출하 야드로', '증기 배관로 돌파', '배관 끝, 야적장 위로 거대한 크레인이 움직인다.',
                 '증기 배관로', ['누출 구역', '정비 통로', '배출 수직구'], (-70, 5000), 813, (576, 4488)),
    'start': (150, F), 'camera': (576, 342), 'exit': (4920, F),
    'decks': [('Works', -100, 3300, F, T), ('Outfall', 3900, 5050, F, T)],
    'checkpoints': [(1800, F), (3230, F)],
    'aim_pads': [(2812, F)],
    'items': [
        ('valve', 'ValveA', 1000, F), ('valve', 'ValveB', 1640, F),
        ('timed', 'TimedRelay', 2960, 300, 2.6),
        ('valve', 'ValveC', 2800, F),
        ('shutter', 'Shutter', 3140, F),
        ('gate', 'DroneGate', 2560, F),
        ('shuttle', 'Ferry', 3400, F, 400, 0, 115),
        ('valve', 'ValveD', 4400, F),
        ('gate', 'ExitGate', 4830, F),
        ('hazard', 'SteamA', 600, F, {'kind': 'steam', 'off_time': 1.7, 'on_time': 1.3}),
        ('hazard', 'SteamB', 1200, F, {'kind': 'steam', 'always_on': True}),
        ('hazard', 'SteamC', 4120, F, {'kind': 'steam', 'always_on': True}),
        ('drone', 'DroneA', 2250, F, 1950, 2480),
        ('drone', 'DroneB', 3600, F, 3350, 3850),
        ('drone', 'DroneC', 4620, F, 4480, 4790),
    ],
})

# ---------------------------------------------------------------- Stage 7 외곽 링
SPECS.append({
    'file': 'outer_ring.tscn', 'name': 'OuterRing', 'script': 'res://scripts/outer_ring.gd',
    'backdrop': 'res://assets/environment/reactor.jpg', 'tint': (0.72, 0.74, 1.0, 1),
    'palette': {'iron': (0.14, 0.14, 0.22, 1), 'edge': (0.52, 0.5, 0.7, 1), 'seam': (0.25, 0.24, 0.36, 1),
                'dark': (0.05, 0.05, 0.1, 1), 'accent': (0.78, 0.68, 1.0, 1), 'live': (0.6, 0.86, 1.0, 1)},
    'root': root('res://scenes/control_spine.tscn', '관제 중추로', '외곽 링 돌파', '저장고 문 너머, 포어맨의 관제탑이 서 있다.',
                 '외곽 링', ['진입 램프', '관성 벨트', '저장고 문'], (-70, 5700), 813, (576, 5188)),
    'start': (150, F), 'camera': (576, 342), 'exit': (5600, F),
    'decks': [('Ramp', -100, 600, F, T), ('RingA', 1350, 2500, F, T), ('Island', 2900, 3050, F, T),
              ('RingB', 3450, 3900, F, T), ('Vault', 4500, 5750, F, T)],
    'checkpoints': [(2420, F), (3540, F)],
    'aim_pads': [(4932, F)],
    'items': [
        ('belt', 'RampBelt', 600, F, 500, 380),
        ('belt', 'DragBeltA', 2500, F, 400, -260),
        ('belt', 'DragBeltB', 3050, F, 400, -260),
        ('shuttle', 'Ferry', 4000, F, 400, 0, 130),
        ('relay', 'ShieldRelay', 5080, 300),
        ('gate', 'ExitGate', 5480, F),
        ('hazard', 'SteamLock', 2330, F, {'kind': 'steam', 'always_on': True}),
        ('hazard', 'SteamA', 2720, F, {'kind': 'steam', 'off_time': 1.6, 'on_time': 1.2}),
        ('hazard', 'SteamB', 3230, F, {'kind': 'steam', 'off_time': 1.6, 'on_time': 1.2, 'phase': 1.4}),
        ('ram', 'RamA', 2100, F, 1480, 2240),
        ('drone', 'DroneA', 2975, F, 2620, 3330),
        ('drone', 'DroneB', 4200, F, 3950, 4450),
        ('warden', 'Sentinel', 5250, F, {'reinforced': True, 'shielded': True, 'arena_start': 4530.0}),
    ],
})

# ---------------------------------------------------------------- Stage 8 관제 중추
L1, L2, L3 = 1160, 840, 520
SPECS.append({
    'file': 'control_spine.tscn', 'name': 'ControlSpine', 'script': 'res://scripts/control_spine.gd',
    'backdrop': 'res://assets/environment/cooling_tower.jpg', 'tint': (0.8, 0.84, 1.0, 1),
    'palette': {'iron': (0.11, 0.16, 0.23, 1), 'edge': (0.5, 0.62, 0.74, 1), 'seam': (0.22, 0.3, 0.4, 1),
                'dark': (0.04, 0.07, 0.12, 1), 'accent': (1.0, 0.72, 0.45, 1), 'live': (0.52, 0.9, 1.0, 1)},
    'root': root('res://scenes/great_wheel.tscn', '대관성륜으로', '관제 중추 돌파', '관제실 바닥이 열린다. 그 아래에 대관성륜이 있다.',
                 '관제 중추', ['하층 정비고', '중층 이송로', '상층 관제실'], (-70, 4420), 1500, (576, 3908), (342, 982)),
    'start': (150, L1), 'camera': (576, 982), 'exit': (4330, L3),
    'decks': [('Lower', -100, 1325, L1, T), ('MiddleA', 1495, 1700, L2, T), ('MiddleB', 2200, 2700, L2, T),
              ('Upper', 2870, 4470, L3, T)],
    'checkpoints': [(1570, L2), (2950, L3)],
    'aim_pads': [(1112, L1), (3102, L3), (3682, L3)],
    'items': [
        ('relay', 'LiftRelay', 1260, 940),
        ('valve', 'ValveL', 1060, L1),
        ('shuttle', 'LiftA', 1410, L1, 0, -320, 150, {'needs_power': True, 'half_width': 80.0, 'wait': 1.2}),
        ('belt', 'TransferBelt', 1700, L2, 500, 240),
        ('gate', 'MiddleGate', 2640, L2),
        ('shuttle', 'LiftB', 2785, L2, 0, -320, 150, {'half_width': 80.0, 'wait': 1.2}),
        ('valve', 'ValveA', 3060, L3),
        ('timed', 'TimedRelay', 3250, 300, 3.0),
        ('shutter', 'Shutter', 3420, L3),
        ('relay', 'ShieldRelay', 3830, 300),
        ('gate', 'ExitGate', 4230, L3),
        ('hazard', 'PressA', 1850, L2, {'kind': 'press', 'off_time': 1.5, 'on_time': 0.3, 'half_width': 56.0}),
        ('hazard', 'PressB', 2050, L2, {'kind': 'press', 'off_time': 1.5, 'on_time': 0.3, 'phase': 1.45, 'half_width': 56.0}),
        ('hazard', 'SteamA', 3330, L3, {'kind': 'steam', 'off_time': 1.6, 'on_time': 0.9}),
        ('ram', 'RamA', 900, L1, 420, 1100),
        ('drone', 'DroneA', 760, L1, 420, 1100),
        ('warden', 'WardenA', 2450, L2, {'reinforced': True, 'arena_start': 1500.0}),
        ('drone', 'DroneB', 3800, L3, 3520, 4150),
        ('warden', 'Sentinel', 4000, L3, {'reinforced': True, 'shielded': True, 'arena_start': 3450.0}),
    ],
})

for spec in SPECS:
    if len(sys.argv) < 3 or spec['file'] in sys.argv[2:]:
        build(spec)
