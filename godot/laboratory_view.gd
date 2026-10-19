# Silicon LogiX / SLX EchoBench
# Copyright (c) 2026 Marco Pezzullo (Silicon LogiX).
# License: Silicon LogiX Evaluation License 1.0. See LICENSE.
extends TextureRect
## Imported geometry is already Y-up. Only incoming Blender poses are converted.
signal instrument_action(action: String)
signal camera_interacted
const Graph = preload("res://ascan.gd")
var viewport: SubViewport
var world: Node3D
var asset: Node3D
var camera: Camera3D
var nodes: Dictionary = {}
var animation: AnimationPlayer
var cables: Array[MeshInstance3D] = []
var live_graph: Control
var display_viewport: SubViewport
var target := Vector3(-.05,1.08,0)
var yaw := -.64
var pitch := .40
var distance := 2.45
var dragging := false
var presentation := false
var reduced_motion := false
var section := false
var revealed := false
var active_scenario := "weld"
var pose: Dictionary = {}
var last_pose: Dictionary = {}
var cable_paths: Array = []
var latest_state: Dictionary = {}

func _ready() -> void:
	expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode=TextureRect.STRETCH_SCALE
	custom_minimum_size=Vector2(400,300)
	size_flags_vertical=Control.SIZE_EXPAND_FILL
	viewport=SubViewport.new()
	viewport.own_world_3d=true
	viewport.handle_input_locally=false
	viewport.msaa_3d=Viewport.MSAA_2X
	add_child(viewport)
	texture=viewport.get_texture()
	resized.connect(_sync_render_size)
	_sync_render_size()
	world=Node3D.new()
	viewport.add_child(world)
	var environment:=WorldEnvironment.new()
	var env:=Environment.new()
	env.background_mode=Environment.BG_COLOR
	env.background_color=Color("e6ebf3")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color("e2eafd")
	env.ambient_light_energy=.4
	env.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	environment.environment=env
	world.add_child(environment)
	for data in [[Vector3(-40,-35,0),.8],[Vector3(-65,120,0),.2]]:
		var light:=DirectionalLight3D.new()
		light.rotation_degrees=data[0]
		light.light_energy=data[1]
		light.shadow_enabled=true
		world.add_child(light)
	asset=load("res://assets/laboratory.glb").instantiate()
	world.add_child(asset)
	_collect(asset)
	for name in ["defect_01","Rigid_defect_02","defect_03"]:
		if nodes.has(name) and nodes[name] is MeshInstance3D:
			var truth_material:=StandardMaterial3D.new()
			truth_material.albedo_color=Color("d77e24")
			truth_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
			nodes[name].material_override=truth_material
	for node in asset.find_children("*","AnimationPlayer",true,false):
		animation=node
		animation.stop()
	for name in ["probe_coax_1","probe_coax_2"]:
		if nodes.has(name):
			nodes[name].hide()
	for i in range(2):
		var cable:=MeshInstance3D.new()
		var material:=StandardMaterial3D.new()
		material.albedo_color=Color("232c3a")
		material.roughness=.64
		cable.material_override=material
		world.add_child(cable)
		cables.append(cable)
	camera=Camera3D.new()
	camera.near=.01
	camera.far=40
	camera.fov=48
	world.add_child(camera)
	camera.current=true
	_camera_update()
	_create_displays()
	_explanation()
	gui_input.connect(_input_view)

func _sync_render_size() -> void:
	if not is_instance_valid(viewport):return
	var pixels:=Vector2i((size*get_window().content_scale_factor).round()).max(Vector2i.ONE)
	if viewport.size!=pixels:viewport.size=pixels

func _collect(node: Node) -> void:
	if node is Node3D:
		nodes[str(node.name)]=node
	for child in node.get_children():
		_collect(child)

func _create_displays() -> void:
	display_viewport=SubViewport.new()
	display_viewport.size=Vector2i(960,480)
	display_viewport.transparent_bg=false
	display_viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	world.add_child(display_viewport)
	live_graph=Graph.new()
	live_graph.size=Vector2(960,480)
	display_viewport.add_child(live_graph)
	for name in ["EB_INST_Display_UI","MON_live_artwork"]:
		if nodes.has(name) and nodes[name] is MeshInstance3D:
			var material:=StandardMaterial3D.new()
			material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
			material.albedo_texture=display_viewport.get_texture()
			material.cull_mode=BaseMaterial3D.CULL_DISABLED
			nodes[name].material_override=material

func set_state(state: Dictionary) -> void:
	latest_state=state
	if presentation:
		return
	pose=state.get("pose",{})
	active_scenario=state.get("scenario","weld")
	revealed=state.get("revealed",false)
	if not pose.is_empty() and pose!=last_pose:
		nodes.axis_x.position.x=pose.x_m
		nodes.axis_y.position.z=-float(pose.y_m)
		nodes.axis_z.position.y=pose.lift_m
		nodes.probe_tilt.rotation=Vector3(0,0,-deg_to_rad(float(pose.tilt_deg)))
		_update_cables()
		last_pose=pose.duplicate(true)
	var frame=state.get("selected")
	if frame is Dictionary:
		live_graph.update_frame(frame)
	_explanation()

func _explanation() -> void:
	for name in ["specimen_shell_left","specimen_shell_right","SP_weld_fill","weld_bead_root"]:
		if nodes.has(name):
			nodes[name].visible=not section
	if nodes.has("ground_truth_root"):
		nodes.ground_truth_root.scale=Vector3.ONE
		nodes.ground_truth_root.visible=section and revealed and active_scenario!="intact"
	if nodes.has("section_outline_root"):
		nodes.section_outline_root.scale=Vector3.ONE
		nodes.section_outline_root.visible=section
	if nodes.has("beam_root"):
		nodes.beam_root.hide()

func set_section(value: bool) -> void:
	section=value
	_explanation()

func preset(kind: String) -> void:
	dragging=false
	match kind:
		"Laboratory": target=Vector3(.15,1.10,-.25);yaw=.66;pitch=.38;distance=5.4
		"Probe": target=Vector3(-.30,1.07,0);yaw=-.64;pitch=.40;distance=1.7
		"Instrument": target=Vector3(.85,1.18,0);yaw=.23;pitch=.18;distance=1.05
		"Section": target=Vector3(-.30,.998,0);yaw=-.65;pitch=.55;distance=.9
	_camera_update()

func set_quality(reduced: bool) -> void:
	viewport.msaa_3d=Viewport.MSAA_DISABLED if reduced else Viewport.MSAA_2X
	for node in world.get_children():
		if node is DirectionalLight3D:
			node.shadow_enabled=not reduced

func _camera_update() -> void:
	camera.position=target+Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))*distance
	camera.look_at(target)

func _input_view(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
			var position_in_view: Vector2=event.position*Vector2(viewport.size)/size
			for key in ["SCAN","FREEZE","GATE","FILTER","REPORT","HOME"]:
				var name: String="EB_INST_Key_"+key
				if nodes.has(name) and not camera.is_position_behind(nodes[name].global_position) and camera.unproject_position(nodes[name].global_position).distance_to(position_in_view)<10:
					instrument_action.emit(key.to_lower())
					return
		if event.button_index==MOUSE_BUTTON_RIGHT:
			dragging=event.pressed
			if event.pressed:camera_interacted.emit()
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			camera_interacted.emit()
			distance=clampf(distance*(.9 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.1),.35,8)
			_camera_update()
			accept_event()
	if event is InputEventMouseMotion and dragging:
		yaw-=event.relative.x*.006
		pitch=clampf(pitch+event.relative.y*.006,.08,1.4)
		_camera_update()

func play_presentation() -> void:
	if not animation:
		return
	presentation=true
	for cable in cables:
		cable.hide()
	for name in ["probe_coax_1","probe_coax_2"]:
		nodes[name].show()
	for clip in animation.get_animation_list():
		if "EchoBench_Demo_32s" in clip:
			animation.play(clip)
			return

func stop_presentation() -> void:
	if animation:
		animation.stop()
	presentation=false
	for cable in cables:
		cable.show()
	for name in ["probe_coax_1","probe_coax_2"]:
		nodes[name].hide()
	for name in ["specimen_shell_left","specimen_shell_right"]:
		if nodes.has(name):
			nodes[name].scale=Vector3.ONE
	last_pose={}
	_explanation()
	if not latest_state.is_empty():
		set_state(latest_state)

func _process(_delta: float) -> void:
	_sync_render_size()
	if presentation and animation and not animation.is_playing():
		stop_presentation()

func _update_cables() -> void:
	cable_paths=[]
	for i in range(2):
		var channel: String = "TX" if i==0 else "RX"
		var a: Vector3=nodes["EB_INST_Cable_"+channel+"_connection"].global_position
		var b: Vector3=nodes["probe_"+channel+"_cable_anchor"].global_position
		var top := maxf(1.66,maxf(a.y,b.y)+.28)+i*.025
		var c1 := a+Vector3(.24,top-a.y,.02+i*.012)
		var c2 := b+Vector3(.12,top-b.y,.02+i*.012)
		var surface:=SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var rings: Array[PackedVector3Array]=[]
		var path:=PackedVector3Array()
		for step in range(41):
			var t:=step/40.0
			var p:Vector3=pow(1-t,3)*a+3*pow(1-t,2)*t*c1+3*(1-t)*t*t*c2+t*t*t*b
			path.append(p)
			var tangent:Vector3=(3*pow(1-t,2)*(c1-a)+6*(1-t)*t*(c2-c1)+3*t*t*(b-c2)).normalized()
			var normal:=tangent.cross(Vector3.FORWARD).normalized()
			if normal.length()<.1:
				normal=Vector3.RIGHT
			var binormal:=tangent.cross(normal).normalized()
			var ring:=PackedVector3Array()
			for j in range(8):
				ring.append(p+.0018*(normal*cos(TAU*j/8)+binormal*sin(TAU*j/8)))
			rings.append(ring)
		for step in range(40):
			for j in range(8):
				var k: int=(j+1)%8
				for vertex in [rings[step][j],rings[step+1][j],rings[step+1][k],rings[step][j],rings[step+1][k],rings[step][k]]:
					surface.add_vertex(vertex)
		surface.generate_normals()
		cables[i].mesh=surface.commit()
		cable_paths.append(path)
