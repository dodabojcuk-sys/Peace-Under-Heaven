class_name CityGateComponentR1
extends Node2D


const ORIENTATION_NAMES := ["北", "东", "南", "西"]

var orientation := 0
var display_name := "城门"


func configure(direction: int, label: String) -> void:
	orientation = posmod(direction, 4)
	display_name = label
	rotation = float(orientation) * PI * 0.5
	queue_redraw()


func _draw() -> void:
	# One component is reused for all cardinal gates. The local geometry stays
	# identical; Node2D rotation supplies the directional presentation.
	draw_rect(Rect2(-48.0, -20.0, 96.0, 40.0), Color("403f39"), true)
	draw_rect(Rect2(-48.0, -20.0, 96.0, 40.0), Color("b89255"), false, 3.0)
	draw_rect(Rect2(-16.0, -26.0, 32.0, 52.0), Color("171c1c"), true)
	draw_line(Vector2(-60.0, -30.0), Vector2(-60.0, 30.0), Color("6f6a59"), 5.0)
	draw_line(Vector2(60.0, -30.0), Vector2(60.0, 30.0), Color("6f6a59"), 5.0)
