# Silicon LogiX / SLX EchoBench
# Copyright (c) 2026 Marco Pezzullo (Silicon LogiX).
# License: Silicon LogiX Evaluation License 1.0. See LICENSE.
extends Control
## C-scan is peak normalized amplitude in gate A, not volumetric coverage.
signal point_selected(index: int)
var frames: Array = []
var selected := 0
var mode := "amplitude"
var texture: ImageTexture
var bscan := false
var row_frames: Array = []

func _ready() -> void:
	custom_minimum_size = Vector2(280, 130 if bscan else 155)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func refresh(values: Array, index: int) -> void:
	frames = values
	selected = index
	row_frames = []
	if bscan and not frames.is_empty():
		var y: float = frames[mini(selected,frames.size()-1)].pose.y_m
		for f in frames:
			if absf(float(f.pose.y_m)-y)<.001:
				row_frames.append(f)
		row_frames.sort_custom(func(a,b): return a.pose.x_m<b.pose.x_m)
		if not row_frames.is_empty():
			var img := Image.create(row_frames.size(),128,false,Image.FORMAT_RGB8)
			for x in row_frames.size():
				var f: Dictionary = row_frames[x]
				for iy in 128:
					var e: float = f.result.envelope[mini(511,iy*4)]
					img.set_pixel(x,iy,Color("17233b").lerp(Color("68e3d4"),clampf(e*1.5,0,1)) if f.result.data_valid else Color("8e7278"))
			texture = ImageTexture.create_from_image(img)
	queue_redraw()

func area() -> Rect2:
	return Rect2(40,27,size.x-57,size.y-55)

func point(pose: Dictionary) -> Vector2:
	var rect := area()
	return rect.position + Vector2((float(pose.x_m)+.62)/.64, (.15-float(pose.y_m))/.30)*rect.size

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT and not frames.is_empty():
		var best := -1
		var distance := INF
		if bscan:
			if not row_frames.is_empty():
				var n := clampi(int((event.position.x-area().position.x)/area().size.x*row_frames.size()),0,row_frames.size()-1)
				best = int(row_frames[n].index)
		else:
			for f in frames:
				var d := point(f.pose).distance_to(event.position)
				if d<distance:
					distance=d
					best=int(f.index)
		if best>=0:
			point_selected.emit(best)

func _draw() -> void:
	draw_style_box(preload("res://slx_theme.gd").box(Color("f3f5f9"),7),Rect2(Vector2.ZERO,size))
	var rect := area()
	var font := ThemeDB.fallback_font
	draw_rect(rect,Color("e3e8f0"))
	if bscan:
		draw_string(font,Vector2(10,18),"B-SCAN · selected Y pass · envelope / FS",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("56647a"))
		if texture and not row_frames.is_empty():
			draw_texture_rect(texture,rect,false)
		draw_string(font,Vector2(4,rect.position.y+8),"0",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("56647a"))
		draw_string(font,Vector2(3,rect.end.y),"20.4",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("56647a"))
		draw_string(font,Vector2(5,rect.get_center().y),"µs",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("56647a"))
	else:
		draw_string(font,Vector2(10,18),"C-SCAN · " + {"amplitude":"gate A peak / FS", "quality":"coupling / data quality", "path":"executed path", "points":"sampled surface points"}.get(mode,mode),HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("56647a"))
		var previous := Vector2.ZERO
		for f in frames:
			var p := point(f.pose)
			var c := Color("5354e8")
			if mode=="amplitude":
				c=Color("dfe9ef").lerp(Color("087762"),clampf(float(f.result.gate_a_peak)*1.4,0,1)) if f.result.data_valid else Color("c1969b")
			elif mode=="quality":
				c=Color("087762").lerp(Color("e2bf67"),1.0-float(f.effective_coupling)) if f.result.data_valid else Color("b4484e")
			if mode=="path" and previous!=Vector2.ZERO:
				draw_line(previous,p,Color("8a8ef0"),1.3)
			if mode in ["amplitude","quality"]:
				draw_rect(Rect2(p-Vector2(4,4),Vector2(8,8)),c)
			else:
				draw_circle(p,2,c)
			previous=p
		if not frames.is_empty():
			draw_arc(point(frames[mini(selected,frames.size()-1)].pose),7,0,TAU,24,Color("e69d31"),2,true)
		draw_string(font,Vector2(3,rect.position.y+9),"150",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("56647a"))
		draw_string(font,Vector2(0,rect.end.y),"-150",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("56647a"))
	var x_title: String="X −620 … 20 mm"
	if bscan and not row_frames.is_empty():
		x_title="X %.0f … %.0f mm"%[float(row_frames[0].pose.x_m)*1000,float(row_frames[-1].pose.x_m)*1000]
	draw_string(font,Vector2(rect.position.x,size.y-8),x_title,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("56647a"))
	draw_string(font,Vector2(rect.end.x-134,size.y-8),"unsampled = grey",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("56647a"))
