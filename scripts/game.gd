## Crossy Duo game world. See AGENTS.md for the full spec.
##
## Authority model:
##   - LOCAL / HOST: this node generates rows, moves cars, checks collisions.
##   - CLIENT: renders synced state and forwards Traffic Master requests.
## Role assignment in network modes: host = Crosser, client = Traffic Master
## (the Crosser needs zero input latency, so it always runs on the host).
extends Node2D

const VIEW := Vector2(1280, 720)
const CELL := 64
const COLS := 20
const CAR_SIZE := Vector2(96, 40)
const CAR_HIT_DIST := 60.0      # |car.x - crosser.x| below this = collision
const ROWS_AHEAD := 14          # generate this many rows above the Crosser
const ROWS_BEHIND := 8          # free rows this far below the Crosser
const MIN_LANE_SPEED := 40.0
const MAX_LANE_SPEED := 280.0
const SPEED_STEP := 40.0

signal exited

var crosser: Crosser
var traffic: TrafficMaster
var camera: Camera2D

## Row registry: row index -> { type, dir, speed, node, spawn_t }.
## On clients spawn_t is unused (the host owns all car spawning).
var rows := {}
var top_generated := -1
var consecutive_roads := 0

## Cars: id -> Node2D (visual). Authoritative kinematics: id -> { row, x }.
var cars := {}
var car_state := {}
var next_car_id := 0

var score := 0
var playing := true
var selected_row := -1          # last road lane tapped by the Traffic Master
## Host-side cooldown tracking for the remote Traffic Master.
var remote_cooldown := 0.0
## Swipe tracking for the Crosser's touch input.
var swipe_start := Vector2.ZERO
var swipe_active := false

var hud: CanvasLayer
var score_label: Label
var cooldown_bar: ProgressBar
var over_box: VBoxContainer
var over_label: Label


func _ready() -> void:
	_build_world()
	_build_players()
	_build_hud()
	if Net.is_authority():
		_ensure_rows()


# --- Scene construction (all original code-drawn art) ----------------------

func _build_world() -> void:
	# Backdrop behind generated rows (visible at the screen edges).
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.18, 0.35, 0.2)
	backdrop.size = Vector2(VIEW.x, 40000.0)
	backdrop.position = Vector2(0, -38000.0)
	add_child(backdrop)

	camera = Camera2D.new()
	camera.position = Vector2(VIEW.x / 2.0, 360.0)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	add_child(camera)
	camera.make_current()


func _build_players() -> void:
	crosser = Crosser.new()
	add_child(crosser)

	traffic = TrafficMaster.new()
	# Role wiring per mode: in LOCAL both roles share the device; in HOST
	# the Traffic Master is the remote client, so the local one is disabled.
	match Net.mode:
		Net.Mode.LOCAL:
			traffic.local_split = true
		Net.Mode.HOST:
			traffic.active = false
		Net.Mode.CLIENT:
			traffic.local_split = false
	traffic.lane_tapped.connect(_on_lane_tapped)
	add_child(traffic)


func _build_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)

	score_label = Label.new()
	score_label.text = "0"
	score_label.add_theme_font_size_override("font_size", 56)
	score_label.position = Vector2(VIEW.x / 2.0 - 20, 24)
	hud.add_child(score_label)

	var is_traffic_master := Net.mode != Net.Mode.HOST

	cooldown_bar = ProgressBar.new()
	cooldown_bar.size = Vector2(220, 18)
	cooldown_bar.position = Vector2(VIEW.x - 244, VIEW.y - 36)
	cooldown_bar.show_percentage = false
	cooldown_bar.visible = is_traffic_master
	hud.add_child(cooldown_bar)

	# Lane speed controls for the Traffic Master (affect the last tapped lane).
	if is_traffic_master:
		var slower := Button.new()
		slower.text = "Lane -"
		slower.custom_minimum_size = Vector2(106, 48)
		slower.position = Vector2(VIEW.x - 244, VIEW.y - 96)
		slower.pressed.connect(_on_speed_button.bind(-SPEED_STEP))
		hud.add_child(slower)
		var faster := Button.new()
		faster.text = "Lane +"
		faster.custom_minimum_size = Vector2(106, 48)
		faster.position = Vector2(VIEW.x - 130, VIEW.y - 96)
		faster.pressed.connect(_on_speed_button.bind(SPEED_STEP))
		hud.add_child(faster)

	# Game-over panel, hidden until the run ends.
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.add_child(center)
	over_box = VBoxContainer.new()
	over_box.add_theme_constant_override("separation", 10)
	over_box.visible = false
	center.add_child(over_box)
	over_label = Label.new()
	over_label.add_theme_font_size_override("font_size", 40)
	over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	over_box.add_child(over_label)
	var restart := Button.new()
	restart.text = "Restart"
	restart.custom_minimum_size = Vector2(220, 48)
	restart.pressed.connect(_on_restart_pressed)
	over_box.add_child(restart)
	var quit := Button.new()
	quit.text = "Back to Menu"
	quit.custom_minimum_size = Vector2(220, 48)
	quit.pressed.connect(func() -> void: exited.emit())
	over_box.add_child(quit)


# --- Row generation ---------------------------------------------------------

func _ensure_rows() -> void:
	# Generate terrain ahead of the Crosser. Authority only; replicated
	# to the client via reliable RPC so both peers share identical lanes.
	while top_generated < crosser.row + ROWS_AHEAD:
		top_generated += 1
		var r := top_generated
		var type := "grass"
		# First rows are always safe; afterwards roads dominate but never
		# stack more than 3 in a row (always a reachable safe spot).
		if r > 2 and consecutive_roads < 3 and randf() < 0.6:
			type = "road"
			consecutive_roads += 1
		else:
			consecutive_roads = 0
		var dir := 1 if randf() < 0.5 else -1
		var speed := randf_range(70.0, 190.0)
		_add_row(r, type, dir, speed)
		if Net.mode == Net.Mode.HOST:
			_add_row_remote.rpc(r, type, dir, speed)
	_free_passed_rows()


func _add_row(r: int, type: String, dir: int, speed: float) -> void:
	var visual := ColorRect.new()
	visual.size = Vector2(VIEW.x, CELL)
	visual.position = Vector2(0, Crosser.row_to_y(r) - CELL / 2.0)
	if type == "road":
		visual.color = Color(0.22, 0.22, 0.25)
		# Dashed center line for the road look.
		for i in 8:
			var dash := ColorRect.new()
			dash.color = Color(0.85, 0.8, 0.3)
			dash.size = Vector2(40, 4)
			dash.position = Vector2(20 + i * 160, CELL / 2.0 - 2)
			visual.add_child(dash)
	else:
		# Alternate two greens so grass rows read as separate cells.
		visual.color = Color(0.4, 0.7, 0.3) if r % 2 == 0 else Color(0.35, 0.64, 0.27)
	add_child(visual)
	rows[r] = {
		"type": type, "dir": dir, "speed": speed,
		"node": visual, "spawn_t": randf_range(1.0, 3.0),
	}


@rpc("authority", "call_remote", "reliable")
func _add_row_remote(r: int, type: String, dir: int, speed: float) -> void:
	_add_row(r, type, dir, speed)


func _free_passed_rows() -> void:
	for r in rows.keys():
		if r < crosser.row - ROWS_BEHIND:
			rows[r]["node"].queue_free()
			rows.erase(r)


# --- Crosser input ----------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not playing or Net.mode == Net.Mode.CLIENT:
		return  # the client is the Traffic Master; it never moves the Crosser
	# Keyboard (desktop/web).
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_UP, KEY_W: _hop(Vector2i(0, 1))
			KEY_DOWN, KEY_S: _hop(Vector2i(0, -1))
			KEY_LEFT, KEY_A: _hop(Vector2i(-1, 0))
			KEY_RIGHT, KEY_D: _hop(Vector2i(1, 0))
		return
	# Touch swipe / tap. In local split mode only the LEFT half is the
	# Crosser's; a short tap means "hop forward", a swipe picks a direction.
	var half := get_viewport().get_visible_rect().size.x * 0.5
	if event is InputEventScreenTouch:
		if event.pressed:
			if Net.mode == Net.Mode.LOCAL and event.position.x >= half:
				return
			swipe_start = event.position
			swipe_active = true
		elif swipe_active:
			swipe_active = false
			_resolve_swipe(event.position - swipe_start)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if Net.mode == Net.Mode.LOCAL and event.position.x >= half:
				return
			swipe_start = event.position
			swipe_active = true
		elif swipe_active:
			swipe_active = false
			_resolve_swipe(event.position - swipe_start)


func _resolve_swipe(delta: Vector2) -> void:
	if delta.length() < 24.0:
		_hop(Vector2i(0, 1))  # tap = hop forward (classic Crossy Road)
	elif absf(delta.x) > absf(delta.y):
		_hop(Vector2i(1 if delta.x > 0.0 else -1, 0))
	else:
		# Screen Y grows downward; row index grows upward.
		_hop(Vector2i(0, 1 if delta.y < 0.0 else -1))


func _hop(dir: Vector2i) -> void:
	if crosser.try_move(dir) and crosser.row > score:
		score = crosser.row  # score = furthest row reached
		score_label.text = str(score)


# --- Traffic Master ---------------------------------------------------------

func _on_lane_tapped(screen_pos: Vector2) -> void:
	# Convert the tap into a row index using the camera transform.
	var world: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * screen_pos
	var r := roundi((688.0 - world.y) / float(CELL))
	if Net.mode == Net.Mode.CLIENT:
		_request_spawn_car.rpc_id(1, r)
	else:
		_try_spawn_car(r)
	selected_row = r


func _on_speed_button(delta: float) -> void:
	if selected_row < 0:
		return
	if Net.mode == Net.Mode.CLIENT:
		_request_lane_speed.rpc_id(1, selected_row, delta)
	else:
		_apply_lane_speed(selected_row, delta)


@rpc("any_peer", "call_remote", "reliable")
func _request_spawn_car(r: int) -> void:
	# Runs on the host when the remote Traffic Master taps a lane.
	if not playing:
		return
	if Net.strict_validation:
		# "Local Server" mode: never trust the client. Re-check the cooldown
		# and confirm the lane actually exists near the play area.
		if remote_cooldown > 0.0:
			return
		if r < crosser.row - 2 or r > crosser.row + ROWS_AHEAD:
			return
	remote_cooldown = TrafficMaster.SPAWN_COOLDOWN
	_try_spawn_car(r)


@rpc("any_peer", "call_remote", "reliable")
func _request_lane_speed(r: int, delta: float) -> void:
	if not playing:
		return
	_apply_lane_speed(r, delta)


func _try_spawn_car(r: int) -> void:
	if not rows.has(r) or rows[r]["type"] != "road":
		return  # only road lanes can hold cars
	_spawn_car(r)


func _apply_lane_speed(r: int, delta: float) -> void:
	if not rows.has(r) or rows[r]["type"] != "road":
		return
	var speed: float = clampf(rows[r]["speed"] + delta, MIN_LANE_SPEED, MAX_LANE_SPEED)
	rows[r]["speed"] = speed
	if Net.mode == Net.Mode.HOST:
		_lane_speed_remote.rpc(r, speed)


@rpc("authority", "call_remote", "reliable")
func _lane_speed_remote(r: int, speed: float) -> void:
	if rows.has(r):
		rows[r]["speed"] = speed


# --- Cars -------------------------------------------------------------------

func _spawn_car(r: int) -> void:
	# Authority only: cars enter from the edge the lane direction points from.
	var id := next_car_id
	next_car_id += 1
	var dir: int = rows[r]["dir"]
	var x := -CAR_SIZE.x if dir > 0 else VIEW.x + CAR_SIZE.x
	car_state[id] = {"row": r, "x": x}
	_make_car_visual(id, r, x)


func _make_car_visual(id: int, r: int, x: float) -> void:
	var car := Node2D.new()
	var body := Polygon2D.new()
	var half := CAR_SIZE / 2.0
	body.polygon = PackedVector2Array([
		Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
		Vector2(half.x, half.y), Vector2(-half.x, half.y)])
	# Random flat color per car for a playful cartoon look.
	body.color = Color.from_hsv(randf(), 0.65, 0.85)
	car.add_child(body)
	var roof := Polygon2D.new()
	roof.polygon = PackedVector2Array([
		Vector2(-24, -14), Vector2(24, -14), Vector2(24, 14), Vector2(-24, 14)])
	roof.color = Color(0.85, 0.9, 0.95)
	car.add_child(roof)
	car.position = Vector2(x, Crosser.row_to_y(r))
	add_child(car)
	cars[id] = car


func _free_car(id: int) -> void:
	if cars.has(id):
		cars[id].queue_free()
		cars.erase(id)
	car_state.erase(id)


# --- Simulation -------------------------------------------------------------

func _physics_process(delta: float) -> void:
	remote_cooldown = maxf(remote_cooldown - delta, 0.0)
	cooldown_bar.value = (1.0 - traffic.cooldown_left / TrafficMaster.SPAWN_COOLDOWN) * 100.0
	# Camera follows the Crosser upward but never below the start view.
	camera.position = Vector2(VIEW.x / 2.0, minf(crosser.position.y - 100.0, 360.0))
	if not playing or Net.mode == Net.Mode.CLIENT:
		return

	_ensure_rows()

	# Ambient traffic: each visible road lane spawns cars on its own timer,
	# on top of whatever the Traffic Master adds manually.
	for r in rows:
		if rows[r]["type"] != "road":
			continue
		rows[r]["spawn_t"] -= delta
		if rows[r]["spawn_t"] <= 0.0:
			rows[r]["spawn_t"] = randf_range(1.5, 4.0)
			_spawn_car(r)

	# Move cars and detect collisions (authoritative).
	var dead_cars: Array[int] = []
	for id in car_state:
		var state: Dictionary = car_state[id]
		var r: int = state["row"]
		if not rows.has(r):
			dead_cars.append(id)
			continue
		state["x"] += float(rows[r]["dir"]) * float(rows[r]["speed"]) * delta
		cars[id].position.x = state["x"]
		if state["x"] < -150.0 or state["x"] > VIEW.x + 150.0:
			dead_cars.append(id)
			continue
		# Collision: same row and horizontally overlapping the Crosser.
		if crosser.alive and r == crosser.row \
				and absf(state["x"] - crosser.position.x) < CAR_HIT_DIST:
			crosser.alive = false
			_on_crosser_died()
	for id in dead_cars:
		_free_car(id)

	if Net.mode == Net.Mode.HOST:
		_send_snapshot()


func _send_snapshot() -> void:
	# Compact unreliable snapshot: crosser + every live car.
	var ids := PackedInt32Array()
	var xs := PackedFloat32Array()
	var rs := PackedInt32Array()
	for id in car_state:
		ids.append(id)
		xs.append(car_state[id]["x"])
		rs.append(car_state[id]["row"])
	_sync.rpc(crosser.position, crosser.row, score, ids, xs, rs)


@rpc("authority", "call_remote", "unreliable")
func _sync(crosser_pos: Vector2, crosser_row: int, new_score: int,
		ids: PackedInt32Array, xs: PackedFloat32Array, rs: PackedInt32Array) -> void:
	crosser.position = crosser_pos
	crosser.row = crosser_row
	if new_score != score:
		score = new_score
		score_label.text = str(score)
	# Reconcile car visuals against the snapshot (create, move, free).
	var seen := {}
	for i in ids.size():
		var id := ids[i]
		seen[id] = true
		if not cars.has(id):
			_make_car_visual(id, rs[i], xs[i])
		cars[id].position = Vector2(xs[i], Crosser.row_to_y(rs[i]))
	for id in cars.keys():
		if not seen.has(id):
			_free_car(id)
	_free_passed_rows()


# --- Game over / restart ----------------------------------------------------

func _on_crosser_died() -> void:
	_show_game_over()
	if Net.mode == Net.Mode.HOST:
		_game_over_remote.rpc(score)


@rpc("authority", "call_remote", "reliable")
func _game_over_remote(final_score: int) -> void:
	score = final_score
	_show_game_over()


func _show_game_over() -> void:
	playing = false
	over_label.text = "Game Over — Rows crossed: %d" % score
	over_box.visible = true


func _on_restart_pressed() -> void:
	if Net.mode == Net.Mode.CLIENT:
		_request_restart.rpc_id(1)  # only the host may restart the match
	else:
		_restart()
		if Net.mode == Net.Mode.HOST:
			_restart_remote.rpc()


@rpc("any_peer", "call_remote", "reliable")
func _request_restart() -> void:
	if not playing:
		_restart()
		_restart_remote.rpc()


@rpc("authority", "call_remote", "reliable")
func _restart_remote() -> void:
	_restart()


func _restart() -> void:
	for id in cars.keys():
		_free_car(id)
	for r in rows.keys():
		rows[r]["node"].queue_free()
	rows.clear()
	top_generated = -1
	consecutive_roads = 0
	selected_row = -1
	crosser.reset()
	camera.position = Vector2(VIEW.x / 2.0, 360.0)
	score = 0
	score_label.text = "0"
	over_box.visible = false
	playing = true
	if Net.is_authority():
		_ensure_rows()
