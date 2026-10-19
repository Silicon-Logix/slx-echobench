# Silicon LogiX / SLX EchoBench
# Copyright (c) 2026 Marco Pezzullo (Silicon LogiX).
# License: Silicon LogiX Evaluation License 1.0. See LICENSE.
extends SceneTree
var app: Control

func _initialize() -> void:
	_run.call_deferred()

func settle() -> void:
	for i in range(8):await process_frame
	await RenderingServer.frame_post_draw

func mouse_button(at: Vector2,pressed: bool) -> void:
	var event:=InputEventMouseButton.new()
	event.position=at
	event.global_position=at
	event.button_index=MOUSE_BUTTON_LEFT
	event.pressed=pressed
	Input.parse_input_event(event)

func _run() -> void:
	app=load("res://main.tscn").instantiate()
	get_root().add_child(app)
	get_root().borderless=true
	while not app.backend_ready:await process_frame
	app._select_view(1)
	app.lab.preset("Laboratory")
	var cases: Array=[]
	for entry in [[1200,760,1.0],[1440,900,1.0],[1920,1080,1.0],[2560,1080,1.0],[1920,1080,1.5]]:
		app._set_interface_scale(entry[2])
		get_root().size=Vector2i(entry[0],entry[1])
		get_root().position=DisplayServer.screen_get_usable_rect().position
		await settle()
		var pixels:=get_root().get_texture().get_image()
		var actual:=get_root().size
		assert((app.size*app.interface_scale).distance_to(Vector2(actual))<2,"Unused window area")
		assert(app.lab.viewport.size==Vector2i((app.lab.size*app.interface_scale).round()),"3D render target is being upscaled")
		for x in [2,pixels.get_width()-3]:
			assert(pixels.get_pixel(x,20).is_equal_approx(Color("111c31")),"Black side bar")
			assert(pixels.get_pixel(x,pixels.get_height()-3).r>.3,"Unused bottom edge")
		cases.append({"requested_pixels":[entry[0],entry[1]],"window_pixels":[actual.x,actual.y],"interface_scale":app.interface_scale,"render_pixels":[app.lab.viewport.size.x,app.lab.viewport.size.y],"analysis_width":app.graph.size.x,"full_window":true,"native_3d_resolution":true})
		if entry[0]==2560:pixels.save_png(ProjectSettings.globalize_path("res://../docs/images/wide.png"))
	app._set_interface_scale(1.0)
	get_root().size=Vector2i(1920,1080)
	assert(cases[2].analysis_width>cases[1].analysis_width,"Analysis panels do not grow with the window")
	await settle()
	var before: float=app.graph.size.x
	var drag_at: Vector2=app.splitter.get_drag_area_control().get_global_rect().get_center()
	mouse_button(drag_at,true)
	await process_frame
	var motion:=InputEventMouseMotion.new()
	motion.position=drag_at-Vector2(80,0)
	motion.relative=Vector2(-80,0)
	motion.button_mask=MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(motion)
	await process_frame
	mouse_button(motion.position,false)
	await settle()
	assert(app.graph.size.x>before+20,"Divider does not respond to dragging")
	var ratio: float=app.split_ratio
	get_root().size=Vector2i(2560,1080)
	await settle()
	var first: Control=app.splitter.get_child(0)
	var second: Control=app.splitter.get_child(1)
	assert(absf(first.size.x/(first.size.x+second.size.x)-ratio)<.01,"Divider ratio changed on resize")
	get_root().borderless=false
	get_root().mode=Window.MODE_MAXIMIZED
	await settle()
	assert((app.size*app.interface_scale).distance_to(Vector2(get_root().size))<2,"Maximized window does not fill")
	get_root().mode=Window.MODE_WINDOWED
	get_root().size=Vector2i(1440,900)
	app._select_view(4)
	await settle()
	assert(app.engineering_contact.is_visible_in_tree())
	assert(get_root().get_visible_rect().encloses(app.engineering_contact.get_global_rect()),"Contact button is outside the visible page")
	get_root().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../docs/images/services.png"))
	var file:=FileAccess.open(ProjectSettings.globalize_path("res://../validation/responsive.json"),FileAccess.WRITE)
	var result={"passed":true,"cases":cases,"maximized_full_window":true,"divider_drag_and_resize":true,"commercial_contact_visible":true,"advanced_services":"Explicit custom-development cards; no advanced UT/AI execution claimed"}
	file.store_string(JSON.stringify(result,"  "))
	print(JSON.stringify(result))
	app.backend.shutdown()
	quit()
