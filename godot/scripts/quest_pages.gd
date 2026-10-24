class_name QuestPages
extends RefCounted

var game
var runtime:
	get: return game.session.tasks
var story_pages:
	get: return game.menus.story_pages
const STATUS={"available":"可接取","active":"进行中","ready":"可交付","completed":"已完成"}

func _init(owner): game=owner

func build(kind: String,subject: String) -> bool:
	match kind:
		"journal": journal()
		"commission-board": board()
		"entrance": entrance(subject)
		"town-life": town_life(subject)
		_: return false
	return true

func task_entry(id: String, source: String = "") -> Dictionary:
	var d=runtime.definition(id); var status=runtime.status(id); var target=runtime.target(id)
	var giver=game.db.raw.npcs.get(d.giver,{}).get("name",game.db.building(d.giver).get("name","边境公会"))
	var progress="%d / %d" % [runtime.stage(id),runtime.goal(id)]
	if not d.get("materials",{}).is_empty():
		var amounts=[]
		for key in d.materials: amounts.append(("草药" if key=="herb" else "矿石")+" %d / %d" % [game.session.state.materials[key],d.materials[key]])
		progress=" · ".join(amounts)
	if status=="completed": progress="已交付（目标已完成）"
	var description=d.desc
	if id.begins_with("expeditions:") and status!="completed":
		var lines=[]; var routes=game.db.route_ids(d.region)
		for i in 3: lines.append(d.steps[i] if runtime.entrance_for(routes[i]).id in runtime.ledger.entrances else "寻找当地下一段入口线索。")
		description="\n".join(lines)
	var text=description+"\n\n委托人："+giver+"\n状态："+STATUS[status]+"\n进度："+progress+"\n奖励："+story_pages.rewards(d.get("reward",{}))
	if target.get("unknown",false): text+="\n\n下一段：寻找当地入口线索。"
	elif not target.is_empty(): text+="\n目标地点："+game.db.location_title(target.scene)
	if status=="ready": text+="\n\n请返回"+("公会委托板" if d.turnin=="board" else giver)+"交付。"
	var callback=Callable(); var label="定位目标"
	if status=="available" and source!="": label="接取委托"; callback=func(): game.toast(runtime.accept(id,source)); game.refresh_menu()
	elif status=="ready" and source==d.turnin: label="交付并领取奖励"; callback=func(): game.toast(runtime.turn_in(id,source)); game.refresh_menu()
	elif status not in ["completed","available"] and not target.is_empty(): callback=func(): locate(id)
	var entry=story_pages._entry(id,d.name,text,d.category,"",label,callback)
	entry.reward=d.get("reward",{}).duplicate(true)
	entry.completed=status=="completed"; entry.rank=0 if status=="ready" else 2 if status=="completed" else 1; entry.order=runtime.ledger.records.get(id,{}).get("order",99999)
	return entry

func sort_entries(entries: Array):
	entries.sort_custom(func(a,b): return a.rank<b.rank if a.rank!=b.rank else a.order<b.order)

func journal():
	var entries=[]; var s=game.session.state
	var main=story_pages._entry("main:prologue","归路与星钟","调查城墙巡径与旧城地下渠，带回星钟线索并完成公会试炼。\n\n"+("序章已完成。" if s.chapter_complete else "主线随剧情自动追踪。"),"主线","","追踪主线",func():
		var scene="town-wall" if not s.scene_progress.get("town-wall:survey",false) else "town-drain" if not s.scene_progress.get("town-drain:survey",false) else "town-trial"
		var e=runtime.entrance_for(scene); game.seek(e.region,"entrance",e.id))
	main.completed=s.chapter_complete; main.rank=2 if s.chapter_complete else 1; main.order=-2
	main.desc+="\n\n当前目标\n"+("✓  " if s.scene_progress.get("town-wall:survey",false) else "◇  ")+"调查城墙巡径\n"+("✓  " if s.scene_progress.get("town-drain:survey",false) else "◇  ")+"调查旧城地下渠\n"+("✓  " if s.chapter_complete else "◇  ")+"完成公会试炼"
	if main.completed: main.callback=Callable()
	entries.append(main)
	if s.chapter_complete:
		var complete=int(s.story.stage)>=8; var d=game.db.narrative.quests.stars
		var e=story_pages._entry("main:stars",d.name,d.desc+"\n\n阶段：%d / 8" % s.story.stage,"主线","" if complete else story_pages.main_target())
		e.completed=complete; e.rank=2 if complete else 1; e.order=-1; entries.append(e)
	if int(s.story.stage)>=8:
		var finished=s.story.events.get("epilogue",false)
		var e=story_pages._entry("main:epilogue","归灯之后","五地调查的剧情事实会独立记录。找到各地线索并核对当地行动，最后前往钟塔调查机芯，再与米拉交谈。","主线","" if finished else "room-clocktower")
		e.completed=finished; e.rank=2 if finished else 1; e.order=-1; entries.append(e)
	for id in runtime.ledger.records: entries.append(task_entry(id))
	for id in s.story.awakenings:
		var stage=int(s.story.awakenings[id].stage)
		if stage==0: continue
		var d=game.db.progression.ultimates[id]
		var e=story_pages._entry("awakening:"+id,d.title,game.session.progression.status(id)+"\n\n"+d.desc,"觉醒","","追踪觉醒故事",func(): game.open_menu("awakening",id))
		if stage==4: e.label="查看觉醒记录"
		if stage==3: e.desc="可交付 · 完成收束交谈\n\n"+e.desc
		e.completed=stage==4; e.rank=2 if stage==4 else 0 if stage==3 else 1; e.order=s.story.awakenings[id].get("order",10000); entries.append(e)
	sort_entries(entries)
	var log=story_pages._entry("log","旅途日志","\n\n".join(s.log),"记录"); log.completed=false; entries.append(log)
	story_pages.collection("journal","旅途记录",entries,["全部","主线","居民","战斗","采集","探索","个人","研究","觉醒","记录"])

func board():
	var entries=[]
	for id in runtime.catalog:
		if runtime.catalog[id].get("board",false) and runtime.published(id): entries.append(task_entry(id,"board"))
	sort_entries(entries)
	story_pages.collection("commission-board","公会委托板",entries,["全部","战斗","居民","采集","探索"])

func locate(id: String):
	var target=runtime.target(id)
	if target.is_empty(): return
	runtime.ledger.tracked=id
	if target.get("unknown",false):
		game.menus.pages.state("map").region=target.scene; game.open_menu("map"); game.toast("下一段尚未发现，请在当地寻找入口线索。"); return
	game.seek(target.scene,target.kind,target.id)

func entrance(id: String):
	var e=runtime.entrance(id)
	if e.is_empty(): return
	var root=game.menus.pages.shell(e.name); var body=UIkit.scroll_at(root,Vector2(80,30),Vector2(1580,730))
	UIkit.label(body,game.db.location_title(e.region)+"  /  探索入口",24,UIkit.GOLD)
	UIkit.label(body,game.db.location_title(e.scene),42)
	UIkit.label(body,"入口发现只发布调查，不会替你接取。可以先自由探索，接取后的目标才计入委托。",27)
	var task="expeditions:"+e.region
	if runtime.published(task):
		UIkit.label(body,runtime.definition(task).name+" · "+STATUS[runtime.status(task)],28,UIkit.GOLD)
		if not runtime.accepted(task): UIkit.button(body,"接取连续调查",func(): game.toast(runtime.accept(task,id)); game.refresh_menu())
		else: UIkit.label(body,"调查进度 %d / 3 · 完成后返回委托人交付" % runtime.stage(task),25)
	UIkit.label(body,"路线已开放。" if runtime.entrance_unlocked(e) else "先调查上一段路线，才能打开这里的通道。",25)
	UIkit.button(body,"进入 · "+game.db.location_title(e.scene),func(): await game.travel_to(e.scene),not runtime.entrance_unlocked(e) or e.id not in runtime.ledger.entrances)

func npc_options(id: String,options: Array,callbacks: Array):
	for task in runtime.catalog:
		var d=runtime.definition(task)
		if d.giver!=id or not runtime.published(task) or runtime.status(task)=="completed": continue
		var status=runtime.status(task)
		options.append({"text":STATUS[status]+" · "+d.name,"disabled":status=="active"})
		callbacks.append(func():
			if runtime.status(task)=="ready" and d.turnin=="board": game.open_menu("commission-board"); return
			game.toast(runtime.turn_in(task,id) if runtime.status(task)=="ready" else runtime.accept(task,id)); game.refresh_menu())

func town_life(id: String):
	var title="街角小事"; var text="观察身边的小小日常。"; var path=""
	var animal=false; var resource=false
	for d in game.db.world_interactions.animals:
		if d.id==id: title=d.name+" · "+d.species; path=d.frames[0]; animal=true
	for d in game.db.world_interactions.objects:
		if d.id==id: title=d.name; text=d.text
	for d in game.db.world_interactions.resources:
		if d.id==id: title=d.name; resource=true; text="已采集；这一份材料不会重复出现。" if runtime.ledger.town.get(id,false) else "可采集一份材料。"
	var root=game.menus.pages.shell(title); var body=UIkit.scroll_at(root,Vector2(650 if animal else 100,40),Vector2(1040 if animal else 1580,720))
	if animal: UIkit.art(root,path,Vector2(80,80),Vector2(480,480))
	UIkit.label(body,title,40,UIkit.GOLD); UIkit.label(body,text,28)
	if animal:
		UIkit.button(body,"观察",func(): game.toast(runtime.town_action(id,"observe")))
		UIkit.button(body,"轻轻抚摸",func(): game.toast(runtime.town_action(id,"pet")))
	if resource:
		UIkit.button(body,"采集",func(): game.toast(runtime.town_action(id,"gather")); game.refresh_menu(),runtime.ledger.town.get(id,false)); return
	for task in runtime.ledger.records:
		var d=runtime.definition(task)
		if runtime.status(task)!="active" or not task.begins_with("resident:"): continue
		var step=d.steps[runtime.stage(task)]
		if step.target==id: UIkit.button(body,"委托互动 · "+d.name,func(): game.toast(runtime.town_action(id,"task")); game.refresh_menu())
