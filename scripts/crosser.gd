## Player B character: hops across the grid one cell at a time, rendered as
## a low-poly voxel chick (Crossy Road style 3D aesthetic, original art).
## Movement is tween-based with a small jump arc. Only the authority decides
## moves; on clients the node is positioned from synced state.
class_name Crosser
extends Node3D

const COLS := 20
const HOP_TIME := 0.14
const HOP_ARC := 0.45  # peak height of the hop, in world units

signal hopped(row: int)

var col := 10
var row := 0
var moving := false
var alive := true


## Grid -> world mapping. One cell = one world unit. Forward is -Z, so row r
## sits at z = -r; columns are centered on x = 0.
static func col_to_x(c: int) -> float:
	return float(c) - COLS / 2.0 + 0.5


static func row_to_z(r: int) -> float:
	return -float(r)


func _ready() -> void:
	# Voxel chick built from flat-colored boxes (no textures, mobile friendly).
	_add_box(Vector3(0.6, 0.6, 0.6), Vector3(0, 0.5, 0), Color(0.98, 0.96, 0.9))   # body
	_add_box(Vector3(0.16, 0.2, 0.3), Vector3(0, 0.92, 0), Color(0.9, 0.25, 0.2))  # comb
	_add_box(Vector3(0.16, 0.12, 0.24), Vector3(0, 0.55, -0.4), Color(1.0, 0.6, 0.1))  # beak
	_add_box(Vector3(0.1, 0.1, 0.05), Vector3(0.18, 0.66, -0.31), Color(0.1, 0.1, 0.1))  # eye L
	_add_box(Vector3(0.1, 0.1, 0.05), Vector3(-0.18, 0.66, -0.31), Color(0.1, 0.1, 0.1)) # eye R
	position = Vector3(col_to_x(col), 0, row_to_z(row))


func _add_box(size: Vector3, pos: Vector3, color: Color) -> void:
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh_instance.material_override = mat
	mesh_instance.position = pos
	add_child(mesh_instance)


## Attempt a one-cell hop. `dir` uses grid coordinates: (0, 1) = forward.
## Returns true when the hop was accepted (used by the game for scoring).
func try_move(dir: Vector2i) -> bool:
	if not alive or moving:
		return false
	var new_col := clampi(col + dir.x, 0, COLS - 1)
	var new_row := maxi(row + dir.y, 0)  # never behind the starting row
	if new_col == col and new_row == row:
		return false
	col = new_col
	row = new_row
	moving = true
	var start := position
	var target := Vector3(col_to_x(col), 0, row_to_z(row))
	# Lerp with a sine arc on Y for the classic hop feel.
	var tween := create_tween()
	tween.tween_method(
		func(t: float) -> void:
			position = start.lerp(target, t) + Vector3(0, sin(t * PI) * HOP_ARC, 0),
		0.0, 1.0, HOP_TIME)
	tween.tween_callback(func() -> void:
		moving = false
		hopped.emit(row))
	return true


func reset() -> void:
	col = 10
	row = 0
	moving = false
	alive = true
	position = Vector3(col_to_x(col), 0, row_to_z(row))
