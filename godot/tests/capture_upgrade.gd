extends SceneTree

var frames=[]
var failures=[]
var directory=""
var surface: SubViewport
var game

func _initialize(): call_deferred("run")

func find_button(node: Node, text: String) -> Button:
	for child in node.get_children():
		if child is Button and child.text==text: return child
		var result=find_button(child,text)
		if result!=null: return result
	return null

func run():
	create_timer(60).timeout.connect(func(): push_error("Continuity capture timed out"); quit(2))
	directory="res://../artifacts/godot/upgrade-review"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--upgrade-dir="): directory=arg.trim_prefix("--upgrade-dir=")
	DirAccess.make_dir_recursive_absolute(directory)
	surface=SubViewport.new(); surface.size=Vector2i(1280,720); surface.size_2d_override=Vector2i(1920,1080); surface.size_2d_override_stretch=true; surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(surface)
	game=load("res://scenes/main.tscn").instantiate(); surface.add_child(game); game.capture_mode=true
	await process_frame; game.new_game("warden"); game.open_menu("inventory"); await process_frame
	game.open_menu("journal"); await process_frame
	var list=game._scrolls(game.overlay_root)[0].get_child(0)
	var journal_background=game.overlay_root.get_child(0)
	for index in 6:
		click(list.get_child(index).get_global_rect().get_center())
		if list.get_children().filter(func(n): return n.get_meta("selected",false)).size()!=1: failures.append("Multiple journal selections")
		await capture_frames("journal-"+str(index),game.overlay_root,journal_background)
	game.open_menu("inventory"); await process_frame
	var background=game.overlay_root.get_child(0)
	for index in 6:
		var text="消耗品" if index%2==0 else "全部物品"
		var button=find_button(game.overlay_root,text)
		click(button.get_global_rect().get_center())
		await capture_frames("category-"+str(index),game.overlay_root,background)
	for index in 4:
		var grid=game.overlay_root.find_children("*","GridContainer",true,false)[0]
		click(grid.get_child(index).get_global_rect().get_center())
		await capture_frames("item-"+str(index),game.overlay_root,background)
	for id in ["mira","toren","sylvi","ridge-scout","eira","alchemist"]:
		if not game.session.state.members.has(id): game.session._add_member(id,game.db.actors[id].job,6)
	game.open_menu("character"); await process_frame; background=game.overlay_root.get_child(0)
	for id in game.session.state.members:
		click(find_button(game.overlay_root,game.db.actors[id].display_name).get_global_rect().get_center())
		await capture_frames("character-"+id,game.overlay_root,background)
	game.open_menu("skills"); await process_frame; background=game.overlay_root.get_child(0)
	var skills=game.db.job_skills(game.session.state.members.hero.job)
	for skill_id in skills.slice(0,4):
		var found: Button
		for node in game.overlay_root.find_children("*","Button",true,false):
			if game.db.skills[skill_id].display_name in node.text: found=node; break
		click(found.get_global_rect().get_center()); await capture_frames("skill-"+skill_id,game.overlay_root,background)
	game.open_menu("map"); await process_frame; background=game.overlay_root.get_child(0)
	for building in game.db.raw.buildings.slice(0,3):
		var map=game.overlay_root.find_children("*","Control",true,false).filter(func(n): return n is RailMap)[0]
		click(map.global_position+map.project(Vector2(building.x+building.w/2,building.y+building.d/2)))
		await capture_frames("map-"+building.id,game.overlay_root,background)
	game.session.state.affinity.mira.value=30
	game.open_menu("topic","mira|past"); var dialogue=game.overlay_root.get_child(0); background=dialogue.get_child(0)
	while dialogue.page_index<dialogue.pages.size()-1: dialogue.advance(); dialogue.advance()
	dialogue.advance(); await process_frame
	click(dialogue.choice_buttons[0].get_global_rect().get_center())
	await capture_frames("dialogue-reply",dialogue,background)
	game.close_menu(); game.session.enter_training("warden",["mira","eira","ridge-scout"],6); game.session.start_battle("town-trial-2",417)
	while game.session.engine.current().team!="ally": game.session.engine.submit(game.session.engine.ai_command())
	game.mode="battle"; game.focused=false; game.refresh(); await process_frame; background=game.main_view.get_child(0)
	for skill_id in game.session.engine.current().skills:
		for node in game.main_view.find_children("*","Button",true,false):
			if game.db.skills[skill_id].display_name in node.text:
				click(node.get_global_rect().get_center()); break
		await capture_frames("battle-"+skill_id,game.main_view,background)
	click(find_button(game.main_view,"普攻").get_global_rect().get_center()); await process_frame
	var target=game.main_view.find_children("*","Button",true,false).filter(func(n): return n.tooltip_text.begins_with("生命 "))[0]
	click(target.get_global_rect().get_center()); await capture_frames("battle-target",game.main_view,background)
	var report={"passed":failures.is_empty(),"frames":frames,"failures":failures}
	var file=FileAccess.open(directory.path_join("click-continuity.json"),FileAccess.WRITE); file.store_string(JSON.stringify(report,"  ")); file.close()
	print("CLICK CONTINUITY: "+JSON.stringify({"passed":report.passed,"frames":frames.size(),"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func click(point: Vector2):
	var event=InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT; event.position=point; event.pressed=true; surface.push_input(event,true)
	event=event.duplicate(); event.pressed=false; surface.push_input(event,true)

func capture_frames(label: String, live: Node, background: Node):
	for frame in 3:
		await RenderingServer.frame_post_draw
		var passed=live.modulate.a==1 and live.get_child(0)==background and background.is_visible_in_tree()
		if not passed: failures.append("Blank background during "+label)
		var file=directory.path_join("click-"+label+"-"+str(frame)+".png"); surface.get_texture().get_image().save_png(file)
		frames.append({"click":label,"frame":frame,"file":file,"opaqueBackground":passed})
