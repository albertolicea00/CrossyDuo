## Player B character: hops across the grid one cell at a time.
## Movement is tween-based (snappy Crossy Road feel). Only the authority
## decides moves; on clients the node is positioned from synced state.
class_name Crosser
extends Node2D

const CELL := 64
const COLS := 20
const HOP_TIME := 0.12

signal hopped(row: int)

var col := 10
var row := 0
var moving := false
var alive := true


## Row index -> world Y of the row center. Row 0 sits near the bottom of the
## start view; rows grow upward (decreasing Y) as the Crosser advances.
static func row_to_y(r: int) -> float:
	return 688.0 - float(r) * CELL


static func col_to_x(c: int) -> float:
	return float(c) * CELL + CELL / 2.0


func _ready() -> void:
	# Visual: flat cartoon chick (original code-drawn art, no assets).
	var body := Polygon2D.new()
	body.polygon = _circle(20.0, 16)
	body.color = Color(0.98, 0.9, 0.5)
	add_child(body)
	var beak := Polygon2D.new()
	beak.polygon = PackedVector2Array([Vector2(14, -4), Vector2(26, 0), Vector2(14, 4)])
	beak.color = Color(0.9, 0.5, 0.15)
	add_child(beak)
	var eye := Polygon2D.new()
	eye.polygon = _circle(3.5, 8)
	eye.color = Color(0.12, 0.12, 0.12)
	eye.position = Vector2(8, -8)
	add_child(eye)
	position = Vector2(col_to_x(col), row_to_y(row))


static func _circle(radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in segments:
		var angle := TAU * float(i) / float(segments)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points


## Attempt a one-cell hop. `dir` uses grid coordinates: (0, 1) = forward (up).
## Returns true when the hop was accepted (used by the game for scoring).
func try_move(dir: Vector2i) -> bool:
	if not alive or moving:
		return false
	var new_col := clampi(col + dir.x, 0, COLS - 1)
	var new_row := maxi(row + dir.y, 0)  # never below the starting row
	if new_col == col and new_row == row:
		return false
	col = new_col
	row = new_row
	moving = true
	var tween := create_tween()
	tween.tween_property(self, "position",
		Vector2(col_to_x(col), row_to_y(row)), HOP_TIME)
	tween.tween_callback(func() -> void:
		moving = false
		hopped.emit(row))
	return true


func reset() -> void:
	col = 10
	row = 0
	moving = false
	alive = true
	position = Vector2(col_to_x(col), row_to_y(row))
