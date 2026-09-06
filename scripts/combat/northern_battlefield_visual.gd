class_name NorthernBattlefieldVisual
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
	var field := Rect2(Vector2(3.0, 3.0), size - Vector2(6.0, 6.0))
	draw_rect(field, NORTHERN_PALETTE.GROUND_WARM.darkened(0.08))
	_draw_ground_variation(field)
	var route_start := 144.0
	var route_end := size.x - 72.0
	var front_y := size.y * 0.25 - 29.5
	var side_y := size.y * 0.48 + 43.7
	_draw_route(route_start, route_end, front_y, false)
	_draw_route(route_start, route_end, side_y, true)
	_draw_muster_mark(Vector2(route_start + 20.0, front_y + 35.0))
	_draw_muster_mark(Vector2(route_start + 20.0, side_y + 35.0))
	_draw_fortification_line(route_end - 8.0, front_y, side_y)


func _draw_ground_variation(field: Rect2) -> void:
	var patch_size := Vector2(132.0, 78.0)
	var rows := ceili(field.size.y / patch_size.y)
	var columns := ceili(field.size.x / patch_size.x)
	for row in range(rows):
		for column in range(columns):
			var color := (
				NORTHERN_PALETTE.with_alpha(
					NORTHERN_PALETTE.GROUND_PALE,
					0.16
				)
				if (row + column) % 3 == 0
				else NORTHERN_PALETTE.with_alpha(
					NORTHERN_PALETTE.GROUND_COOL,
					0.10
				)
			)
			var origin := Vector2(
				field.position.x + float(column) * patch_size.x,
				field.position.y + float(row) * patch_size.y
			)
			draw_rect(Rect2(origin, patch_size), color)
	for index in range(12):
		var rock := Vector2(
			40.0 + fmod(float(index * 157), maxf(size.x - 80.0, 1.0)),
			52.0 + fmod(float(index * 83), maxf(size.y - 92.0, 1.0))
		)
		draw_circle(
			rock,
			2.0 + float(index % 3),
			NORTHERN_PALETTE.with_alpha(
				NORTHERN_PALETTE.GROUND_MARK,
				0.42
			)
		)

func _draw_route(
	start_x: float,
	end_x: float,
	top_y: float,
	is_side_route: bool
) -> void:
	var width := maxf(end_x - start_x, 1.0)
	var shoulder := Rect2(start_x, top_y - 6.0, width, 82.0)
	var surface := Rect2(start_x, top_y + 1.0, width, 68.0)
	draw_rect(shoulder, NORTHERN_PALETTE.ROAD_EDGE)
	draw_rect(
		surface,
		(
			NORTHERN_PALETTE.ROAD_DUST.darkened(0.08)
			if is_side_route
			else NORTHERN_PALETTE.ROAD_SURFACE
		)
	)
	for y_offset in [18.0, 50.0]:
		draw_dashed_line(
			Vector2(start_x + 12.0, top_y + y_offset),
			Vector2(end_x - 12.0, top_y + y_offset),
			NORTHERN_PALETTE.with_alpha(
				NORTHERN_PALETTE.ROAD_RUT,
				0.62
			),
			2.0,
			8.0
		)
	for marker_index in range(5):
		var x := start_x + 92.0 + float(marker_index) * maxf(
			(width - 184.0) / 4.0,
			1.0
		)
		draw_circle(
			Vector2(x, top_y + 35.0),
			5.0,
			NORTHERN_PALETTE.with_alpha(
				NORTHERN_PALETTE.INK_TEAL,
				0.30
			)
		)


func _draw_muster_mark(center: Vector2) -> void:
	draw_arc(
		center,
		24.0,
		-PI * 0.65,
		PI * 0.65,
		20,
		NORTHERN_PALETTE.JADE,
		3.0
	)
	draw_line(
		center + Vector2(-13.0, -15.0),
		center + Vector2(-13.0, 15.0),
		NORTHERN_PALETTE.JADE_PALE,
		2.0
	)


func _draw_fortification_line(
	x: float,
	front_y: float,
	side_y: float
) -> void:
	var top := front_y - 18.0
	var bottom := side_y + 88.0
	draw_rect(
		Rect2(x - 9.0, top, 18.0, bottom - top),
		NORTHERN_PALETTE.WALL_STONE
	)
	for y in range(int(top) + 8, int(bottom), 22):
		draw_line(
			Vector2(x - 9.0, float(y)),
			Vector2(x + 9.0, float(y)),
			NORTHERN_PALETTE.WALL_HIGHLIGHT,
			1.0
		)
