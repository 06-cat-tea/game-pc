class_name BattleView
extends RefCounted

var game
func _init(owner): game=owner

func build(parent: Control):
	var engine=game.session.engine; var battle=engine.battle; var actor=engine.current()
	var route=game.db.encounters[battle.encounter].route
	if game.db.is_outdoor(route): route=game.db.route_ids(route)[0]
	game.background(parent,game.db.raw.scenes[route].background,0.0)
	UIkit.gradient(parent,Vector2.ZERO,Vector2(1920,170),false,true)
	UIkit.text(parent,battle.title,Vector2(234,39),Vector2(1000,55),33)
	UIkit.text(parent,"第 %d 回合  /  %s阵型  /  协奏 %d" % [battle.round,game.db.raw.formations[battle.formation].name,battle.synergy],Vector2(235,104),Vector2(1140,40),21,UIkit.GOLD)
	UIkit.icon_button(parent,"log","战斗记录",Vector2(1650,40),func(): game.open_menu("battle_log"))
	UIkit.icon_button(parent,"play" if game.paused else "pause","继续" if game.paused else "暂停",Vector2(1732,40),func(): game.paused=not game.paused; game.refresh())
	UIkit.icon_button(parent,"settings","战术设置",Vector2(1814,40),func(): game.open_menu("party"))
	UIkit.text(parent,"行动序列",Vector2(40,54),Vector2(160,38),22,UIkit.GOLD)
	_order(parent,actor)
	if game.session.state.training: UIkit.action(parent,"退出回响试炼" if game.session.progression.trial_actor!="" else "退出演练",Vector2(36,1000),Vector2(160,54),game.exit_training).add_theme_font_size_override("font_size",17)
	var targets=[] if actor.is_empty() else engine.legal_targets(actor,game.pending_action,game.pending_skill)
	if game.pending_action=="swap": targets=targets.filter(func(unit): return unit.id!=actor.id)
	if not targets.any(func(unit): return unit.id==game.selected_target): game.selected_target=targets[0].id if not targets.is_empty() else ""
	var friends=battle.units.filter(func(unit): return unit.team=="ally"); friends.sort_custom(func(a,b): return a.slot<b.slot)
	var foes=battle.units.filter(func(unit): return unit.team=="enemy" and unit.hp>0); foes.sort_custom(func(a,b): return a.slot>=3 if (a.slot>=3)!=(b.slot>=3) else a.slot<b.slot)
	for i in friends.size():
		var unit=friends[i]
		var portrait=game.db.art("portraits",unit.id)
		if portrait=="": portrait=game.db.art("actors",unit.art)
		var point=fighter_position(unit)
		var art=UIkit.art(parent,portrait,point,Vector2(250,280))
		art.set_meta("fighter_id",unit.id); art.set_meta("fighter_slot",unit.slot)
		art.modulate=Color.WHITE if unit.hp>0 else Color(0.5,0.5,0.5,0.3)
		UIkit.text(parent,"前排" if unit.slot<2 else "后排",point+Vector2(20,284),Vector2(210,28),18,UIkit.GOLD).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		_ally_strip(parent,unit,actor,Vector2(228+i*237,850))
	for i in foes.size():
		var unit=foes[i]; var back=unit.slot>=3; var slot=int(unit.slot)%3
		var point=Vector2(1020+slot*277,190 if back else 430) if foes.size()>3 else Vector2(1020+i*277,288)
		_enemy(parent,unit,actor,point,Vector2(250,252 if foes.size()>3 else 300))
	UIkit.card(parent,Vector2(210,784),Vector2(984,49),Color(0.96,0.95,0.92,0.86),Color.TRANSPARENT)
	var latest=battle.log[-1] if not battle.log.is_empty() else "观察敌方意图，再选择行动。"
	var log_line=UIkit.text(parent,latest,Vector2(230,793),Vector2(942,34),19); log_line.autowrap_mode=TextServer.AUTOWRAP_OFF; log_line.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	_commands(parent,actor)

func fighter_position(unit: Dictionary) -> Vector2:
	var slot=clampi(int(unit.slot),0,3)
	var formation=game.session.engine.battle.formation
	var layouts={
		"balanced":[Vector2(630,220),Vector2(660,480),Vector2(280,210),Vector2(310,470)],
		"assault":[Vector2(690,220),Vector2(720,480),Vector2(390,210),Vector2(420,470)],
		"watch":[Vector2(570,220),Vector2(600,480),Vector2(250,210),Vector2(280,470)]
	}
	return layouts.get(formation,layouts.balanced)[slot]

func _order(parent: Node, actor: Dictionary):
	var engine=game.session.engine; var ids=engine.battle.queue.slice(int(engine.battle.cursor))
	var column=UIkit.scroll_at(parent,Vector2(40,120),Vector2(160,860))
	for id in ids:
		var unit=engine.unit(id)
		if unit.hp<=0: continue
		var row=UIkit.panel(column); row.custom_minimum_size.y=71
		row.add_theme_stylebox_override("panel",UIkit.style(Color(0.96,0.95,0.92,0.68),UIkit.GOLD if unit.id==actor.get("id","") else UIkit.LINE))
		var inside=UIkit.h(row); var path=game.db.art("portraits",unit.id,"avatar") if unit.team=="ally" else game.db.art("enemies",unit.art)
		if path=="": path=game.db.art("actors",unit.art)
		UIkit.image(inside,path,Vector2(43,48))
		UIkit.label(inside,"▶" if unit.id==actor.get("id","") else "友" if unit.team=="ally" else "敌",18,UIkit.GOLD if unit.team=="ally" else Color("9c554a"))

func _select(unit: Dictionary):
	if game.action_cooldown>0: return
	game.selected_target=unit.id; game.refresh()

func _effects(unit: Dictionary) -> String:
	var lines=[]
	for shield in unit.get("shields",[]): lines.append("护盾 %d · %d 次行动 · %s" % [shield.potency,shield.turns,shield.source])
	for fx in unit.effects: lines.append("%s %d · 来源 %s" % [BattleEngine.EFFECT_NAMES.get(fx.type,fx.type),fx.turns,fx.source])
	return "\n".join(lines) if not lines.is_empty() else "状态平稳"

func _targetable(unit: Dictionary, actor: Dictionary) -> bool:
	return not actor.is_empty() and game.session.engine.legal_targets(actor,game.pending_action,game.pending_skill).has(unit) and (game.pending_action!="swap" or unit.id!=actor.id)

func _ally_strip(parent: Node, unit: Dictionary, actor: Dictionary, point: Vector2):
	var active=unit.id==actor.get("id",""); var selected=unit.id==game.selected_target
	var panel=UIkit.card(parent,point,Vector2(222,176),Color(0.96,0.95,0.92,0.86),UIkit.GOLD if selected or active else UIkit.LINE)
	var face=UIkit.art(panel,game.db.art("portraits",unit.id,"avatar"),Vector2(10,12),Vector2(72,72))
	if unit.hp<=0: face.modulate=Color(0.5,0.5,0.5,0.5)
	UIkit.text(panel,unit.name,Vector2(91,14),Vector2(123,66),21,UIkit.GOLD if active else UIkit.INK)
	UIkit.text(panel,"%d / %d" % [unit.hp,unit.max_hp],Vector2(12,94),Vector2(198,29),19)
	var hp=UIkit.bar(panel,unit.hp,unit.max_hp); hp.position=Vector2(12,127); hp.size=Vector2(198,6)
	var shield=UIkit.bar(panel,BattleRules.shield_value(unit),unit.max_hp); shield.position=Vector2(12,135); shield.size=Vector2(198,3); shield.add_theme_stylebox_override("fill",UIkit.meter(Color("7ba6ab")))
	var mp=UIkit.bar(panel,unit.mp,unit.max_mp,true); mp.position=Vector2(12,140); mp.size=Vector2(198,4)
	var tp=UIkit.bar(panel,unit.get("tp",0),100); tp.position=Vector2(12,147); tp.size=Vector2(198,3); tp.add_theme_stylebox_override("fill",UIkit.meter(UIkit.GOLD))
	UIkit.text(panel,"倒地 · 可苏生" if unit.hp<=0 else "MP %d · TP %d · 盾%d" % [unit.mp,unit.get("tp",0),BattleRules.shield_value(unit)],Vector2(12,151),Vector2(198,25),16,UIkit.MUTED)
	var hit=UIkit.action(panel,"",Vector2.ZERO,Vector2(222,176),func():
		if _targetable(unit,actor): _select(unit)
		else: game.toast("请选择适合当前行动的目标。"))
	hit.add_theme_stylebox_override("normal",UIkit.style(Color.TRANSPARENT,Color.TRANSPARENT)); hit.tooltip_text=_effects(unit)
	if not unit.effects.is_empty(): UIkit.text(parent,"◆ %d" % unit.effects.size(),point+Vector2(160,-26),Vector2(60,26),17,UIkit.GOLD)

func _enemy(parent: Node, unit: Dictionary, actor: Dictionary, point: Vector2, dimensions: Vector2):
	var selected=unit.id==game.selected_target; var legal=_targetable(unit,actor)
	var root=UIkit.canvas(parent,point-Vector2(0,94),Vector2(dimensions.x,dimensions.y+140))
	UIkit.card(root,Vector2.ZERO,Vector2(dimensions.x,82),Color(0.96,0.95,0.92,0.82),UIkit.GOLD if selected else Color.TRANSPARENT)
	UIkit.text(root,("◇ " if selected else "")+unit.name,Vector2(7,3),Vector2(dimensions.x-14,30),20,UIkit.GOLD if selected else UIkit.INK)
	var hp=UIkit.bar(root,unit.hp,unit.max_hp); hp.position=Vector2(8,39); hp.size=Vector2(dimensions.x-16,5); hp.add_theme_stylebox_override("fill",UIkit.meter(Color("d78e86")))
	var shield=UIkit.bar(root,BattleRules.shield_value(unit),unit.max_hp); shield.position=Vector2(8,45); shield.size=Vector2(dimensions.x-16,3); shield.add_theme_stylebox_override("fill",UIkit.meter(Color("7ba6ab")))
	var posture=UIkit.bar(root,unit.posture,unit.max_posture); posture.position=Vector2(8,50); posture.size=Vector2(dimensions.x-16,3); posture.add_theme_stylebox_override("fill",UIkit.meter(UIkit.ACCENT))
	var weakness=[]
	for element in unit.weakness: weakness.append(GameContent.ELEMENT_NAMES[element])
	var info=UIkit.text(root,"%s · 韧 %d/%d" % [GameContent.ELEMENT_NAMES[unit.get("affinity","physical")],unit.posture,unit.max_posture],Vector2(8,57),Vector2(dimensions.x-82,26),14,UIkit.GOLD)
	for i in unit.weakness.size():
		var weak_icon=UIkit.art(root,ItemIcons.path(game.db,unit.weakness[i]),Vector2(dimensions.x-22*(unit.weakness.size()-i)-4,60),Vector2(18,18))
		weak_icon.tooltip_text="弱点 · "+GameContent.ELEMENT_NAMES[unit.weakness[i]]
	info.autowrap_mode=TextServer.AUTOWRAP_OFF; info.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	var art=UIkit.art(root,game.db.art("enemies",unit.art),Vector2(0,94),dimensions)
	art.set_meta("fighter_id",unit.id)
	if selected: art.modulate=Color(1.1,1.05,0.92)
	var next=unit.get("intent",{}); var target=game.session.engine.unit(next.get("target",""))
	var intent=str(next.get("label","等待行动"))
	if next.get("kind","") not in ["charge","summon"]: intent+=" → "+str(target.get("name",""))
	UIkit.text(root,intent,Vector2(0,81),Vector2(dimensions.x,28),16,Color("854e37")).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var hit=UIkit.action(root,"",Vector2.ZERO,root.size,func():
		if legal: _select(unit)
		else: game.toast("近战优先攻击前排；这个目标不适合当前行动。"))
	hit.add_theme_stylebox_override("normal",UIkit.style(Color.TRANSPARENT,Color.TRANSPARENT)); hit.add_theme_stylebox_override("hover",UIkit.style(Color(1,1,1,0.04),UIkit.GOLD if legal else UIkit.LINE)); hit.tooltip_text="生命 %d/%d · 韧性 %d/%d\n弱点：%s\n%s\n%s · %s" % [unit.hp,unit.max_hp,unit.posture,unit.max_posture," / ".join(weakness),_effects(unit),"后排" if unit.slot>=3 else "前排",intent]
	if not unit.effects.is_empty(): UIkit.text(root,"◆ %d" % unit.effects.size(),Vector2(190,78),Vector2(60,28),17,UIkit.GOLD)

func _commands(parent: Node, actor: Dictionary):
	var engine=game.session.engine; var manual=not actor.is_empty() and actor.team=="ally" and not game.paused and game.action_cooldown<=0
	var root=UIkit.card(parent,Vector2(1230,764),Vector2(650,270),Color(0.96,0.95,0.92,0.94),UIkit.LINE)
	UIkit.text(root,("已暂停 · " if game.paused else "行动 · ")+actor.get("name","等待结算"),Vector2(18,12),Vector2(422,33),21,UIkit.GOLD)
	if actor.get("team","")=="ally": UIkit.action(root,"切为手动" if actor.auto else "交由 AI",Vector2(484,8),Vector2(150,40),func(): actor.auto=not actor.auto; game.session.state.members[actor.id].auto=actor.auto; game.session.changed.emit(); game.ai_clock=0; game.refresh()).add_theme_font_size_override("font_size",18)
	var names=[["普攻","attack"],["护卫","guard"],["换位","swap"],["道具","items"],["羁绊","combos"],["变阵","formations"],["撤离","flee"]]
	for i in names.size():
		var action=names[i][1]; var node=UIkit.action(root,names[i][0],Vector2(12+i*90,55),Vector2(88,42),func():
			if action in ["items","combos","formations"]: game.open_menu(action)
			else: game.choose_action(action),false,not manual)
		node.add_theme_font_size_override("font_size",16); node.set_meta("avoid_overlap","commands"); node.tooltip_text="羁绊技 / 双人协奏" if action=="combos" else names[i][0]; UIkit.selected(node,game.pending_action==action)
	if actor.get("team","")=="ally":
		for i in 4:
			var available=i<actor.skills.size(); var skill_id=actor.skills[i] if available else ""; var skill=game.db.skills.get(skill_id); var cd=int(actor.cooldowns.get(skill_id,0))
			var disabled=not manual or not available or cd>0 or (available and actor.mp<skill.mp) or (available and engine.has_effect(actor,"silence") and actor.job in ["priest","arcanist","alchemist"])
			var value="%d  %s\n%s" % [i+1,skill.display_name if available else "空技能位",("冷却 %d" % cd if cd>0 else "%d MP" % skill.mp) if available else "—"]
			var node=UIkit.action(root,value,Vector2(16+i*156,108),Vector2(148,65),func(): game.choose_action("ability",skill_id),false,disabled)
			node.add_theme_font_size_override("font_size",16); node.set_meta("avoid_overlap","commands"); node.tooltip_text=game.db.describe_skill(skill_id) if available else "尚未配置技能"; UIkit.selected(node,available and game.pending_skill==skill_id)
	else: UIkit.text(root,"敌方正在依照意图行动……",Vector2(18,119),Vector2(610,50),24,UIkit.MUTED)
	var selected=engine.unit(game.selected_target)
	var preview_text="目标："+selected.get("name","无需目标")
	if not actor.is_empty() and not selected.is_empty() and selected.team=="enemy":
		var estimate=engine.preview(actor,selected,game.pending_action,game.pending_skill)
		preview_text+=" · ×%.2f · 削韧%d%s" % [estimate.multiplier,estimate.reduction," · 可击破" if estimate.breaks else ""]
		if estimate.target!=selected.id: preview_text+=" · 护卫代受"
	UIkit.card(parent,Vector2(1230,724),Vector2(650,36),Color(UIkit.PAPER,.94),Color.TRANSPARENT)
	var preview_line=UIkit.text(parent,preview_text,Vector2(1246,729),Vector2(618,30),17,UIkit.INK)
	preview_line.autowrap_mode=TextServer.AUTOWRAP_OFF; preview_line.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS; preview_line.tooltip_text=preview_text
	if actor.get("team","")=="ally":
		var d=game.db.progression.ultimates[actor.id]
		var ready=actor.get("awakened",false) and actor.get("tp",0)>=100 and not engine.has_effect(actor,"silence")
		var burst=UIkit.action(root,GameBindings.label("ultimate")+"  "+d.name+"\nTP %d / 100" % actor.get("tp",0) if actor.get("awakened",false) else GameBindings.label("ultimate")+"  大招待觉醒",Vector2(16,184),Vector2(299,58),func(): game.choose_action("ultimate",actor.id),false,not manual or not ready)
		burst.add_theme_font_size_override("font_size",18); burst.tooltip_text=d.desc if actor.get("awakened",false) else game.session.progression.status(actor.id); burst.set_meta("avoid_overlap","commands"); UIkit.selected(burst,game.pending_action=="ultimate")
	UIkit.action(root,"确认行动 · "+GameBindings.label("confirm"),Vector2(325,184),Vector2(307,58),game.perform,true,not manual or game.resolving or game.action_cooldown>0).set_meta("avoid_overlap","commands")
	UIkit.text(parent,"1–4 / %s 战技    %s 大招    点击目标    %s 确认" % [GameBindings.label("default_skill"),GameBindings.label("ultimate"),GameBindings.label("confirm")],Vector2(1235,1043),Vector2(640,29),16)

