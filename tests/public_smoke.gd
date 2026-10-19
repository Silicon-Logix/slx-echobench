# Silicon LogiX / SLX EchoBench
# Copyright (c) 2026 Marco Pezzullo (Silicon LogiX).
# License: Silicon LogiX Evaluation License 1.0. See LICENSE.
extends SceneTree
var app: Control
var response: Dictionary={}
var errors: Array=[]
var output:=""
func _initialize() -> void:
	var args:=OS.get_cmdline_user_args()
	if not args.is_empty():output=args[0]
	_run.call_deferred()
func call_core(op: String,p: Dictionary={}) -> Dictionary:
	response.erase(op)
	app.backend.request(op,p)
	var start:=Time.get_ticks_msec()
	while not response.has(op) and Time.get_ticks_msec()-start<32000:await process_frame
	assert(response.has(op),op+" timeout")
	return response.get(op,{})
func _run() -> void:
	app=load("res://main.tscn").instantiate()
	get_root().add_child(app)
	app.backend.response.connect(func(op,r): response[op]=r)
	app.backend.failed.connect(func(op,code,message): errors.append([op,code,message]))
	var start:=Time.get_ticks_msec()
	while not app.backend_ready and not "CORE_UNAVAILABLE" in app.status_label.text and Time.get_ticks_msec()-start<10000:await process_frame
	if OS.get_environment("SLX_TEST_MISSING_CORE")=="1":
		assert(not app.backend_ready and "CORE_UNAVAILABLE" in app.status_label.text)
		_finish({"passed":true,"missing_core":app.status_label.text})
		return
	assert(app.backend_ready,"Missing binary SDK")
	await call_core("probe.position",{"x_m":-.301,"y_m":-.12})
	await call_core("acquire")
	assert(app.session.selected.result.classification=="indication")
	await call_core("fault.set",{"fault":"overflow"})
	await call_core("acquire")
	await call_core("processing.start",{"profile":"rtl_cosimulation"})
	var job:=await call_core("processing.state")
	while job.status=="running":
		await create_timer(.1).timeout
		job=await call_core("processing.state")
	assert(job.status=="completed")
	assert(job.result.results[0].indication and not job.result.results[1].evaluable)
	var folder:=ProjectSettings.globalize_path("user://smoke-evidence")
	DirAccess.make_dir_recursive_absolute(folder)
	await call_core("storage.set",{"directory":folder})
	await call_core("session.save",{"name":"smoke.echo.json"})
	await call_core("report.export",{"name":"smoke"})
	await call_core("session.load",{"name":"smoke.echo.json"})
	await call_core("replay.seek",{"index":0})
	assert(app.session.pose==app.session.selected.pose)
	await call_core("nde.export",{"name":"smoke.nde"})
	var nde_job:=await call_core("nde.state")
	while nde_job.status=="running":
		await create_timer(.1).timeout
		nde_job=await call_core("nde.state")
	assert(nde_job.status=="completed")
	await call_core("nde.import",{"name":"smoke.nde"})
	nde_job=await call_core("nde.state")
	while nde_job.status=="running":
		await create_timer(.1).timeout
		nde_job=await call_core("nde.state")
	assert(nde_job.status=="completed")
	_finish({"passed":errors.is_empty(),"errors":errors,"frames":app.session.frame_count,"firmware_rtl_job":job.status,"same_inputs":job.result.same_inputs,"session_roundtrip":true,"nde_roundtrip":true,"reports":true})
func _finish(result: Dictionary) -> void:
	if output!="":
		var file:=FileAccess.open(output,FileAccess.WRITE)
		file.store_string(JSON.stringify(result,"  "))
	print(JSON.stringify(result))
	app.backend.shutdown()
	quit(0 if result.passed else 1)
