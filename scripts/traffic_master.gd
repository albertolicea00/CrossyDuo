## Player A controller: spawns cars on tapped road lanes (with a cooldown)
## and tweaks lane speeds. Input zoning:
##   - LOCAL mode: only the RIGHT half of the screen belongs to the
##     Traffic Master (the left half is the Crosser's swipe zone).
##   - CLIENT mode: the whole screen is the Traffic Master's.
## The cooldown here drives the local UI; the authoritative check lives in
## the game world ("Local Server" strict validation).
class_name TrafficMaster
extends Node

const SPAWN_COOLDOWN := 1.5

signal lane_tapped(screen_pos: Vector2)
signal speed_change_requested(delta: float)

var cooldown_left := 0.0
var active := true
## True when sharing the screen with the Crosser (local same-device mode).
var local_split := false


func _process(delta: float) -> void:
	cooldown_left = maxf(cooldown_left - delta, 0.0)


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	# Accept both touch (mobile) and left mouse click (desktop/web).
	var pos := Vector2.ZERO
	var pressed := false
	if event is InputEventScreenTouch and event.pressed:
		pos = event.position
		pressed = true
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
		pressed = true
	if not pressed:
		return
	# In split-screen local mode, ignore taps on the Crosser's half.
	if local_split and pos.x < get_viewport().get_visible_rect().size.x * 0.5:
		return
	if cooldown_left > 0.0:
		return
	cooldown_left = SPAWN_COOLDOWN
	lane_tapped.emit(pos)
