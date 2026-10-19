# Silicon LogiX / SLX EchoBench
# Copyright (c) 2026 Marco Pezzullo (Silicon LogiX).
# License: Silicon LogiX Evaluation License 1.0. See LICENSE.
extends Control
## Draws recorded samples only. Time is microseconds; amplitude is full scale.
signal cursor_changed(time_us: float)
var frame: Dictionary = {}
var mode := "envelope"
var cursor_us := 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(280, 170)
	mouse_default_cursor_shape = Control.CURSOR_CROSS

func update_frame(value: Dictionary) -> void:
	frame = value
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		cursor_us = clampf((event.position.x - 43) / maxf(1, size.x - 60) * 20.44, 0, 20.44)
		queue_redraw()
		cursor_changed.emit(cursor_us)

func _draw() -> void:
	draw_style_box(preload("res://slx_theme.gd").box(Color("111c31"), 7), Rect2(Vector2.ZERO, size))
	var area := Rect2(43, 27, size.x - 60, size.y - 57)
	var font := ThemeDB.fallback_font
	for i in range(6):
		var x := area.position.x + area.size.x * i / 5
		draw_line(Vector2(x, area.position.y), Vector2(x, area.end.y), Color("28374f"))
		draw_string(font, Vector2(x-8, size.y-9), "%.1f" % (20.44*i/5), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("a8b6d0"))
	for i in range(5):
		var y := area.position.y + area.size.y*i/4
		draw_line(Vector2(area.position.x,y),Vector2(area.end.x,y),Color("28374f"))
		draw_string(font,Vector2(5,y+4),"%.2f" % (1.0-i/4.0 if mode=="envelope" else 1.0-i/2.0),HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("a8b6d0"))
	draw_string(font,Vector2(12,17),"A-SCAN  /  %s  /  normalized FS" % mode.to_upper(),HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("a8b6d0"))
	if frame.is_empty():
		draw_string(font,Vector2(60,90),"Acquire a point to inspect its samples",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("a8b6d0"))
		return
	var config: Dictionary = frame.configuration
	for gate in ["a", "b"]:
		var a: float = config["gate_"+gate+"_start_us"] / 20.44
		var b: float = config["gate_"+gate+"_end_us"] / 20.44
		var color := Color("e6b25c") if gate=="a" else Color("8186f2")
		var threshold: float = config["gate_"+gate+"_threshold"]
		var rect := Rect2(area.position+Vector2(area.size.x*a,0),Vector2(area.size.x*(b-a),area.size.y))
		draw_rect(rect,Color(color,0.055))
		var yy := area.end.y-threshold*area.size.y if mode=="envelope" else area.get_center().y-threshold*area.size.y*.5
		draw_line(Vector2(rect.position.x,yy),Vector2(rect.end.x,yy),color,1.5)
		draw_string(font,Vector2(rect.position.x+4,area.position.y+14),gate.to_upper(),HORIZONTAL_ALIGNMENT_LEFT,-1,11,color)
	var values: Array = frame.result.envelope if mode=="envelope" else frame.result.processed_rf
	var points := PackedVector2Array()
	for i in values.size():
		var yy: float = area.end.y-float(values[i])*area.size.y if mode=="envelope" else area.get_center().y-float(values[i])*area.size.y*.5
		points.append(Vector2(area.position.x+area.size.x*i/maxi(1,values.size()-1),yy))
	if points.size()>1:
		draw_polyline(points,Color("70e0ce"),1.6,true)
	var cx := area.position.x+cursor_us/20.44*area.size.x
	draw_line(Vector2(cx,area.position.y),Vector2(cx,area.end.y),Color("dfe5f3"),1)
	draw_string(font,Vector2(area.end.x-18,17),"µs",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("a8b6d0"))
