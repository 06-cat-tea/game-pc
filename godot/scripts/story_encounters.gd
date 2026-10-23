class_name StoryEncounters
extends RefCounted

static func install(db):
	for place in db.narrative.routes:
		if place=="town": continue
		for route in db.narrative.routes[place]:
			var id=route[0]; var scene=db.raw.scenes[id]; var level=int(scene.level); var foes=[]
			for i in (2 if scene.index==0 else 3):
				foes.append({"name":db.narrative.enemyNames[place][i%2]+(" · 护卫" if i==1 else " · 巫医" if i==2 else ""),"art":enemy_art(place,i),"hp":50+level*12,"atk":ceili((12+level*2)*(.85 if scene.index==0 else .8)),"def":int(level/3),"speed":10+i,"role":"guard" if i==1 else "healer" if i==2 else "striker","slot":i if i<2 else 3,"weakness":role_weakness(place,i),"affinity":role_affinity(place,i)})
			_add(db,id+"-0",id,scene.title+" · 警戒敌群",100+level*65,40+level*6,foes,{"scene":id})
	for id in db.narrative.challenges:
		var c=db.narrative.challenges[id]; var place=c.place; var route=db.route_ids(place)[2]
		var enemy={"name":c.name,"art":enemy_art(place,2),"hp":int(c.hp),"atk":int(c.power),"def":int(c.level/2),"speed":10,"boss":c.get("boss",false),"elite":true,"summoner":c.get("summoner",false),"slot":0,"weakness":role_weakness(place,2),"affinity":role_affinity(place,2)}
		var budget=BattleRules.config().challenge_budget; var boss=c.get("boss",false)
		enemy.hp=ceili(enemy.hp*float(budget.boss_hp if boss else budget.elite_hp))
		enemy.atk=ceili(enemy.atk*float(budget.boss_attack if boss else budget.elite_attack))
		enemy.weakness={"town":["fire","astral"],"wood":["astral","poison"],"pass":["holy","fire"],"fen":["holy","physical"],"coast":["astral","fire"]}[place]
		enemy.pressure=not boss
		enemy.attack_element={"burn":"fire","poison":"poison","vulnerable":"astral","shield":"physical"}.get(c.get("status","shield"),"physical")
		var squad=[enemy]
		if boss:
			squad.append({"name":"誓阵护卫","art":"knight","hp":65+int(c.level)*18,"atk":8+int(c.level)*2,"def":3+int(c.level/3),"speed":14,"role":"guard","slot":1,"weakness":["astral","physical"],"affinity":"holy"})
			squad.append({"name":"回响司祭","art":"eclipse-priest","hp":45+int(c.level)*14,"atk":10+int(c.level)*2,"def":2,"speed":13,"role":"healer","ranged":true,"slot":3,"weakness":["holy","poison"],"affinity":"poison"})
		else:
			squad.append({"name":"侧翼弩手","art":"smuggler","hp":35+int(c.level)*12,"atk":8+int(c.level)*3,"def":2,"speed":14,"ranged":true,"slot":3,"weakness":["holy","fire"],"affinity":"astral"})
		_add(db,id,route,c.name,c.xp,int((c.gold[0]+c.gold[1])/2),squad,{"challenge":id})
	for place in ["wood","pass","fen","coast"]:
		var pool=db.narrative.enemies[place]; var foes=[]
		for i in 2:
			var e=pool[i%pool.size()]
			foes.append({"name":e.name,"art":enemy_art(place,i),"hp":int(e.hp),"atk":int(e.power),"def":2,"speed":11+i,"slot":i,"weakness":weakness(place)})
		_add(db,"roam-"+place,place,db.location_title(place)+" · 旅途遭遇",70,35,foes,{"roam":place})
		for index in pool.size():
			var source=pool[index]
			for elite in [false,true]:
				var art={"wood":["wolf","treant","deer"],"pass":["raider","lava-beast","knight"],"fen":["eclipse-priest","golem","prince"],"coast":["smuggler","crab"]}[place][index]
				var enemy={"name":source.name,"art":art,"hp":int(source.hp)+(16 if elite else 0),"atk":int(source.power)+(3 if elite else 0),"def":2,"speed":11,"slot":0,"elite":elite,"weakness":weakness(place)}
				_add(db,("roamelite-" if elite else "roam-")+place+"-"+str(index),place,source.name,source.xp,int((source.gold[0]+source.gold[1])/2),[enemy],{"roam":place,"loot":source.get("loot",[]),"gold_range":source.gold})
	_add(db,"activity-temple","fen","沉没神殿 · 守门人",140,70,[{"name":"沉星王朝守卫","art":"golem","hp":220,"atk":25,"def":5,"speed":10,"slot":0,"elite":true,"weakness":["holy","fire"]}],{"on_win":"temple"})

static func _add(db,id,route,title,xp,gold,enemies,meta):
	db.encounters[id]=EncounterDefinition.from_data(id,{"route":route,"title":title,"xp":xp,"gold":gold,"enemies":enemies,"lesson":"观察护卫与治疗者，选择你的集火目标。"})
	db.encounters[id].story=meta

static func enemy_art(place: String, index: int) -> String:
	return {"town":["raider","knight","commander"],"wood":["wolf","eclipse-priest","golem"],"pass":["raider","sentinel","golem"],"fen":["sentinel","sorceress","golem"],"coast":["smuggler","crab","commander"]}[place][index%3]

static func weakness(place: String) -> Array:
	return {"town":["fire","astral"],"wood":["fire","physical"],"pass":["astral","poison"],"fen":["holy","fire"],"coast":["astral","physical"]}[place]

static func role_weakness(place: String, index: int) -> Array:
	var base=weakness(place); var elements=["physical","fire","astral","holy","poison"]
	var first=base[index%base.size()]; var second=(index+GameContent.OUTDOORS.find(place)+2)%5
	if elements[second]==first: second=(second+1)%5
	return [first,elements[second]]

static func role_affinity(place: String, index: int) -> String:
	return ["physical","fire","astral","holy","poison"][(index+maxi(0,GameContent.OUTDOORS.find(place)))%5]
