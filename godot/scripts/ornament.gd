extends Control
## Ornamentos medievais desenhados com primitivas Godot 4.3.
@export var gold: Color = Color("#e8bd75")
@export var bronze: Color = Color("#8d5426")
@export var corner_size: float = 22.0
@export var ornate_edges: bool = true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	queue_redraw()

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w < 22.0 or h < 22.0:
		return
	var c: float = minf(corner_size, minf(w, h) * 0.28)
	draw_line(Vector2(c, 3), Vector2(w - c, 3), gold, 2.0, true)
	draw_line(Vector2(c, h - 3), Vector2(w - c, h - 3), bronze, 2.0, true)
	draw_line(Vector2(3, c), Vector2(3, h - c), gold, 2.0, true)
	draw_line(Vector2(w - 3, c), Vector2(w - 3, h - c), bronze, 2.0, true)
	_corner(Vector2(0, 0), Vector2(1, 1), c)
	_corner(Vector2(w, 0), Vector2(-1, 1), c)
	_corner(Vector2(0, h), Vector2(1, -1), c)
	_corner(Vector2(w, h), Vector2(-1, -1), c)
	if ornate_edges and w > 130.0:
		draw_circle(Vector2(w * 0.5, 3), 3.0, gold)
		draw_circle(Vector2(w * 0.5, h - 3), 3.0, gold)

func _corner(pos: Vector2, dir: Vector2, c: float) -> void:
	var p1: Vector2 = pos + Vector2(dir.x * 2, dir.y * (c + 2))
	var p2: Vector2 = pos + Vector2(dir.x * 2, dir.y * 7)
	var p3: Vector2 = pos + Vector2(dir.x * 7, dir.y * 2)
	var p4: Vector2 = pos + Vector2(dir.x * (c + 2), dir.y * 2)
	draw_line(p1, p2, bronze, 5.0, true)
	draw_line(p2, p3, bronze, 5.0, true)
	draw_line(p3, p4, bronze, 5.0, true)
	draw_line(p1, p2, gold, 2.0, true)
	draw_line(p2, p3, gold, 2.0, true)
	draw_line(p3, p4, gold, 2.0, true)
	draw_line(pos + Vector2(dir.x * 7, dir.y * 7), pos + Vector2(dir.x * (c - 2), dir.y * (c - 2)), gold, 1.5, true)
	draw_circle(pos + Vector2(dir.x * 9, dir.y * 9), 3.0, gold)
