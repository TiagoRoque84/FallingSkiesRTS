extends RefCounted

const Catalog = preload("res://src/catalog.gd")
const MapData = preload("res://src/battle_map.gd")
const Cheats = preload("res://src/cheats.gd")
const CommanderAI = preload("res://src/commander_ai.gd")
signal notice(text: String, sound: String)
signal ended(winner: int)
var catalog = Catalog.new()
var cheats = Cheats.new()
var map
var config: Dictionary
var teams: Array = []
var entities: Array = []
var by_id: Dictionary = {}
var effects: Array = []
var strikes: Array = []
var zones: Array = []
var ai_agents: Array = []
var vision: Array = []
var explored: Array = []
var memory: Array = []
var buckets: Dictionary = {}
var clock = 0.0
var finished = false
var winner = -2
var next_id = 1
var pop_limit = 60
var rng = RandomNumberGenerator.new()
var vision_timer = 0.0
var alert_timer = 0.0
var ai_slot = 0
var tick_count = 0
var profile={}
var vision_cursor=0
var support_timer=0.0
var points_timer=0.0
var building_cache_dirty=true
var building_cache: Array=[]

func start(options: Dictionary):
	config=options.duplicate(true)
	config.enemies=clampi(config.enemies,1,int(catalog.maps[config.map].max_enemies))
	rng.seed=config.get("seed",83421)
	map=MapData.new()
	map.generate(catalog.maps[config.map],config.enemies+1,int(rng.seed))
	cheats.reset(config.get("cheats",false))
	pop_limit=mini(60,int(270/(config.enemies+1)))
	for i in config.enemies+1:
		var f=int(config.faction) if i==0 else int(config.get("enemy_factions",[])[i-1])
		if f<0: f=rng.randi_range(0,2)
		var col=int(config.color) if i==0 else int(config.get("enemy_colors",[])[i-1])
		teams.append({"faction":f,"color":col,"money":float(config.resources),"power":0.0,"use":0.0,"alive":true,"collected":0.0,"spent":0.0,"produced":0,"lost":0,"kills":0,"hero_ready":0.0,"super_charge":0.0,"super_warned":false,"upgrade":false,"domination":0.0,"research":0.0})
		var field=PackedByteArray(); field.resize(map.cells*map.cells)
		vision.append(field.duplicate()); explored.append(field.duplicate()); memory.append({})
		spawn("mcv",i,map.starts[i])
		for n in 3: spawn("rifle",i,map.starts[i]+Vector2(60+n*30,85))
		spawn("scout",i,map.starts[i]+Vector2(25,120))
		if i>0: ai_agents.append(CommanderAI.new(self,i))
	if config.get("neutrals",false):
		for point in map.points:
			for n in 2: spawn("rifle",-1,point.p+Vector2(65+n*25,65))
	update_vision()
	rebuild_buckets()
	notice.emit("Selecione seu comando móvel e pressione D para implantar a base.","ready")

func spawn(kind: String,owner: int,p: Vector2,construction: bool=false) -> Dictionary:
	var faction=teams[owner].faction if owner>=0 else 1
	var d=catalog.definition(kind,faction)
	var building=catalog.buildings.has(kind)
	var e={"id":next_id,"kind":kind,"owner":owner,"p":map.walkable(p),"hp":float(d.hp),"max_hp":float(d.hp),"d":d,"building":building,"order":"idle","target":0,"goal":p,"path":PackedVector2Array(),"cool":0.0,"scan":rng.randf()*.4,"angle":0.0,"cargo":0.0,"deposit":-1,"queue":[],"rally":p+Vector2(0,115),"build":float(d.time) if construction else 0.0,"disabled":0.0,"ability":0.0,"garrison":-1,"patrol_a":p,"patrol_b":p,"state":"idle","converted_until":0.0,"original_owner":owner,"last_hit":-100.0,"buff":false}
	next_id+=1
	entities.append(e); by_id[e.id]=e
	if building: map.set_building(e.p,true); building_cache_dirty=true
	if not building and owner>=0 and kind!="mcv": teams[owner].produced+=1
	return e

func get_entity(id: int) -> Dictionary:
	return by_id.get(id,{})

func hostile(a: int,b: int) -> bool:
	if a==b: return false
	if a<0 or b<0: return true
	return not (config.get("coalition",false) and a>0 and b>0)

func own(owner: int,kind: String="") -> Array:
	return entities.filter(func(e): return e.owner==owner and e.hp>0 and (kind=="" or e.kind==kind))

func has_building(owner: int,kind: String) -> bool:
	if building_cache_dirty:
		building_cache.clear()
		for team in teams: building_cache.append({})
		for e in entities:
			if e.building and e.owner>=0 and e.build<=0 and e.hp>0:
				building_cache[e.owner][e.kind]=building_cache[e.owner].get(e.kind,0)+1
		building_cache_dirty=false
	return owner>=0 and owner<building_cache.size() and building_cache[owner].get(kind,0)>0

func population(owner: int,include_queued: bool=true) -> int:
	var n=0
	for e in entities:
		if e.owner!=owner and e.original_owner==owner and e.converted_until>0 and e.hp>0: n+=1
		if e.owner!=owner or e.hp<=0: continue
		if not e.building: n+=1
		if include_queued: n+=e.queue.size()
	return n

func pay(owner: int,amount: float) -> bool:
	if cheats.active("resources",owner): return true
	if teams[owner].money<amount: return false
	teams[owner].money-=amount
	teams[owner].spent+=amount
	return true

func energy_factor(owner: int) -> float:
	return 1.0 if teams[owner].power>=teams[owner].use else .3

func update_economy(dt: float):
	for team in teams: team.power=0.0; team.use=0.0
	for e in entities:
		if not e.building or e.owner<0 or e.hp<=0 or e.build>0 or e.disabled>0: continue
		var power=e.d.get("power",0)
		if power>0: teams[e.owner].power+=power
		else: teams[e.owner].use-=power
	for i in teams.size():
		var team=teams[i]
		team.hero_ready=maxf(0,team.hero_ready-dt)
		if team.research>0:
			team.research-=dt*energy_factor(i) if has_building(i,"lab") else 0.0
			if team.research<=0: team.upgrade=true; say(i,"Pesquisa concluída: dano +15%.","ready")
		if has_building(i,"super") and energy_factor(i)==1:
			team.super_charge=minf(weapon_reload(i),team.super_charge+dt)
			if team.super_charge>=weapon_reload(i)-20 and not team.super_warned:
				team.super_warned=true
				for e in own(i,"super"):
					for viewer in teams.size(): memory[viewer][e.id]={"p":e.p,"kind":e.kind,"owner":i}
				notice.emit("ALERTA: superarma de %s quase pronta!" % team_name(i),"alert")
		if cheats.active("superweapon",i): team.super_charge=weapon_reload(i)
	if config.get("regenerate",false):
		for d in map.deposits: d.amount=minf(d.max,d.amount+dt*2)

func team_name(owner: int) -> String:
	if owner<0: return "Patrulha neutra"
	return ("Você" if owner==0 else "IA %d" % owner)+" · "+catalog.factions[teams[owner].faction].short

func deploy(id: int) -> bool:
	var e=get_entity(id)
	if e.is_empty() or e.kind!="mcv": return false
	var owner=e.owner
	var p=e.p
	remove_entity(e,false)
	spawn("hq",owner,p)
	spawn("worker",owner,p+Vector2(-80,80))
	say(owner,"Base implantada. Construa um gerador e um depósito.","ready")
	return true

func build_error(owner: int,kind: String,p: Vector2) -> String:
	if not catalog.buildings.has(kind) or kind=="hq": return "Construção inválida."
	var d=catalog.definition(kind,teams[owner].faction)
	if kind=="super" and not config.get("superweapons",true): return "Superarmas desativadas nesta partida."
	if kind=="super" and not own(owner,kind).is_empty(): return "Somente uma superarma por comandante."
	if not has_building(owner,"hq"): return "Implante primeiro o comando móvel (D)."
	if d.has("requires") and not has_building(owner,d.requires): return "Requer "+catalog.definition(d.requires,teams[owner].faction).name+"."
	if not cheats.active("resources",owner) and teams[owner].money<d.cost: return "Suprimentos insuficientes."
	if not visible(owner,p): return "Explore a área antes de construir."
	if p.x<64 or p.y<64 or p.x>map.size-64 or p.y>map.size-64 or map.at(p)==3: return "Terreno bloqueado."
	var near=false
	for e in entities:
		if e.hp<=0: continue
		if e.building and e.p.distance_to(p)<e.d.radius+d.radius+28: return "Espaço ocupado."
		if e.owner==owner and e.building and e.build<=0 and e.p.distance_to(p)<470: near=true
	for dpt in map.deposits:
		if dpt.p.distance_to(p)<95: return "Deixe acesso ao depósito de recursos."
	for point in map.points:
		if point.p.distance_to(p)<85: return "Área de captura reservada."
	return "" if near else "Construa a até 470 m de uma estrutura pronta."

func build(owner: int,kind: String,p: Vector2) -> bool:
	var error=build_error(owner,kind,p)
	if error!="": say(owner,error,"select"); return false
	var d=catalog.definition(kind,teams[owner].faction)
	if not pay(owner,d.cost): return false
	spawn(kind,owner,p,true)
	say(owner,"Construindo "+d.name+".","order")
	return true

func train(owner: int,kind: String,producer_id: int=0) -> bool:
	if not catalog.units.has(kind) or kind=="mcv": return false
	var d=catalog.definition(kind,teams[owner].faction)
	if population(owner)>=pop_limit: say(owner,"Limite de população atingido.","select"); return false
	if d.has("requires") and not has_building(owner,d.requires): say(owner,"Requer "+catalog.definition(d.requires,teams[owner].faction).name+".","select"); return false
	if kind=="hero":
		if not own(owner,"hero").is_empty() or teams[owner].hero_ready>0: say(owner,"Herói ativo ou em recuperação.","select"); return false
		for e in own(owner):
			for q in e.queue:
				if q.kind=="hero": return false
	var producers=own(owner,d.producer).filter(func(e): return e.build<=0 and e.queue.size()<8)
	if producers.is_empty(): say(owner,"Construa "+catalog.definition(d.producer,teams[owner].faction).name+" ou libere sua fila.","select"); return false
	producers.sort_custom(func(a,b): return a.queue.size()<b.queue.size())
	var producer=producers[0]
	if producer_id!=0:
		for e in producers:
			if e.id==producer_id: producer=e
	if not pay(owner,d.cost): say(owner,"Suprimentos insuficientes.","select"); return false
	producer.queue.append({"kind":kind,"left":float(d.time),"total":float(d.time),"paid":0 if cheats.active("resources",owner) else d.cost})
	return true

func cancel_queue(id: int):
	var e=get_entity(id)
	if e.is_empty() or e.owner!=0 or e.queue.is_empty(): return
	var q=e.queue.pop_back()
	teams[0].money+=q.paid
	teams[0].spent-=q.paid

func research(owner: int) -> bool:
	if teams[owner].upgrade or teams[owner].research>0 or not has_building(owner,"lab"): return false
	if not pay(owner,500): return false
	teams[owner].research=35.0
	return true

func tick(dt: float):
	if finished: return
	var section=Time.get_ticks_usec()
	clock+=dt; tick_count+=1; alert_timer=maxf(0,alert_timer-dt)
	update_economy(dt)
	rebuild_buckets()
	support_timer-=dt
	if support_timer<=0:
		for e in entities: e.buff=false
		for hero in entities:
			if hero.kind=="hero":
				for friend in nearby(hero.p,180):
					if friend.owner==hero.owner and friend.id!=hero.id: friend.buff=true
		support_timer=.5
	vision_timer-=dt
	if vision_timer<=0:
		update_vision_owner(vision_cursor)
		vision_cursor=(vision_cursor+1)%teams.size()
		vision_timer=.05
	profile.setup_ms=(Time.get_ticks_usec()-section)/1000.0; section=Time.get_ticks_usec()
	for e in entities.duplicate():
		if e.hp<=0: continue
		e.cool=maxf(0,e.cool-dt); e.disabled=maxf(0,e.disabled-dt); e.ability=maxf(0,e.ability-dt)
		if e.converted_until>0 and clock>=e.converted_until:
			e.owner=e.original_owner; e.converted_until=0; e.target=0
		if e.build>0:
			e.build=maxf(0,e.build-dt*energy_factor(e.owner))
			if e.build==0:
				building_cache_dirty=true
				say(e.owner,e.d.name+" concluído.","ready")
				if e.kind=="refinery" and population(e.owner)<pop_limit: spawn("worker",e.owner,e.p+Vector2(75,60))
			continue
		if e.disabled>0: continue
		if e.building:
			if not e.queue.is_empty():
				var q=e.queue[0]; q.left-=dt*energy_factor(e.owner)
				if q.left<=0:
					var u=spawn(q.kind,e.owner,e.p+Vector2(0,75))
					move_order(u,e.rally,"move")
					e.queue.pop_front(); say(e.owner,u.d.name+" pronto.","ready")
			if e.kind=="hospital" and e.cool<=0 and energy_factor(e.owner)==1:
				for friend in nearby(e.p,210):
					if friend.owner==e.owner and not friend.building and friend.d.biological: friend.hp=minf(friend.max_hp,friend.hp+8)
				e.cool=1.0
			if e.kind!="turret" or energy_factor(e.owner)<1: continue
		if e.kind=="worker": update_worker(e,dt); continue
		if e.kind=="mcv": move_unit(e,dt); continue
		update_support(e,dt)
		update_combat(e,dt)
		if not e.building: move_unit(e,dt)
	profile.units_ms=(Time.get_ticks_usec()-section)/1000.0; section=Time.get_ticks_usec()
	for e in entities.duplicate():
		if e.hp<=0: remove_entity(e,true)
	for agent in ai_agents: agent.update(dt)
	update_superweapons(dt)
	points_timer+=dt
	if points_timer>=.25: update_points(points_timer); points_timer=0.0
	for fx in effects: fx.life-=dt
	effects=effects.filter(func(fx): return fx.life>0)
	if effects.size()>220: effects=effects.slice(effects.size()-220)
	check_end()
	profile.other_ms=(Time.get_ticks_usec()-section)/1000.0

func rebuild_buckets():
	buckets.clear()
	for e in entities:
		if e.hp<=0: continue
		var c=Vector2i(e.p/160)
		if not buckets.has(c): buckets[c]=[]
		buckets[c].append(e)

func nearby(p: Vector2,radius: float) -> Array:
	var result=[]
	var a=Vector2i((p-Vector2.ONE*radius)/160)
	var b=Vector2i((p+Vector2.ONE*radius)/160)
	for y in range(a.y,b.y+1):
		for x in range(a.x,b.x+1):
			for e in buckets.get(Vector2i(x,y),[]):
				if e.hp>0 and e.p.distance_squared_to(p)<=radius*radius: result.append(e)
	return result

func update_vision():
	for owner in teams.size(): update_vision_owner(owner)

func update_vision_owner(owner: int):
	var current: PackedByteArray=vision[owner]
	var known: PackedByteArray=explored[owner]
	current.fill(0)
	for e in entities:
		if e.owner!=owner or e.hp<=0: continue
		var radius=e.d.sight if e.build<=0 else 160
		var c=map.cell(e.p); var r=int(radius/map.CELL)+1
		for y in range(maxi(0,c.y-r),mini(map.cells,c.y+r+1)):
			for x in range(maxi(0,c.x-r),mini(map.cells,c.x+r+1)):
				if Vector2(x-c.x,y-c.y).length_squared()<=r*r:
					current[y*map.cells+x]=1; known[y*map.cells+x]=1
	vision[owner]=current; explored[owner]=known
	for id in memory[owner].keys():
		var old=memory[owner][id]
		if visible(owner,old.p): memory[owner].erase(id)
	for e in entities:
		if e.building and hostile(owner,e.owner) and visible(owner,e.p): memory[owner][e.id]={"p":e.p,"kind":e.kind,"owner":e.owner}

func visible(owner: int,p: Vector2) -> bool:
	if owner<0: return true
	if cheats.active("reveal",owner): return true
	var c=map.cell(p)
	return vision[owner][c.y*map.cells+c.x]==1

func seen(owner: int,p: Vector2) -> bool:
	if cheats.active("reveal",owner): return true
	var c=map.cell(p)
	return explored[owner][c.y*map.cells+c.x]==1

func move_order(e: Dictionary,p: Vector2,mode: String):
	if e.building: e.rally=map.walkable(p); return
	if e.garrison>=0: map.ruins[e.garrison].occupant=0; e.garrison=-1
	e.order=mode; e.state="moving"; e.target=0; e.goal=map.walkable(p)
	e.path=map.path(e.p,e.goal)
	if mode=="patrol": e.patrol_a=e.p; e.patrol_b=e.goal

func command(ids: Array,p: Vector2,mode: String="context",target_id: int=0):
	var target=get_entity(target_id)
	var index=0
	for id in ids:
		var e=get_entity(id)
		if e.is_empty() or e.owner!=0: continue
		if mode=="stop" or mode=="hold":
			e.order=mode; e.path.clear(); e.target=0; e.state="idle"; continue
		if mode=="context" and e.kind=="worker":
			var nearest=nearest_deposit(e.owner,p)
			if not nearest.is_empty() and nearest.p.distance_to(p)<100:
				e.deposit=nearest.id; e.order="gather"; e.target=0; e.path.clear(); continue
		if not target.is_empty() and hostile(e.owner,target.owner) and visible(e.owner,target.p):
			e.target=target.id; e.order="attack"; e.path=map.path(e.p,target.p); continue
		if mode=="context" and e.d.get("biological",false):
			var occupied=false
			for n in map.ruins.size():
				if map.ruins[n].p.distance_to(p)<40 and map.ruins[n].occupant==0:
					e.order="garrison"; e.goal=map.ruins[n].p; e.path=map.path(e.p,p); e.target=-(n+1); occupied=true; break
			if occupied: continue
		var offset=Vector2((index%5-2)*27,(index/5)*27)
		move_order(e,p+offset,"move" if mode=="context" else mode)
		index+=1

func move_unit(e: Dictionary,dt: float):
	if e.garrison>=0 or e.order in ["hold","stop"]: return
	if e.target>0:
		var target=get_entity(e.target)
		if not target.is_empty() and visible(e.owner,target.p) and e.p.distance_to(target.p)<=e.d.range+target.d.radius: return
	if e.path.is_empty():
		if e.order=="patrol":
			var dest=e.patrol_b if e.p.distance_to(e.patrol_a)<60 else e.patrol_a
			e.path=map.path(e.p,dest)
		elif e.order=="garrison" and e.target<0:
			var n=-e.target-1
			if map.ruins[n].occupant==0 and e.p.distance_to(map.ruins[n].p)<110:
				e.garrison=n; map.ruins[n].occupant=e.id; e.p=map.ruins[n].p; e.target=0; e.order="hold"
		else: e.state="idle"
		return
	var dest=e.path[0]
	var delta: Vector2=dest-e.p
	var speed=e.d.speed*(.72 if map.at(e.p)==1 else 1.0)
	if map.at(e.p)==2: speed*=1.12
	if delta.length()<maxf(6,speed*dt): e.p=dest; e.path.remove_at(0); return
	var direction=delta.normalized()
	var separation=Vector2.ZERO
	for other in nearby(e.p,28):
		if other.id==e.id or other.building or other.garrison>=0: continue
		var gap: Vector2=e.p-other.p
		if gap.length_squared()<1: gap=Vector2.from_angle(e.id)
		separation+=gap.normalized()*(1-minf(1,gap.length()/28))
	var next=e.p+(direction+separation*.6).normalized()*speed*dt
	if not map.nav.is_point_solid(map.cell(next)): e.p=next
	else:
		e.path=map.path(e.p,e.goal if e.target<=0 else dest)
	e.angle=direction.angle(); e.state="moving"
	for crate in map.crates:
		if crate.amount>0 and e.owner>=0 and e.p.distance_to(crate.p)<40:
			teams[e.owner].money+=crate.amount; teams[e.owner].collected+=crate.amount; crate.amount=0
			say(e.owner,"Esconderijo encontrado: +180 suprimentos.","ready")

func nearest_deposit(owner: int,p: Vector2) -> Dictionary:
	var result={}; var distance=INF
	for d in map.deposits:
		if d.amount<=0 or not visible(owner,d.p): continue
		var dist=p.distance_squared_to(d.p)
		if dist<distance: result=d; distance=dist
	return result

func update_worker(e: Dictionary,dt: float):
	if e.order in ["hold","stop"]: return
	if e.order=="move" and not e.path.is_empty(): move_unit(e,dt); return
	var dep: Dictionary={}
	if e.deposit>=0: dep=map.deposits[e.deposit]
	if dep.is_empty() or dep.amount<=0:
		dep=nearest_deposit(e.owner,e.p); e.deposit=dep.get("id",-1)
	var goal: Vector2=e.p
	if e.cargo>=90 or (e.cargo>0 and dep.is_empty()):
		var refineries=own(e.owner,"refinery").filter(func(x):return x.build<=0)
		if refineries.is_empty(): return
		refineries.sort_custom(func(a,b):return a.p.distance_squared_to(e.p)<b.p.distance_squared_to(e.p))
		goal=refineries[0].p+Vector2(0,65)
		if e.p.distance_to(goal)<65:
			teams[e.owner].money+=e.cargo; teams[e.owner].collected+=e.cargo
			e.cargo=0; e.path.clear(); e.state="gathering"; return
		e.state="returning"
	elif not dep.is_empty():
		goal=dep.p
		if e.p.distance_to(goal)<60:
			var amount=minf(minf(90-e.cargo,dep.amount),dt*23)
			e.cargo+=amount; dep.amount-=amount; e.path.clear(); e.state="gathering"; return
	else: return
	if e.path.is_empty(): e.path=map.path(e.p,goal); e.goal=goal
	e.order="gather"
	move_unit(e,dt)

func update_support(e: Dictionary,dt: float):
	if e.kind=="medic" and e.cool<=0:
		for ally in nearby(e.p,155):
			if ally.owner==e.owner and not ally.building and ally.d.biological and ally.hp<ally.max_hp:
				ally.hp=minf(ally.max_hp,ally.hp+e.d.heal); e.cool=1.0
				effects.append({"type":"heal","p":ally.p,"life":.4,"max":.4}); break
	if e.kind=="engineer" and e.cool<=0:
		for ally in nearby(e.p,85):
			if ally.owner==e.owner and ally.hp<ally.max_hp: ally.hp=minf(ally.max_hp,ally.hp+20); e.cool=1.0; break
		var target=get_entity(e.target)
		if not target.is_empty() and target.building and e.p.distance_to(target.p)<110 and target.hp<target.max_hp*.35 and not cheats.active("invincible",target.owner):
			if target.kind!="hq" and population(e.owner)<pop_limit and (target.kind!="super" or own(e.owner,"super").is_empty()):
				target.owner=e.owner; target.queue.clear(); e.target=0; e.order="idle"; building_cache_dirty=true
				say(e.owner,"Estrutura capturada.","ready")
	if e.kind=="elite" and e.owner>=0 and teams[e.owner].faction==1 and clock-e.last_hit>5: e.hp=minf(e.max_hp,e.hp+dt*5)

func update_combat(e: Dictionary,dt: float):
	if e.d.damage<=0 or e.order=="garrison": return
	e.scan-=dt
	var target=get_entity(e.target)
	if target.is_empty() or target.hp<=0 or not hostile(e.owner,target.owner) or not visible(e.owner,target.p):
		e.target=0; target={}
	if e.scan<=0:
		e.scan=.4+rng.randf()*.12
		var best_distance=INF
		if e.order!="move" and (target.is_empty() or e.order!="attack"):
			for enemy in nearby(e.p,e.d.range+80):
				if not hostile(e.owner,enemy.owner) or not visible(e.owner,enemy.p): continue
				var distance=e.p.distance_squared_to(enemy.p)
				if distance<best_distance: target=enemy; best_distance=distance
			if not target.is_empty(): e.target=target.id
		if not target.is_empty() and not e.building and e.order not in ["hold","stop","move"] and e.garrison<0:
			if e.p.distance_to(target.p)>e.d.range+target.d.radius:
				e.path=map.path(e.p,target.p); e.goal=target.p
	if target.is_empty(): return
	var reach=e.d.range+(70 if e.garrison>=0 else 0)
	if e.p.distance_to(target.p)>reach+target.d.radius or e.cool>0: return
	e.angle=(target.p-e.p).angle(); e.cool=e.d.get("cooldown",1.0); e.state="attacking"
	var amount=float(e.d.damage)
	if e.owner>=0 and teams[e.owner].upgrade: amount*=1.15
	if e.kind=="heavy" and (target.building or not target.d.get("biological",false)): amount*=2
	if e.kind=="sniper" and target.d.get("biological",false): amount*=1.4
	if e.buff: amount*=1.2
	if e.kind=="siege":
		for enemy in nearby(target.p,65):
			if hostile(e.owner,enemy.owner): damage(enemy,amount,e.owner)
	else: damage(target,amount,e.owner)
	effects.append({"type":"shot","p":e.p,"to":target.p,"life":.15,"max":.15,"owner":e.owner})

func damage(e: Dictionary,amount: float,attacker: int,ignore_cover: bool=false):
	if e.hp<=0 or cheats.active("invincible",e.owner): return
	if not ignore_cover and not e.building:
		if e.garrison>=0: amount*=.45
		elif map.at(e.p)==1: amount*=.78
	e.hp-=amount; e.last_hit=clock
	if e.hp<=0 and e.building: building_cache_dirty=true
	if e.owner==0 and alert_timer<=0: notice.emit("Sua base ou suas tropas estão sob ataque!","alert"); alert_timer=12
	if e.hp<=0 and attacker>=0:
		teams[attacker].kills+=1
		if teams[attacker].faction==2: teams[attacker].money+=45 if e.building else 18

func remove_entity(e: Dictionary,count_loss: bool):
	if e.building: map.set_building(e.p,false); building_cache_dirty=true
	if e.kind=="super" and e.owner>=0: teams[e.owner].super_charge=0; teams[e.owner].super_warned=false
	if e.garrison>=0: map.ruins[e.garrison].occupant=0
	if e.owner>=0 and count_loss:
		teams[e.owner].lost+=1
		if e.kind=="hero": teams[e.owner].hero_ready=90.0
	if count_loss:
		effects.append({"type":"blast","p":e.p,"life":.65,"max":.65,"radius":48 if e.building else 22})
		if e.building: map.crates.append({"p":e.p,"amount":120})
	by_id.erase(e.id); entities.erase(e)

func weapon_reload(owner: int) -> float:
	return 140.0 if teams[owner].faction==2 else 180.0

func weapon_ready(owner: int) -> bool:
	if cheats.active("superweapon",owner): return true
	return config.get("superweapons",true) and has_building(owner,"super") and teams[owner].super_charge>=weapon_reload(owner) and energy_factor(owner)==1

func launch_weapon(owner: int,p: Vector2) -> bool:
	if not weapon_ready(owner): say(owner,"Superarma indisponível: verifique estrutura, energia e recarga.","select"); return false
	if not visible(owner,p): say(owner,"Revele o alvo antes de disparar.","select"); return false
	var faction=int(teams[owner].faction)
	if faction==2: p+=Vector2(rng.randf_range(-45,45),rng.randf_range(-45,45))
	strikes.append({"p":p,"owner":owner,"faction":faction,"left":7.0,"radius":235.0 if faction==2 else 200.0})
	teams[owner].super_charge=0; teams[owner].super_warned=false
	notice.emit("IMPACTO EM 7 s — "+catalog.factions[faction].weapon+"!","alert")
	return true

func update_superweapons(dt: float):
	for strike in strikes.duplicate():
		strike.left-=dt
		if strike.left>0: continue
		for e in nearby(strike.p,strike.radius):
			var falloff=clampf(1-e.p.distance_to(strike.p)/strike.radius,.12,1)
			var amount=1250*falloff
			if strike.faction==1:
				amount=(1600 if e.d.get("biological",false) else 420)*falloff
				if not cheats.active("invincible",e.owner): e.disabled=14.0
			damage(e,amount,strike.owner,true)
		effects.append({"type":"super","p":strike.p,"life":2.0,"max":2.0,"radius":strike.radius,"faction":strike.faction})
		if strike.faction!=1: zones.append({"p":strike.p,"radius":strike.radius*.8,"life":18.0 if strike.faction==0 else 12.0,"owner":strike.owner,"faction":strike.faction})
		strikes.erase(strike); notice.emit("Impacto confirmado.","blast")
	for zone in zones.duplicate():
		zone.life-=dt
		for e in nearby(zone.p,zone.radius): damage(e,dt*(17 if zone.faction==0 else 26),zone.owner,true)
		if zone.life<=0: zones.erase(zone)

func ability(id: int,p: Vector2) -> bool:
	var e=get_entity(id)
	if e.is_empty() or e.kind not in ["hero","special"] or e.ability>0 or e.owner<0: return false
	if not visible(e.owner,p) or e.p.distance_to(p)>380: say(e.owner,"Habilidade: alvo visível a até 380 m.","select"); return false
	var f=teams[e.owner].faction
	e.ability=55.0 if e.kind=="hero" else 35.0
	if e.kind=="hero":
		if f==0:
			for n in 3:
				if population(e.owner)<pop_limit: spawn("rifle",e.owner,e.p+Vector2(n*25,45))
		elif f==1:
			for enemy in nearby(p,160):
				if hostile(e.owner,enemy.owner) and not cheats.active("invincible",enemy.owner): enemy.disabled=5.0
		else:
			for enemy in nearby(p,120):
				if hostile(e.owner,enemy.owner): damage(enemy,280,e.owner)
	else:
		if f==0:
			for enemy in nearby(p,160):
				if hostile(e.owner,enemy.owner) and not cheats.active("invincible",enemy.owner): enemy.disabled=6.0
		elif f==1:
			for enemy in nearby(p,160):
				if hostile(e.owner,enemy.owner) and not enemy.building and enemy.d.get("biological",false) and enemy.kind!="hero" and not cheats.active("invincible",enemy.owner) and population(e.owner)<pop_limit:
					enemy.original_owner=enemy.owner; enemy.owner=e.owner; enemy.converted_until=clock+16; enemy.target=0; break
		else:
			var d=nearest_deposit(e.owner,p)
			if not d.is_empty() and d.p.distance_to(p)<150:
				var amount=minf(400,d.amount); d.amount-=amount; teams[e.owner].money+=amount; teams[e.owner].collected+=amount
	effects.append({"type":"ability","p":p,"life":.8,"max":.8,"radius":160})
	return true

func update_points(dt: float):
	for point in map.points:
		var owners=[]
		for e in nearby(point.p,130):
			if e.owner>=0 and not e.building and e.kind not in ["worker","mcv"] and not owners.has(e.owner): owners.append(e.owner)
		var contested=false
		for a in owners:
			for b in owners:
				if hostile(a,b): contested=true
		if not owners.is_empty() and not contested:
			var owner=owners[0]
			if point.owner!=owner and (point.owner<0 or hostile(owner,point.owner)):
				if point.capturing!=owner: point.progress=0; point.capturing=owner
				point.progress+=dt
				if point.progress>=10: point.owner=owner; point.progress=0; say(owner,"Ponto estratégico capturado.","ready")
		else: point.progress=maxf(0,point.progress-dt)
	for i in teams.size():
		if not teams[i].alive: teams[i].domination=0; continue
		var controlled=0
		for point in map.points:
			if point.owner==i or (config.get("coalition",false) and i>0 and point.owner>0): controlled+=1
		if config.get("victory",0)==1 and controlled>map.points.size()/2.0: teams[i].domination+=dt
		else: teams[i].domination=0
		if teams[i].domination>=config.get("domination_time",180): finish(i)

func check_end():
	if finished: return
	for owner in teams.size():
		if not teams[owner].alive: continue
		if own(owner,"hq").is_empty() and own(owner,"mcv").is_empty():
			teams[owner].alive=false
			for point in map.points:
				if point.owner==owner: point.owner=-1; point.progress=0
			for e in own(owner): e.hp=0
			notice.emit(team_name(owner)+" foi eliminado.","blast")
	if not teams[0].alive: finish(-1); return
	var enemy_alive=false
	for i in range(1,teams.size()):
		if teams[i].alive: enemy_alive=true
	if not enemy_alive: finish(0)

func finish(result: int):
	if finished: return
	finished=true; winner=result; ended.emit(result)

func say(owner: int,text: String,sound: String=""):
	if owner==0: notice.emit(text,sound)
