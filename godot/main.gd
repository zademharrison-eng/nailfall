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

var CHARS: Array = [
	{"name": "Pale Wisp", "cloak": Color("1d2633"), "trim": Color("9fdcf5"), "horn": "straight"},
	{"name": "Ember Husk", "cloak": Color("2e1c18"), "trim": Color("f29a52"), "horn": "hooked"},
]

const PALE := Color("eef2f4")
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
	var x := 0.0
	var y := 0.0
	var vx := 0.0
	var vy := 0.0
	var hw := 16.0
	var h := 58.0
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
var spires: Array = []
var stalactites: Array = []
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
	for layer in 2:
		for i in 14:
			spires.append([layer, rng.randf() * 1500.0, 30.0 + rng.randf() * 70.0, 220.0 + rng.randf() * 380.0 + layer * 80.0])
	var sx := 0.0
	while sx < 1500.0:
		stalactites.append([sx, 30.0 + rng.randf() * 120.0])
		sx += 26.0 + rng.randf() * 40.0
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
	sparks(b.x, b.y - 30.0, dir_x, 10 + int(kb))
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
	var ox := -110.0 - (cam_x - 640.0) * 0.12
	var oy := -70.0 - (cam_y - 400.0) * 0.08
	var top := Color("0c161c")
	var mid := Color("081015")
	var bot := Color("040608")
	var bands := 24
	for i in bands:
		var t := float(i) / bands
		var c := top.lerp(mid, t / 0.55) if t < 0.55 else mid.lerp(bot, (t - 0.55) / 0.45)
		draw_rect(Rect2(0, i * H / bands, W, H / bands + 1.0), c)
	for r in range(12, 0, -1):
		draw_circle(Vector2(ox + 750.0, oy + 330.0), r * 35.0, Color(0.62, 0.86, 0.96, 0.009))
	for s in spires:
		var x: float = ox + s[1]
		var w: float = s[2]
		var hh: float = s[3]
		var ground := oy + 860.0
		var tp := ground - hh
		var pts := PackedVector2Array([Vector2(x, ground), Vector2(x, tp + 40.0)])
		quad_to(pts, Vector2(x + w / 2.0, tp - 30.0), Vector2(x + w, tp + 40.0))
		pts.append(Vector2(x + w, ground))
		fill(pts, Color("0d171e") if s[0] == 1 else Color("0a1218"))
		for k in 3:
			draw_circle(Vector2(x + w / 2.0, tp + 70.0 + k * 60.0), 4.0, Color(0.62, 0.86, 0.96, 0.08))
	for st in stalactites:
		var x: float = ox + st[0]
		fill(PackedVector2Array([Vector2(x - 14.0, 0), Vector2(x, st[1] + oy + 70.0), Vector2(x + 14.0, 0)]), Color("05080b"))
	for m in motes:
		m[1] -= m[2]
		m[0] += sin((frame + m[1]) * 0.01) * 0.2
		if m[1] < -5.0:
			m[1] = H + 5.0
			m[0] = randf() * W
		draw_circle(Vector2(m[0], m[1]), m[3], Color(0.62, 0.86, 0.96, 0.35))


func draw_stage() -> void:
	var line := Color("2b3743")
	for p in SOFT:
		var r: Rect2 = p
		for cx in [r.position.x + 18.0, r.end.x - 18.0]:
			draw_line(Vector2(cx, -400), Vector2(cx, r.position.y), line, 3.0)
		var lx := r.position.x + r.size.x / 2.0
		var ly := r.position.y + 46.0
		draw_line(Vector2(lx, r.position.y + 12.0), Vector2(lx, ly - 10.0), line, 2.0)
		var flick := 0.22 + sin(frame * 0.07 + r.position.x) * 0.03
		for k in range(7, 0, -1):
			draw_circle(Vector2(lx, ly), k * 10.0, Color(0.62, 0.86, 0.96, flick / 7.0))
		fill(ellipse(lx, ly, 6, 9), Color("cfeefa"))
		draw_rect(Rect2(lx - 8.0, ly - 11.0, 16, 22), Color("3b4a58"), false, 2.0)
		draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 14), Color("1b232c"))
		draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 3), Color("3a4856"))
		var x := r.position.x + 8.0
		while x < r.end.x - 8.0:
			fill(PackedVector2Array([Vector2(x, r.position.y + 14.0), Vector2(x + 6.0, r.position.y + 24.0), Vector2(x + 12.0, r.position.y + 14.0)]), Color("10161c"))
			x += 22.0
	# main ruin
	var bands := 16
	for i in bands:
		var t := float(i) / bands
		var c := Color("1c252e").lerp(Color("10161c"), t / 0.4) if t < 0.4 else Color("10161c").lerp(Color("06090c"), (t - 0.4) / 0.6)
		draw_rect(Rect2(MX, MY + i * MH / bands, MW, MH / bands + 1.0), c)
	draw_rect(Rect2(MX - 6.0, MY, MW + 12.0, 5), Color("3a4856"))
	draw_rect(Rect2(MX - 6.0, MY + 5.0, MW + 12.0, 8), Color("26313c"))
	var arch := Color(0.62, 0.86, 0.96, 0.10)
	var ax := MX + 40.0
	while ax < MX + MW - 40.0:
		draw_line(Vector2(ax, MY + 140.0), Vector2(ax, MY + 70.0), arch, 2.0)
		draw_arc(Vector2(ax + 30.0, MY + 70.0), 30.0, PI, TAU, 16, arch, 2.0)
		draw_line(Vector2(ax + 60.0, MY + 70.0), Vector2(ax + 60.0, MY + 140.0), arch, 2.0)
		ax += 100.0
	var fx := MX + 10.0
	while fx < MX + MW:
		var hh := 4.0 + float(int(fx * 13.0) % 7)
		var pts := PackedVector2Array()
		for i in 9:
			var a := PI + PI * i / 8.0
			pts.append(Vector2(fx + cos(a) * 3.0, MY - 1.0 + sin(a) * hh / 2.0))
		fill(pts, Color(0.7, 0.9, 0.86, 0.55))
		fx += 37.0
	for side in [[MX, -1.0], [MX + MW, 1.0]]:
		var ex: float = side[0]
		var d: float = side[1]
		for i in 4:
			var pts := PackedVector2Array([Vector2(ex, MY + 14.0 + i * 10.0)])
			quad_to(pts, Vector2(ex + d * 18.0, MY + 60.0 + i * 20.0), Vector2(ex + d * 6.0, MY + 110.0 + i * 26.0))
			draw_polyline(pts, Color("0c1115"), 3.0)


func draw_mask(x: float, y: float, s: float, c: Color) -> void:
	fill(ellipse(x, y, 7.0 * s, 8.0 * s), c)
	fill(PackedVector2Array([Vector2(x - 4 * s, y - 6 * s), Vector2(x - 6 * s, y - 15 * s), Vector2(x - 1 * s, y - 7 * s)]), c)
	fill(PackedVector2Array([Vector2(x + 4 * s, y - 6 * s), Vector2(x + 1 * s, y - 7 * s), Vector2(x + 6 * s, y - 15 * s)]), c)
	fill(ellipse(x - 2.6 * s, y, 1.8 * s, 3.0 * s, 12), INK)
	fill(ellipse(x + 2.6 * s, y, 1.8 * s, 3.0 * s, 12), INK)


func draw_fighter(world: Transform2D, f: Fighter) -> void:
	if f.dead:
		return
	var a := 0.4 if (f.invuln > 0 and (frame >> 2) % 2 == 1) else 1.0
	draw_set_transform_matrix(world * Transform2D(0.0, Vector2(f.facing, 1), 0.0, Vector2(f.x, f.y)))
	var running := f.on_ground and absf(f.vx) > 1.0 and f.hitstun == 0
	var stp := sin(frame * 0.45) if running else 0.0
	var lean := clampf(-absf(f.vx) * 0.6, -8.0, 0.0)
	# legs
	draw_line(Vector2(-5, -12), Vector2(-5 + stp * 5.0, -1), fade(INK, a), 5.0)
	draw_line(Vector2(5, -12), Vector2(5 - stp * 5.0, -1), fade(INK, a), 5.0)
	# cloak
	var sway := clampf(absf(f.vx) * 0.9 + (3.0 if f.vy < 0.0 else 0.0), 0.0, 10.0)
	var cloak := Color.WHITE if f.flash > 0 else f.cloak
	var pts := PackedVector2Array([Vector2(-12, -40)])
	quad_to(pts, Vector2(-20 - sway * 0.4, -20), Vector2(-18 - sway, -9))
	pts.append_array(PackedVector2Array([Vector2(-10 - sway * 0.6, -13), Vector2(-3, -8), Vector2(4, -12), Vector2(13, -8)]))
	quad_to(pts, Vector2(17, -24), Vector2(12, -40))
	fill(pts, fade(cloak, a))
	# collar
	var collar := PackedVector2Array([Vector2(-12, -40)])
	quad_to(collar, Vector2(0, -33), Vector2(12, -40), 6)
	collar.append(Vector2(10, -36))
	quad_to(collar, Vector2(0, -30), Vector2(-10, -36), 6)
	fill(collar, fade(Color.WHITE if f.flash > 0 else f.trim, a))
	# nail at rest
	if f.atk == 0 and f.focus == 0:
		draw_line(Vector2(6, -24), Vector2(24 + lean, -6), fade(Color("c9d2d8"), a), 3.0)
		draw_line(Vector2(3, -27), Vector2(9, -21), fade(Color("3b4a58"), a), 3.0)
	# mask and horns
	var hx := lean * 0.2
	var mask := fade(PALE, a)
	if f.horn == "straight":
		var h1 := PackedVector2Array([Vector2(hx - 7, -60)])
		quad_to(h1, Vector2(hx - 13, -72), Vector2(hx - 9, -84))
		quad_to(h1, Vector2(hx - 5, -72), Vector2(hx - 1, -62))
		fill(h1, mask)
		var h2 := PackedVector2Array([Vector2(hx + 9, -60)])
		quad_to(h2, Vector2(hx + 15, -72), Vector2(hx + 12, -84))
		quad_to(h2, Vector2(hx + 8, -72), Vector2(hx + 4, -62))
		fill(h2, mask)
	else:
		var h1 := PackedVector2Array([Vector2(hx - 6, -61)])
		quad_to(h1, Vector2(hx - 22, -66), Vector2(hx - 22, -80))
		quad_to(h1, Vector2(hx - 14, -70), Vector2(hx - 1, -64))
		fill(h1, mask)
		var h2 := PackedVector2Array([Vector2(hx + 8, -61)])
		quad_to(h2, Vector2(hx + 24, -66), Vector2(hx + 24, -80))
		quad_to(h2, Vector2(hx + 16, -70), Vector2(hx + 3, -64))
		fill(h2, mask)
	fill(ellipse(hx + 1, -50, 14, 14, 24), mask)
	var blink := 0.25 if (frame + f.id * 97) % 200 < 6 else 1.0
	fill(ellipse(hx - 3, -49, 3.6, 5.6 * blink, 12), fade(INK, a))
	fill(ellipse(hx + 8, -49, 3.6, 5.6 * blink, 12), fade(INK, a))
	# focus glow
	draw_set_transform_matrix(world)
	if f.focus > 0:
		for k in range(6, 0, -1):
			draw_circle(Vector2(f.x, f.y - 30.0), k * 10.0, Color(1, 1, 1, 0.06))
	# slash
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
		fill(crescent(off, 54.0, 1.15, off - 16.0, 46.0, 1.0), Color(1, 1, 1, alpha))
		fill(crescent(off + 4.0, 60.0, 1.05, off - 4.0, 54.0, 1.0), fade(f.trim, alpha * 0.35))
		draw_set_transform_matrix(world)


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
