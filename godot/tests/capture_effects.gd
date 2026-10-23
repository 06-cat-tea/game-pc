extends SceneTree

var results=[]
var failures=[]
var surface: SubViewport
var game
var directory=""

func _initialize(): call_deferred("run")

func run():
	create_timer(150).timeout.connect(func(): push_error("Effects capture timed out"); quit(2))
	directory="res://../artifacts/godot/upgrade-review"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--effects-dir="): directory=arg.trim_prefix("--effects-dir=")
	DirAccess.make_dir_recursive_absolute(directory)
	surface=SubViewport.new(); surface.size=Vector2i(1280,720); surface.size_2d_override=Vector2i(1920,1080); surface.size_2d_override_stretch=true; surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(surface)
	game=load("res://scenes/main.tscn").instantiate(); surface.add_child(game)
	game.capture_mode=true; game.capture_args.path=""; game.set_process(false); game.world.set_process(false)
	for id in game.db.skills:
		if game.db.skills[id].data.kind=="active": await capture("skill",id,false)
	for id in game.db.progression.ultimates: await capture("ultimate",id,false)
	await capture("ultimate","eira",true)
	var report={"passed":failures.is_empty(),"results":results,"failures":failures,"activeSkills":58,"ultimates":7,"reducedMotion":true}
	var file=FileAccess.open(directory.path_join("combat-effects.json"),FileAccess.WRITE); file.store_string(JSON.stringify(report,"  ")); file.close()
	print("EFFECT CAPTURE: "+JSON.stringify({"passed":report.passed,"captures":results.size(),"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func capture(kind: String, id: String, reduced: bool):
	game.new_game("warden"); game.session.enter_training(game.db.skills[id].job if kind=="skill" else "warden",[id] if kind=="ultimate" and id!="hero" else ["mira","toren","eira"],12)
	game.toast_label.visible=false
	game.session.start_battle("town-trial-2",417)
	var engine=game.session.engine
	var actor_id="hero" if kind=="skill" else id
	engine.battle.cursor=engine.battle.queue.find(actor_id)
	var actor=engine.unit(actor_id); actor.mp=300; actor.max_mp=300; actor.skills=[id] if kind=="skill" else actor.skills
	for unit in engine.battle.units:
		if unit.team=="enemy": unit.hp=9000; unit.max_hp=9000
		else: unit.hp=maxi(1,unit.hp/2)
	game.action_cooldown=0; game.battle_end_pending=false; game.paused=false; game.focused=true; game.mode="battle"; game.session.state.settings.reduce_motion=reduced; game.refresh()
	await process_frame; await process_frame
	game.choose_action("ability" if kind=="skill" else "ultimate",id); game.perform()
	game.combat_effects.elapsed=game.combat_effects.duration*.4; game.combat_effects.set_process(false); game.combat_effects.queue_redraw()
	await RenderingServer.frame_post_draw
	var label=kind+"-"+id+("-reduced" if reduced else "")
	var path=directory.path_join("fx-"+label+".png")
	surface.get_texture().get_image().save_png(path)
	var missing=[]
	for event in game.combat_effects.visuals:
		if event.kind in ["damage","heal","revive","status","mana","dot","break"] and not game.combat_effects.anchors.has(event.target): missing.append(event.target)
	var audit=RailAudit.inspect(game.main_view)
	var passed=not game.combat_effects.visuals.is_empty() and missing.is_empty() and game.action_cooldown>0 and audit.passed
	if not passed: failures.append(label+": missing anchors "+str(missing)+"; layout "+str(audit))
	results.append({"kind":kind,"id":id,"reduced":reduced,"passed":passed,"events":game.last_events.size(),"duration":game.action_cooldown,"file":path})
