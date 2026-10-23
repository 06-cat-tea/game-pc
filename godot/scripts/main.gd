extends Control

var db: GameContent
var session: GameSession
var store: SaveStore
var world: WorldView
var ui: Control
var main_view: Control
var overlay_root: Control
var toast_label: Label
var menus: GameMenus
var battle_view: BattleView
var mode = "title"
var overlay = ""
var pending_action = "attack"
var pending_skill = ""
var selected_target = ""
var paused = false
var focused = true
var resolving = false
var action_cooldown = 0.0
var last_events = []
var needs_refresh = false
var ai_clock = 0.0
var autosave_clock = 0.0
var toast_clock = 0.0
var hint = "WASD 移动 · Shift 奔跑"
var capture_mode = false
var capture_args = {}
var hud_hint: Label
var wheel_open = false
var quick_wheel: QuickWheel
var rail_hud: RailHUD
var menu_subject="hero"
var navigation=[]
var scroll_memory={}
var message_back={}
var rendered_mode=""
var combat_effects: CombatEffects
var battle_end_pending=false
var loading: LoadingScreen
var presented_battle_id=""

func _ready():
	_parse_args()
	_install_input()
	loading=LoadingScreen.new(); add_child(loading); loading.setup(self)
	db = GameContent.new(); session = GameSession.new(db); store = SaveStore.new(session)
	world = WorldView.new(); add_child(world); world.setup(db,session); world.visible = false
	world.interacted.connect(_interact); world.position_changed.connect(func(x,y): session.state.location.x=x; session.state.location.y=y)
	world.hint_changed.connect(func(text): hint=text; if is_instance_valid(hud_hint): hud_hint.text=text)
	var layer = CanvasLayer.new(); add_child(layer)
	ui = Control.new(); ui.theme = UIkit.theme(); UIkit.fill(ui); ui.mouse_filter = Control.MOUSE_FILTER_IGNORE; layer.add_child(ui)
	main_view = Control.new(); UIkit.fill(main_view); main_view.mouse_filter = Control.MOUSE_FILTER_IGNORE; ui.add_child(main_view)
	combat_effects=CombatEffects.new(); ui.add_child(combat_effects); combat_effects.setup(self)
	overlay_root = Control.new(); UIkit.fill(overlay_root); overlay_root.mouse_filter = Control.MOUSE_FILTER_IGNORE; ui.add_child(overlay_root)
	toast_label = Label.new(); toast_label.position = Vector2(540,134); toast_label.size = Vector2(840,90); toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; toast_label.add_theme_color_override("font_color",UIkit.GOLD); toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE; ui.add_child(toast_label)
	menus = GameMenus.new(self); battle_view = BattleView.new(self); rail_hud=RailHUD.new(self)
	session.changed.connect(_session_changed)
	get_tree().auto_accept_quit = false
	if OS.has_feature("editor") and OS.get_environment("ASHEN_DEV_BRIDGE")=="1" and ResourceLoader.exists("res://addons/godot-mcp/runtime_bridge.gd"):
		var bridge=load("res://addons/godot-mcp/runtime_bridge.gd").new()
		bridge.name="godot_mcp_runtime"; get_tree().root.add_child.call_deferred(bridge)
	refresh()
	if capture_mode: call_deferred("_capture_demo")

func _parse_args():
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="): capture_mode=true; capture_args.path=argument.trim_prefix("--capture=")
		elif argument.begins_with("--view="): capture_args.view=argument.trim_prefix("--view=")
		elif argument.begins_with("--smoke="): capture_mode=true; capture_args.smoke=argument.trim_prefix("--smoke=")
		elif argument.begins_with("--capture-size="):
			var dimensions=argument.trim_prefix("--capture-size=").split("x")
			capture_args.capture_size=Vector2i(int(dimensions[0]),int(dimensions[1]))

func _install_input():
	GameBindings.install()

func clear(node: Node):
	for child in node.get_children(): node.remove_child(child); child.queue_free()

func background(parent: Node, path: String, opacity: float = 0.6):
	var art = TextureRect.new(); art.texture = load(path); art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED; UIkit.fill(art); art.mouse_filter=Control.MOUSE_FILTER_IGNORE; parent.add_child(art)
	var shade = ColorRect.new(); shade.color=Color(0.015,0.025,0.045,opacity); UIkit.fill(shade); shade.mouse_filter=Control.MOUSE_FILTER_IGNORE; parent.add_child(shade)

func refresh():
	if loading!=null and loading.busy and not loading.committing: needs_refresh=true; return
	if mode != "title" and not session.state.is_empty(): mode="battle" if session.state.battle != null else "world"
	if battle_end_pending: mode="battle"
	if mode=="battle" and rendered_mode!="battle": combat_effects.reset()
	var retain_battle=mode=="battle" and rendered_mode=="battle" and main_view.get_child_count()>0
	if not retain_battle: clear(main_view); hud_hint=null
	world.visible = mode == "world"
	world.blocked = mode != "world" or overlay != "" or paused or not focused or (loading!=null and loading.busy)
	if mode == "title": _title()
	elif mode == "battle":
		if retain_battle:
			var staging=Control.new(); staging.visible=false; staging.size=main_view.size; ui.add_child(staging)
			battle_view.build(staging); UIReconciler.update_children(main_view,staging); staging.queue_free()
		else: battle_view.build(main_view)
	else:
		world.show_location()
		_world_hud()
	needs_refresh=false; rendered_mode=mode

func _title():
	rail_hud.title(main_view)

func new_game(job: String):
	session.new_game(job); _sync_region_map(); mode="world"; close_menu(); refresh()
	toast("先到钟塔结识米拉，或到礼拜堂接受艾拉的同行委托。")

func continue_game(slot: int = 0):
	var error = store.load_slot(slot)
	if error != "": toast(error); return
	_sync_region_map(); mode="world"; close_menu(); refresh(); toast("旅程已载入。")

func _sync_region_map():
	var scene_id=session.state.location.scene
	menus.pages.state("map").region=db.place_of(scene_id)
	menus.pages.state("map").category="region" if db.is_outdoor(scene_id) else "current"
	menus.pages.state("map").selection=""

func _world_hud():
	rail_hud.world(main_view)

func _session_changed():
	if not capture_mode and not store.import_in_progress and not session.state.is_empty() and not session.state.training:
		var error=store.save(0)
		if error != "": toast(error)
	needs_refresh=true
	if session.state.get("battle")!=null:
		var instance_id=str(session.state.battle.get("instance_id",""))
		if instance_id!=presented_battle_id:
			presented_battle_id=instance_id
			if not capture_mode and not loading.busy:
				loading.run("battle",func():
					mode="battle"; selected_target=""; pending_action="attack"; pending_skill=""; close_menu(); refresh(); return "")

func open_menu(kind: String, subject: String = "hero"):
	if overlay!="" and overlay!=kind and overlay not in ["wheel","message","confirm"]: push_current_menu()
	replace_menu(kind,subject)

func push_current_menu():
	remember_scroll()
	if overlay!="" and overlay not in ["wheel","message","confirm"]: navigation.append({"kind":overlay,"subject":menu_subject})

func replace_menu(kind: String, subject: String = "hero"):
	if overlay==kind and kind!="wheel": refresh_menu(kind,subject); return
	remember_scroll()
	if not navigation.is_empty() and navigation[-1].kind==kind and navigation[-1].subject==subject: navigation.pop_back()
	wheel_open=false; quick_wheel=null
	var retain_dialogue=kind in ["npc","topic"] and overlay in ["npc","topic","message"]
	world.stop(); overlay=kind; menu_subject=subject; message_back={}; world.blocked=true
	if not retain_dialogue: clear(overlay_root)
	overlay_root.mouse_filter=Control.MOUSE_FILTER_STOP; menus.open(kind,subject)
	main_view.visible=kind=="wheel"
	_restore_scroll.call_deferred(kind+"|"+subject)
	_focus_menu.call_deferred()
	UIkit.enter(overlay_root,true)

func refresh_menu(kind: String = "", subject: String = "hero"):
	if kind=="": kind=overlay; subject=menu_subject
	if overlay!=kind: replace_menu(kind,subject); return
	if kind in ["npc","topic"]:
		menu_subject=subject; menus.open(kind,subject); return
	remember_scroll()
	var live=overlay_root
	var focus=get_viewport().gui_get_focus_owner()
	var staging=Control.new(); staging.visible=false; staging.size=live.size; ui.add_child(staging)
	menu_subject=subject; overlay_root=staging
	menus.open(kind,subject)
	overlay_root=live
	UIReconciler.update_children(live,staging); staging.queue_free()
	UIkit.enter(live,true)
	_restore_scroll.call_deferred(kind+"|"+subject)
	if not is_instance_valid(focus) or not live.is_ancestor_of(focus): _focus_menu.call_deferred()

func _scrolls(node: Node) -> Array:
	var result=[]
	for child in node.get_children():
		if child is ScrollContainer: result.append(child)
		result.append_array(_scrolls(child))
	return result

func remember_scroll():
	if overlay=="": return
	scroll_memory[overlay+"|"+menu_subject]=_scrolls(overlay_root).map(func(node): return node.scroll_vertical)

func _restore_scroll(key: String):
	if key!=overlay+"|"+menu_subject: return
	var nodes=_scrolls(overlay_root); var offsets=scroll_memory.get(key,[])
	for i in mini(nodes.size(),offsets.size()): nodes[i].set_deferred("scroll_vertical",offsets[i])

func _focusables(node: Node) -> Array:
	var result=[]
	for child in node.get_children():
		if child is Control and child.is_visible_in_tree() and child.focus_mode==Control.FOCUS_ALL and (not child is BaseButton or not child.disabled): result.append(child)
		result.append_array(_focusables(child))
	return result

func _focus_menu():
	if overlay=="": return
	if overlay=="wheel": get_viewport().gui_release_focus(); return
	for child in overlay_root.get_children():
		if child is RailDialogue: child.grab_focus(); return
	var nodes=_focusables(overlay_root)
	for node in nodes:
		if node.has_meta("default_focus"): node.grab_focus(); return
	if not nodes.is_empty(): nodes[0].grab_focus()

func _cycle_focus(reverse: bool):
	var nodes=_focusables(overlay_root)
	if nodes.is_empty(): return
	var index=nodes.find(get_viewport().gui_get_focus_owner())
	index=posmod(index+(-1 if reverse else 1),nodes.size())
	nodes[index].grab_focus()

func back_menu():
	if overlay=="message" and not message_back.is_empty():
		var back=message_back.duplicate(); replace_menu(back.kind,back.subject); return
	if not navigation.is_empty():
		var back=navigation.pop_back(); replace_menu(back.kind,back.subject)
	else: close_menu()

func close_menu():
	remember_scroll(); overlay=""; wheel_open=false; quick_wheel=null; navigation=[]; message_back={}; clear(overlay_root); overlay_root.mouse_filter=Control.MOUSE_FILTER_IGNORE; main_view.visible=true; UIkit.enter(overlay_root,true); world.blocked=paused or not focused or mode!="world" or (loading!=null and loading.busy); needs_refresh=true

func message(title: String, text: String, back: String = "", subject: String = "hero", mood: String = "neutral"):
	remember_scroll(); overlay="message"; world.blocked=true; world.stop(); overlay_root.mouse_filter=Control.MOUSE_FILTER_STOP
	main_view.visible=false
	message_back={"kind":back,"subject":subject} if back!="" else {}
	var dialogue=show_dialogue(title,db.art("portraits",subject,mood),[text],[],func(_index): pass)
	dialogue.grab_focus()

func show_dialogue(speaker: String, portrait: String, lines: Array, options: Array, callback: Callable) -> RailDialogue:
	for child in overlay_root.get_children():
		if child is RailDialogue:
			child.update_content(speaker,portrait,lines,options,callback); return child
	clear(overlay_root)
	var dialogue=RailDialogue.new(); overlay_root.add_child(dialogue)
	dialogue.setup(self,speaker,portrait,lines,options,callback)
	return dialogue

func toast(text: String):
	if toast_label == null: return
	toast_label.text=text; toast_clock=4.5

func navigate(scene_id: String):
	var error=session.visit(scene_id)
	if error != "": toast(error); return
	if db.is_outdoor(scene_id):
		menus.pages.state("map").region=scene_id; menus.pages.state("map").category="region"; menus.pages.state("map").selection=""
	world.scene_id=""; close_menu(); mode="world"; refresh()

func travel_to(scene_id: String):
	var key=scene_id if db.is_outdoor(scene_id) else "ruins"
	return await loading.run(key,func():
		var error=session.visit(scene_id)
		if error!="": return error
		if db.is_outdoor(scene_id):
			menus.pages.state("map").region=scene_id; menus.pages.state("map").category="region"; menus.pages.state("map").selection=""
		world.scene_id=""; close_menu(); mode="world"; refresh(); world.blocked=true
		return "")

func load_new_game(job: String):
	return await loading.run("departure",func(): new_game(job); world.blocked=true; return "")

func load_continue(slot: int = 0):
	return await loading.run("departure",func():
		var error=store.load_slot(slot)
		if error!="": return error
		_sync_region_map(); mode="world"; close_menu(); refresh(); world.blocked=true
		return "")

func load_encounter(id: String):
	return await loading.run("battle",func():
		var error=session.start_battle(id)
		if error!="": return error
		mode="battle"; selected_target=""; pending_action="attack"; pending_skill=""; close_menu(); refresh(); return "")

func rest_with_loading():
	return await loading.run("camp",func():
		var before=int(session.state.supplies); var message_text=session.rest()
		if int(session.state.supplies)==before: return message_text
		close_menu(); refresh(); world.blocked=true; toast(message_text); return "")

func _interact(kind: String, id: String):
	world.stop()
	if kind == "entrance": open_menu("entrance",id)
	elif kind == "town-life": open_menu("town-life",id)
	elif kind == "building": open_menu("building",id)
	elif kind == "npc": session.chat(id); open_menu("npc",id)
	elif kind == "exit": travel_to(id)
	elif kind == "travel": travel_to(id)
	elif kind == "landmark":
		menus.pages.state("map").region=world.scene_id; menus.pages.state("map").selection=id; menus.pages.state("map").category="region"; open_menu("map")
	elif kind == "prop":
		if id=="noticeboard" and session.state.location.scene=="room-guildhall": open_menu("commission-board"); return
		var scene_id=session.state.location.scene
		for prop in session.progression.scene_props(scene_id):
			if prop.id != id: continue
			match prop.get("action","service"):
				"encounter": open_menu("encounters",scene_id)
				"event": open_menu("event",scene_id)
				"portal":
					var routes=db.route_ids(db.place_of(scene_id)); var index=routes.find(scene_id)
					if index>=0 and index<2: travel_to(routes[index+1])
				_:
					var text=session.inspect_prop(scene_id,prop)
					if prop.has("awakening"): world.scene_id=""
					if prop.has("building"): open_menu("building-service",prop.building)
					else: message(prop.name,text,"",str(prop.get("awakening","hero")),"serious" if prop.has("awakening") else "neutral")

func seek(scene: String, kind: String, id: String):
	if session.state.battle!=null or session.state.training: toast("请先结束战斗或训练。"); return
	if session.state.location.scene!=scene:
		var error=await travel_to(scene)
		if error!="": toast(error); return
	close_menu(); refresh()
	for target in world.targets:
		if target.kind==kind and target.id==id: world.navigate(target.point,target); return
	toast("已抵达目标所在场景。")

func start_encounter(id: String):
	var error=session.start_battle(id)
	if error != "": toast(error); return
	mode="battle"; selected_target=""; pending_action="attack"; pending_skill=""; close_menu(); refresh()

func choose_action(action: String, skill: String = ""):
	pending_action=action; pending_skill=skill
	var actor=session.engine.current()
	if actor.is_empty(): return
	var targets=session.engine.legal_targets(actor,action,skill)
	if action == "swap": targets=targets.filter(func(candidate): return candidate.id != actor.id)
	if not targets.any(func(candidate): return candidate.id == selected_target): selected_target=targets[0].id if not targets.is_empty() else ""
	refresh()

func perform():
	if resolving or action_cooldown>0 or paused or session.state.battle == null: return
	var actor=session.engine.current()
	if actor.is_empty() or actor.team != "ally": return
	var command=BattleCommand.new(actor.id,pending_action,selected_target,pending_skill,session.engine.battle.token).to_dict()
	var error=session.engine.validate(command)
	if error != "": toast(error); return
	var anchors=_fighter_anchors()
	resolving=true
	var result=session.combat(command)
	if result.error != "": toast(result.error)
	else:
		pending_action="attack"; pending_skill=""; selected_target=""; ai_clock=0.0
		last_events=result.events; action_cooldown=combat_effects.play(result.events,anchors,session.state.settings.reduce_motion)
		battle_end_pending=session.state.battle==null
	resolving=false
	if not battle_end_pending: refresh()
	if battle_end_pending and action_cooldown==0: _finish_battle_presentation()

func _fighter_anchors() -> Dictionary:
	var anchors={}
	for node in main_view.find_children("*","TextureRect",true,false):
		if node.has_meta("fighter_id"): anchors[str(node.get_meta("fighter_id"))]=node.get_global_rect().get_center()
	return anchors

func _finish_battle_presentation():
	battle_end_pending=false
	var id=session.progression.trial_actor
	var text=session.progression.finish_trial() if id!="" else session.last_message
	if id!="": world.scene_id=""
	refresh()
	message("觉醒试炼" if id!="" else "战斗结束",text,"awakening" if id!="" else "",id if id!="" else "hero")

func exit_training():
	action_cooldown=0; battle_end_pending=false; paused=false; last_events=[]; combat_effects.reset()
	session.exit_training(); world.scene_id=""; close_menu(); refresh(); toast("已返回剧情进度，训练没有消耗物资。")

func _process(delta: float):
	if session==null or (loading!=null and loading.busy): return
	if toast_clock>0: toast_clock-=delta; if toast_clock<=0: toast_label.text=""
	if action_cooldown>0 and not paused:
		action_cooldown=maxf(0,action_cooldown-delta)
		if action_cooldown==0:
			last_events=[]; needs_refresh=true
			if battle_end_pending: _finish_battle_presentation()
	if needs_refresh and overlay == "" and action_cooldown==0: refresh()
	if mode == "world" and overlay == "" and not paused:
		autosave_clock+=delta
		if autosave_clock>2.0:
			autosave_clock=0
			if not capture_mode and not session.state.training: store.save(0)
	if mode == "battle" and overlay == "" and not paused and focused and not resolving and action_cooldown==0 and session.state.battle != null:
		var actor=session.engine.current()
		if actor.is_empty(): return
		if actor.team == "enemy" or actor.get("auto",false):
			ai_clock+=delta
			if ai_clock >= (0.15 if session.state.settings.reduce_motion else 0.65):
				var anchors=_fighter_anchors()
				ai_clock=0; resolving=true
				var result=session.combat(session.engine.ai_command())
				resolving=false
				if result.error != "": paused=true; toast(result.error)
				else:
					last_events=result.events; action_cooldown=combat_effects.play(result.events,anchors,session.state.settings.reduce_motion); battle_end_pending=session.state.battle==null
				if not battle_end_pending: refresh()

func _input(event: InputEvent):
	if loading!=null and loading.busy:
		if loading.failed:
			if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE: loading.complete(); get_viewport().set_input_as_handled()
		else: get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.echo:
		if overlay=="wheel": get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and focused:
		var focus=get_viewport().gui_get_focus_owner()
		var typing=focus is LineEdit or focus is TextEdit
		var key=GameBindings.key(event)
		if not typing and overlay not in ["message","confirm","npc","topic","wheel"] and mode=="world" and GameBindings.MENUS.has(key):
			var kind=GameBindings.MENUS[key]
			if overlay==kind: close_menu()
			else: open_menu(kind)
			get_viewport().set_input_as_handled(); return
	if overlay=="wheel" and is_instance_valid(quick_wheel) and event is InputEventMouseMotion:
		quick_wheel.track_pointer(event); get_viewport().set_input_as_handled(); return
	if event is InputEventKey and event.pressed and event.keycode==KEY_TAB and overlay!="" and overlay!="wheel":
		_cycle_focus(event.shift_pressed); get_viewport().set_input_as_handled(); return
	if event.is_action_pressed("wheel") and mode == "world" and overlay == "" and not paused and focused:
		open_menu("wheel"); wheel_open=true; quick_wheel.begin_hold(); get_viewport().set_input_as_handled(); return
	elif event.is_action_released("wheel") and wheel_open:
		var selected=quick_wheel.take_selection() if is_instance_valid(quick_wheel) else -1
		close_menu()
		if selected>=0: menus.wheel_action(selected)
		get_viewport().set_input_as_handled(); return
	if overlay=="wheel":
		if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE: close_menu()
		get_viewport().set_input_as_handled(); return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if overlay != "": back_menu()
		elif mode == "battle": paused=not paused; refresh()
		elif mode == "world": open_menu("terminal")
		get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and mode == "battle" and overlay == "" and not paused:
		if action_cooldown>0: get_viewport().set_input_as_handled(); return
		var actor=session.engine.current()
		if actor.is_empty() or actor.team != "ally": return
		if GameBindings.matches(event,"confirm"): perform(); get_viewport().set_input_as_handled()
		elif GameBindings.matches(event,"ultimate"): choose_action("ultimate",actor.id); get_viewport().set_input_as_handled()
		elif GameBindings.matches(event,"default_skill") and not actor.skills.is_empty(): choose_action("ability",actor.skills[0]); get_viewport().set_input_as_handled()
		elif event.keycode>=KEY_1 and event.keycode<=KEY_4:
			var index=event.keycode-KEY_1
			if index<actor.skills.size(): choose_action("ability",actor.skills[index]); get_viewport().set_input_as_handled()

func _notification(what: int):
	if capture_args.has("path") and what in [NOTIFICATION_WM_WINDOW_FOCUS_OUT,NOTIFICATION_WM_WINDOW_FOCUS_IN]: return
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		focused=false
		if world != null: world.stop(); world.blocked=true
		for action in ["move_left","move_right","move_up","move_down","run"]: Input.action_release(action)
		if mode == "battle": paused=true; needs_refresh=true
		if overlay=="wheel": close_menu()
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		focused=true
		if world != null: world.blocked=paused or overlay!="" or (loading!=null and loading.busy)
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		if store != null and not capture_mode and not session.state.is_empty() and not session.state.training: store.save(0)
		get_tree().quit()

func _capture_demo():
	var view=capture_args.get("view","title")
	if view != "title":
		session.new_game("warden"); session.state.gold=999
		for e in db.world_interactions.entrances: session.tasks.ledger.entrances.append(e.id)
		session.state.knowledge=1; session.recruit("mira"); session.state.personal.eira={"stage":2,"done":true}; session.recruit("eira")
		mode="world"
		if view.begins_with("portrait-") or view.begins_with("expression-") or view.begins_with("awakening-") or view.begins_with("effect-"):
			for id in db.actors:
				if not session.state.members.has(id): session._add_member(id,db.actors[id].job,6)
		if view.begins_with("battle") or view.begins_with("effect-"):
			var team=["mira","eira","ridge-scout"]
			if view=="battle-strategy": team=["mira","toren","eira"]
			if view.begins_with("effect-") and view.trim_prefix("effect-")!="hero": team=[view.trim_prefix("effect-"),"mira" if view!="effect-mira" else "toren","eira" if view!="effect-eira" else "sylvi"]
			session.enter_training("warden",team,6); session.start_battle("town-trial-2",417); paused=false; mode="battle"
			if view=="battle-strategy":
				session.engine.start(session.state,"boss-wood",417,true); session.state.battle=session.engine.battle
				session.engine.battle.cursor=session.engine.battle.queue.find("hero")
				session.engine.grant_shield(session.engine.unit("hero"),45,2,"同袍壁垒",true,"toren:bond")
			if view.begins_with("effect-"): session.engine.battle.cursor=session.engine.battle.queue.find(view.trim_prefix("effect-"))
			if view == "battle-six":
				var boss=session.engine.unit("enemy-0"); boss.phase=2; boss.intent={"kind":"summon","target":"hero","label":"召唤","power":1.0}
				for i in 3: session.engine._enemy_action(boss)
				session.engine._begin_round(); session.engine._prepare_turn()
		elif view in ["room","map-room"]: session.visit("room-chapel")
		elif view in ["route-wall","route-drain","route-trial","map-route"]:
			session.state.scene_progress["town-wall:survey"]=true; session.state.scene_progress["town-drain:survey"]=true
			session.visit({"route-wall":"town-wall","route-drain":"town-drain","route-trial":"town-trial","map-route":"town-wall"}[view])
		elif view.begins_with("region-") or view.begins_with("landmark-") or view.begins_with("atlas-"):
			var id=str(view).get_slice("-",1); session.visit(id)
			if view.begins_with("landmark-"):
				for building in db.regions[id].buildings:
					if building.id==db.regions[id].landmark: session.state.location.x=building.entry[0]; session.state.location.y=building.entry[1]; break
		elif view.begins_with("content-room-"):
			var id=view.trim_prefix("content-room-")
			for route in db.route_ids(db.place_of(id)): session.state.scene_progress[route+":survey"]=true
			session.visit(id)
		elif view.begins_with("awakening-") and view!="awakening-log":
			var id=view.trim_prefix("awakening-"); session.state.chapter_complete=true
			if id!="hero": session.state.personal[id]={"stage":2,"done":true}
			for route in db.route_ids(db.place_of(db.progression.ultimates[id].scene)): session.state.scene_progress[route+":survey"]=true
			session.visit(db.progression.ultimates[id].scene); session.state.story.awakenings[id]={"stage":2,"clues":[0,1]}
		elif view.begins_with("building-site-"):
			var scene=db.progression.buildings[view.trim_prefix("building-site-")].scene
			for route in db.route_ids(db.place_of(scene)): session.state.scene_progress[route+":survey"]=true
			session.visit(scene)
		elif view=="room-observatory": session.visit("room-city-academy-3")
		elif view=="room-archive": session.visit("room-city-faith-3")
		elif view in ["content-npc","content-deep","content-journal","content-lore","content-people","content-achievements","content-ending","content-city-room","content-actions","content-event","content-battle","content-service"]:
			if view=="content-city-room": session.visit("room-city-palace-0")
			elif view in ["content-npc","content-deep"]: session.visit("coast"); session.state.affinity.lian.value=60
			elif view in ["content-actions","content-event"]: session.visit("wood")
			elif view=="content-battle": session.visit("fen"); session.start_battle("activity-temple",417); mode="battle"
			elif view=="content-service": session.visit("coast")
			session.state.chapter_complete=true; session.state.story.stage=8
			if view=="content-ending": session.state.story.events.epilogue=true
		if view in ["quest-board","quest-journal","quest-archive"]:
			session.visit("room-guildhall"); session.tasks.accept("first","board"); session.state.quests.first.progress=1
			session.tasks.accept("service:guildhall","board"); session.state.materials.herb=3
			session.tasks.accept("guild-ore","board"); session.state.materials.ore=2; session.tasks.turn_in("guild-ore","board")
			session.tasks.accept("resident:cat","board"); session.tasks.ledger.records["resident:cat"].stage=1
		elif view in ["town-life","town-life-night"]: session.state.location={"scene":"town","x":24.0,"y":30.0}; session.state.phase=3 if view=="town-life-night" else 0
		elif view=="quest-entrance": session.state.location={"scene":"town","x":22.5,"y":14.0}; session.state.scene_progress["town-wall:survey"]=true
		elif view in ["child-luo","child-aya","child-ling"]: session.visit("town")
		refresh()
		if view=="quest-board": open_menu("commission-board")
		elif view in ["quest-journal","quest-archive"]:
			menus.pages.state("journal").show_completed=view=="quest-archive"; open_menu("journal")
		elif view=="quest-entrance": open_menu("entrance","entrance-town-drain")
		elif view.begins_with("child-"): open_menu("npc","kid-"+view.trim_prefix("child-"))
		elif view.begins_with("portrait-"): open_menu("character",view.trim_prefix("portrait-"))
		elif view.begins_with("awakening-"): open_menu("awakening",view.trim_prefix("awakening-"))
		elif view.begins_with("building-site-"): open_menu("building-service",view.trim_prefix("building-site-"))
		elif view in ["awakening-log","building-log"]: open_menu(view)
		elif view.begins_with("effect-"): choose_action("ultimate",session.engine.current().id); perform()
		elif view.begins_with("expression-"):
			var detail=str(view).trim_prefix("expression-"); var mood=str(detail).get_slice("|",1); var id=str(detail).get_slice("|",0)
			message(db.actors[id].display_name,"在钟声与雾中，寻找归路。","",id,mood)
		elif menus.pages.NAMES.has(view): open_menu(view)
		elif view.begins_with("atlas-"):
			menus.pages.state("map").region=str(view).get_slice("-",1); menus.pages.state("map").category="region"; open_menu("map")
		elif view in ["map-room","map-route"]:
			menus.pages.state("map").category="current"; open_menu("map")
		elif view=="dialogue": open_menu("npc","mira")
		elif view=="content-npc": open_menu("npc","lian")
		elif view=="content-deep": open_menu("topic","lian|past")
		elif view=="content-journal": open_menu("journal")
		elif view in ["content-lore","content-people","content-achievements"]: open_menu(view.trim_prefix("content-"))
		elif view=="content-actions": open_menu("region-actions")
		elif view=="content-service": open_menu("local-service","world:harbor-trade")
		elif view=="content-event": open_menu("region-event","wood-deer")
		elif view=="content-ending": message("归灯之后","收尾任务「归灯之后」完成。五地的名字重新写入星图，钟声终于有了归处。")
		elif view=="topic": open_menu("topic","mira|past")
		elif view=="building": open_menu("building","inn")
		elif view=="actions": open_menu("actions")
		elif view=="event": open_menu("event","town-wall")
		elif view=="encounters": open_menu("encounters","town-wall")
		elif view in ["wheel","wheel-selected"]:
			open_menu("wheel")
			if view=="wheel-selected": quick_wheel.select_at(quick_wheel.center()+Vector2(0,-200))
	if view.begins_with("loading-"): loading.begin(view.trim_prefix("loading-"),"正在准备场景资源")
	await get_tree().process_frame
	await get_tree().process_frame
	if capture_args.has("path"): await get_tree().create_timer(.32 if view.begins_with("effect-") else .7).timeout
	if view in ["dialogue","topic","content-npc","content-deep","content-ending"]:
		for child in overlay_root.get_children():
			if child is RailDialogue:
				while child.page_index<child.pages.size()-1: child.advance(); child.advance()
				child.advance()
	if capture_args.has("smoke"):
		var report={"mode":mode,"scene":session.state.get("location",{}).get("scene","title"),"ui_nodes":ui.get_child_count(),"editor_binary":OS.has_feature("editor"),"dev_plugin_included":ResourceLoader.exists("res://addons/godot-mcp/plugin.gd"),"test_sources_included":ResourceLoader.exists("res://tests/test_suite.gd"),"authoring_included":FileAccess.file_exists("res://authoring/rocks/rock1.obj"),"refined_map_included":ResourceLoader.exists("res://assets/refined-world/maps/town.png"),"cc0_notice_included":FileAccess.file_exists("res://LICENSE-ThirdParty-CC0.txt"),"passed":true}
		report.region_count=db.regions.size(); report.regional_maps_included=db.regions.keys().all(func(id): return ResourceLoader.exists("res://assets/refined-world/maps/"+id+".png"))
		report.content_counts={"npcs":db.raw.npcs.size(),"scenes":db.raw.scenes.size(),"lore":db.narrative.lore.size()}; report.content_maps=db.raw.scenes.keys().all(func(id): return ResourceLoader.exists("res://assets/refined-world/maps/"+id+".png"))
		report.brand_logo_included=ResourceLoader.exists("res://assets/ui/branding/logo.svg")
		report.native_icon_included=FileAccess.file_exists("res://assets/ui/branding/logo.ico")
		report.progression={"ultimates":db.progression.ultimates.size(),"buildings":db.progression.buildings.size(),"rooms":db.progression.rooms.size(),"emblems":db.progression.ultimates.keys().all(func(id): return ResourceLoader.exists("res://assets/ui/icons/ultimate-"+id+".svg"))}
		report.quests={"catalog":db.quest_catalog.tasks.size(),"entrances":db.world_interactions.entrances.size(),"children":db.world_interactions.children.size(),"animals":db.world_interactions.animals.size(),"resources":db.world_interactions.resources.size()}
		report.strategy={"rules_version":int(BattleRules.config().version),"loading_count":loading.config.images.size(),"loading_included":loading.config.images.values().all(func(entry): return ResourceLoader.exists(entry.path)),"icons_included":ItemIcons.catalog.get("icons",{}).values().all(func(entry): return ResourceLoader.exists(entry.path)),"icon_license_included":FileAccess.file_exists("res://LICENSE-Icons-CC-BY-3.0.txt")}
		report.passed=report.strategy.loading_count==10 and report.strategy.loading_included and report.strategy.icons_included and report.strategy.icon_license_included
		var file=FileAccess.open(capture_args.smoke,FileAccess.WRITE); file.store_string(JSON.stringify(report)); file.close()
	if capture_args.has("path"):
		await RenderingServer.frame_post_draw
		var rendered=get_viewport().get_texture().get_image()
		var requested=capture_args.get("capture_size",rendered.get_size())
		var output=rendered
		if requested!=rendered.get_size():
			output=Image.create(requested.x,requested.y,false,rendered.get_format()); output.fill(Color.BLACK)
			output.blit_rect(rendered,Rect2i(Vector2i.ZERO,rendered.get_size()),Vector2i((requested-rendered.get_size())/2))
		output.save_png(capture_args.path)
		var audit=RailAudit.inspect(main_view if overlay=="" else overlay_root)
		audit.view=view; audit.viewport=str(get_viewport_rect().size); audit.rendered_size=str(rendered.get_size()); audit.output_size=str(output.get_size())
		audit.scene=session.state.get("location",{}).get("scene","title")
		var file=FileAccess.open(capture_args.path+".json",FileAccess.WRITE); file.store_string(JSON.stringify(audit)); file.close()
	get_tree().quit()
