# Silicon LogiX / SLX EchoBench
# Copyright (c) 2026 Marco Pezzullo (Silicon LogiX).
# License: Silicon LogiX Evaluation License 1.0. See LICENSE.
extends Control
## The core owns acquisition state. UI selection, plots, 3D and replay use its frame ID.
const Palette = preload("res://slx_theme.gd")
const Client = preload("res://core_client.gd")
const Lab = preload("res://laboratory_view.gd")
const Graph = preload("res://ascan.gd")
const Map = preload("res://scan_map.gd")
const Documents = preload("res://product_dialogs.gd")
var backend: Node
var backend_ready := false
var documents: Node
var session: Dictionary = {}
var frames: Array = []
var lab: TextureRect
var graph: Control
var bscan: Control
var cscan: Control
var status_label: Label
var clock_label: Label
var data_label: Label
var result_label: Label
var detail_label: Label
var guide_label: Label
var guide_title: Label
var guide_progress: ProgressBar
var timeline: HSlider
var events: ItemList
var indications: ItemList
var event_indices: Array[int] = []
var indication_indices: Array[int] = []
var comparison_text: RichTextLabel
var view_stack: TabContainer
var nav_buttons: Array[Button] = []
var controls: Dictionary = {}
var scenario: OptionButton
var fault: OptionButton
var scan_button: Button
var pause_button: Button
var resume_button: Button
var stop_button: Button
var annotation: LineEdit
var name_field: LineEdit
var last_tick_ms := 0
var last_heartbeat_ms := 0
var frozen := false
var syncing := false
var guide_running := false
var guide_ms := 0
var guide_phase := -1
var reference: Dictionary = {}
var reduce_motion := false
var settings := ConfigFile.new()
var interface_scale := 1.0
var splitter: HSplitContainer
var split_ratio := .64
var dialog: AcceptDialog
var processing_profile: OptionButton
var processing_running := false
var processing_poll_ms := 0
var processing_poll_pending := false
var low_quality := false
var camera_manual := false
var provenance_dialog: AcceptDialog
var provenance_text: RichTextLabel
var provenance_json := ""
var freeze_control: CheckButton
var freeze_requested := false
var nde_running := false
var nde_finished_job := ""
var nde_poll_pending := false
var nde_poll_ms := 0
var nde_export_button: Button
var nde_import_button: Button
var engineering_contact: Button

func label(value: String, size_px: int=14, color: Color=Palette.INK) -> Label:
	var l := Label.new()
	l.text=value
	l.add_theme_font_size_override("font_size",size_px)
	l.add_theme_color_override("font_color",color)
	return l

func wrapped(value: String, size_px: int=13, color: Color=Palette.MUTED) -> Label:
	var l:=label(value,size_px,color)
	l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	return l

func button(value: String, action: Callable, primary: bool=false, danger: bool=false) -> Button:
	var b:=Button.new()
	b.text=value
	b.custom_minimum_size.y=36
	b.pressed.connect(action)
	if primary or danger:
		Palette.emphasize(b,danger)
	return b

func column(parent: Node, separation: int=10) -> VBoxContainer:
	var c:=VBoxContainer.new()
	c.add_theme_constant_override("separation",separation)
	c.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	parent.add_child(c)
	return c

func row(parent: Node) -> HBoxContainer:
	var r:=HBoxContainer.new()
	r.add_theme_constant_override("separation",8)
	parent.add_child(r)
	return r

func card(parent: Node) -> VBoxContainer:
	var p:=PanelContainer.new()
	p.add_theme_stylebox_override("panel",Palette.box(Palette.PANEL,8,Palette.LINE))
	p.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	parent.add_child(p)
	return column(p)

func _ready() -> void:
	theme=Palette.create()
	settings.load("user://preferences.cfg")
	interface_scale=float(settings.get_value("interface","scale",clampf(snappedf(DisplayServer.screen_get_dpi()/96.0,.25),1.0,2.0)))
	_set_interface_scale(interface_scale)
	reduce_motion=settings.get_value("interface","reduced_motion",false)
	low_quality=settings.get_value("interface","low_quality",false)
	var bg:=ColorRect.new()
	bg.color=Palette.CANVAS
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root:=VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation",0)
	add_child(root)
	_build_header(root)
	_build_toolbar(root)
	var margin:=MarginContainer.new()
	for k in ["margin_left","margin_right","margin_top","margin_bottom"]:
		margin.add_theme_constant_override(k,10)
	margin.size_flags_vertical=Control.SIZE_EXPAND_FILL
	root.add_child(margin)
	var page_scroll:=ScrollContainer.new()
	page_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(page_scroll)
	var body:=row(page_scroll)
	body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	body.size_flags_vertical=Control.SIZE_EXPAND_FILL
	_build_navigation(body)
	view_stack=TabContainer.new()
	view_stack.tabs_visible=false
	view_stack.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	view_stack.size_flags_vertical=Control.SIZE_EXPAND_FILL
	view_stack.add_theme_stylebox_override("panel",Palette.box(Color.TRANSPARENT,0))
	body.add_child(view_stack)
	_build_workspace()
	_build_setup()
	_build_evidence()
	_build_services()
	var foot:=PanelContainer.new()
	foot.add_theme_stylebox_override("panel",Palette.box(Palette.PANEL,0,Palette.LINE))
	root.add_child(foot)
	var f:=row(foot)
	status_label=label("Connecting to local core…",12,Palette.MUTED)
	status_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	f.add_child(status_label)
	clock_label=label("SIMULATED  0.0 s",12,Palette.MUTED)
	f.add_child(clock_label)
	documents=Documents.new()
	documents.attach(self)
	backend=Client.new()
	add_child(backend)
	backend.response.connect(_response)
	backend.failed.connect(_failed)
	backend.start()
	_select_view(0)
	get_tree().auto_accept_quit=false
	get_tree().root.close_requested.connect(_quit)

func _build_header(parent: Node) -> void:
	var panel:=PanelContainer.new()
	panel.add_theme_stylebox_override("panel",Palette.box(Palette.NAVY,0))
	parent.add_child(panel)
	var h:=row(panel)
	h.add_theme_constant_override("separation",20)
	var logo:=TextureRect.new()
	logo.texture=load("res://assets/logo.png")
	logo.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size=Vector2(124,58)
	h.add_child(logo)
	h.add_child(VSeparator.new())
	var title:=column(h,0)
	title.add_child(label("EchoBench",26,Palette.ON_DARK))
	title.add_child(label("ULTRASONICS  /  EMBEDDED  /  EVIDENCE",10,Palette.DARK_MUTED))
	var spacer:=Control.new()
	spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	h.add_child(spacer)
	h.add_child(label("OFFLINE DEMONSTRATION",11,Color("83d4c4")))
	h.add_child(button("Help",func(): documents.show_document("guide")))
	h.add_child(button("About",func(): documents.show_about()))
	h.add_child(button("Custom engineering",func(): _select_view(4)))

func _build_toolbar(parent: Node) -> void:
	var margin:=MarginContainer.new()
	for k in ["margin_left","margin_right","margin_top"]:
		margin.add_theme_constant_override(k,10)
	parent.add_child(margin)
	var r:=row(margin)
	scenario=OptionButton.new()
	scenario.add_item("Weld · 3 known reflectors")
	scenario.add_item("Intact reference")
	scenario.add_item("Training · hidden reference")
	scenario.custom_minimum_size.x=220
	scenario.item_selected.connect(func(i):
		guide_running=false
		lab.stop_presentation()
		backend.request("scenario.load",{"scenario":["weld","intact","training"][i]}))
	r.add_child(scenario)
	scan_button=button("▶ Scan",func(): _end_presentation(); backend.request("scan.start"),true)
	r.add_child(scan_button)
	pause_button=button("Ⅱ Pause",func(): backend.request("pause"))
	r.add_child(pause_button)
	resume_button=button("Resume",func(): _set_frozen(false); backend.request("resume"))
	r.add_child(resume_button)
	stop_button=button("■ STOP",_stop,false,true)
	r.add_child(stop_button)
	r.add_child(button("Reset",func(): guide_running=false; backend.request("simulation.reset")))
	var spacer:=Control.new()
	spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	r.add_child(spacer)
	r.add_child(label("SOURCE",10,Palette.MUTED))
	data_label=label("Software model · C++",12,Palette.SUCCESS)
	r.add_child(data_label)

func _build_navigation(parent: Node) -> void:
	var nav:=card(parent)
	nav.add_theme_constant_override("separation",6)
	nav.get_parent().custom_minimum_size.x=170
	nav.get_parent().size_flags_horizontal=Control.SIZE_FILL
	nav.add_child(label("WORKSPACE",10,Palette.MUTED))
	for text in ["01  Guided visit","02  Technical analysis","03  Setup & calibration","04  Evidence & replay","05  SLX services"]:
		var idx:=nav_buttons.size()
		var b:=button(text,func(): _select_view(idx))
		b.alignment=HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size.y=38
		nav.add_child(b)
		nav_buttons.append(b)
	nav.add_child(HSeparator.new())
	nav.add_child(label("OPERATIONAL DEMO",10,Palette.SUCCESS))
	for text in ["Normal beam · A / B / C","Quality · faults · model A/B","Replay · local reports"]:
		nav.add_child(label(text,12,Palette.MUTED))
	var spacer:=Control.new()
	spacer.size_flags_vertical=Control.SIZE_EXPAND_FILL
	nav.add_child(spacer)
	nav.add_child(wrapped("Synthetic model. Customer physics, hardware and AI require a dedicated project.",12))
	var motion:=CheckButton.new()
	motion.text="Reduce motion"
	motion.button_pressed=reduce_motion
	motion.toggled.connect(func(value): reduce_motion=value; lab.reduced_motion=value)
	nav.add_child(motion)
	var quality:=OptionButton.new()
	quality.add_item("Standard graphics")
	quality.add_item("Reduced graphics")
	quality.select(1 if low_quality else 0)
	quality.item_selected.connect(func(i): low_quality=i==1; lab.set_quality(low_quality))
	nav.add_child(quality)
	var scale_choice:=OptionButton.new()
	for percent in [100,125,150,175,200]:scale_choice.add_item("Interface · %d%%"%percent)
	scale_choice.select(clampi(roundi((interface_scale-1.0)/.25),0,4))
	scale_choice.item_selected.connect(func(i): _set_interface_scale(1.0+i*.25))
	nav.add_child(scale_choice)
	nav.add_child(label("Silicon LogiX / v0.1.0",11,Palette.MUTED))

func _set_interface_scale(value: float) -> void:
	interface_scale=clampf(value,1.0,2.0)
	var window:=get_window()
	window.content_scale_factor=interface_scale
	var usable:=DisplayServer.screen_get_usable_rect(window.current_screen)
	var available:=usable.size
	if available.x<=0 or available.y<=0:available=Vector2i(3840,2160)
	window.min_size=Vector2i((Vector2(1200,760)*interface_scale).round()).min(available)
	if window.mode==Window.MODE_WINDOWED:
		window.size=window.size.max(window.min_size).min(available)
		window.position=window.position.clamp(usable.position,(usable.end-window.size).max(usable.position))
	settings.set_value("interface","scale",interface_scale)

func _build_workspace() -> void:
	var page:=VBoxContainer.new()
	page.name="Laboratory"
	view_stack.add_child(page)
	splitter=HSplitContainer.new()
	splitter.size_flags_vertical=Control.SIZE_EXPAND_FILL
	split_ratio=clampf(float(settings.get_value("interface","split_ratio",.64)),.4,.8)
	page.add_child(splitter)
	var main:=card(splitter)
	main.add_theme_constant_override("separation",6)
	main.get_parent().size_flags_stretch_ratio=split_ratio
	var title:=row(main)
	title.add_child(label("Virtual inspection laboratory",20))
	var spacer:=Control.new()
	spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	title.add_child(spacer)
	title.add_child(label("SLX-UT-01 / 40 mm",11,Palette.MUTED))
	var guide:=PanelContainer.new()
	guide.name="GuideCard"
	guide.add_theme_stylebox_override("panel",Palette.box(Palette.HOVER,7))
	main.add_child(guide)
	var g:=column(guide,5)
	guide_title=label("From a 3D component to reproducible evidence",16,Palette.ACCENT)
	g.add_child(guide_title)
	guide_label=wrapped("Follow a 75-second inspection: reference, scan, lost coupling, acquisition fault and an A/B explanation.")
	g.add_child(guide_label)
	var actions:=row(g)
	actions.add_child(button("Start guided inspection",_start_guide,true))
	actions.add_child(button("Asset presentation · 32 s",func():
		if not session.get("status","") in ["running","paused","replaying"]:
			lab.play_presentation()
			guide_label.text="Asset presentation: recorded animation only. Stop to return to the acquisition session."))
	actions.add_child(button("End presentation",_end_presentation))
	guide_progress=ProgressBar.new()
	guide_progress.max_value=75
	guide_progress.show_percentage=false
	guide_progress.custom_minimum_size.y=5
	g.add_child(guide_progress)
	lab=Lab.new()
	main.add_child(lab)
	lab.set_quality(low_quality)
	lab.instrument_action.connect(_instrument_action)
	lab.camera_interacted.connect(func(): camera_manual=true)
	var views:=row(main)
	for text in ["Laboratory","Probe","Instrument","Section"]:
		views.add_child(button(text,func():
			camera_manual=true
			lab.preset(text)
			lab.set_section(text=="Section")))
	views.add_child(button("Reveal reference",func(): backend.request("training.reveal")))
	main.add_child(label("Right-drag to orbit · scroll to zoom · section = known synthetic reference",11,Palette.MUTED))
	var timeline_row:=row(main)
	timeline_row.add_child(button("▶ Replay",func(): _end_presentation(); backend.request("replay.start")))
	timeline_row.add_child(button("Return live",func(): backend.request("replay.exit")))
	timeline=HSlider.new()
	timeline.min_value=0
	timeline.max_value=1
	timeline.step=1
	timeline.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	timeline.value_changed.connect(func(value):
		if not syncing and backend_ready:
			backend.request("replay.seek",{"index":int(value)}))
	timeline_row.add_child(timeline)
	timeline_row.add_child(button("Acquire point",func(): _end_presentation(); backend.request("acquire")))
	var analysis:=card(splitter)
	analysis.add_theme_constant_override("separation",6)
	analysis.get_parent().size_flags_stretch_ratio=1.0-split_ratio
	splitter.drag_ended.connect(func():
		var first: Control=main.get_parent()
		var second: Control=analysis.get_parent()
		split_ratio=first.size.x/maxf(1,first.size.x+second.size.x)
		first.size_flags_stretch_ratio=split_ratio
		second.size_flags_stretch_ratio=1.0-split_ratio
		splitter.split_offset=0)
	analysis.get_parent().custom_minimum_size.x=380
	var heading:=row(analysis)
	heading.add_child(label("Signal & inspection",19))
	var rf:=OptionButton.new()
	rf.add_item("Envelope")
	rf.add_item("RF")
	rf.item_selected.connect(func(i): graph.mode="envelope" if i==0 else "rf"; graph.queue_redraw())
	heading.add_child(rf)
	freeze_control=CheckButton.new()
	freeze_control.text="Freeze"
	freeze_control.toggled.connect(_set_frozen)
	heading.add_child(freeze_control)
	graph=Graph.new()
	graph.size_flags_vertical=Control.SIZE_EXPAND_FILL
	graph.size_flags_stretch_ratio=1.25
	analysis.add_child(graph)
	graph.cursor_changed.connect(func(t): status_label.text="Cursor %.2f µs · amplitude and gates use the selected acquisition"%t)
	result_label=label("No acquisition selected",16,Palette.MUTED)
	var result_row:=row(analysis)
	result_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	result_row.add_child(result_label)
	result_row.add_child(button("Details",_show_provenance))
	detail_label=wrapped("Pose, gates and calibration will follow the selected acquisition.",12)
	analysis.add_child(detail_label)
	var map_choice:=OptionButton.new()
	for text in ["Gate A amplitude · FS","Coupling / data quality","Executed path","Sampled points"]:
		map_choice.add_item(text)
	map_choice.item_selected.connect(func(i): cscan.mode=["amplitude","quality","path","points"][i]; cscan.queue_redraw())
	analysis.add_child(map_choice)
	cscan=Map.new()
	cscan.size_flags_vertical=Control.SIZE_EXPAND_FILL
	cscan.point_selected.connect(_seek)
	analysis.add_child(cscan)
	bscan=Map.new()
	bscan.size_flags_vertical=Control.SIZE_EXPAND_FILL
	bscan.size_flags_stretch_ratio=.9
	bscan.bscan=true
	bscan.custom_minimum_size.y=140
	bscan.point_selected.connect(_seek)
	analysis.add_child(bscan)
	analysis.add_child(label("Low  ░ → ▓  High · red = not evaluable · grey = unsampled",10,Palette.MUTED))

func field(parent: Node,key: String,title: String,value: float,minimum: float,maximum: float,step: float) -> SpinBox:
	var r:=row(parent)
	var l:=label(title,13)
	l.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	r.add_child(l)
	var s:=SpinBox.new()
	s.min_value=minimum
	s.max_value=maximum
	s.step=step
	s.value=value
	s.custom_minimum_size.x=130
	r.add_child(s)
	controls[key]=s
	return s

func _build_setup() -> void:
	var scroll:=ScrollContainer.new()
	scroll.name="Setup"
	view_stack.add_child(scroll)
	var c:=column(scroll,16)
	c.add_child(label("Technical setup & model calibration",25))
	c.add_child(wrapped("Raster acquisition uses the C++ normal-beam model. The firmware profiles in Evidence & replay execute the selected saved input through native Renode, with an optional Verilator FIFO."))
	var halves:=row(c)
	var pose_panel:=card(halves)
	pose_panel.add_child(label("Probe & acquisition faults",19))
	field(pose_panel,"x_m","X / mm",-300,-620,20,1)
	field(pose_panel,"y_m","Y / mm",-120,-150,150,1)
	field(pose_panel,"lift_m","Lift / mm",0,0,80,1)
	field(pose_panel,"tilt_deg","Tilt / degrees · raised only",0,0,12,1)
	field(pose_panel,"coupling","Coupling factor",1,0,1,.05)
	pose_panel.add_child(button("Apply probe pose",_apply_pose,true))
	pose_panel.add_child(wrapped("The nominal 0.5 mm gap represents a couplant layer. Lift above 1 mm means air separation; tilt requires at least 75 mm lift."))
	fault=OptionButton.new()
	for text in ["No injected fault","Coupling loss · X −400…−200 mm","Acquisition overflow · 64 lost samples"]:
		fault.add_item(text)
	fault.item_selected.connect(func(i): backend.request("fault.set",{"fault":["none","coupling_loss","overflow"][i]}))
	pose_panel.add_child(fault)
	pose_panel.add_child(button("Acquire at this pose",func(): backend.request("acquire")))
	var signal_panel:=card(halves)
	signal_panel.add_child(label("Signal model & processing",19))
	field(signal_panel,"velocity_m_s","Model velocity / m/s",5900,1000,10000,10)
	field(signal_panel,"attenuation_db_mm","Attenuation / dB/mm",.012,0,1,.001)
	field(signal_panel,"noise_fraction","Noise / full scale",.009,0,.2,.001)
	field(signal_panel,"gain_db","Gain / dB",0,-24,30,1)
	for key in ["a","b"]:
		var gate: String=key.to_upper()
		field(signal_panel,"gate_"+key+"_start_us","Gate "+gate+" start / µs",2 if key=="a" else 12,.8,19,.1)
		field(signal_panel,"gate_"+key+"_end_us","Gate "+gate+" end / µs",11.6 if key=="a" else 15.2,1,20,.1)
		field(signal_panel,"gate_"+key+"_threshold","Gate "+gate+" threshold / FS",.28 if key=="a" else .2,.01,1,.01)
	field(signal_panel,"raster_step_x_m","Raster X pitch / mm",20,10,100,5)
	field(signal_panel,"raster_step_y_m","Raster Y pitch / mm",20,10,100,5)
	var filter:=OptionButton.new()
	filter.add_item("No filter")
	filter.add_item("3-point moving average")
	controls.filter=filter
	signal_panel.add_child(filter)
	var build:=OptionButton.new()
	build.add_item("Model B · quality admission")
	build.add_item("Model A · ignores overflow")
	controls.build=build
	signal_panel.add_child(build)
	signal_panel.add_child(button("Apply acquisition setup",_apply_configuration,true))
	var cal:=card(c)
	cal.add_child(label("Two-thickness synthetic reference",19))
	cal.add_child(wrapped("Read the 20 mm and 40 mm references, inspect time of flight, then fit velocity and transducer delay. Results apply to future acquisitions; saved frames retain their original setup. This calibrates the model, not a real instrument."))
	var rr:=row(cal)
	rr.add_child(button("1. Read synthetic reference",func(): backend.request("calibration.reference")))
	field(cal,"tof_20mm_us","Reference 20 mm / µs",7.12,3,30,.04)
	field(cal,"tof_40mm_us","Reference 40 mm / µs",13.92,4,60,.04)
	cal.add_child(button("2. Apply fitted calibration",func(): backend.request("calibration.apply",{"tof_20mm_us":controls.tof_20mm_us.value,"tof_40mm_us":controls.tof_40mm_us.value}),true))

func _build_evidence() -> void:
	var c:=column(view_stack)
	c.name="Evidence"
	c.add_child(label("Evidence, causal comparison & replay",25))
	c.add_child(wrapped("Select an indication or event to inspect the same pose, RF samples, parameters and simulated time in the laboratory."))
	var r:=row(c)
	name_field=LineEdit.new()
	name_field.text="inspection"
	name_field.max_length=70
	name_field.placeholder_text="Local file base name"
	name_field.custom_minimum_size.x=200
	r.add_child(name_field)
	r.add_child(button("Save session",func(): backend.request("session.save",{"name":name_field.text+".echo.json"})))
	r.add_child(button("Load session",func(): backend.request("session.load",{"name":name_field.text+".echo.json"})))
	r.add_child(button("Export report",func(): backend.request("report.export",{"name":name_field.text}),true))
	r.add_child(button("Storage folder…",_choose_storage))
	c.add_child(wrapped("Default folder: Documents / SLX EchoBench. A session includes inputs, processed outputs, poses, events, calibration, annotations and checksums. Reports include HTML, JSON and unit-labelled CSV."))
	var nde_row:=row(c)
	nde_row.add_child(label("NDE 4.4 · raw single A-scan",13,Palette.ACCENT))
	nde_export_button=button("Export selected .nde",func(): backend.request("nde.export",{"name":name_field.text+".nde"}))
	nde_export_button.tooltip_text="Maps one complete, coupled, unsaturated RF acquisition. Includes the native SLX session for exact replay roundtrip."
	nde_row.add_child(nde_export_button)
	nde_import_button=button("Import SLX .nde",func(): backend.request("nde.import",{"name":name_field.text+".nde"}))
	nde_import_button.tooltip_text="Accepts only the documented SLX single-A-scan mapping; general instrument .nde files are rejected."
	nde_row.add_child(nde_import_button)
	nde_row.add_child(button("Cancel file job",func(): backend.request("nde.cancel")))
	var split:=HSplitContainer.new()
	split.size_flags_vertical=Control.SIZE_EXPAND_FILL
	c.add_child(split)
	var left:=card(split)
	left.add_child(label("Indications",19))
	indications=ItemList.new()
	indications.custom_minimum_size=Vector2(330,150)
	indications.size_flags_vertical=Control.SIZE_EXPAND_FILL
	indications.item_selected.connect(func(i): _seek(indication_indices[i]); _select_view(1))
	left.add_child(indications)
	left.add_child(label("Event timeline",19))
	events=ItemList.new()
	events.custom_minimum_size=Vector2(330,180)
	events.size_flags_vertical=Control.SIZE_EXPAND_FILL
	events.item_selected.connect(func(i): _seek(event_indices[i]); _select_view(1))
	left.add_child(events)
	var right:=card(split)
	right.add_child(label("Repeat with another processor",19))
	right.add_child(wrapped("Model A and model B process the exact saved RF input. A deliberately ignores overflow; B rejects incomplete data. This is a host processor comparison. The firmware profiles below execute the compiled ThreadX examples."))
	right.add_child(button("Compare model A / B",func(): backend.request("comparison.run"),true))
	right.add_child(wrapped("Execute the selected saved acquisition with the two included ThreadX builds. Renode and the compiled RTL FIFO run in a separate native process; cancellation keeps the interface responsive.",12))
	processing_profile=OptionButton.new()
	processing_profile.add_item("ThreadX / Renode · compiled A/B")
	processing_profile.add_item("ThreadX + Verilator FIFO · compiled A/B")
	right.add_child(processing_profile)
	var processing_actions:=row(right)
	processing_actions.add_child(button("Execute firmware A/B",func(): backend.request("processing.start",{"profile":["threadx_renode","rtl_cosimulation"][processing_profile.selected]}),true))
	processing_actions.add_child(button("Cancel job",func(): backend.request("processing.cancel")))
	comparison_text=RichTextLabel.new()
	comparison_text.bbcode_enabled=true
	comparison_text.selection_enabled=true
	comparison_text.size_flags_vertical=Control.SIZE_EXPAND_FILL
	comparison_text.custom_minimum_size=Vector2(330,180)
	comparison_text.text="Acquire an overflow example, then run the comparison."
	right.add_child(comparison_text)
	right.add_child(label("Annotation on selected acquisition",14))
	annotation=LineEdit.new()
	annotation.placeholder_text="Observation, cause or follow-up…"
	annotation.max_length=300
	right.add_child(annotation)
	right.add_child(button("Add annotation",func(): backend.request("annotation.add",{"text":annotation.text})))

func _build_services() -> void:
	var scroll:=ScrollContainer.new()
	scroll.name="Services"
	view_stack.add_child(scroll)
	var c:=column(scroll,16)
	c.add_child(label("Engineering around your inspection problem",25))
	c.add_child(wrapped("EchoBench demonstrates reproducible links between acquisition, processing and inspection evidence. The following integrations are developed and validated for an agreed customer application."))
	var contact:=row(c)
	engineering_contact=button("Discuss a custom development",func(): OS.shell_open("https://www.siliconlogix.it/contatti"),true)
	contact.add_child(engineering_contact)
	contact.add_child(button("Save enquiry locally",func():
		var file:=FileAccess.open("user://engineering-enquiry.txt",FileAccess.WRITE)
		file.store_string("SLX EchoBench — custom development enquiry\n\nInspection problem:\nReference data and permissions:\nFirmware / device / software versions:\nRequired acceptance evidence:\n\nContact: https://www.siliconlogix.it/contatti\n")
		_notice("Enquiry saved locally","Saved in application user data. No enquiry or telemetry was transmitted.")))
	var grid:=GridContainer.new()
	grid.columns=2
	grid.add_theme_constant_override("h_separation",16)
	grid.add_theme_constant_override("v_separation",16)
	c.add_child(grid)
	var services: Array = JSON.parse_string(FileAccess.get_file_as_string("res://content/services.json"))
	for service in services:
		var panel:=card(grid)
		panel.custom_minimum_size.x=390
		panel.add_child(label(service.title,19))
		panel.add_child(label("CUSTOM DEVELOPMENT",10,Palette.ACCENT))
		panel.add_child(wrapped(service.problem,14,Palette.INK))
		panel.add_child(wrapped("Example result: "+service.result))
		panel.add_child(wrapped("Project inputs: "+service.inputs,12))
	c.add_child(wrapped("PAUT/TFM, AI, adaptive planning, DICONDE/PACS, HIL and robot integration are not included as operational analyses in this demo. Feasibility and validation are defined with the customer."))

func _select_view(index: int) -> void:
	if index>0 and is_instance_valid(lab) and lab.presentation:
		_end_presentation()
	for i in nav_buttons.size():
		nav_buttons[i].add_theme_stylebox_override("normal",Palette.box(Palette.SELECTED if i==index else Color.WHITE,5))
	view_stack.current_tab=0 if index<2 else index-1
	if index<2:
		guide_title.get_parent().get_parent().visible=index==0

func _instrument_action(action: String) -> void:
	match action:
		"scan":
			_end_presentation()
			backend.request("scan.start")
		"freeze": _set_frozen(not frozen)
		"gate", "filter": _select_view(2)
		"report": _select_view(3)
		"home": lab.preset("Laboratory")

func _apply_pose() -> void:
	backend.request("probe.position",{"x_m":controls.x_m.value/1000,"y_m":controls.y_m.value/1000,"lift_m":controls.lift_m.value/1000,"tilt_deg":controls.tilt_deg.value,"coupling":controls.coupling.value})

func _apply_configuration() -> void:
	var config: Dictionary={}
	for key in ["velocity_m_s","attenuation_db_mm","noise_fraction","gain_db","gate_a_start_us","gate_a_end_us","gate_a_threshold","gate_b_start_us","gate_b_end_us","gate_b_threshold"]:
		config[key]=controls[key].value
	for key in ["raster_step_x_m","raster_step_y_m"]:
		config[key]=controls[key].value/1000
	config.filter=["none","box3"][controls.filter.selected]
	config.build=["model-B","model-A"][controls.build.selected]
	backend.request("configuration.set",config)

func _seek(index: int) -> void:
	guide_running=false
	_set_frozen(false)
	backend.request("replay.seek",{"index":index})

func _set_frozen(value: bool) -> void:
	freeze_requested=false
	frozen=value
	freeze_control.set_pressed_no_signal(value)
	if value:
		guide_running=false
		if session.get("status","")=="running":
			frozen=false
			freeze_requested=true
			backend.request("pause")
		elif session.get("status","")=="replaying":
			frozen=false
			freeze_requested=true
			backend.request("stop")
	elif not session.is_empty():
		_apply_state(session)

func _stop() -> void:
	guide_running=false
	_end_presentation()
	backend.request("stop")

func _end_presentation() -> void:
	_set_frozen(false)
	lab.stop_presentation()
	if not session.is_empty():
		lab.set_state(session)

func _choose_storage() -> void:
	var chooser:=FileDialog.new()
	chooser.title="Choose local session and report directory"
	chooser.access=FileDialog.ACCESS_FILESYSTEM
	chooser.file_mode=FileDialog.FILE_MODE_OPEN_DIR
	chooser.use_native_dialog=true
	add_child(chooser)
	chooser.dir_selected.connect(func(path): backend.request("storage.set",{"directory":path}); chooser.queue_free())
	chooser.canceled.connect(chooser.queue_free)
	chooser.popup_centered(Vector2i(900,600))

func _notice(title: String,message: String) -> void:
	if not is_instance_valid(dialog):
		dialog=AcceptDialog.new()
		dialog.min_size=Vector2i(540,180)
		add_child(dialog)
	dialog.title=title
	dialog.dialog_text=message
	dialog.popup_centered()

func _show_provenance() -> void:
	var selected=graph.frame if frozen else session.get("selected")
	if not selected is Dictionary:
		_notice("No selected acquisition","Acquire or select a recorded point first.")
		return
	var f: Dictionary=selected
	var processed: Dictionary=f.result.duplicate(true)
	processed.erase("processed_rf")
	processed.erase("envelope")
	var sample:=clampi(int(round(graph.cursor_us/float(f.dt_us))),0,511)
	var context: Dictionary={"acquisition_id":f.acquisition_id,"frame_index":f.index,"time_simulated_s":f.time_s,"source":f.source,"model_version":f.model_version,"input_sha256":f.input_sha256,"pose":f.pose,"configuration":f.configuration,"calibration":f.calibration,"effective_coupling":f.effective_coupling,"dropped_samples":f.dropped_samples,"result":processed,"cursor_sample":{"index":sample,"time_us":sample*float(f.dt_us),"raw_rf_normalized":f.raw_rf[sample],"processed_rf_normalized":f.result.processed_rf[sample],"envelope_normalized":f.result.envelope[sample]}}
	if f.has("processing_history"):
		context.compiled_processing=f.processing_history
	provenance_json=JSON.stringify(context,"  ")
	if not is_instance_valid(provenance_dialog):
		provenance_dialog=AcceptDialog.new()
		provenance_dialog.title="Selected acquisition · provenance & decision"
		provenance_dialog.ok_button_text="Close"
		add_child(provenance_dialog)
		var content:=column(provenance_dialog)
		content.add_child(wrapped("Recorded pose, actual samples, applied parameters and decision. Known reflector geometry is a separate explanatory reference."))
		provenance_text=RichTextLabel.new()
		provenance_text.selection_enabled=true
		provenance_text.custom_minimum_size=Vector2(760,480)
		provenance_text.size_flags_vertical=Control.SIZE_EXPAND_FILL
		content.add_child(provenance_text)
		content.add_child(button("Copy acquisition context",func(): DisplayServer.clipboard_set(provenance_json)))
	provenance_text.text=provenance_json
	provenance_text.scroll_to_line(0)
	provenance_dialog.popup_centered_clamped(Vector2i(900,680),.9)

func _response(op: String,result: Dictionary) -> void:
	if op=="open":
		if result.get("capabilities",{}).get("api","")!="slx.echobench/v1":
			_failed("open","API_VERSION","The installed interface and core are incompatible.")
			backend.shutdown()
			return
		backend_ready=true
		documents.core_version=result.capabilities.version
		for i in range(2):
			processing_profile.set_item_disabled(i,result.capabilities.profiles[i+1].status=="unavailable")
		nde_export_button.disabled=result.capabilities.get("nde","unavailable")=="unavailable"
		nde_import_button.disabled=nde_export_button.disabled
		_apply_state(result.state)
		_sync_setup(result.state)
		return
	if result.has("status") and result.has("session_id"):
		if op in ["acquire","scan.start","resume","scenario.load","session.load","simulation.reset"]:
			frozen=false
			freeze_requested=false
			freeze_control.set_pressed_no_signal(false)
		if session.get("session_id","")!=result.session_id or op=="session.load":
			frames=[]
		session=result
		_apply_state(result)
		if op in ["pause","stop"] and freeze_requested:
			frozen=true
			freeze_requested=false
		if op in ["configuration.set","probe.position","scenario.load","session.load","simulation.reset","calibration.apply"]:
			_sync_setup(result)
		if int(result.frame_count)>frames.size():
			backend.request("frames.read",{"offset":frames.size(),"limit":16,"full":true})
	if op=="frames.read":
		for f in result.frames:
			if int(f.index)==frames.size():
				frames.append(f)
		if frames.size()<int(result.total):
			backend.request("frames.read",{"offset":frames.size(),"limit":16,"full":true})
		_refresh_maps()
		_refresh_lists()
	if op=="calibration.reference":
		reference=result
		controls.tof_20mm_us.value=result.points[0].measured_tof_us
		controls.tof_40mm_us.value=result.points[1].measured_tof_us
		_notice("Synthetic reference acquired","20 mm: %.2f µs\n40 mm: %.2f µs\nInitial offset %.2f µs. Review and apply the fit. Model calibration only." % [result.points[0].measured_tof_us,result.points[1].measured_tof_us,result.initial_setup.offset_us])
	if op=="comparison.run":
		comparison_text.text="[b]Same inputs · %d compared · %d changed[/b]\n\n%s\n\nOrigin: %s\nAmplitude tolerance: 1e-12\n" % [result.rows.size(),result.changed_frames,result.difference_stage,result.source]
		if result.first_difference!=null:
			comparison_text.text+="\nFirst changed acquisition: %d\n"%int(result.first_difference)
		for entry in result.rows:
			if entry.changed:
				comparison_text.text+="\nFrame %d: A %s → B %s"%[entry.frame_index,entry.a.classification,entry.b.classification]
	if op in ["processing.start","processing.state","processing.cancel"]:
		processing_running=result.status=="running"
		processing_poll_pending=false
		if result.status=="running":
			comparison_text.text="[b]Executing compiled firmware…[/b]\n\n"+str(result.metadata.get("profile",""))+"\nTwo ThreadX ELFs use the same saved Q15 input.\nUse Cancel job or STOP to interrupt."
		elif result.status=="completed":
			var evidence: Dictionary=result.result
			comparison_text.text="[b]Compiled firmware execution completed[/b]\n\n%s · frame %d\nSame input: %s\nHost execution: %.2f s\n"%[evidence.profile,evidence.frame_index,str(evidence.same_inputs),evidence.host_elapsed_s]
			for processed in evidence.results:
				comparison_text.text+="\n%s · %d samples · peak %d Q15\nEvaluable: %s · indication: %s · RTOS ticks %d\n"%[processed.build,processed.count,processed.peak_q15,str(processed.evaluable),str(processed.indication),processed.threadx_ticks]
			comparison_text.text+="\n"+evidence.difference_stage+"\n\n"+evidence.sample_loss
			backend.request("state")
		elif result.status in ["failed","timeout"]:
			comparison_text.text="Embedded job "+result.status+". No replacement result was generated. Check the complete runtime package."
		else:
			comparison_text.text="Embedded job "+str(result.status)
	if op in ["nde.export","nde.import","nde.state","nde.cancel"]:
		nde_running=result.status=="running"
		nde_poll_pending=false
		if nde_running:
			status_label.text="NDE "+str(result.operation)+" · validating the declared single-A-scan mapping…"
		elif result.status=="completed":
			if nde_finished_job!=str(result.job_id):
				nde_finished_job=str(result.job_id)
				if result.operation=="import":
					frames=[]
					_set_frozen(false)
					backend.request("state")
				_notice("NDE subset completed","NDE 4.4 single A-scan mapping validated. Native session roundtrip verified.\n\nGeneral device .nde files and DICONDE are outside this subset.")
		elif result.status in ["failed","timeout"]:
			_notice("NDE mapping rejected","The file job could not validate the declared SLX single-A-scan mapping. The current session is unchanged.")
		else:
			status_label.text="NDE file job "+str(result.status)
	if op=="training.reveal":
		session.revealed=true
		lab.set_state(session)
		lab.set_section(true)
		if not reduce_motion and not camera_manual:
			lab.preset("Section")
	if op=="annotation.add":
		annotation.clear()
		status_label.text="Annotation saved on the selected acquisition"
	if op=="session.save":
		_notice("Session saved","Saved %s with %d acquisitions and a SHA-256 checksum in the configured local folder."%[result.saved,result.frames])
	if op=="report.export":
		_notice("Report exported","Created %s in the configured local folder."%", ".join(result.files))

func _apply_state(value: Dictionary) -> void:
	session=value
	var state: String=value.get("status","idle")
	status_label.text="● %s · %d sampled points · application STOP"%[state.capitalize(),int(value.get("frame_count",0))]
	clock_label.text="SIMULATED %.2f s   /   HOST %.1f s"%[float(value.get("time_s",0)),float(value.get("host_elapsed_s",0))]
	data_label.text="Recorded replay · model" if state in ["replay_ready","replaying"] else "Software model · C++"
	scan_button.disabled=not backend_ready or state in ["running","paused","replaying","replay_ready"]
	pause_button.disabled=state!="running"
	resume_button.disabled=state!="paused"
	scenario.disabled=state in ["running","paused","replaying"]
	if not frozen:
		lab.set_state(value)
		var frame=value.get("selected")
		if frame is Dictionary:
			graph.update_frame(frame)
			var r: Dictionary=frame.result
			result_label.text={"indication":"Indication · gate A","no_indication":"No indication · backwall present","not_evaluable":"Not evaluable","no_backwall":"No backwall echo"}.get(r.classification,r.classification)
			result_label.add_theme_color_override("font_color",Palette.ATTENTION if r.classification=="indication" else Palette.FAILURE if not r.data_valid else Palette.SUCCESS)
			detail_label.text="X %.1f / Y %.1f mm · %.2f s · %s\nGate A %.3f FS · %s · lost %d\nThickness %s mm · %s"%[float(frame.pose.x_m)*1000,float(frame.pose.y_m)*1000,float(frame.time_s),frame.result.build,float(r.gate_a_peak),r.quality_reason,int(frame.dropped_samples),"—" if r.thickness_mm==null else "%.2f"%float(r.thickness_mm),"calibrated model" if frame.calibration.valid else "initial setup"]
		_refresh_maps()
	syncing=true
	timeline.max_value=maxi(0,int(value.get("frame_count",0))-1)
	timeline.value=value.get("cursor",0)
	timeline.editable=state not in ["running","paused"] and int(value.get("frame_count",0))>0
	syncing=false
	_refresh_lists()

func _sync_setup(value: Dictionary) -> void:
	for key in value.get("configuration",{}):
		if controls.has(key) and controls[key] is SpinBox:
			controls[key].value=float(value.configuration[key])*(1000 if key in ["raster_step_x_m","raster_step_y_m"] else 1)
	for key in value.get("pose",{}):
		if controls.has(key):
			controls[key].value=float(value.pose[key])*(1000 if key in ["x_m","y_m","lift_m"] else 1)
	controls.filter.select(0 if value.configuration.filter=="none" else 1)
	controls.build.select(0 if value.configuration.build=="model-B" else 1)

func _refresh_maps() -> void:
	if not frozen:
		cscan.refresh(frames,int(session.get("cursor",0)))
		bscan.refresh(frames,int(session.get("cursor",0)))

func _refresh_lists() -> void:
	if not is_instance_valid(indications):
		return
	indications.clear()
	indication_indices=[]
	for f in frames:
		if f.result.classification=="indication":
			indications.add_item("#%d · X %.0f / Y %.0f mm · depth %.1f mm"%[int(f.index),float(f.pose.x_m)*1000,float(f.pose.y_m)*1000,float(f.result.depth_mm)])
			indication_indices.append(int(f.index))
	events.clear()
	event_indices=[]
	for e in session.get("events",[]):
		events.add_item("%.2f s · %s"%[float(e.time_s),e.code])
		events.set_item_tooltip(events.item_count-1,e.message)
		event_indices.append(clampi(int(e.frame_index),0,maxi(0,frames.size()-1)))

func _failed(op: String,code: String,message: String) -> void:
	if op.begins_with("nde."):
		nde_running=false
		nde_poll_pending=false
	status_label.text="%s · %s"%[code,message]
	if code in ["CORE_UNAVAILABLE","CORE_EXITED","API_VERSION"]:
		backend_ready=false
	if op!="tick":
		_notice("Operation could not complete",message+"\n\n"+code)
	guide_running=false

func _process(_delta: float) -> void:
	if not backend_ready:
		return
	var now:=Time.get_ticks_msec()
	if now-last_tick_ms>=75 and not backend.tick_pending and session.get("status","") in ["running","replaying"]:
		backend.request("tick",{"count":1})
		last_tick_ms=now
	if now-last_heartbeat_ms>=2000 and backend.pending.is_empty():
		backend.request("state")
		last_heartbeat_ms=now
	if processing_running and not processing_poll_pending and now-processing_poll_ms>200:
		processing_poll_pending=true
		processing_poll_ms=now
		backend.request("processing.state")
	if nde_running and not nde_poll_pending and now-nde_poll_ms>200:
		nde_poll_pending=true
		nde_poll_ms=now
		backend.request("nde.state")
	if guide_running:
		_guide_step(now)

func _start_guide() -> void:
	if session.get("status","") in ["running","paused","replaying"]:
		_notice("Session is active","Stop the current scan or replay before starting a new guided inspection.")
		return
	_end_presentation()
	guide_running=true
	camera_manual=false
	guide_ms=Time.get_ticks_msec()
	guide_phase=-1
	frames=[]
	backend.request("scenario.load",{"scenario":"weld"})
	backend.request("probe.position",{"x_m":-.6,"y_m":-.14,"lift_m":0,"tilt_deg":0,"coupling":1})
	backend.request("configuration.set",{"build":"model-B","velocity_m_s":5900,"attenuation_db_mm":.012,"noise_fraction":.009,"gain_db":0,"filter":"none","gate_a_start_us":2,"gate_a_end_us":11.6,"gate_a_threshold":.28,"gate_b_start_us":12,"gate_b_end_us":15.2,"gate_b_threshold":.2,"raster_step_x_m":.02,"raster_step_y_m":.02,"sample_period_s":.1})
	_select_view(0)

func _guide_step(now: int) -> void:
	var elapsed: float=(now-guide_ms)/1000.0
	guide_progress.value=elapsed
	var phase:=0 if elapsed<5 else 1 if elapsed<9 else 2 if elapsed<48 else 3 if elapsed<56 else 4 if elapsed<64 else 5 if elapsed<75 else 6
	if phase==guide_phase:
		return
	guide_phase=phase
	match phase:
		0:
			guide_title.text="01 / Reference & provenance"
			guide_label.text="A 40 mm synthetic weld coupon, three known reflectors and one deterministic acquisition chain. Every sample will retain its pose and setup."
			if not reduce_motion: lab.preset("Probe")
		1:
			guide_title.text="02 / Model calibration"
			guide_label.text="Two synthetic references fit acoustic velocity and transducer delay. This is a model calibration, with no real instrument certificate."
			backend.request("calibration.apply",{"tof_20mm_us":7.12,"tof_40mm_us":13.92})
		2:
			guide_title.text="03 / Sample the weld"
			guide_label.text="Pose changes the actual RF samples. C-scan shows gate A amplitude; B-scan shows one pass. Visited points and volumetric UT coverage are different concepts."
			backend.request("scan.start",{"x_min_m":-.40,"x_max_m":-.20,"y_min_m":-.14,"y_max_m":.14})
		3:
			guide_title.text="04 / A physical problem"
			guide_label.text="Loss of couplant reduces the signal. The result becomes not evaluable, rather than an intact part."
			backend.request("stop")
			backend.request("probe.position",{"x_m":-.301,"y_m":-.12,"coupling":.05})
			backend.request("acquire")
		4:
			guide_title.text="05 / An acquisition problem"
			guide_label.text="The host acquisition model now drops 64 samples. The loss propagates into quality admission and the inspection result."
			backend.request("probe.position",{"coupling":1})
			backend.request("fault.set",{"fault":"overflow"})
			backend.request("acquire")
		5:
			guide_title.text="06 / Same input, another processor"
			guide_label.text="Model A ignores overflow. Model B rejects the incomplete input. The comparison isolates the quality-admission rule on the same saved RF samples."
			backend.request("comparison.run")
		6:
			guide_running=false
			guide_title.text="Inspection complete · inspect the evidence"
			guide_label.text="Explore the known reference separately from indications, select a suspicious point, or export the report in Evidence & replay. Custom embedded and UT integrations build on this traceability."
			backend.request("training.reveal")
			backend.request("fault.set",{"fault":"none"})

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_F1: documents.show_document("guide")
		elif event.keycode==KEY_F12: documents.show_about()
		elif event.keycode==KEY_ESCAPE: _stop()
		elif event.ctrl_pressed and event.keycode==KEY_S: backend.request("session.save",{"name":name_field.text+".echo.json"})
		elif event.ctrl_pressed and event.keycode==KEY_O: backend.request("session.load",{"name":name_field.text+".echo.json"})

func _quit() -> void:
	settings.set_value("interface","reduced_motion",reduce_motion)
	settings.set_value("interface","split_ratio",split_ratio)
	settings.set_value("interface","low_quality",low_quality)
	settings.save("user://preferences.cfg")
	backend.shutdown()
	get_tree().quit()

