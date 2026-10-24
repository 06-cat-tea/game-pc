class_name RailPages
extends RefCounted

var game
var menu_ref: WeakRef
var menus:
	get: return menu_ref.get_ref()
var states={}
const NAMES={"terminal":"旅人终端","character":"角色详情","party":"队伍配置","skills":"职业技艺","inventory":"背包","craft":"旅行工坊","journal":"旅途记录","map":"地点地图","shop":"行省杂货","new":"新的旅程","settings":"设置","saves":"存档管理","training":"战术训练"}
const ITEM_NAMES={"potion":"赤松药剂","tonic":"月露灵剂","revive":"苏生药","supply":"旅行补给"}
const ITEM_TEXT={"potion":"恢复指定队员 40 点生命。","tonic":"恢复指定队员 30 点法力。","revive":"使倒地队员恢复 30% 生命。","supply":"旅店休息消耗的旅行补给。"}

func _init(owner, menu_owner): game=owner; menu_ref=weakref(menu_owner)

func state(kind: String, subject: String = "hero") -> Dictionary:
	var key=kind+"|"+subject
	if not states.has(key): states[key]={"selection":"","category":"all"}
	return states[key]

func redraw(kind: String, subject: String = "hero"): game.refresh_menu(kind,subject)

func build(kind: String, subject: String) -> bool:
	if not NAMES.has(kind): return false
	if kind=="terminal": _terminal(); return true
	var root=shell(NAMES[kind])
	match kind:
		"new": _new(root)
		"character": _character(root,subject)
		"party": _party(root,subject)
		"skills": _skills(root,subject)
		"inventory": _inventory(root,subject)
		"craft": _craft(root)
		"journal": _journal(root)
		"map": _map(root)
		"shop": _shop(root,subject)
		"saves": _saves(root)
		"settings": _settings(root)
		"training": _training(root)
	return true

func shell(title: String) -> Control:
	var root=game.overlay_root
	var dark=title in ["角色详情","旅途记录","公会委托板","职业技艺"]
	root.set_meta("starlit_dark",dark)
	UIkit.art(root,"res://assets/starlit-town/menu-background.webp",Vector2.ZERO,Vector2(1920,1080),true)
	UIkit.card(root,Vector2.ZERO,Vector2(1920,1080),Color(UIkit.NIGHT,.28) if dark else Color(UIkit.PAPER,.93),Color.TRANSPARENT)
	UIkit.icon_button(root,"back","返回",Vector2(56,52),game.back_menu)
	UIkit.text(root,title,Vector2(148,54),Vector2(630,50),36)
	UIkit.text(root,"ASHEN FRONTIER  /  星陨纪事",Vector2(150,108),Vector2(700,30),17,UIkit.GOLD)
	UIkit.icon_button(root,"close","关闭界面",Vector2(1796,52),game.close_menu)
	UIkit.rule(root,Vector2(64,152),1792)
	UIkit.rule(root,Vector2(64,1008),1792)
	UIkit.text(root,"ESC  返回     ·     鼠标选择     ·     TAB 切换焦点",Vector2(64,1028),Vector2(1100,34),18,UIkit.MUTED)
	if not game.session.state.is_empty(): UIkit.text(root,"金币  %d     /     补给  %d" % [game.session.state.gold,game.session.state.supplies],Vector2(1400,1030),Vector2(455,32),20,UIkit.GOLD).horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	return UIkit.canvas(root,Vector2(64,178),Vector2(1792,804))

func _tabs(parent: Node, kind: String, subject: String):
	var x=maxf(0,(1792-game.session.state.members.size()*214)/2.0)
	for id in game.session.state.members:
		var button=UIkit.action(parent,game.db.actors[id].display_name,Vector2(x,0),Vector2(202,66),func(): redraw(kind,id))
		button.icon=load(game.db.art("portraits",id,"avatar")); button.expand_icon=true; button.add_theme_constant_override("icon_max_width",44); UIkit.selected(button,id==subject)
		x+=214

func _section(parent: Node, title: String, y: float, width: float):
	UIkit.text(parent,title,Vector2(0,y),Vector2(width,40),26,UIkit.GOLD); UIkit.rule(parent,Vector2(0,y+49),width)

func _terminal():
	var root=game.overlay_root
	root.set_meta("starlit_dark",false)
	UIkit.card(root,Vector2.ZERO,Vector2(1920,1080),Color(0.22,0.25,0.28,0.15),Color.TRANSPARENT)
	var panel=UIkit.canvas(root,Vector2(1160,0),Vector2(760,1080))
	UIkit.art(panel,"res://assets/ui/orbit.svg",Vector2.ZERO,Vector2(760,1080),true)
	UIkit.card(panel,Vector2.ZERO,Vector2(760,1080),Color(0.96,0.95,0.92,0.92),UIkit.LINE)
	UIkit.text(panel,"旅人终端",Vector2(54,62),Vector2(550,50),38)
	UIkit.icon_button(panel,"close","返回旅程",Vector2(635,54),game.close_menu)
	var hero=game.session.state.members.hero
	UIkit.art(panel,game.db.art("portraits","hero","avatar"),Vector2(54,150),Vector2(116,116))
	UIkit.text(panel,"归路的见证者",Vector2(192,162),Vector2(490,42),30,UIkit.GOLD)
	UIkit.text(panel,"%s  /  等级 %d\n第 %d 日 · %s" % [GameContent.JOB_NAMES[hero.job],hero.level,game.session.state.day,["清晨","正午","黄昏","深夜"][game.session.state.phase]],Vector2(192,212),Vector2(490,80),22,UIkit.MUTED)
	UIkit.rule(panel,Vector2(54,310),652)
	var entries=[["character","角色","character"],["party","队伍","affinity"],["inventory","背包","backpack"],["skills","技艺","skills"],["journal","任务","main-quest"],["map","地图","map"],["craft","工坊","crafting"],["saves","存档","save"],["settings","设置","settings"],["people","人物","dialogue"],["lore","世界志","main-quest"],["achievements","成就","affinity"],["awakening-log","角色觉醒","ultimate-hero"],["building-log","六地见闻","map"]]
	for i in entries.size():
		var entry=entries[i]; var kind=entry[0]
		var node=UIkit.action(panel,entry[1],Vector2(54+(i%3)*220,326+int(i/3)*110),Vector2(208,96),func(): game.open_menu(kind))
		node.icon=UIkit.icon(entry[2]); node.expand_icon=true; node.add_theme_constant_override("icon_max_width",36)
	UIkit.text(panel,"六地归途 · 星钟谜语",Vector2(54,906),Vector2(650,45),27,UIkit.GOLD)
	UIkit.text(panel,"在钟声与雾中，带你的同伴找到归路。",Vector2(54,958),Vector2(650,45),22,UIkit.MUTED)
	UIkit.text(panel,"ESC  返回旅程",Vector2(54,1020),Vector2(650,30),19)

func _new(root: Control):
	UIkit.text(root,"选择最初的道路",Vector2(0,10),Vector2(1000,65),42,UIkit.GOLD)
	UIkit.text(root,"从晨星镇序章出发，走向五地与归灯结局。新旅程会覆盖自动档，手动档保留。",Vector2(0,88),Vector2(1700,50),24,UIkit.MUTED)
	var jobs=["ranger","arcanist","warden"]
	for i in jobs.size():
		var job=jobs[i]; var card=UIkit.card(root,Vector2(i*598,164),Vector2(570,600))
		UIkit.art(card,game.db.art("portraits","hero"),Vector2(20,28),Vector2(270,400))
		var symbol=TextureRect.new(); symbol.texture=UIkit.icon(job); symbol.position=Vector2(370,56); symbol.size=Vector2(100,100); symbol.mouse_filter=Control.MOUSE_FILTER_IGNORE; card.add_child(symbol)
		UIkit.text(card,GameContent.JOB_NAMES[job],Vector2(294,186),Vector2(260,60),38,UIkit.GOLD)
		UIkit.text(card,game.db.raw.jobs[job].desc,Vector2(294,264),Vector2(240,178),23)
		UIkit.action(card,"以此职业出发",Vector2(38,494),Vector2(494,62),func(): game.load_new_game(job),true)

func _character(root: Control, id: String):
	_tabs(root,"character",id)
	var member=game.session.state.members[id]; var stats=PartyMemberState.stats(member,game.session.state,game.db)
	var links=[["属性","character"],["职业技艺","skills"],["装备","inventory"],["队伍与战术","party"]]
	for i in links.size():
		var kind=links[i][1]; var node=UIkit.action(root,links[i][0],Vector2(0,138+i*84),Vector2(220,64),func(): game.open_menu(kind,id)); UIkit.selected(node,i==0)
	var awakened=game.session.progression.unlocked(id); var ultimate=game.db.progression.ultimates[id]
	UIkit.art(root,"res://assets/ui/icons/ultimate-"+id+".svg",Vector2(56,494),Vector2(100,100))
	UIkit.text(root,ultimate.name,Vector2(0,608),Vector2(220,40),25,UIkit.GOLD)
	UIkit.text(root,"TP %d / 100" % member.get("tp",0) if awakened else "尚未觉醒",Vector2(0,655),Vector2(220,34),22)
	var tp=UIkit.bar(root,member.get("tp",0),100); tp.position=Vector2(0,698); tp.size=Vector2(220,5); tp.add_theme_stylebox_override("fill",UIkit.meter(UIkit.GOLD))
	UIkit.action(root,"觉醒档案" if awakened else "追踪觉醒故事",Vector2(0,728),Vector2(220,58),func(): game.open_menu("awakening",id)).tooltip_text=game.session.progression.status(id)
	UIkit.art(root,game.db.art("portraits",id),Vector2(265,70),Vector2(830,730))
	var detail=UIkit.canvas(root,Vector2(1180,110),Vector2(610,690))
	UIkit.text(detail,GameContent.JOB_NAMES[member.job],Vector2.ZERO,Vector2(580,36),23,UIkit.GOLD)
	UIkit.text(detail,game.db.actors[id].display_name,Vector2(0,48),Vector2(600,76),43)
	UIkit.text(detail,"等级  %d     /     技能点  %d" % [member.level,member.skill_points],Vector2(0,141),Vector2(600,44),27,UIkit.GOLD)
	var xp=UIkit.bar(detail,member.xp,PartyMemberState.next_xp(member.level)); xp.position=Vector2(0,198); xp.size=Vector2(580,6)
	UIkit.text(detail,"经验  %d / %d" % [member.xp,PartyMemberState.next_xp(member.level)],Vector2(0,217),Vector2(600,34),20,UIkit.MUTED)
	var values=[["生命","%d / %d" % [member.hp,stats.max_hp]],["法力","%d / %d" % [member.mp,stats.max_mp]],["攻击",str(stats.atk)],["防御",str(stats.def)],["速度",str(stats.speed)],["暴击","%d%%" % int(stats.crit*100)]]
	for i in values.size():
		UIkit.rule(detail,Vector2(0,269+i*48),580)
		UIkit.text(detail,values[i][0],Vector2(6,277+i*48),Vector2(230,40),23,UIkit.MUTED)
		UIkit.text(detail,values[i][1],Vector2(260,277+i*48),Vector2(314,40),24).horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	if id=="hero":
		UIkit.text(detail,"营地转职",Vector2(0,587),Vector2(180,42),22,UIkit.GOLD)
		var options=UIkit.canvas(detail,Vector2(174,580),Vector2(400,60))
		var choice=UIkit.option(options,GameContent.JOB_ORDER.map(func(job): return GameContent.JOB_NAMES[job]),GameContent.JOB_ORDER.find(member.job),func(index): menus._result(game.session.change_job(GameContent.JOB_ORDER[index]),"character",id)); choice.size=Vector2(400,56)
		choice.disabled=game.session.state.battle!=null or game.session.state.location.scene!="town"

func _party(root: Control, id: String):
	var s=game.session.state
	UIkit.text(root,"同行队伍",Vector2(0,0),Vector2(1000,46),30,UIkit.GOLD)
	UIkit.text(root,"%d / 4 出战  ·  每位队员独立成长" % s.active.size(),Vector2(1120,4),Vector2(670,40),23,UIkit.MUTED).horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	for i in 4:
		var panel=UIkit.card(root,Vector2(i*450,64),Vector2(428,350))
		if i<s.active.size():
			var who=s.active[i]; var member=s.members[who]
			UIkit.art(panel,game.db.art("portraits",who),Vector2(0,12),Vector2(428,270))
			UIkit.card(panel,Vector2(0,258),Vector2(428,92),Color(0.96,0.95,0.92,0.88),Color.TRANSPARENT)
			UIkit.text(panel,game.db.actors[who].display_name,Vector2(18,267),Vector2(390,38),24,UIkit.GOLD)
			UIkit.text(panel,"Lv.%d  ·  %s  ·  %s" % [member.level,GameContent.JOB_NAMES[member.job],"前排" if member.slot<2 else "后排"],Vector2(18,307),Vector2(390,32),19)
			var hit=UIkit.action(panel,"",Vector2.ZERO,Vector2(428,350),func(): redraw("party",who)); hit.add_theme_stylebox_override("normal",UIkit.style(Color.TRANSPARENT,UIkit.GOLD if who==id else UIkit.LINE)); hit.add_theme_stylebox_override("hover",UIkit.style(Color(1,1,1,0.04),UIkit.GOLD)); hit.tooltip_text="配置 "+game.db.actors[who].display_name
		else: UIkit.text(panel,"＋\n待命席位",Vector2(40,100),Vector2(348,130),31,UIkit.MUTED).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var body=UIkit.scroll_at(root,Vector2(0,443),Vector2(1792,350))
	menus._member_tabs(body,"party",id)
	var member=s.members[id]
	UIkit.button(body,"回营地待命" if id in s.active else "加入出战队伍",func(): menus._result(game.session.toggle_member(id),"party",id),id=="hero" or s.battle!=null)
	menus._tactics(body,id)

func _skills(root: Control, id: String):
	_tabs(root,"skills",id)
	var s=game.session.state; var member=s.members[id]; var ui_state=state("skills",id); var all=game.db.job_skills(member.job)
	if ui_state.selection not in all: ui_state.selection=all[0]
	UIkit.text(root,"%s · %s\n剩余技能点  %d" % [game.db.actors[id].display_name,GameContent.JOB_NAMES[member.job],member.skill_points],Vector2(0,111),Vector2(250,125),28,UIkit.GOLD)
	UIkit.text(root,"选择节点查看详情\n主动技最多配置四项",Vector2(0,271),Vector2(230,90),22,UIkit.MUTED)
	UIkit.action(root,"免费重配",Vector2(0,440),Vector2(218,58),func(): menus._confirm("重配技能","退回当前职业已花费的技能点，清空该职业配置。",func(): menus._result(game.session.respec(id),"skills",id)),false,s.battle!=null or s.location.scene!="town")
	var col=0
	for branch in game.db.raw.jobs[member.job].branches:
		UIkit.text(root,game.db.raw.jobs[member.job].branches[branch],Vector2(285+col*282,104),Vector2(260,45),27,UIkit.GOLD)
		var row=0
		for skill_id in all:
			var skill=game.db.skills[skill_id]; var d=skill.data
			if d.branch!=branch: continue
			var known=skill_id in member.learned; var configured=skill_id in member.loadouts.get(member.job,[])
			if row<4: UIkit.rule(root,Vector2(413+col*282,232+row*103),1,UIkit.GOLD)
			var node=UIkit.action(root,("◆ " if configured else "✓ " if known else "◇ ")+skill.display_name+"\nLv.%d · %s" % [d.level,"主动" if d.kind=="active" else "被动"],Vector2(285+col*282,164+row*103),Vector2(260,82),func(): ui_state.selection=skill_id; redraw("skills",id))
			node.add_theme_font_size_override("font_size",21); UIkit.selected(node,skill_id==ui_state.selection); row+=1
		col+=1
	var loadout=member.loadouts.get(member.job,[])
	for i in 4:
		UIkit.card(root,Vector2(284+i*211,710),Vector2(199,70))
		UIkit.text(root,"%d  %s" % [i+1,game.db.skills[loadout[i]].display_name if i<loadout.size() else "空技能位"],Vector2(298+i*211,730),Vector2(175,40),21,UIkit.GOLD)
	var detail=UIkit.card(root,Vector2(1168,104),Vector2(624,680)); var chosen=game.db.skills[ui_state.selection]; var d=chosen.data
	UIkit.text(detail,chosen.display_name,Vector2(34,36),Vector2(556,80),36,UIkit.GOLD)
	UIkit.text(detail,"%s  /  需要等级 %d  /  %d 技能点" % ["主动技能" if d.kind=="active" else "被动天赋",d.level,d.cost],Vector2(34,132),Vector2(550,65),22,UIkit.MUTED)
	UIkit.rule(detail,Vector2(34,216),556)
	UIkit.text(detail,game.db.describe_skill(ui_state.selection),Vector2(34,248),Vector2(556,260),25)
	var known=ui_state.selection in member.learned; var configured=ui_state.selection in loadout; var blocked=s.battle!=null
	for prerequisite in d.get("requires",[]):
		if prerequisite not in member.learned: blocked=true
	if not known: blocked=blocked or member.level<d.level or member.skill_points<d.cost
	if known and d.kind=="active": blocked=blocked or (not configured and loadout.size()>=4)
	var caption=("移出配置" if configured else "加入配置") if known and d.kind=="active" else "已习得被动" if known else "学习技能"
	UIkit.action(detail,caption,Vector2(34,580),Vector2(556,62),func(): menus._result(game.session.configure_skill(id,ui_state.selection) if known else game.session.learn(id,ui_state.selection),"skills",id),true,blocked or (known and d.kind=="passive"))

func _inventory(root: Control, id: String):
	_tabs(root,"inventory",id)
	var ui_state=state("inventory",id); var entries=[]; var s=game.session.state
	var categories=[["all","全部物品"],["weapon","武器"],["armor","防具"],["charm","饰品"],["items","消耗品"]]
	for i in categories.size():
		var category=categories[i][0]; var node=UIkit.action(root,categories[i][1],Vector2(0,114+i*78),Vector2(194,60),func(): ui_state.category=category; ui_state.selection=""; redraw("inventory",id)); UIkit.selected(node,ui_state.category==category)
	for uid in s.gear:
		var gear=s.gear[uid]; var item=game.db.raw.items[gear.item]
		if ui_state.category in ["all",item.slot]: entries.append({"id":uid,"item":gear.item,"name":item.name,"rank":gear.rank,"kind":"gear"})
	if ui_state.category in ["all","items"]:
		for item in ["potion","tonic","revive"]: entries.append({"id":"item:"+item,"item":item,"name":ITEM_NAMES[item],"rank":s.items[item],"kind":"item"})
	if not entries.any(func(entry): return entry.id==ui_state.selection): ui_state.selection=entries[0].id if not entries.is_empty() else ""
	UIkit.text(root,"物品一览  /  %d" % entries.size(),Vector2(230,106),Vector2(850,45),25,UIkit.GOLD)
	var grid_scroll=ScrollContainer.new(); grid_scroll.follow_focus=true; grid_scroll.position=Vector2(230,165); grid_scroll.size=Vector2(884,550); grid_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; root.add_child(grid_scroll)
	var grid=GridContainer.new(); grid.columns=5; grid.add_theme_constant_override("h_separation",14); grid.add_theme_constant_override("v_separation",14); grid_scroll.add_child(grid)
	var selection={}
	for entry in entries:
		var node=UIkit.button(grid,"",func(): ui_state.selection=entry.id; redraw("inventory",id)); node.custom_minimum_size=Vector2(156,166); node.tooltip_text=entry.name
		node.set_meta("grid_tile",true)
		node.add_theme_stylebox_override("normal",UIkit.button_style(Color("e3e6e9"),Color("d0d4d9"),8))
		node.add_theme_stylebox_override("hover",UIkit.button_style(Color("f4eee2"),UIkit.GOLD,8))
		UIkit.selected(node,entry.id==ui_state.selection)
		var path=ItemIcons.path(game.db,entry.item)
		var art=UIkit.art(node,path,Vector2(14,8),Vector2(128,102))
		if path=="": art.texture=UIkit.icon("potion")
		UIkit.text(node,entry.name,Vector2(9,111),Vector2(138,30),18,UIkit.INK if entry.id==ui_state.selection else UIkit.INK).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		UIkit.text(node,"+%d" % entry.rank if entry.kind=="gear" else "×%d" % entry.rank,Vector2(12,139),Vector2(130,25),17,UIkit.INK if entry.id==ui_state.selection else UIkit.GOLD).horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
		if entry.id==ui_state.selection: selection=entry
	for index in maxi(0,15-entries.size()):
		var empty=Panel.new(); empty.custom_minimum_size=Vector2(156,166); empty.mouse_filter=Control.MOUSE_FILTER_IGNORE
		empty.add_theme_stylebox_override("panel",UIkit.style(Color("e6e7e7"),Color("d6d9dc"),8)); grid.add_child(empty)
	ItemIcons.strip(root,game.db,{"gold":s.gold,"herb":s.materials.herb,"ore":s.materials.ore,"shard":s.materials.shard},Vector2(240,738),210)
	var detail=UIkit.card(root,Vector2(1156,108),Vector2(636,680),Color(UIkit.PAPER,.88),UIkit.LINE)
	if selection.is_empty(): UIkit.text(detail,"这个分类还没有物品",Vector2(40,260),Vector2(556,100),30,UIkit.MUTED); return
	var art=UIkit.art(detail,ItemIcons.path(game.db,selection.item),Vector2(205,24),Vector2(226,190))
	if art.texture==null: art.texture=UIkit.icon("potion")
	UIkit.text(detail,selection.name,Vector2(34,226),Vector2(568,60),34,UIkit.GOLD)
	UIkit.rule(detail,Vector2(34,308),568)
	if selection.kind=="gear":
		var item=game.db.raw.items[selection.item]; var owner=""
		for member in s.members.values():
			if selection.id in member.equip.values(): owner=member.id
		var description=UIkit.scroll_at(detail,Vector2(34,335),Vector2(568,168))
		UIkit.label(description,item.text,22)
		UIkit.label(description,_stats(item.stats),22)
		UIkit.label(description,"归属："+(game.db.actors[owner].display_name if owner!="" else "背包"),20,UIkit.MUTED)
		UIkit.action(detail,"卸下装备" if owner==id else "装备给 "+game.db.actors[id].display_name,Vector2(34,580),Vector2(347,62),func(): menus._result(game.session.equip(id,selection.id),"inventory",id),true,s.battle!=null or (owner!="" and owner!=id))
		var gear=s.gear[selection.id]; var rank=int(gear.rank); var price=["矿石 2 / 金币 30","矿石 4 / 星屑 1 / 金币 60","矿石 6 / 星屑 2 / 金币 100","已达上限"][rank]
		var enhance=UIkit.action(detail,"强化 +%d" % mini(rank+1,3),Vector2(399,580),Vector2(203,62),func(): menus._result(game.session.enhance(selection.id),"inventory",id),false,s.battle!=null or rank>=3); enhance.tooltip_text=price
		UIkit.text(detail,price,Vector2(34,531),Vector2(568,35),19,UIkit.MUTED)
	else:
		UIkit.text(detail,ITEM_TEXT[selection.item]+"\n\n持有 %d 份\n使用目标：%s" % [selection.rank,game.db.actors[id].display_name],Vector2(34,335),Vector2(568,220),25)
		var dead=s.members[id].hp<=0
		UIkit.action(detail,"使用道具",Vector2(34,580),Vector2(568,62),func(): menus._result(game.session.use_item(selection.item,id),"inventory",id),true,s.battle!=null or selection.rank<=0 or (not dead if selection.item=="revive" else dead))

func _stats(values: Dictionary) -> String:
	var names={"atk":"攻击","def":"防御","hp":"生命","mp":"法力","crit":"暴击","speed":"速度"}; var lines=[]
	for key in values: lines.append("%s  +%s" % [names.get(key,key),("%d%%" % int(values[key]*100)) if key=="crit" else str(values[key])])
	return "     ".join(lines)

func _craft(root: Control):
	var ui_state=state("craft"); var recipes=game.db.raw.recipes; var s=game.session.state
	if not recipes.has(ui_state.selection): ui_state.selection=recipes.keys()[0]
	ItemIcons.strip(root,game.db,{"herb":s.materials.herb,"ore":s.materials.ore,"shard":s.materials.shard},Vector2(0,8),260)
	var list=UIkit.scroll_at(root,Vector2(0,83),Vector2(760,705))
	for id in recipes:
		var recipe=recipes[id]; var name=recipe.get("name",game.db.raw.items.get(recipe.get("item",""),{}).get("name",id))
		var node=UIkit.button(list,name+"\n"+menus._cost_text(recipe.cost),func(): ui_state.selection=id; redraw("craft")); node.custom_minimum_size.y=96; node.alignment=HORIZONTAL_ALIGNMENT_LEFT; UIkit.selected(node,id==ui_state.selection)
	var recipe=recipes[ui_state.selection]; var detail=UIkit.card(root,Vector2(800,84),Vector2(992,704))
	UIkit.art(detail,ItemIcons.path(game.db,recipe.get("item","")),Vector2(330,24),Vector2(320,240))
	UIkit.text(detail,recipe.get("name",game.db.raw.items.get(recipe.get("item",""),{}).get("name",ui_state.selection)),Vector2(42,284),Vector2(908,70),37,UIkit.GOLD)
	UIkit.text(detail,recipe.get("desc",game.db.raw.items.get(recipe.get("item",""),{}).get("text","旅行工坊的制作配方。")),Vector2(42,368),Vector2(908,110),26)
	UIkit.text(detail,"材料："+menus._cost_text(recipe.cost),Vector2(42,506),Vector2(908,60),24,UIkit.GOLD)
	var blocked=s.battle!=null or (recipe.get("once",false) and s.flags.get("crafted:"+ui_state.selection,false))
	for key in recipe.cost:
		if s.materials.get(key,0)<recipe.cost[key]: blocked=true
	for pre in recipe.get("requires",[]):
		if not s.flags.get("crafted:"+pre,false): blocked=true
	UIkit.action(detail,"制作",Vector2(42,606),Vector2(908,62),func(): menus._result(game.session.craft(ui_state.selection),"craft"),true,blocked)

func _journal(_root: Control):
	game.menus.quest_pages.journal()

func _map(root: Control):
	var ui_state=state("map")
	if not ui_state.has("region"): ui_state.region=game.world.scene_id if game.db.is_outdoor(game.world.scene_id) else "town"
	if ui_state.category=="all": ui_state.category="world"
	var world_button=UIkit.action(root,"六地总览",Vector2.ZERO,Vector2(160,44),func(): ui_state.category="world"; redraw("map")); UIkit.selected(world_button,ui_state.category=="world")
	for i in GameContent.OUTDOORS.size():
		var id=GameContent.OUTDOORS[i]
		var button=UIkit.action(root,game.db.location_title(id),Vector2(176+i*162,0),Vector2(152,44),func(): ui_state.region=id; ui_state.category="region"; ui_state.selection=""; redraw("map")); button.add_theme_font_size_override("font_size",18); UIkit.selected(button,id==ui_state.region)
	if ui_state.category=="world": _world_map(root,ui_state); return
	if game.db.regions.has(ui_state.region) and not (ui_state.category=="current" and game.db.raw.scenes.has(game.world.scene_id)): _region_map(root,ui_state); return
	if ui_state.selection=="": ui_state.selection="clocktower"
	var current=ui_state.category=="current" and game.db.raw.scenes.has(game.world.scene_id)
	var map=RailMap.new(); map.scene_override=game.world.scene_id if current else "town"; map.position=Vector2(0,110); map.size=Vector2(1150,594); map.selected=ui_state.selection; root.add_child(map); map.setup(game)
	map.picked.connect(func(id): ui_state.selection=id; redraw("map"))
	var town=UIkit.action(root,"所属地区总览",Vector2(0,54),Vector2(230,48),func(): ui_state.category="region"; ui_state.selection="clocktower"; redraw("map")); UIkit.selected(town,not current)
	var scene=UIkit.action(root,"当前场景",Vector2(244,54),Vector2(230,48),func(): ui_state.category="current"; ui_state.selection=""; redraw("map"),false,not game.db.raw.scenes.has(game.world.scene_id)); UIkit.selected(scene,current)
	UIkit.text(root,"地标    ▷ 当前位置",Vector2(803,64),Vector2(330,34),19,UIkit.MUTED)
	var detail=UIkit.card(root,Vector2(1186,0),Vector2(606,788)); var selected={}
	if current:
		var scene_data=game.db.raw.scenes[game.world.scene_id]
		for prop in scene_data.props:
			if prop.id==ui_state.selection: selected=prop
		if selected.is_empty() and not scene_data.props.is_empty(): selected=scene_data.props[0]
		if not selected.is_empty(): ui_state.selection=selected.id; map.selected=selected.id
		UIkit.art(detail,scene_data.background,Vector2(16,30),Vector2(574,285))
		UIkit.text(detail,scene_data.title,Vector2(32,340),Vector2(542,60),36,UIkit.GOLD)
		if not selected.is_empty():
			UIkit.text(detail,selected.name+"\n\n"+selected.get("detail",""),Vector2(32,418),Vector2(542,220),24)
			UIkit.action(detail,"前往交互地点",Vector2(32,650),Vector2(542,58),func():
				game.close_menu()
				for target in game.world.targets:
					if target.id==selected.id: game.world.navigate(target.point,target); break,true,game.session.state.battle!=null)
		UIkit.action(detail,"返回"+game.db.location_title(game.session.story.return_scene()),Vector2(32,720),Vector2(542,58),func(): await game.travel_to(game.session.story.return_scene()),false,game.session.state.battle!=null)
		return
	for b in game.db.raw.buildings:
		if b.id==ui_state.selection: selected=b
	if selected.is_empty(): selected=game.db.raw.buildings[0]; ui_state.selection=selected.id; map.selected=selected.id
	UIkit.art(detail,game.db.raw.art.buildings[selected.id].path,Vector2(60,30),Vector2(486,245))
	UIkit.text(detail,selected.name,Vector2(32,300),Vector2(542,55),36,UIkit.GOLD)
	UIkit.text(detail,selected.description,Vector2(32,375),Vector2(542,132),24)
	UIkit.action(detail,"进入内室",Vector2(32,558),Vector2(542,58),func(): await game.travel_to("room-"+selected.id),true,game.session.state.battle!=null)
	UIkit.action(detail,"在城镇中定位",Vector2(32,630),Vector2(542,58),func(): await game.travel_to("town"); game.world.navigate(game.world.entry(selected),{"kind":"building","id":selected.id}),false,game.session.state.battle!=null)
	var route=game.db.raw.entrances.get(selected.id,"")
	if route in GameContent.ROUTES: UIkit.action(detail,"前往"+game.db.raw.scenes[route].title,Vector2(32,702),Vector2(542,58),func(): await game.travel_to(route),false,game.session.state.battle!=null)
	for i in GameContent.ROUTES.size():
		var route_id=GameContent.ROUTES[i]
		UIkit.action(root,game.db.raw.scenes[route_id].title,Vector2(24+i*367,718),Vector2(343,52),func(): game.seek("town","entrance",game.session.tasks.entrance_for(route_id).id),false,game.session.state.battle!=null)

func _world_map(root: Control, ui_state: Dictionary):
	var picture=UIkit.art(root,"res://assets/starlit-town/world-map.webp",Vector2(0,68),Vector2(1150,704),true)
	picture.stretch_mode=TextureRect.STRETCH_SCALE
	var positions={"town":Vector2(.48,.58),"wood":Vector2(.26,.32),"pass":Vector2(.73,.32),"fen":Vector2(.25,.73),"coast":Vector2(.75,.72),"city":Vector2(.50,.16)}
	for id in GameContent.OUTDOORS:
		var point=Vector2(0,68)+positions[id]*Vector2(1150,704)
		var button=UIkit.action(root,game.db.location_title(id),point-Vector2(85,25),Vector2(170,50),func(): ui_state.region=id; redraw("map"),true)
		button.add_theme_font_size_override("font_size",20); UIkit.selected(button,id==ui_state.region)
	var detail=UIkit.card(root,Vector2(1186,0),Vector2(606,788),Color(UIkit.PAPER,.9),UIkit.LINE)
	var id=ui_state.region
	UIkit.art(detail,"res://assets/loading/"+id+".webp",Vector2(30,32),Vector2(546,290),true)
	UIkit.text(detail,game.db.location_title(id),Vector2(32,350),Vector2(540,60),38)
	UIkit.text(detail,"当前所在地" if game.db.place_of(game.world.scene_id)==id else "六地归途 · 地区总览",Vector2(32,424),Vector2(540,40),23,UIkit.GOLD)
	UIkit.text(detail,"钟塔的第十三声，等待一个回答。" if id=="town" else game.db.regions[id].get("description","沿路探索地标，记录归途与见闻。"),Vector2(32,480),Vector2(540,124),24)
	UIkit.action(detail,"查看地区地图",Vector2(32,626),Vector2(542,60),func(): ui_state.category="region"; ui_state.selection=""; redraw("map"),true)
	UIkit.action(detail,"前往本区域" if game.world.scene_id!=id else "当前已抵达",Vector2(32,706),Vector2(542,58),func(): await game.travel_to(id),false,game.world.scene_id==id or game.session.state.battle!=null or game.session.state.training)

func _region_map(root: Control, ui_state: Dictionary):
	var id=ui_state.region; var region=game.db.regions[id]; var selected={}
	for building in region.buildings:
		if building.id==ui_state.selection: selected=building
	if selected.is_empty():
		selected=region.buildings.filter(func(b): return b.id==region.landmark)[0]; ui_state.selection=selected.id
	var map=RailMap.new(); map.scene_override=id; map.position=Vector2(0,55); map.size=Vector2(1150,650); map.selected=selected.id; root.add_child(map); map.setup(game)
	map.picked.connect(func(value): ui_state.selection=value; redraw("map"))
	UIkit.text(root,"滚轮缩放  /  拖动空白处平移  /  点击地标查看",Vector2(20,724),Vector2(1120,42),20,UIkit.MUTED)
	var detail=UIkit.canvas(root,Vector2(1186,0),Vector2(606,788))
	UIkit.art(detail,selected.art,Vector2(60,24),Vector2(486,250))
	UIkit.text(detail,region.title,Vector2(32,284),Vector2(542,36),22,UIkit.GOLD)
	UIkit.text(detail,selected.name,Vector2(32,333),Vector2(542,60),34)
	UIkit.text(detail,selected.description,Vector2(32,412),Vector2(542,123),23)
	var disabled=game.session.state.battle!=null or game.session.state.training
	UIkit.action(detail,"前往地标",Vector2(32,558),Vector2(542,58),func():
		if game.world.scene_id!=id: await game.travel_to(id)
		else: game.close_menu()
		for target in game.world.targets:
			if target.id==selected.id: game.world.navigate(target.point,target); break,true,disabled)
	UIkit.action(detail,"前往本区域" if game.world.scene_id!=id else "当前已抵达",Vector2(32,630),Vector2(542,58),func(): await game.travel_to(id),false,disabled or game.world.scene_id==id)
	UIkit.action(detail,"返回晨星镇",Vector2(32,702),Vector2(542,58),func(): await game.travel_to("town"),false,disabled)

func _shop(root: Control, subject: String = "hero"):
	var ui_state=state("shop",subject); var prices={"potion":28,"tonic":32,"revive":55,"supply":20,"bow":85,"ward":96}
	if subject=="forge": prices={"plate":150,"ember":165,"bracer":92}
	var discount=game.session.state.affinity.get("forge-master" if subject=="forge" else "shopkeeper",{}).get("value",0)>=60
	if discount:
		for key in prices: prices[key]=ceili(prices[key]*.9)
	if not prices.has(ui_state.selection): ui_state.selection=prices.keys()[0]
	var list=UIkit.scroll_at(root,Vector2(0,0),Vector2(810,788))
	for id in prices:
		var name=ITEM_NAMES.get(id,game.db.raw.items.get(id,{}).get("name",id))
		var node=UIkit.button(list,name+"\n金币  %d" % prices[id],func(): ui_state.selection=id; redraw("shop",subject)); node.custom_minimum_size.y=108; node.alignment=HORIZONTAL_ALIGNMENT_LEFT; UIkit.selected(node,id==ui_state.selection)
	var id=ui_state.selection; var detail=UIkit.card(root,Vector2(850,0),Vector2(942,788)); var art=UIkit.art(detail,ItemIcons.path(game.db,id),Vector2(301,30),Vector2(340,290))
	if art.texture==null: art.texture=UIkit.icon("potion" if id!="supply" else "backpack")
	UIkit.text(detail,ITEM_NAMES.get(id,game.db.raw.items.get(id,{}).get("name",id)),Vector2(40,354),Vector2(862,65),37,UIkit.GOLD)
	UIkit.text(detail,ITEM_TEXT.get(id,game.db.raw.items.get(id,{}).get("text","")),Vector2(40,450),Vector2(862,120),26)
	UIkit.text(detail,"单价  %d 金币" % prices[id],Vector2(40,612),Vector2(862,45),26,UIkit.GOLD)
	UIkit.action(detail,"购买 1 份",Vector2(40,686),Vector2(862,62),func(): menus._result(game.session.buy(id,subject),"shop",subject),true,game.session.state.gold<prices[id] or game.session.state.battle!=null)

func _saves(root: Control):
	UIkit.text(root,"旅程的记录",Vector2.ZERO,Vector2(1700,60),37,UIkit.GOLD)
	UIkit.text(root,BrowserFileBridge.save_notice() if BrowserFileBridge.is_browser() else "自动档与三个手动档独立保存。支持原生 JSON 导入导出。",Vector2(0,82),Vector2(1700,70 if BrowserFileBridge.is_browser() else 50),22 if BrowserFileBridge.is_browser() else 24,UIkit.MUTED)
	for slot in 4:
		var panel=UIkit.card(root,Vector2(slot*450,172),Vector2(428,400)); var exists=FileAccess.file_exists(game.store.path_for(slot)) or FileAccess.file_exists(game.store.path_for(slot)+".bak")
		UIkit.text(panel,"自动存档" if slot==0 else "手动存档  %d" % slot,Vector2(28,30),Vector2(372,60),30,UIkit.GOLD)
		UIkit.text(panel,"已有旅程记录" if exists else "尚无记录",Vector2(28,135),Vector2(372,80),25,UIkit.MUTED)
		UIkit.action(panel,"读取旅程",Vector2(28,252),Vector2(372,56),func(): game.load_continue(slot),true,not exists)
		if slot>0: UIkit.action(panel,"保存到此处",Vector2(28,326),Vector2(372,50),func(): menus._confirm("保存确认","将覆盖这个手动档；其他档位保留。",func(): menus._result(game.store.save(slot),"saves")),false,game.session.state.is_empty() or game.session.state.training)
	UIkit.action(root,"导出 JSON",Vector2(0,644),Vector2(430,62),func(): menus._file_dialog(true),false,game.session.state.is_empty() or game.session.state.training)
	UIkit.action(root,"导入 JSON",Vector2(454,644),Vector2(430,62),func(): menus._file_dialog(false))
	if not BrowserFileBridge.is_browser(): UIkit.action(root,"打开存档目录",Vector2(908,644),Vector2(430,62),func(): OS.shell_open(ProjectSettings.globalize_path(game.store.base_path)))

func _settings(root: Control):
	UIkit.text(root,"显示与操作",Vector2.ZERO,Vector2(1000,56),34,UIkit.GOLD)
	var body=UIkit.scroll_at(root,Vector2(330,0),Vector2(1462,788)); menus._settings(body)
	for i in 3: UIkit.text(root,["画面与声音","键鼠操作","旅程管理"][i],Vector2(0,110+i*82),Vector2(290,60),27,UIkit.INK if i==0 else UIkit.MUTED)

func _training(root: Control):
	var body=UIkit.scroll_at(root,Vector2(0,0),Vector2(1792,788)); menus._training(body)
