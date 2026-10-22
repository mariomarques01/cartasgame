extends Control
## Ornamentos vetoriais: molduras de bronze, filigrana e cantoneiras.
## Desenhados em runtime, sem depender de fontes ou imagens externas.

@export var gold := Color("#e8bd75")
@export var bronze := Color("#8d5426")
@export var inner := Color("#ffdf9b")
@export var corner_size := 22.0
@export var ornate_edges := true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 22.0 or h < 22.0:
		return
	var c := minf(corner_size, minf(w, h) * 0.28)
	var pts := [
		Vector2(2, 2), Vector2(w - 2, 2),
		Vector2(w - 2, h - 2), Vector2(2, h - 2)
	]
	# Borda dupla com reflexos dourados
	draw_line(Vector2(c, 3), Vector2(w - c, 3), gold.darkened(0.12), 1.6, true)
	draw_line(Vector2(c, h - 3), Vector2(w - c, h - 3), bronze, 1.5, true)
	draw_line(Vector2(3, c), Vector2(3, h - c), gold.darkened(0.28), 1.5, true)
	draw_line(Vector2(w - 3, c), Vector2(w - 3, h - c), bronze, 1.5, true)
	for k in 4:
		var ox := 0.0 if k % 2 == 0 else w
		var oy := 0.0 if k < 2 else h
		var dx := 1.0 if ox == 0.0 else -1.0
		var dy := 1.0 if oy == 0.0 else -1.0
		_draw_corner(Vector2(ox, oy), Vector2(dx, dy), c)
	if ornate_edges and w > 130.0:
		_draw_diamond(Vector2(w * 0.5, 3), 4.0)
		_draw_diamond(Vector2(w * 0.5, h - 3), 4.0)
		if h > 95.0:
			_draw_diamond(Vector2(3, h * 0.5), 3.5)
			_draw_diamond(Vector2(w - 3, h * 0.5), 3.5)

func _draw_corner(origin: Vector2, direction: Vector2, c: float) -> void:
	var x := direction.x
	var y := direction.y
	var a := origin + Vector2(x * 2, y * (c + 2))
	var b := origin + Vector2(x * 2, y * 7)
	var d := origin + Vector2(x * 7, y * 2)
	var e := origin + Vector2(x * (c + 2), y * 2)
	draw_polyline(PackedVector2Array([a, b, d, e]), bronze, 5.0, true)
	draw_polyline(PackedVector2Array([a, b, d, e]), gold, 2.0, true)
	draw_line(origin + Vector2(x * 7, y * 7), origin + Vector2(x * (c - 2), y * (c - 2)), gold, 1.4, true)
	draw_line(origin + Vector2(x * 6, y * (c - 2)), origin + Vector2(x * (c - 2), y * 6), bronze, 1.4, true)
	_draw_diamond(origin + Vector2(x * 9, y * 9), 3.5)

func _draw_diamond(center: Vector2, r: float) -> void:
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(0, -r), center + Vector2(r * 0.7, 0),
		center + Vector2(0, r), center + Vector2(-r * 0.7, 0)
	]), gold)
	draw_circle(center, 1.0, inner)
