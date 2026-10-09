extends Node2D
## Nailfall: a platform fighter with Hollow Knight style nail combat and
## Brawlhalla style damage-percent knockouts. Everything is drawn in code.

const W := 1280.0
const H := 720.0
const ATK_LEN := 20
const ACT_START := 4
const ACT_END := 11
const SOUL_COST := 33
const BLAST_L := -190.0
const BLAST_R := 1470.0
const BLAST_T := -150.0
const BLAST_B := 920.0

# Main ruin and hanging ledges
const MX := 250.0
const MY := 520.0
const MW := 780.0
const MH := 380.0
var SOFT: Array = [Rect2(300, 395, 200, 14), Rect2(780, 395, 200, 14), Rect2(540, 270, 200, 14)]

# damage, base knockback, knockback growth per damage point
var MOVES := {
	"side": [7.0, 5.0, 0.095],
	"up": [6.0, 5.5, 0.1],
	"down": [7.0, 4.5, 0.08],
	"bolt": [11.0, 5.5, 0.095],
}

# Each legend: cape, accent trim, armor, helm, skin, blade colors, horn shape and weapon
var CHARS: Array = [
	{"name": "Pale Wisp", "cloak": Color("2f5677"), "trim": Color("9fdcf5"), "armor": Color("6a7d8f"), "helm": Color("eef2f4"),
		"skin": Color("f1d6bf"), "blade": Color("e3edf2"), "horn": "straight", "weapon": "nail"},
	{"name": "Ember Husk", "cloak": Color("9a3d1e"), "trim": Color("f29a52"), "armor": Color("4d3d36"), "helm": Color("d08f4c"),
		"skin": Color("b97c56"), "blade": Color("ffe1c2"), "horn": "hooked", "weapon": "great"},
]

const PALE := Color("eef2f4")
const OUTLINE := Color("0a0d12")
const INK := Color("05070a")
const DIM := Color("8794a0")
const SOUL := Color("9fdcf5")

var BINDS: Array = [
	{"l": [KEY_A], "r": [KEY_D], "u": [KEY_W], "d": [KEY_S], "atk": [KEY_F], "dash": [KEY_G], "spell": [KEY_H]},
	{"l": [KEY_LEFT], "r": [KEY_RIGHT], "u": [KEY_UP], "d": [KEY_DOWN],
		"atk": [KEY_PERIOD, KEY_KP_1], "dash": [KEY_SLASH, KEY_KP_2], "spell": [KEY_COMMA, KEY_KP_3]},
]
var SOLO_EXTRA := {"l": [KEY_LEFT], "r": [KEY_RIGHT], "u": [KEY_UP], "d": [KEY_DOWN], "atk": [KEY_J], "dash": [KEY_K], "spell": [KEY_L]}


class Fighter:
	var id := 0
	var name := ""
	var cloak := Color.BLACK
	var trim := Color.WHITE
	var horn := ""
	var armor := Color.GRAY
	var helm := Color.WHITE
	var skin := Color.WHITE
	var blade := Color.WHITE
	var weapon := "nail"
	var x := 0.0
	var y := 0.0
	var vx := 0.0
	var vy := 0.0
	var hw := 16.0
	var h := 68.0
	var facing := 1
	var on_ground := false
	var on_soft := false
	var jumps := 1
	var air_dash := true
	var dmg := 0.0
	var stocks := 3
	var hitstun := 0
	var atk := 0
	var atk_type := "side"
	var atk_hit := false
	var dash := 0
	var dash_cd := 0
	var invuln := 0
	var soul := 33
	var spell_cd := 0
	var focus := 0
	var dead := false
	var respawn := 0
	var drop := 0
	var flash := 0
	var cpu := false
	var ai_cool := 0.0


class Ctl:
	var l := false
	var r := false
	var u := false
	var d := false
	var jh := false   # jump held, for short hops
	var jump := false
	var dp := false   # down pressed, drops through ledges
	var atk := false
	var dash := false
	var spell := false


class Particle:
	var x := 0.0
	var y := 0.0
	var vx := 0.0
	var vy := 0.0
	var life := 0.0
	var max_life := 1.0
	var color := Color.WHITE
	var size := 2.0
	var kind := "dot"
	var g := 0.0


class Bolt:
	var x := 0.0
	var y := 0.0
	var vx := 0.0
	var owner := 0
	var life := 80


var fighters: Array = []
var bolts: Array = []
var parts: Array = []
var state := "demo"   # demo (menu with CPU vs CPU behind it), play, paused, over
var mode := 1
var frame := 0
var freeze := 0
var shake := 0.0
var ready_timer := 0
var end_timer := 0
var winner: Fighter = null
var muted := false
var cam_x := 640.0
var cam_y := 400.0
var cam_z := 1.0

var pressed := {}
var pad_prev: Array = [{}, {}]
var font: Font
var body_font: Font
var far_towers: Array = []
var mid_cols: Array = []
var near_rocks: Array = []
var motes: Array = []
var buttons: Array = []   # [Rect2, action] for mouse clicks on menus
var sfx := {}
var players: Array = []
var next_player := 0


func _ready() -> void:
	var f = load("res://fonts/IMFellEnglishSC.ttf")
	font = f if f is Font else ThemeDB.fallback_font
	body_font = ThemeDB.fallback_font
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 24:
		far_towers.append([i * 72.0 + rng.randf() * 40.0, 18.0 + rng.randf() * 26.0, 160.0 + rng.randf() * 300.0, 10.0 + rng.randf() * 30.0])
	var cx := 0.0
	while cx < 1900.0:
		mid_cols.append([cx, 230.0 + rng.randf() * 60.0])
		cx += 196.0
	var rx := 0.0
	while rx < 1900.0:
		near_rocks.append([rx, 60.0 + rng.randf() * 170.0, 34.0 + rng.randf() * 50.0])
		rx += 70.0 + rng.randf() * 110.0
	for i in 50:
		motes.append([randf() * W, randf() * H, 0.2 + randf() * 0.6, 1.0 + randf() * 2.0])
	_build_sounds()
	new_match(1, true)


# ---------------------------------------------------------------- match flow

func make_fighter(i: int) -> Fighter:
	var c: Dictionary = CHARS[i]
	var f := Fighter.new()
	f.id = i
	f.name = c["name"]
	f.cloak = c["cloak"]
	f.trim = c["trim"]
	f.horn = c["horn"]
	f.armor = c["armor"]
	f.helm = c["helm"]
	f.skin = c["skin"]
	f.blade = c["blade"]
	f.weapon = c["weapon"]
	f.facing = -1 if i == 1 else 1
	return f


func new_match(m: int, demo: bool) -> void:
	mode = m
	fighters = [make_fighter(0), make_fighter(1)]
	fighters[0].cpu = demo
	fighters[1].cpu = demo or m == 1
	for f in fighters:
		spawn(f, true)
	bolts = []
	parts = []
	freeze = 0
	shake = 0.0
	end_timer = 0
	winner = null
	ready_timer = 0 if demo else 75
	cam_x = 640.0
	cam_y = 400.0
	cam_z = 1.0


func spawn(f: Fighter, initial: bool) -> void:
	f.dead = false
	f.vx = 0.0
	f.vy = 0.0
	f.hitstun = 0
	f.atk = 0
	f.dash = 0
	f.focus = 0
	f.jumps = 1
	f.air_dash = true
	f.dmg = 0.0
	f.flash = 0
	if initial:
		f.x = 840.0 if f.id == 1 else 440.0
		f.y = MY
		f.facing = -1 if f.id == 1 else 1
		f.invuln = 0
	else:
		f.x = 680.0 if f.id == 1 else 600.0
		f.y = 120.0
		f.invuln = 120
		burst(f.x, f.y - 30.0, f.trim, 18, 4.0)


func start_match(m: int) -> void:
	new_match(m, false)
	state = "play"


func to_menu() -> void:
	new_match(1, true)
	state = "demo"


# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.physical_keycode
		pressed[k] = true
		if k == KEY_M:
			muted = not muted
		elif k == KEY_ESCAPE:
			if state == "play":
				state = "paused"
			elif state == "paused":
				state = "play"
			elif state == "over":
				to_menu()
		elif state == "demo":
			if k == KEY_1 or k == KEY_ENTER:
				start_match(1)
			elif k == KEY_2:
				start_match(2)
		elif state == "over" and (k == KEY_ENTER or k == KEY_SPACE):
			start_match(mode)
	elif event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START:
		match state:
			"play": state = "paused"
			"paused": state = "play"
			"demo": start_match(1)
			"over": start_match(mode)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var p := get_local_mouse_position()
		for b in buttons:
			if (b[0] as Rect2).has_point(p):
				match b[1]:
					"cpu": start_match(1)
					"two": start_match(2)
					"again": start_match(mode)
					"menu": to_menu()
				break


func _held(keys: Array) -> bool:
	for k in keys:
		if Input.is_physical_key_pressed(k):
			return true
	return false


func _pressed(keys: Array) -> bool:
	for k in keys:
		if pressed.has(k):
			return true
	return false


func human_controls(i: int) -> Ctl:
	var c := Ctl.new()
	var sets: Array = [BINDS[i]]
	if mode == 1 and i == 0:
		sets.append(SOLO_EXTRA)
	for b in sets:
		c.l = c.l or _held(b["l"])
		c.r = c.r or _held(b["r"])
		c.u = c.u or _held(b["u"])
		c.d = c.d or _held(b["d"])
		c.jump = c.jump or _pressed(b["u"])
		c.dp = c.dp or _pressed(b["d"])
		c.atk = c.atk or _pressed(b["atk"])
		c.dash = c.dash or _pressed(b["dash"])
		c.spell = c.spell or _pressed(b["spell"])
	c.jh = c.u
	# Controller: stick or d-pad to move and aim, A jump, X nail, B or RB dash, Y spell
	var pads := Input.get_connected_joypads()
	if i < pads.size():
		var dev: int = pads[i]
		var ax := Input.get_joy_axis(dev, JOY_AXIS_LEFT_X)
		var ay := Input.get_joy_axis(dev, JOY_AXIS_LEFT_Y)
		c.l = c.l or ax < -0.4 or Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_LEFT)
		c.r = c.r or ax > 0.4 or Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_RIGHT)
		c.u = c.u or ay < -0.5 or Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_UP)
		var down_now := ay > 0.5 or Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_DOWN)
		var now := {
			"a": Input.is_joy_button_pressed(dev, JOY_BUTTON_A),
			"x": Input.is_joy_button_pressed(dev, JOY_BUTTON_X),
			"b": Input.is_joy_button_pressed(dev, JOY_BUTTON_B) or Input.is_joy_button_pressed(dev, JOY_BUTTON_RIGHT_SHOULDER),
			"y": Input.is_joy_button_pressed(dev, JOY_BUTTON_Y),
			"down": down_now,
		}
		var prev: Dictionary = pad_prev[i]
		c.d = c.d or down_now
		c.jh = c.jh or now["a"]
		c.jump = c.jump or (now["a"] and not prev.get("a", false))
		c.atk = c.atk or (now["x"] and not prev.get("x", false))
		c.dash = c.dash or (now["b"] and not prev.get("b", false))
		c.spell = c.spell or (now["y"] and not prev.get("y", false))
		c.dp = c.dp or (down_now and not prev.get("down", false))
		pad_prev[i] = now
	return c


func ai_controls(f: Fighter, o: Fighter) -> Ctl:
	var c := Ctl.new()
	if f.dead or f.hitstun > 0 or f.focus > 0:
		return c
	f.ai_cool -= 1.0
	var left := MX
	var right := MX + MW
	# recover toward the stage
	if f.x < left - 4.0 or f.x > right + 4.0:
		var toward := 1 if f.x < 640.0 else -1
		c.r = toward > 0
		c.l = toward < 0
		c.u = f.vy < 0.0
		if f.vy > 1.0 and f.jumps > 0 and f.y > MY - 90.0:
			c.jump = true
			c.u = true
		elif f.air_dash and f.dash_cd == 0 and f.y < MY + 20.0 and f.vy > -2.0:
			c.dash = true
		c.jh = c.u
		return c
	var tx := 640.0 if o.dead else o.x
	var ty := MY if o.dead else o.y
	var dx := tx - f.x
	var dy := ty - f.y
	var adx := absf(dx)
	var face := 1 if dx > 0.0 else -1
	if adx > 62.0:
		c.r = dx > 0.0
		c.l = dx < 0.0
	elif adx < 26.0 and randf() < 0.3:
		c.r = face < 0
		c.l = face > 0
	if f.on_ground and ((f.x < left + 24.0 and c.l) or (f.x > right - 24.0 and c.r)):
		c.l = false
		c.r = false
	if o.dead:
		return c
	for b in bolts:
		if b.owner != f.id and absf(b.y - (f.y - 30.0)) < 40.0 and signf(f.x - b.x) == signf(b.vx) and absf(f.x - b.x) < 170.0 and randf() < 0.25:
			c.jump = true
			c.u = true
	if dy < -70.0 and f.on_ground and randf() < 0.07:
		c.jump = true
		c.u = true
	if not f.on_ground and dy < -40.0 and f.vy > 0.0 and f.jumps > 0 and randf() < 0.05:
		c.jump = true
		c.u = true
	if f.vy < 0.0 and dy < -30.0:
		c.u = true
	if dy > 70.0 and f.on_soft and randf() < 0.05:
		c.d = true
		c.dp = true
	if f.atk == 0 and f.ai_cool <= 0.0:
		if adx < 90.0 and absf(dy) < 50.0 and randf() < 0.2:
			c.u = false
			c.d = false
			c.l = face < 0
			c.r = face > 0
			c.atk = true
		elif adx < 55.0 and dy < -40.0 and dy > -140.0 and randf() < 0.2:
			c.u = true
			c.atk = true
		elif not f.on_ground and dy > 15.0 and dy < 120.0 and adx < 45.0 and randf() < 0.25:
			c.d = true
			c.u = false
			c.atk = true
		if c.atk:
			f.ai_cool = 10.0 + randf() * 16.0
	if adx > 260.0 and f.on_ground and f.dash_cd == 0 and randf() < 0.02:
		c.dash = true
	if f.soul >= SOUL_COST and f.spell_cd == 0 and adx > 180.0 and absf(dy) < 40.0 and randf() < 0.015:
		c.spell = true
		c.u = false
		c.d = false
		c.l = face < 0
		c.r = face > 0
	if f.soul >= SOUL_COST and f.dmg > 70.0 and adx > 380.0 and f.on_ground and randf() < 0.05:
		c.l = false
		c.r = false
		c.u = false
		c.d = true
		c.spell = true
	c.jh = c.u
	return c


# ---------------------------------------------------------------- sound

func _make_sound(f0: float, f1: float, dur: float, gain: float, wave: String, noise: float, lp: float) -> AudioStreamWAV:
	var rate := 22050
	var n := int(dur * rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	var ph := 0.0
	var filt := 0.0
	for i in n:
		var t := float(i) / n
		var fr := f0 * pow(f1 / f0, t)
		ph += fr / rate
		var p := fmod(ph, 1.0)
		var s := 0.0
		match wave:
			"sine": s = sin(ph * TAU)
			"square": s = 1.0 if p < 0.5 else -1.0
			"saw": s = p * 2.0 - 1.0
			_: s = 4.0 * absf(p - 0.5) - 1.0
		var nz := randf() * 2.0 - 1.0
		filt += lp * (nz - filt)
		s = s * (1.0 - noise) + filt * noise * 2.0
		s *= gain * pow(1.0 - t, 2.0)
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	return w


func _build_sounds() -> void:
	sfx["slash"] = _make_sound(900, 400, 0.09, 0.35, "tri", 0.9, 0.6)
	sfx["hit"] = _make_sound(200, 50, 0.2, 0.9, "sine", 0.35, 0.3)
	sfx["hit_big"] = _make_sound(140, 30, 0.4, 1.0, "sine", 0.35, 0.2)
	sfx["clang"] = _make_sound(1900, 1500, 0.22, 0.35, "square", 0.05, 0.5)
	sfx["dash"] = _make_sound(200, 80, 0.14, 0.5, "sine", 0.85, 0.1)
	sfx["jump"] = _make_sound(260, 420, 0.08, 0.25, "tri", 0.0, 0.5)
	sfx["wings"] = _make_sound(500, 700, 0.16, 0.3, "sine", 0.7, 0.5)
	sfx["spell"] = _make_sound(320, 120, 0.3, 0.45, "saw", 0.4, 0.4)
	sfx["heal"] = _make_sound(420, 880, 0.4, 0.35, "sine", 0.0, 0.5)
	sfx["ko"] = _make_sound(140, 30, 0.8, 1.0, "sine", 0.45, 0.1)
	sfx["fight"] = _make_sound(220, 330, 0.5, 0.35, "tri", 0.0, 0.5)
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)


func play_sfx(name: String) -> void:
	if muted or state == "demo" or not sfx.has(name):
		return
	var p: AudioStreamPlayer = players[next_player]
	next_player = (next_player + 1) % players.size()
	p.stream = sfx[name]
	p.play()


# ---------------------------------------------------------------- particles

func add_part(x: float, y: float, vx: float, vy: float, life: float, color: Color, size: float, kind: String, g: float) -> void:
	var p := Particle.new()
	p.x = x
	p.y = y
	p.vx = vx
	p.vy = vy
	p.life = life
	p.max_life = life
	p.color = color
	p.size = size
	p.kind = kind
	p.g = g
	parts.append(p)


func burst(x: float, y: float, color: Color, n: int, spd: float) -> void:
	for i in n:
		var a := randf() * TAU
		var s := spd * (0.3 + randf())
		add_part(x, y, cos(a) * s, sin(a) * s, 20.0 + randf() * 20.0, color, 2.0 + randf() * 3.0, "dot", 0.05)


func sparks(x: float, y: float, dir: float, n: int) -> void:
	for i in n:
		var a := atan2(-0.4, dir) + (randf() - 0.5) * 1.6
		var s := 6.0 + randf() * 10.0
		add_part(x, y, cos(a) * s, sin(a) * s, 10.0 + randf() * 10.0, Color.WHITE, 2.0, "line", 0.2)


func dust(x: float, y: float) -> void:
	for i in 6:
		add_part(x + (randf() - 0.5) * 20.0, y, (randf() - 0.5) * 3.0, -randf() * 1.5, 18.0, Color("6b7884"), 3.0 + randf() * 3.0, "puff", 0.0)


func update_particles() -> void:
	for p in parts:
		p.x += p.vx
		p.y += p.vy
		p.vy += p.g
		p.vx *= 0.96
		p.life -= 1.0
		if p.kind == "ring":
			p.size += 9.0
	parts = parts.filter(func(p): return p.life > 0.0)


# ---------------------------------------------------------------- fighters

func update_fighter(f: Fighter, c: Ctl) -> void:
	if f.dead:
		f.respawn -= 1
		if f.respawn <= 0 and f.stocks > 0:
			spawn(f, false)
		return
	if f.invuln > 0: f.invuln -= 1
	if f.dash_cd > 0: f.dash_cd -= 1
	if f.spell_cd > 0: f.spell_cd -= 1
	if f.flash > 0: f.flash -= 1
	if f.drop > 0: f.drop -= 1
	var grav := 0.62
	var max_fall := 13.0
	if f.hitstun > 0:
		f.hitstun -= 1
		f.vx *= 0.85 if f.on_ground else 0.985
		grav = 0.48
		max_fall = 20.0
		if frame % 3 == 0:
			add_part(f.x, f.y - 30.0, 0, 0, 14, f.trim, 5, "puff", 0)
	elif f.focus > 0:
		f.focus -= 1
		f.vx *= 0.7
		if f.focus % 4 == 0:
			var a := randf() * TAU
			add_part(f.x + cos(a) * 50.0, f.y - 30.0 + sin(a) * 50.0, -cos(a) * 3.0, -sin(a) * 3.0, 16, Color.WHITE, 2.5, "dot", 0)
		if f.focus == 0:
			f.dmg = maxf(0.0, f.dmg - 25.0)
			burst(f.x, f.y - 30.0, Color.WHITE, 22, 5.0)
			play_sfx("heal")
	else:
		var dir := (1 if c.r else 0) - (1 if c.l else 0)
		if f.dash > 0:
			f.dash -= 1
			f.vx = f.facing * 16.0
			f.vy = 0.0
			grav = 0.0
			add_part(f.x - f.facing * 10.0, f.y - 28.0, -f.facing * 2.0, 0, 12, Color("0b0e12"), 14, "shade", 0)
		else:
			var acc := 1.3 if f.on_ground else 0.75
			f.vx += clampf(dir * 6.4 - f.vx, -acc, acc)
			if dir != 0 and f.atk == 0:
				f.facing = dir
			if dir == 0 and f.on_ground:
				f.vx *= 0.8
		if c.dp and f.on_soft:
			f.drop = 14
			f.on_ground = false
		if c.jump and f.dash == 0:
			if f.on_ground:
				f.vy = -13.2
				f.on_ground = false
				dust(f.x, f.y)
				play_sfx("jump")
			elif f.jumps > 0:
				f.jumps -= 1
				f.vy = -12.0
				play_sfx("wings")
				add_part(f.x, f.y - 34.0, 0, 1, 16, Color.WHITE, 1, "wings", 0)
		if not c.jh and f.vy < -3.0 and f.dash == 0:
			grav = 1.15   # short hop when jump is released
		if c.d and not f.on_ground and f.vy > 0.0:
			max_fall = 18.0   # fast fall
			grav = 0.9
		if c.dash and f.dash_cd == 0 and f.dash == 0 and (f.on_ground or f.air_dash):
			if dir != 0:
				f.facing = dir
			f.dash = 9
			f.dash_cd = 38
			f.atk = 0
			if not f.on_ground:
				f.air_dash = false
			play_sfx("dash")
		if c.atk and f.atk == 0 and f.dash == 0:
			if c.u:
				f.atk_type = "up"
			elif c.d and not f.on_ground:
				f.atk_type = "down"
			else:
				f.atk_type = "side"
			f.atk = ATK_LEN
			f.atk_hit = false
			play_sfx("slash")
		if c.spell and f.spell_cd == 0 and f.soul >= SOUL_COST and f.dash == 0:
			f.soul -= SOUL_COST
			f.spell_cd = 30
			f.atk = 0
			if c.d and f.on_ground:
				f.focus = 48
			else:
				var b := Bolt.new()
				b.x = f.x + f.facing * 26.0
				b.y = f.y - 32.0
				b.vx = f.facing * 13.0
				b.owner = f.id
				bolts.append(b)
				f.vx -= f.facing * 3.0
				play_sfx("spell")
	if f.atk > 0:
		f.atk -= 1
	f.vy = minf(f.vy + grav, max_fall)
	move_fighter(f)


func land(f: Fighter, top: float, was_ground: bool) -> void:
	f.y = top
	if f.hitstun > 0 and f.vy > 9.0:
		f.vy *= -0.45
		dust(f.x, top)
		shake = maxf(shake, 4.0)
		return
	f.vy = 0.0
	f.on_ground = true
	f.jumps = 1
	f.air_dash = true
	if not was_ground:
		dust(f.x, top)


func move_fighter(f: Fighter) -> void:
	var py := f.y
	var was := f.on_ground
	f.x += f.vx
	if f.y > MY + 1.0 and f.y - f.h < MY + MH and f.x + f.hw > MX and f.x - f.hw < MX + MW:
		f.x = MX - f.hw if f.x < MX + MW / 2.0 else MX + MW + f.hw
		f.vx = -f.vx * 0.4 if f.hitstun > 0 else 0.0
	f.y += f.vy
	f.on_ground = false
	f.on_soft = false
	if f.vy >= 0.0:
		if py <= MY + 0.01 and f.y >= MY and f.x + f.hw > MX + 2.0 and f.x - f.hw < MX + MW - 2.0:
			land(f, MY, was)
		elif f.drop == 0:
			for p in SOFT:
				var r: Rect2 = p
				if py <= r.position.y + 0.01 and f.y >= r.position.y and f.x > r.position.x - 6.0 and f.x < r.end.x + 6.0:
					land(f, r.position.y, was)
					f.on_soft = f.on_ground
					break


func atk_box(f: Fighter) -> Rect2:
	if f.dead or f.atk == 0:
		return Rect2()
	var fr := ATK_LEN - f.atk
	if fr < ACT_START or fr > ACT_END:
		return Rect2()
	var cy := f.y - f.h / 2.0
	if f.atk_type == "side":
		return Rect2(f.x + 4.0 if f.facing > 0 else f.x - 84.0, cy - 26.0, 80, 48)
	if f.atk_type == "up":
		return Rect2(f.x - 36.0, f.y - f.h - 62.0, 72, 68)
	return Rect2(f.x - 30.0, f.y - 8.0, 60, 64)


func hurt_box(f: Fighter) -> Rect2:
	return Rect2(f.x - f.hw, f.y - f.h, f.hw * 2.0, f.h)


func bolt_box(b: Bolt) -> Rect2:
	return Rect2(b.x - 20.0, b.y - 12.0, 40, 24)


func hit(a: Fighter, b: Fighter, kind: String, dir_x: float) -> void:
	var m: Array = MOVES[kind]
	b.dmg = minf(999.0, b.dmg + m[0])
	var kb: float = m[1] + b.dmg * m[2]
	var dx := 0.0
	var dy := 0.0
	if kind == "side" or kind == "bolt":
		dx = dir_x * 0.86
		dy = -0.5
	elif kind == "up":
		dx = dir_x * 0.25
		dy = -1.0
	elif b.on_ground:
		dx = dir_x * 0.5
		dy = -0.85
	else:
		dx = dir_x * 0.25
		dy = 0.95
	b.vx = dx * kb
	b.vy = dy * kb
	b.hitstun = int(10.0 + kb * 1.7)
	b.on_ground = false
	b.flash = 8
	b.atk = 0
	b.dash = 0
	b.focus = 0
	if b.vy < 0.0:
		b.y -= 2.0
	freeze = mini(14, 4 + int(kb * 0.5))
	shake = maxf(shake, minf(18.0, kb))
	sparks(b.x, b.y - 34.0, dir_x, 10 + int(kb))
	add_part(b.x, b.y - 34.0, 0, 0, 9, Color.WHITE, 18.0 + kb, "star", 0)
	burst(b.x, b.y - 30.0, b.trim, 8, 3.0)
	play_sfx("hit_big" if kb > 14.0 else "hit")
	if a != null:
		a.soul = mini(99, a.soul + 11)
		a.atk_hit = true
		if kind == "down":
			a.vy = -11.5
			a.jumps = 1
			a.air_dash = true
		if kind == "side":
			a.vx -= a.facing * 5.0


func handle_combat() -> void:
	var a: Fighter = fighters[0]
	var b: Fighter = fighters[1]
	var ba := atk_box(a)
	var bb := atk_box(b)
	# nails meeting clash
	if ba.has_area() and bb.has_area() and not a.atk_hit and not b.atk_hit and ba.intersects(bb):
		a.atk_hit = true
		b.atk_hit = true
		var s := signf(b.x - a.x)
		if s == 0.0:
			s = 1.0
		a.vx = -s * 8.0
		b.vx = s * 8.0
		freeze = 7
		shake = maxf(shake, 6.0)
		var mid := (ba.get_center() + bb.get_center()) / 2.0
		sparks(mid.x, mid.y, 0.0, 18)
		play_sfx("clang")
		return
	for pair in [[a, b, ba], [b, a, bb]]:
		var p: Fighter = pair[0]
		var q: Fighter = pair[1]
		var box: Rect2 = pair[2]
		if not box.has_area() or p.atk_hit:
			continue
		# nail versus spells: pogo off them or send them back
		for bo in bolts:
			if bo.owner == p.id or not box.intersects(bolt_box(bo)):
				continue
			if p.atk_type == "down":
				p.vy = -11.5
				p.jumps = 1
				p.air_dash = true
				bo.life = 0
				burst(bo.x, bo.y, Color.WHITE, 14, 4.0)
			else:
				bo.owner = p.id
				bo.vx = p.facing * absf(bo.vx) * 1.15
				bo.life = 80
				sparks(bo.x, bo.y, p.facing, 10)
			p.atk_hit = true
			freeze = 5
			play_sfx("clang")
		if not p.atk_hit and not q.dead and q.invuln == 0 and box.intersects(hurt_box(q)):
			var d := float(p.facing)
			if p.atk_type != "side":
				d = signf(q.x - p.x)
				if d == 0.0:
					d = p.facing
			hit(p, q, p.atk_type, d)


func update_bolts() -> void:
	for bo in bolts:
		bo.x += bo.vx
		bo.life -= 1
		if frame % 2 == 0:
			add_part(bo.x, bo.y + (randf() - 0.5) * 10.0, -bo.vx * 0.1, randf() - 0.5, 16, Color("cfeefa"), 4.0 + randf() * 4.0, "puff", 0)
		var t: Fighter = fighters[1 - bo.owner]
		if bo.life > 0 and not t.dead and t.invuln == 0 and bolt_box(bo).intersects(hurt_box(t)):
			hit(null, t, "bolt", signf(bo.vx))
			bo.life = 0
		if bo.x < BLAST_L or bo.x > BLAST_R:
			bo.life = 0
	bolts = bolts.filter(func(b): return b.life > 0)


func check_ko() -> void:
	for f in fighters:
		if f.dead or not (f.x < BLAST_L or f.x > BLAST_R or f.y > BLAST_B or f.y < BLAST_T):
			continue
		f.dead = true
		f.stocks -= 1
		f.respawn = 80
		var kx := clampf(f.x, cam_x - 600.0 / cam_z, cam_x + 600.0 / cam_z)
		var ky := clampf(f.y, cam_y - 330.0 / cam_z, cam_y + 330.0 / cam_z)
		add_part(kx, ky, 0, 0, 24, f.trim, 10, "ring", 0)
		burst(kx, ky, f.trim, 40, 9.0)
		burst(kx, ky, Color.WHITE, 20, 12.0)
		shake = 22.0
		freeze = 10
		play_sfx("ko")
		if f.stocks <= 0:
			winner = fighters[1 - f.id]
			end_timer = 110


func update_camera() -> void:
	var tx := 640.0
	var ty := 400.0
	var tz := 1.0
	var alive: Array = fighters.filter(func(f): return not f.dead)
	if alive.size() > 0:
		var minx := INF
		var maxx := -INF
		var miny := INF
		var maxy := -INF
		for f in alive:
			minx = minf(minx, f.x)
			maxx = maxf(maxx, f.x)
			miny = minf(miny, f.y - 30.0)
			maxy = maxf(maxy, f.y - 30.0)
		tx = (minx + maxx) / 2.0
		ty = (miny + maxy) / 2.0 - 20.0
		var span := maxf(maxx - minx + 560.0, (maxy - miny + 400.0) * 16.0 / 9.0)
		tz = clampf(W / span, 0.62, 1.12)
	tx = clampf(tx, 420.0, 860.0)
	ty = clampf(ty, 250.0, 470.0)
	cam_x += (tx - cam_x) * 0.08
	cam_y += (ty - cam_y) * 0.08
	cam_z += (tz - cam_z) * 0.06


func _physics_process(_delta: float) -> void:
	step()
	pressed.clear()
	queue_redraw()


func step() -> void:
	if state != "play" and state != "demo":
		return
	frame += 1
	if shake > 0.0:
		shake *= 0.86
	if freeze > 0:
		freeze -= 1
		return
	var ctrls: Array = []
	for i in 2:
		var f: Fighter = fighters[i]
		if ready_timer > 0 or end_timer > 0:
			ctrls.append(Ctl.new())
		elif f.cpu:
			ctrls.append(ai_controls(f, fighters[1 - i]))
		else:
			ctrls.append(human_controls(i))
	if ready_timer > 0:
		ready_timer -= 1
		if ready_timer == 20:
			play_sfx("fight")
	for i in 2:
		update_fighter(fighters[i], ctrls[i])
	handle_combat()
	update_bolts()
	check_ko()
	update_particles()
	update_camera()
	if end_timer > 0:
		end_timer -= 1
		if end_timer == 0:
			if state == "demo":
				new_match(1, true)
			else:
				state = "over"


# ---------------------------------------------------------------- drawing helpers

func fade(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, c.a * a)


func ellipse(cx: float, cy: float, rx: float, ry: float, n: int = 20) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(Vector2(cx + cos(a) * rx, cy + sin(a) * ry))
	return pts


func quad_to(pts: PackedVector2Array, p1: Vector2, p2: Vector2, n: int = 8) -> void:
	var p0 := pts[pts.size() - 1]
	for i in range(1, n + 1):
		var t := float(i) / n
		pts.append(p0.lerp(p1, t).lerp(p1.lerp(p2, t), t))


func fill(pts: PackedVector2Array, c: Color) -> void:
	if pts.size() >= 3:
		draw_colored_polygon(pts, c)


func text(s: String, pos: Vector2, size: int, c: Color, f: Font = null, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	draw_string(f if f != null else font, pos, s, align, width, size, c)


func center_text(s: String, size: int, y: float, c: Color, f: Font = null) -> void:
	text(s, Vector2(0, y), size, c, f, HORIZONTAL_ALIGNMENT_CENTER, W)


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	buttons.clear()
	var sk := shake
	var sx := (randf() - 0.5) * sk
	var sy := (randf() - 0.5) * sk
	draw_set_transform_matrix(Transform2D())
	draw_background()
	var world := Transform2D(0.0, Vector2(cam_z, cam_z), 0.0, Vector2(W / 2.0 + sx - cam_x * cam_z, H / 2.0 + sy - cam_y * cam_z))
	draw_set_transform_matrix(world)
	draw_stage()
	for b in bolts:
		draw_bolt(world, b)
	for f in fighters:
		draw_fighter(world, f)
	draw_set_transform_matrix(world)
	draw_particles()
	draw_set_transform_matrix(Transform2D())
	draw_fog_and_foreground()
	draw_vignette()
	if state != "demo":
		draw_hud()
	match state:
		"demo": draw_menu()
		"over": draw_over()
		"paused":
			draw_rect(Rect2(0, 0, W, H), Color(0.02, 0.035, 0.047, 0.6))
			center_text("Paused", 90, H / 2.0, PALE)
			center_text("Press Esc or Start to return to the fight", 22, H / 2.0 + 50.0, DIM, body_font)
		"play":
			if ready_timer > 20:
				center_text("Rise", 96, H / 2.0 - 10.0, fade(PALE, clampf((ready_timer - 20) / 20.0, 0.0, 1.0)))
			elif ready_timer > 0:
				center_text("Fight", 110, H / 2.0 - 10.0, fade(Color.WHITE, ready_timer / 20.0))


func draw_background() -> void:
	var px := cam_x - 640.0
	var py := cam_y - 400.0
	# misty sky: pale and blue up high, near black at the floor of the cavern
	var top := Color("2a4256")
	var mid := Color("162634")
	var bot := Color("091017")
	var bands := 30
	for i in bands:
		var t := float(i) / bands
		var c := top.lerp(mid, t / 0.55) if t < 0.55 else mid.lerp(bot, (t - 0.55) / 0.45)
		draw_rect(Rect2(0, i * H / bands, W, H / bands + 1.0), c)
	# far city of towers, barely there through the fog
	var ox := -160.0 - px * 0.05
	var oy := -py * 0.03
	for t in far_towers:
		var x: float = ox + t[0]
		var w: float = t[1]
		var base := oy + 640.0
		var tp: float = base - t[2]
		var pts := PackedVector2Array([Vector2(x, base), Vector2(x, tp + w * 0.5)])
		for i in range(1, 12):
			var a := PI + PI * i / 12.0
			pts.append(Vector2(x + w / 2.0 + cos(a) * w / 2.0, tp + w * 0.5 + sin(a) * w * 0.7))
		pts.append(Vector2(x + w, tp + w * 0.5))
		pts.append(Vector2(x + w, base))
		fill(pts, Color("2c4559"))
		draw_line(Vector2(x + w / 2.0, tp - w * 0.2), Vector2(x + w / 2.0, tp - w * 0.2 - t[3]), Color("2c4559"), 3.0)
		for k in int(t[2] / 70.0):
			draw_rect(Rect2(x + w / 2.0 - 2.0, tp + w + k * 60.0, 4, 9), Color(0.78, 0.92, 1.0, 0.16))
	# fog over the far city
	for i in 6:
		draw_rect(Rect2(0, oy + 380.0 + i * 40.0, W, 400), Color(0.6, 0.76, 0.88, 0.022))
	# light shafts falling from cracks in the ceiling
	for i in 4:
		var x0: float = 160.0 + i * 310.0 - px * 0.1
		var a := 0.03 + 0.012 * sin(frame * 0.012 + i * 1.7)
		fill(PackedVector2Array([Vector2(x0, -10), Vector2(x0 + 60.0, -10), Vector2(x0 + 250.0, H), Vector2(x0 + 120.0, H)]), Color(0.82, 0.93, 1.0, a))
	# middle colonnade
	var ox2 := -120.0 - px * 0.15
	var oy2 := -py * 0.08
	var colc := Color("1a2a37")
	for c in mid_cols:
		var x: float = ox2 + c[0]
		var ctop: float = oy2 + c[1]
		draw_rect(Rect2(x, ctop, 26, H - ctop + 80.0), colc)
		draw_rect(Rect2(x - 8.0, ctop - 10.0, 42, 12), colc)
		draw_arc(Vector2(x + 13.0 + 85.0, ctop + 4.0), 85.0, PI, TAU, 24, colc, 14.0)
	# near rock teeth hanging from the ceiling
	var ox3 := -140.0 - px * 0.3
	var oy3 := -py * 0.2 - 20.0
	for r in near_rocks:
		var x: float = ox3 + r[0]
		var ln: float = r[1]
		var w: float = r[2]
		fill(PackedVector2Array([Vector2(x - w / 2.0, oy3 - 40.0), Vector2(x + w / 2.0, oy3 - 40.0), Vector2(x + w * 0.25, oy3 + ln * 0.55),
			Vector2(x + w * 0.05, oy3 + ln), Vector2(x - w * 0.2, oy3 + ln * 0.6)]), Color("0d1820"))
	for m in motes:
		m[1] -= m[2]
		m[0] += sin((frame + m[1]) * 0.01) * 0.2
		if m[1] < -5.0:
			m[1] = H + 5.0
			m[0] = randf() * W
		draw_circle(Vector2(m[0], m[1]), m[3], Color(0.75, 0.9, 1.0, 0.4))


func draw_stage() -> void:
	var chain := Color("1e2b36")
	for p in SOFT:
		var r: Rect2 = p
		for cx in [r.position.x + 18.0, r.end.x - 18.0]:
			draw_line(Vector2(cx, -400), Vector2(cx, r.position.y), chain, 3.0)
		# lumafly lantern
		var lx := r.position.x + r.size.x / 2.0
		var ly := r.position.y + 50.0
		draw_line(Vector2(lx, r.position.y + 14.0), Vector2(lx, ly - 12.0), chain, 2.0)
		var flick := 0.26 + sin(frame * 0.07 + r.position.x) * 0.04
		for k in range(8, 0, -1):
			draw_circle(Vector2(lx, ly), k * 11.0, Color(0.7, 0.9, 1.0, flick / 8.0))
		outlined(ellipse(lx, ly, 8, 11, 16), Color("d9f2ff"), 1.0, 2.0)
		draw_line(Vector2(lx - 9.0, ly - 12.0), Vector2(lx + 9.0, ly - 12.0), OUTLINE, 3.0)
		# stone shelf
		var x0 := r.position.x
		var x1 := r.end.x
		var y0 := r.position.y
		outlined(PackedVector2Array([Vector2(x0 - 6, y0), Vector2(x1 + 6, y0), Vector2(x1 + 2, y0 + 10), Vector2(x1 - 14, y0 + 18),
			Vector2(lx + 30.0, y0 + 22.0), Vector2(x0 + 14, y0 + 18), Vector2(x0 - 2, y0 + 10)]), Color("1a2631"), 1.0, 3.0)
		draw_line(Vector2(x0 - 4, y0 + 1.5), Vector2(x1 + 4, y0 + 1.5), Color("a8c6d6"), 2.0)
		var mx := x0 + 10.0
		while mx < x1 - 6.0:
			var ln := 8.0 + float(int(mx * 7.0) % 13)
			draw_line(Vector2(mx, y0 + 16.0), Vector2(mx + 1.0, y0 + 16.0 + ln), Color("2c4a4a"), 2.0)
			mx += 17.0
	# main ruin: a chunky slab of carved rock
	var pts := PackedVector2Array([Vector2(MX - 10, MY), Vector2(MX + MW + 10, MY), Vector2(MX + MW + 4, MY + 36), Vector2(MX + MW - 14, MY + 120),
		Vector2(MX + MW - 34, MY + 250), Vector2(MX + MW - 70, MY + 420), Vector2(MX + 70, MY + 420), Vector2(MX + 34, MY + 250),
		Vector2(MX + 14, MY + 120), Vector2(MX - 4, MY + 36)])
	outlined(pts, Color("121d26"), 1.0, 3.0)
	fill(PackedVector2Array([Vector2(MX + 20, MY + 150), Vector2(MX + MW - 20, MY + 150), Vector2(MX + MW - 66, MY + 418), Vector2(MX + 66, MY + 418)]), Color("0b131a"))
	draw_rect(Rect2(MX - 6, MY + 4, MW + 12, 12), Color("1c2a36"))
	draw_line(Vector2(MX - 8, MY + 1.5), Vector2(MX + MW + 8, MY + 1.5), Color("b4d0de"), 2.5)
	draw_line(Vector2(MX - 6, MY + 16), Vector2(MX + MW + 6, MY + 16), OUTLINE, 2.0)
	var arch := Color(0.65, 0.85, 0.95, 0.09)
	var ax := MX + 50.0
	while ax < MX + MW - 60.0:
		draw_line(Vector2(ax, MY + 130.0), Vector2(ax, MY + 70.0), arch, 2.0)
		draw_arc(Vector2(ax + 30.0, MY + 70.0), 30.0, PI, TAU, 16, arch, 2.0)
		draw_line(Vector2(ax + 60.0, MY + 70.0), Vector2(ax + 60.0, MY + 130.0), arch, 2.0)
		draw_circle(Vector2(ax + 30.0, MY + 52.0), 4.0, arch)
		ax += 100.0
	# pale fungus and grass along the lip
	var fx := MX + 6.0
	while fx < MX + MW:
		var hh := 5.0 + float(int(fx * 13.0) % 9)
		fill(PackedVector2Array([Vector2(fx - 3, MY + 1), Vector2(fx + 1, MY - hh), Vector2(fx + 3, MY + 1)]), Color("6f9a92"))
		if int(fx) % 3 == 0:
			outlined(ellipse(fx + 8.0, MY - 4.0, 4, 3, 10), Color("cfe9e4"), 1.0, 1.5)
		fx += 23.0
	for side in [[MX, -1.0], [MX + MW, 1.0]]:
		var ex: float = side[0]
		var d: float = side[1]
		for i in 4:
			var root := PackedVector2Array([Vector2(ex, MY + 14.0 + i * 10.0)])
			quad_to(root, Vector2(ex + d * 18.0, MY + 60.0 + i * 20.0), Vector2(ex + d * 4.0, MY + 110.0 + i * 26.0))
			draw_polyline(root, OUTLINE, 3.0)


func draw_fog_and_foreground() -> void:
	# low mist hanging over the cavern floor
	for i in 8:
		draw_rect(Rect2(0, H - 150.0 + i * 20.0, W, 160), Color(0.62, 0.78, 0.9, 0.012))
	var fxo := -(cam_x - 640.0) * 0.4
	var fyo := -(cam_y - 400.0) * 0.3
	var dark := Color("020406")
	# thorn vine curling up from the bottom left
	var vine := PackedVector2Array([Vector2(-60 + fxo, H + 40 + fyo)])
	quad_to(vine, Vector2(150 + fxo, H - 60 + fyo), Vector2(90 + fxo, H - 250 + fyo), 14)
	draw_polyline(vine, dark, 20.0)
	for i in range(2, vine.size(), 2):
		var p := vine[i]
		var d := (vine[i] - vine[i - 1]).normalized()
		var n := Vector2(-d.y, d.x) * (1.0 if i % 4 == 0 else -1.0)
		fill(PackedVector2Array([p + n * 8.0 - d * 6.0, p + n * 28.0 + d * 6.0, p + n * 8.0 + d * 6.0]), dark)
	# broken pillar on the right
	fill(PackedVector2Array([Vector2(W - 34 + fxo, H + 40 + fyo), Vector2(W - 34 + fxo, H - 260 + fyo), Vector2(W - 20 + fxo, H - 290 + fyo),
		Vector2(W - 4 + fxo, H - 270 + fyo), Vector2(W + 10 + fxo, H - 340 + fyo), Vector2(W + 60 + fxo, H - 320 + fyo), Vector2(W + 60 + fxo, H + 40 + fyo)]), dark)
	# grass along the bottom edge
	var gx := -40.0
	while gx < W + 40.0:
		var gh := 12.0 + float(int(gx * 3.7) % 17)
		fill(PackedVector2Array([Vector2(gx + fxo * 1.2, H + 10 + fyo), Vector2(gx + 6 + fxo * 1.2, H - gh + fyo), Vector2(gx + 12 + fxo * 1.2, H + 10 + fyo)]), dark)
		gx += 11.0


func draw_mask(x: float, y: float, s: float, c: Color) -> void:
	fill(ellipse(x, y, 7.0 * s, 8.0 * s), c)
	fill(PackedVector2Array([Vector2(x - 4 * s, y - 6 * s), Vector2(x - 6 * s, y - 15 * s), Vector2(x - 1 * s, y - 7 * s)]), c)
	fill(PackedVector2Array([Vector2(x + 4 * s, y - 6 * s), Vector2(x + 1 * s, y - 7 * s), Vector2(x + 6 * s, y - 15 * s)]), c)
	fill(ellipse(x - 2.6 * s, y, 1.8 * s, 3.0 * s, 12), INK)
	fill(ellipse(x + 2.6 * s, y, 1.8 * s, 3.0 * s, 12), INK)


func outlined(pts: PackedVector2Array, c: Color, a: float, w: float = 2.5) -> void:
	if pts.size() < 3:
		return
	draw_colored_polygon(pts, fade(c, a))
	var cl := pts.duplicate()
	cl.append(pts[0])
	draw_polyline(cl, fade(OUTLINE, a), w, true)


func capsule(p: Vector2, q: Vector2, r: float) -> PackedVector2Array:
	var ang := (q - p).angle()
	var pts := PackedVector2Array()
	for i in 9:
		var t := ang + PI / 2.0 + PI * i / 8.0
		pts.append(p + Vector2(cos(t), sin(t)) * r)
	for i in 9:
		var t := ang - PI / 2.0 + PI * i / 8.0
		pts.append(q + Vector2(cos(t), sin(t)) * r)
	return pts


func dirv(a: float) -> Vector2:
	return Vector2(cos(a), sin(a))


# A legend's pose: front arm angle, blade angle, back arm angle, leg swing and body lean.
func legend_pose(f: Fighter) -> Array:
	var run := f.on_ground and absf(f.vx) > 1.0 and f.hitstun == 0 and f.dash == 0
	var swing := sin(frame * 0.35) * 0.75 if run else 0.0
	var arm := 1.15
	var blade := 0.3
	var back := 1.5
	var lean := 0.0
	if f.hitstun > 0:
		arm = -2.3; blade = -2.7; back = -2.0; lean = -4.0
	elif f.dash > 0:
		arm = 2.3; blade = 2.9; back = 2.4; lean = 7.0
	elif f.atk > 0:
		var fr := ATK_LEN - f.atk
		var p := clampf(float(fr - 1) / float(ACT_END - 1), 0.0, 1.0)
		p = 1.0 - pow(1.0 - p, 2.0)
		back = 2.0
		match f.atk_type:
			"side":
				arm = lerpf(-2.0, 0.7, p); blade = lerpf(-2.4, 1.0, p); lean = lerpf(-2.0, 5.0, p)
			"up":
				arm = lerpf(0.9, -2.2, p); blade = lerpf(0.6, -2.7, p)
			_:
				arm = lerpf(-1.3, 1.5, p); blade = lerpf(-1.6, 1.57, p)
	elif f.focus > 0:
		arm = -1.2; blade = 2.6; back = -1.6
	elif f.spell_cd > 20:
		arm = 0.0; blade = 2.6; back = 2.2; lean = -3.0
	elif not f.on_ground:
		arm = -0.4; blade = -1.1; back = -0.8
	elif run:
		arm = 1.3 + swing * 0.4; blade = 2.6; back = 1.4 - swing * 0.6; lean = 4.0
	return [arm, blade, back, swing, lean, run]


func draw_fighter(world: Transform2D, f: Fighter) -> void:
	if f.dead:
		return
	var a := 0.4 if (f.invuln > 0 and (frame >> 2) % 2 == 1) else 1.0
	var white := f.flash > 0
	var tilt := 0.0
	if f.hitstun > 0:
		tilt = -0.22
	elif f.dash > 0:
		tilt = 0.12
	draw_set_transform_matrix(world * Transform2D(0.0, Vector2(f.facing, 1), 0.0, Vector2(f.x, f.y)) * Transform2D(tilt, Vector2(1.12, 1.12), 0.0, Vector2.ZERO))
	var pose := legend_pose(f)
	var arm: float = pose[0]
	var blade_a: float = pose[1]
	var back_a: float = pose[2]
	var swing: float = pose[3]
	var lean: float = pose[4]
	var running: bool = pose[5]
	var bob := 0.0
	if running:
		bob = -absf(sin(frame * 0.35)) * 2.5
	elif f.on_ground:
		bob = sin(frame * 0.08 + f.id) * 1.2
	var armor := Color.WHITE if white else f.armor
	var armor_dk := Color.WHITE if white else f.armor.darkened(0.3)
	var cape := Color.WHITE if white else f.cloak
	var trim := Color.WHITE if white else f.trim
	var skin := Color.WHITE if white else f.skin
	var helm := Color.WHITE if white else f.helm
	var boot := Color.WHITE if white else Color("2a2f36")
	var hip := Vector2(0, -26 + bob)
	var sh := Vector2(3 + lean, -50 + bob)
	var head := Vector2(4 + lean * 1.2, -67 + bob)
	# cape
	var sway := clampf(absf(f.vx) * 1.2 + (4.0 if f.vy < 0.0 else 0.0) + (10.0 if f.dash > 0 else 0.0), 0.0, 16.0)
	var flutter := sin(frame * 0.2 + f.id) * 2.0
	outlined(PackedVector2Array([sh + Vector2(-10, -2), sh + Vector2(2, -3), Vector2(-5 + lean * 0.3, -16 + bob),
		Vector2(-13 - sway, -8 + flutter), Vector2(-20 - sway * 1.3, -22 + flutter * 0.5)]), cape, a)
	# back arm and leg
	var bs := sh + Vector2(-8, 2)
	outlined(capsule(bs, bs + dirv(back_a) * 15.0, 4.5), armor_dk, a)
	var leg_back := PI / 2.0 - swing
	var leg_front := PI / 2.0 + swing
	var leg_len := 21.0
	if not f.on_ground:
		leg_back = PI / 2.0 + 0.5
		leg_front = PI / 2.0 - 0.6
		leg_len = 18.0
	var bhip := hip + Vector2(-4, 0)
	var bfoot := bhip + dirv(leg_back) * leg_len
	outlined(capsule(bhip, bfoot, 5.0), armor_dk, a)
	outlined(capsule(bfoot + Vector2(-1, 0), bfoot + Vector2(6, 0), 4.5), boot, a)
	var fhip := hip + Vector2(4, 0)
	var ffoot := fhip + dirv(leg_front) * leg_len
	outlined(capsule(fhip, ffoot, 5.5), armor, a)
	outlined(capsule(ffoot + Vector2(-1, 0), ffoot + Vector2(7, 0), 5.0), boot, a)
	# torso, tabard and belt
	outlined(PackedVector2Array([sh + Vector2(-12, -2), sh + Vector2(13, -2), hip + Vector2(10, 2), hip + Vector2(-9, 2)]), armor, a)
	outlined(PackedVector2Array([sh + Vector2(-3, 4), sh + Vector2(7, 4), hip + Vector2(6, 11), hip + Vector2(1, 15), hip + Vector2(-4, 11)]), cape, a, 2.0)
	draw_line(hip + Vector2(-9, 0), hip + Vector2(10, 0), fade(OUTLINE, a), 3.5)
	outlined(PackedVector2Array([hip + Vector2(-1, -3), hip + Vector2(5, -3), hip + Vector2(5, 3), hip + Vector2(-1, 3)]), trim, a, 1.5)
	outlined(ellipse(sh.x - 6.0, sh.y + 1.0, 9, 6, 14), Color.WHITE if white else f.armor.lightened(0.18), a)
	# head under a horned helm
	draw_head(f, head, a, white)
	# blade, then the arm gripping it
	var hand := sh + Vector2(4, 2) + dirv(arm) * 15.0
	draw_blade(f, hand, blade_a, a, white)
	outlined(capsule(sh + Vector2(4, 2), hand, 5.0), Color.WHITE if white else f.armor.lightened(0.08), a)
	outlined(ellipse(hand.x, hand.y, 5, 5, 12), boot, a, 2.0)
	# focus glow
	draw_set_transform_matrix(world)
	if f.focus > 0:
		for k in range(6, 0, -1):
			draw_circle(Vector2(f.x, f.y - 34.0), k * 11.0, Color(1, 1, 1, 0.06))
	# slash arc
	var fr := ATK_LEN - f.atk
	if f.atk > 0 and fr >= ACT_START - 1 and fr <= ACT_END + 2:
		var p := float(fr - ACT_START + 1) / float(ACT_END - ACT_START + 3)
		var ang := 0.0
		if f.atk_type == "up":
			ang = -PI / 2.0
		elif f.atk_type == "down":
			ang = PI / 2.0
		elif f.facing < 0:
			ang = PI
		var off := 22.0 if f.atk_type == "side" else 30.0
		draw_set_transform_matrix(world * Transform2D(ang, Vector2(f.x, f.y - f.h / 2.0)))
		var alpha := clampf(1.0 - p * 0.8, 0.15, 1.0)
		fill(crescent(off, 56.0, 1.15, off - 16.0, 47.0, 1.0), Color(1, 1, 1, alpha))
		fill(crescent(off + 4.0, 62.0, 1.05, off - 4.0, 56.0, 1.0), fade(f.trim, alpha * 0.4))
		draw_set_transform_matrix(world)


func draw_head(f: Fighter, c: Vector2, a: float, white: bool) -> void:
	var skin := Color.WHITE if white else f.skin
	var helm := Color.WHITE if white else f.helm
	# horns first so the helm overlaps their roots
	if f.horn == "straight":
		for hx in [-5.0, 7.0]:
			var s := -1.0 if hx < 0.0 else 1.0
			var h := PackedVector2Array([c + Vector2(hx - 4.0, -9)])
			quad_to(h, c + Vector2(hx + s * 2.0 - 3.0, -22), c + Vector2(hx + s * 3.0, -33), 6)
			quad_to(h, c + Vector2(hx + s * 4.0 + 2.0, -20), c + Vector2(hx + 4.0, -10), 6)
			outlined(h, helm, a)
	else:
		for s in [-1.0, 1.0]:
			var bx: float = 1.0 + s * 6.0
			var h := PackedVector2Array([c + Vector2(bx + s * 3.0, -10)])
			quad_to(h, c + Vector2(bx + s * 16.0, -16), c + Vector2(bx + s * 18.0, -31), 6)
			quad_to(h, c + Vector2(bx + s * 8.0, -20), c + Vector2(bx - s * 3.0, -12), 6)
			outlined(h, helm, a)
	outlined(ellipse(c.x, c.y, 14, 14, 24), skin, a)
	var hp := PackedVector2Array()
	for i in 17:
		var ang := deg_to_rad(125.0 + 220.0 * i / 16.0)
		hp.append(c + Vector2(cos(ang), sin(ang)) * 15.5)
	hp.append(c + Vector2(7, -2))
	hp.append(c + Vector2(-1, 5))
	outlined(hp, helm, a)
	draw_line(c + Vector2(-9, -9), c + Vector2(2, -13), fade(Color.WHITE, 0.35 * a), 2.0)
	var ink := fade(OUTLINE, a)
	fill(ellipse(c.x + 7.0, c.y + 2.0, 2.3, 3.2, 10), ink)
	fill(ellipse(c.x + 12.5, c.y + 2.0, 2.3, 3.2, 10), ink)
	draw_circle(c + Vector2(7.6, 1.0), 0.9, fade(Color.WHITE, a))
	draw_circle(c + Vector2(13.1, 1.0), 0.9, fade(Color.WHITE, a))
	draw_line(c + Vector2(4.5, -2.5), c + Vector2(9.5, -1.0), ink, 2.0)
	draw_line(c + Vector2(11.0, -1.0), c + Vector2(15.0, -2.8), ink, 2.0)
	draw_line(c + Vector2(9.0, 8.5), c + Vector2(12.5, 8.0), ink, 1.5)


func draw_blade(f: Fighter, hand: Vector2, ang: float, a: float, white: bool) -> void:
	var d := dirv(ang)
	var n := Vector2(-d.y, d.x)
	var great := f.weapon == "great"
	var w := 10.0 if great else 5.5
	var ln := 46.0 if great else 50.0
	var b0 := hand + d * 5.0
	var steel := Color.WHITE if white else f.blade
	outlined(PackedVector2Array([b0 + n * w / 2.0, b0 + d * (ln - 9.0) + n * w / 2.0, b0 + d * ln, b0 + d * (ln - 9.0) - n * w / 2.0, b0 - n * w / 2.0]), steel, a)
	draw_line(b0 + d * 3.0 + n * w * 0.15, b0 + d * (ln - 10.0) + n * w * 0.15, fade(Color.WHITE, 0.65 * a), 1.5)
	if great:
		draw_line(b0 + d * 6.0 - n * w * 0.25, b0 + d * (ln - 10.0) - n * w * 0.25, fade(f.trim, 0.8 * a), 2.0)
	var guard := Color.WHITE if white else f.trim
	outlined(capsule(hand + d * 5.0 + n * (11.0 if great else 9.0), hand + d * 5.0 - n * (11.0 if great else 9.0), 2.8), guard, a, 2.0)
	outlined(capsule(hand - d * 7.0, hand + d * 3.0, 2.6), Color.WHITE if white else Color("4a3428"), a, 2.0)
	outlined(ellipse(hand.x - d.x * 8.0, hand.y - d.y * 8.0, 3.5, 3.5, 10), guard, a, 2.0)


func crescent(c1: float, r1: float, a1: float, c2: float, r2: float, a2: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := 16
	for i in n + 1:
		var a := -a1 + 2.0 * a1 * i / n
		pts.append(Vector2(c1 + cos(a) * r1, sin(a) * r1))
	for i in n + 1:
		var a := a2 - 2.0 * a2 * i / n
		pts.append(Vector2(c2 + cos(a) * r2, sin(a) * r2))
	return pts


func draw_bolt(world: Transform2D, b: Bolt) -> void:
	var d := signf(b.vx)
	draw_set_transform_matrix(world * Transform2D(0.0, Vector2(d, 1), 0.0, Vector2(b.x, b.y)))
	for k in range(5, 0, -1):
		draw_circle(Vector2.ZERO, k * 7.0, Color(0.85, 0.96, 1.0, 0.1))
	var w := sin(frame) * 3.0
	var pts := PackedVector2Array([Vector2(18, 0)])
	quad_to(pts, Vector2(10, -14), Vector2(-22, -10 + w))
	quad_to(pts, Vector2(-8, 0), Vector2(-22, 10 - w))
	quad_to(pts, Vector2(10, 14), Vector2(18, 0))
	pts.remove_at(pts.size() - 1)
	fill(pts, Color("f2fbff"))
	fill(ellipse(8, -3, 2.5, 3.5, 10), INK)
	fill(ellipse(8, 4, 2.5, 3.5, 10), INK)
	draw_set_transform_matrix(world)


func draw_particles() -> void:
	for p in parts:
		var a := clampf(p.life / p.max_life, 0.0, 1.0)
		match p.kind:
			"line":
				draw_line(Vector2(p.x, p.y), Vector2(p.x - p.vx * 1.5, p.y - p.vy * 1.5), fade(p.color, a), 2.0)
			"ring":
				draw_arc(Vector2(p.x, p.y), p.size, 0, TAU, 48, fade(p.color, a), maxf(1.0, 6.0 * a))
			"shade":
				fill(ellipse(p.x, p.y, p.size * a + 6.0, 18), fade(p.color, a * 0.5))
			"wings":
				for s in [-1.0, 1.0]:
					var w1 := PackedVector2Array([Vector2(p.x, p.y)])
					quad_to(w1, Vector2(p.x + s * 30.0, p.y - 26.0 * a - 6.0), Vector2(p.x + s * 44.0, p.y + 6.0))
					draw_polyline(w1, fade(Color.WHITE, a), 3.0)
					var w2 := PackedVector2Array([Vector2(p.x, p.y + 4.0)])
					quad_to(w2, Vector2(p.x + s * 24.0, p.y - 10.0 * a), Vector2(p.x + s * 34.0, p.y + 14.0))
					draw_polyline(w2, fade(Color.WHITE, a), 3.0)
			"star":
				var r: float = p.size * (1.6 - a * 0.6)
				var st := PackedVector2Array()
				for i in 8:
					var ang := PI / 4.0 * i + 0.3
					st.append(Vector2(p.x, p.y) + Vector2(cos(ang), sin(ang)) * (r if i % 2 == 0 else r * 0.28))
				fill(st, fade(Color.WHITE, a))
			"puff":
				draw_circle(Vector2(p.x, p.y), p.size * (1.5 - a * 0.5), fade(p.color, a))
			_:
				draw_circle(Vector2(p.x, p.y), p.size, fade(p.color, a))


func draw_vignette() -> void:
	for i in 10:
		var t := float(i) / 10.0
		var r := Rect2(-t * 30.0, -t * 20.0, W + t * 60.0, H + t * 40.0)
		draw_rect(Rect2(0, 0, W, 18.0 - t * 18.0), Color(0, 0, 0, 0.04))
		draw_rect(Rect2(0, H - 18.0 + t * 18.0, W, 18.0 - t * 18.0), Color(0, 0, 0, 0.04))
		draw_rect(Rect2(0, 0, 40.0 - t * 40.0, H), Color(0, 0, 0, 0.04))
		draw_rect(Rect2(W - 40.0 + t * 40.0, 0, 40.0 - t * 40.0, H), Color(0, 0, 0, 0.04))


func dmg_color(d: float) -> Color:
	var t := clampf(d / 160.0, 0.0, 1.0)
	if t < 0.5:
		return Color("e8edf0").lerp(Color("f29a52"), t * 2.0)
	return Color("f29a52").lerp(Color("d63434"), (t - 0.5) * 2.0)


func draw_hud() -> void:
	for f in fighters:
		var bx := W - 300.0 if f.id == 1 else 40.0
		var by := H - 96.0
		draw_rect(Rect2(bx - 10.0, by - 6.0, 270, 84), Color(0.024, 0.035, 0.047, 0.6))
		draw_rect(Rect2(bx - 10.0, by - 6.0, 270, 84), fade(f.trim, 0.35), false, 1.0)
		# soul vessel
		var vc := Vector2(bx + 34.0, by + 36.0)
		var r := 28.0
		draw_circle(vc, r, Color("0b1015"))
		var lvl: float = vc.y + (r - 3.0) - (f.soul / 99.0) * (2.0 * (r - 3.0))
		var a0 := asin(clampf((lvl - vc.y) / (r - 3.0), -1.0, 1.0))
		if f.soul > 0:
			var pts := PackedVector2Array()
			for i in 33:
				var ang := a0 + (PI - 2.0 * a0) * i / 32.0
				pts.append(vc + Vector2(cos(ang), sin(ang)) * (r - 3.0))
			fill(pts, Color("e8f6fb") if f.soul >= SOUL_COST else Color("7d8a94"))
		draw_arc(vc, r, 0, TAU, 40, Color("c9d2d8"), 2.0)
		var label: String = f.name + ("  (CPU)" if f.cpu else "")
		text(label, Vector2(bx + 74.0, by + 18.0), 20, f.trim)
		var j := (randf() - 0.5) * 6.0 if f.flash > 0 else 0.0
		text(str(int(f.dmg)) + "%", Vector2(bx + 74.0 + j, by + 64.0 + j), 46, Color("56626d") if f.dead else dmg_color(f.dmg))
		for s in 3:
			draw_mask(bx + 196.0 + s * 22.0, by + 52.0, 1.1, PALE if s < f.stocks else Color("26313c"))


func button(r: Rect2, label: String, action: String, accent: Color) -> void:
	var hover := r.has_point(get_local_mouse_position())
	draw_rect(r, Color(0.08, 0.106, 0.133, 0.8))
	draw_rect(r, accent if hover else Color("2b3743"), false, 1.5)
	text(label, Vector2(r.position.x, r.position.y + r.size.y / 2.0 + 9.0), 26, Color.WHITE if hover else PALE, null, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	buttons.append([r, action])


func draw_menu() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.024, 0.035, 0.047, 0.72))
	center_text("A platform fighter beneath the ruined city", 18, 150, DIM, body_font)
	center_text("Nailfall", 130, 270, PALE)
	button(Rect2(W / 2.0 - 330.0, 310, 300, 56), "1  Duel the CPU", "cpu", SOUL)
	button(Rect2(W / 2.0 + 30.0, 310, 300, 56), "2  Two players", "two", Color("f29a52"))
	var lx := W / 2.0 - 330.0
	var rx := W / 2.0 + 30.0
	text("Pale Wisp", Vector2(lx, 420), 24, SOUL)
	text("Ember Husk", Vector2(rx, 420), 24, Color("f29a52"))
	var left := ["Move, jump    A D, W (twice for wings)", "Nail          F, with W or S to aim", "Dash          G", "Spell         H, or S+H on the ground to heal"]
	var right := ["Move, jump    Arrow keys", "Nail          .  or  Num 1", "Dash          /  or  Num 2", "Spell         ,  or  Num 3"]
	for i in 4:
		text(left[i], Vector2(lx, 450.0 + i * 24.0), 16, PALE, body_font)
		text(right[i], Vector2(rx, 450.0 + i * 24.0), 16, PALE, body_font)
	center_text("Controllers: stick to move and aim, A jump, X nail, B dash, Y spell, Start to begin or pause.", 15, 572, DIM, body_font)
	center_text("Knock your rival out of the cavern three times. Down-strike in midair to pogo, nail a spell to send it back.", 15, 596, DIM, body_font)
	center_text("Esc pauses  ·  M mutes", 15, 620, DIM, body_font)


func draw_over() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.024, 0.035, 0.047, 0.72))
	var sub := "The CPU took this one" if winner.cpu else ("You won the duel" if mode == 1 else "Player %d wins" % (winner.id + 1))
	center_text(sub, 20, 250, DIM, body_font)
	center_text(winner.name + " prevails", 80, 340, PALE)
	button(Rect2(W / 2.0 - 330.0, 400, 300, 56), "Rematch  (Enter)", "again", SOUL)
	button(Rect2(W / 2.0 + 30.0, 400, 300, 56), "Menu  (Esc)", "menu", Color("f29a52"))
