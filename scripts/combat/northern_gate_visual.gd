class_name NorthernGateVisual
extends Control


const NORTHERN_PALETTE := preload(
	"res://resources/visuals/northern_campaign_palette.gd"
)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var tower_width := maxf(size.x * 0.28, 8.0)
	var door := Rect2(
		Vector2(tower_width, size.y * 0.17),
		Vector2(size.x - tower_width * 2.0, size.y * 0.83)
	)
	draw_rect(Rect2(Vector2.ZERO, Vector2(tower_width, size.y)), NORTHERN_PALETTE.WALL_STONE)
	draw_rect(
		Rect2(Vector2(size.x - tower_width, 0.0), Vector2(tower_width, size.y)),
		NORTHERN_PALETTE.WALL_STONE
	)
	draw_rect(door, NORTHERN_PALETTE.ROAD_EDGE)
	for plank in range(1, 4):
		var x := door.position.x + door.size.x * float(plank) / 4.0
		draw_line(
			Vector2(x, door.position.y),
			Vector2(x, door.end.y),
			NORTHERN_PALETTE.ROAD_RUT.darkened(0.28),
			1.5
		)
	for y in range(8, int(size.y), 16):
		draw_line(
			Vector2(0.0, float(y)),
			Vector2(tower_width, float(y)),
			NORTHERN_PALETTE.WALL_HIGHLIGHT,
			1.0
		)
		draw_line(
			Vector2(size.x - tower_width, float(y)),
			Vector2(size.x, float(y)),
			NORTHERN_PALETTE.WALL_HIGHLIGHT,
			1.0
		)
	var pennant := PackedVector2Array([
		Vector2(size.x * 0.5, 1.0),
		Vector2(size.x * 0.5, -13.0),
		Vector2(size.x * 0.5 + 13.0, -7.0),
		Vector2(size.x * 0.5, -2.0),
	])
	draw_colored_polygon(pennant, NORTHERN_PALETTE.HOSTILE_RUST)
