extends SceneTree

var surface: SubViewport
var game
var failures=[]
var frames=[]
var output="res://../artifacts/godot/starlit-review"

func _initialize(): call_deferred("run")

func verify(condition: bool, message: String):
	if not condition: failures.append(message); push_error(message)

func make_game():
	game=load("res://scenes/main.tscn").instantiate(); surface.add_child(game); game.capture_mode=true
	await process_frame
	game.new_game("warden"); game.session.state.settings.reduce_motion=true
	for id in ["mira","toren","eira"]: game.session._add_member(id,game.db.actors[id].job,12)
	game.session.state.active=["hero","mira","toren","eira"]
	game.session.state.gold=1280; game.session.state.items={"potion":12,"tonic":8,"revive":3}; game.session.state.members.hero.level=12
	for id in game.session.state.active:
		var member=game.session.state.members[id]; var stats=PartyMemberState.stats(member,game.session.state,game.db)
		member.hp=stats.max_hp; member.mp=stats.max_mp; member.tp=60
	game.refresh(); game.toast_clock=0; game.toast_label.hide(); await process_frame

func shot(label: String):
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	var audit=RailAudit.inspect(game.overlay_root if game.overlay!="" else game.main_view)
	verify(audit.passed,"Layout "+label+": "+str(audit.overflow))
	var file=output.path_join(label+".png"); surface.get_texture().get_image().save_png(file)
	frames.append({"label":label,"file":file,"size":str(surface.size),"audit":audit})

func run():
	create_timer(180).timeout.connect(func(): push_error("Review timed out"); quit(2))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	surface=SubViewport.new(); surface.size_2d_override=Vector2i(1920,1080); surface.size_2d_override_stretch=true; surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(surface)
	for dimensions in [Vector2i(1920,1080),Vector2i(1280,720),Vector2i(3840,2160)]:
		surface.size=dimensions; await make_game()
		var prefix=str(dimensions.x)+"-"
		await shot(prefix+"01-exploration")
		for target in game.world.targets:
			verify(game.world._can_walk(target.point),"Target on walkable ground: "+target.id)
			var destination=Vector2i(roundi(target.point.x),roundi(target.point.y))
			verify(not game.world.grid.get_point_path(Vector2i(30,27),destination).is_empty(),"Reachable target: "+target.id)
			game.world.player=target.point
			verify(game.world._nearest().get("id","")==target.id,"F selects this target independently: "+target.id)
		game.world.player=Vector2(30,27)
		for kind in ["character","inventory","journal","map"]:
			game.open_menu(kind); await shot(prefix+{"character":"02-character","inventory":"03-inventory","journal":"04-quests","map":"05-map"}[kind]); game.close_menu()
		game.session.enter_training("warden",["mira","toren","eira"],12); game.session.start_battle("town-trial-2",417)
		game.session.engine.battle.cursor=game.session.engine.battle.queue.find("hero"); game.mode="battle"; game.refresh()
		await shot(prefix+"06-combat")
		game.queue_free(); await process_frame
	# Detail views and an actual high-resolution overview of the composed town.
	surface.size=Vector2i(1920,1080); await make_game()
	for id in ["sylvi","ridge-scout","alchemist"]: game.session._add_member(id,game.db.actors[id].job,12)
	game.open_menu("character"); await shot("edge-seven-characters"); game.close_menu()
	var original_gear=game.session.state.gear.duplicate(true)
	game.session.state.gear.clear(); game.menus.pages.state("inventory").category="weapon"
	game.open_menu("inventory"); await shot("edge-empty-inventory"); game.close_menu()
	game.session.state.gear=original_gear; game.menus.pages.state("inventory").category="all"
	for item in [["clocktower",Vector2(30,27)],["chapel",Vector2(28,15)],["market",Vector2(22,31)],["inn",Vector2(42,34)]]:
		game.world.player=item[1]; game.world._update_actor(Vector2.ZERO,0); game.world._update_camera(); await shot("detail-"+item[0])
	game.session.state.location={"scene":"town","x":27.0,"y":20.0}; game.world.scene_id=""; game.world.show_location()
	verify(game.world._can_walk(game.world.player) and game.world.player!=Vector2(27,20),"Old save inside new building moves safely")
	verify(game.session.state.location.x==game.world.player.x and game.session.state.location.y==game.world.player.y,"Recovered position matches the next saved location")
	game.world.player=Vector2(30,27); game.world._update_actor(Vector2.ZERO,0)
	game.ui.hide(); game.world.set_process(false); game.world.hero.hide(); game.world.hero_shadow.hide()
	for sprite in game.world.town_visuals: sprite.modulate.a=1
	for target in game.world.targets:
		for child in target.node.get_children():
			if child.has_meta("world_caption"): child.hide()
	surface.size=Vector2i(4096,2500); surface.size_2d_override=Vector2i(4096,2500)
	var bounds=WorldPresentation.bounds("town"); game.world.camera.position=bounds.get_center(); game.world.camera.zoom=Vector2.ONE*4096.0/bounds.size.x
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	surface.get_texture().get_image().save_png(output.path_join("town-overview.png"))
	# Bake only the changed town; all other region and interior overviews remain byte-identical.
	surface.size=Vector2i(2048,1317); surface.size_2d_override=surface.size; game.world.camera.zoom=Vector2.ONE*2048.0/bounds.size.x
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	surface.get_texture().get_image().save_png("res://assets/refined-world/maps/town.png")
	var report={"passed":failures.is_empty(),"failures":failures,"frames":frames,"native4K":true}
	var file=FileAccess.open(output.path_join("review.json"),FileAccess.WRITE); file.store_string(JSON.stringify(report,"  ")); file.close()
	print("STARLIT REVIEW: "+JSON.stringify({"passed":report.passed,"screenshots":frames.size(),"failures":failures})); quit(0 if report.passed else 1)
