extends ProgressBar

var fill_style: StyleBoxFlat


func _ready() -> void:
	min_value = 0.0
	max_value = 100.0
	show_percentage = false
	custom_minimum_size = Vector2(0, 22)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.1, 0.07, 0.05, 0.85)
	back.set_corner_radius_all(4)
	add_theme_stylebox_override("background", back)
	fill_style = StyleBoxFlat.new()
	fill_style.bg_color = Color(0.42, 0.58, 0.32)
	fill_style.set_corner_radius_all(4)
	add_theme_stylebox_override("fill", fill_style)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
