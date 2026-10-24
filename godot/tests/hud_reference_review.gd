extends SceneTree

var surface: SubViewport
var game
var failures=[]
var frames=[]
var output="res://../artifacts/godot/hud-reference-review"

func _initialize(): call_deferred("run")
func verify(value: bool,message: String):
	if not value: failures.append(message); push_error(message)

func capture(label: String):
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	var audit=RailAudit.inspect(game.main_view); verify(audit.passed,label+" controls in viewport")
	for node in game.main_view.find_children("*","Label",true,false):
		verify(node.size.y<100,label+" text uses its intended line box: "+node.text)
		verify(Rect2(-1,-1,1922,1082).encloses(node.get_global_rect()),label+" text stays in viewport: "+node.text)
		if node.text in ["W","A","S","D","Shift","Tab","F"]:
			verify(node.get_parent().get_global_rect().grow(2).encloses(node.get_global_rect()),label+" keycap text contained: "+node.text)
	for node in game.main_view.find_children("*","Button",true,false):
		if node is HUDSeal: verify(node.art!=null,label+" solid menu icon loaded: "+node.caption_text)
	var file=output.path_join(label+".png"); surface.get_texture().get_image().save_png(file)
	frames.append({"label":label,"file":file,"size":str(surface.size),"audit":audit})

func run():
	create_timer(90).timeout.connect(func(): push_error("HUD review timed out"); quit(2))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	surface=SubViewport.new(); surface.size_2d_override=Vector2i(1920,1080); surface.size_2d_override_stretch=true; surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(surface)
	game=load("res://scenes/main.tscn").instantiate(); surface.add_child(game); game.capture_mode=true
	await process_frame; game.new_game("warden"); game.session.state.settings.reduce_motion=true
	game.session._add_member("mira",game.db.actors.mira.job,12); game.session.state.active=["hero","mira"]
	game.session.state.members.hero.level=12; game.session.state.day=3; game.toast_clock=0; game.toast_label.text=""
	for id in game.session.state.active:
		var member=game.session.state.members[id]; var stats=PartyMemberState.stats(member,game.session.state,game.db)
		member.hp=stats.max_hp; member.mp=stats.max_mp
	game.world.player=Vector2(30,27); game.world._update_actor(Vector2.ZERO,0); game.world._update_camera(); game.world.set_process(false)
	game.refresh()
	for dimensions in [Vector2i(1672,941),Vector2i(1280,720),Vector2i(1920,1080),Vector2i(3840,2160)]:
		surface.size=dimensions; await capture("two-party-"+str(dimensions.x)+"x"+str(dimensions.y))
	for id in ["toren","eira"]: game.session._add_member(id,game.db.actors[id].job,12)
	game.session.state.active=["hero","mira","toren","eira"]; game.refresh()
	surface.size=Vector2i(1280,720); await capture("four-party-1280x720")
	var file=FileAccess.open(output.path_join("review.json"),FileAccess.WRITE); file.store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"frames":frames},"  ")); file.close()
	print("HUD REFERENCE REVIEW: "+JSON.stringify({"passed":failures.is_empty(),"frames":frames.size(),"failures":failures})); quit(0 if failures.is_empty() else 1)
