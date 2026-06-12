## Automated smoke playtest (headless-friendly).
## Boots the real game in LOCAL mode and drives both roles programmatically:
## the Crosser hops forward on a timer, the Traffic Master spawns extra cars
## on the lane ahead. Verifies: play -> die -> game over -> restart -> play.
## Run with: godot --headless res://tests/playtest.tscn
extends Node

const MAX_TIME := 60.0

var main: Node
var game: Node3D
var phase := "play"
var t := 0.0
var hop_timer := 0.5
var spawn_timer := 2.0
var died_once := false
var restarted := false
var max_score := 0

func _ready() -> void:
	main = $Main
	await get_tree().process_frame
	main._on_local()
	game = main.game
	print("[playtest] CrossyDuo started in LOCAL mode (3D voxel world)")


func _physics_process(delta: float) -> void:
	if game == null:
		return
	t += delta
	max_score = maxi(max_score, game.score)
	match phase:
		"play":
			# Drive the Crosser: hop forward blindly (will eventually get hit).
			hop_timer -= delta
			if hop_timer <= 0.0:
				hop_timer = 0.45
				game._hop(Vector2i(0, 1))
			# Drive the Traffic Master: spawn extra cars two rows ahead.
			spawn_timer -= delta
			if spawn_timer <= 0.0:
				spawn_timer = 2.0
				game._try_spawn_car(game.crosser.row + 2)
			if not game.playing:
				died_once = true
				print("[playtest] game over at t=%.1fs rows=%d cars=%d gen_rows=%d" % [
					t, game.score, game.cars.size(), game.rows.size()])
				phase = "restart"
		"restart":
			game._on_restart_pressed()
			restarted = game.playing and game.score == 0
			print("[playtest] restart -> playing=%s score=%d rows=%d" % [
				game.playing, game.score, game.rows.size()])
			phase = "second"
		"second":
			hop_timer -= delta
			if hop_timer <= 0.0:
				hop_timer = 0.45
				game._hop(Vector2i(0, 1))
			if t > 45.0 or not game.playing:
				_finish()
	if t > MAX_TIME:
		_finish()


func _finish() -> void:
	var ok := died_once and restarted
	print("[playtest] RESULT: %s | died_once=%s restarted=%s max_rows=%d" % [
		"PASS" if ok else "FAIL", died_once, restarted, max_score])
	get_tree().quit(0 if ok else 1)
