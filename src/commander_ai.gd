extends RefCounted

var sim_ref: WeakRef
var sim:
	get: return sim_ref.get_ref()
var owner: int
var elapsed=0.0
var decision=0.0
var next_attack=0.0
var next_scout=8.0
var build_index=0
var params: Dictionary
var hard=false
var expansion=0

func _init(battle,team: int):
	sim_ref=weakref(battle); owner=team
	hard=sim.config.difficulty==1
	params=sim.catalog.ai.hard if hard else sim.catalog.ai.casual
	decision=owner*.23
	next_attack=float(params.first_attack_after_seconds)+owner*7

func update(dt: float):
	if not sim.teams[owner].alive: return
	elapsed+=dt; decision-=dt
	if decision>0: return
	decision=params.decision_interval_seconds
	for vehicle in sim.own(owner,"mcv"): sim.deploy(vehicle.id)
	var bases=sim.own(owner,"hq")
	if bases.is_empty(): return
	var base=bases[0]
	var team=sim.teams[owner]
	var structures=sim.own(owner).filter(func(e):return e.building)
	var building_now=structures.any(func(e):return e.build>0)
	if not building_now:
		var desired=""
		if not sim.has_building(owner,"power") or team.power-team.use<25: desired="power"
		elif not sim.has_building(owner,"refinery"): desired="refinery"
		elif not sim.has_building(owner,"barracks"): desired="barracks"
		elif not sim.has_building(owner,"factory") and elapsed>45: desired="factory"
		elif sim.own(owner,"turret").size()<2 and elapsed>75: desired="turret"
		elif not sim.has_building(owner,"lab") and elapsed>130: desired="lab"
		elif not sim.has_building(owner,"hospital") and elapsed>170: desired="hospital"
		elif sim.config.superweapons and not sim.has_building(owner,"super") and elapsed>220 and team.money>2100: desired="super"
		elif sim.own(owner,"refinery").size()<3 and elapsed>140+expansion*80 and team.money>750: desired="refinery"
		if desired!="": place(desired,base,structures)
	var workers=sim.own(owner,"worker")
	if sim.has_building(owner,"refinery") and workers.size()< (5 if hard else 4): sim.train(owner,"worker")
	if sim.has_building(owner,"barracks") and sim.population(owner)<sim.pop_limit:
		var composition=["rifle","rifle","heavy","scout","medic","sniper"]
		if hard:
			var enemy_armor=0
			for enemy in sim.entities:
				if sim.hostile(owner,enemy.owner) and sim.visible(owner,enemy.p) and not enemy.d.get("biological",false): enemy_armor+=1
			if enemy_armor>=3: composition=["heavy","heavy","rifle","medic"]
		if sim.has_building(owner,"lab"): composition.append_array(["elite","special"])
		if team.money>240: sim.train(owner,composition[sim.rng.randi_range(0,composition.size()-1)])
		if sim.has_building(owner,"factory") and team.money>900: sim.train(owner,"tank" if sim.rng.randf()<.65 else "buggy")
		if sim.has_building(owner,"lab") and team.money>1250:
			if sim.own(owner,"hero").is_empty(): sim.train(owner,"hero")
			elif not team.upgrade: sim.research(owner)
	var army=sim.own(owner).filter(func(e):return not e.building and e.kind not in ["worker","mcv","scout"])
	var threats=[]
	for enemy in sim.nearby(base.p,600):
		if sim.hostile(owner,enemy.owner) and sim.visible(owner,enemy.p): threats.append(enemy)
	if not threats.is_empty():
		for u in army:
			if u.p.distance_to(base.p)<900: sim.move_order(u,threats[0].p,"attack_move")
	if elapsed>=next_scout:
		next_scout=elapsed+params.scout_interval_seconds
		var scouts=sim.own(owner,"scout")
		if scouts.is_empty() and sim.has_building(owner,"barracks"): sim.train(owner,"scout")
		for scout in scouts:
			var goal=Vector2(sim.rng.randf_range(100,sim.map.size-100),sim.rng.randf_range(100,sim.map.size-100))
			# Only unexplored terrain is sampled, never hidden entity positions.
			for retry in 8:
				if not sim.seen(owner,goal): break
				goal=Vector2(sim.rng.randf_range(100,sim.map.size-100),sim.rng.randf_range(100,sim.map.size-100))
			sim.move_order(scout,goal,"attack_move")
	if elapsed>next_attack and army.size()>=params.minimum_attack_group:
		next_attack=elapsed+params.attack_interval_seconds
		var target=choose_target(base.p)
		for n in army.size():
			var u=army[n]
			if hard and n%3==0 and u.p.distance_to(target)>700:
				sim.move_order(u,target+Vector2(150,-140),"attack_move")
			else: sim.move_order(u,target+Vector2((n%5)*27,(n/5)*27),"attack_move")
	if hard:
		for u in army:
			if u.hp<u.max_hp*params.retreat_health_fraction and u.p.distance_to(base.p)>350: sim.move_order(u,base.p+Vector2(0,140),"move")
	for u in army:
		if u.kind in ["hero","special"] and u.ability<=0:
			var target=sim.get_entity(u.target)
			if not target.is_empty(): sim.ability(u.id,target.p)
	if sim.weapon_ready(owner):
		var best={}; var score=-INF
		for enemy in sim.entities:
			if not sim.hostile(owner,enemy.owner) or not sim.visible(owner,enemy.p): continue
			var value=enemy.max_hp if enemy.building else 50
			if hard:
				value=0
				for nearby in sim.nearby(enemy.p,180):
					if sim.hostile(owner,nearby.owner) and sim.visible(owner,nearby.p): value+=nearby.hp
			if value>score: best=enemy; score=value
		if not best.is_empty():
			var offset=Vector2.ZERO if hard else Vector2(sim.rng.randf_range(-80,80),sim.rng.randf_range(-80,80))
			sim.launch_weapon(owner,best.p+offset)

func choose_target(origin: Vector2) -> Vector2:
	var candidates=sim.memory[owner].values()
	if not candidates.is_empty():
		candidates.sort_custom(func(a,b):return a.p.distance_squared_to(origin)<b.p.distance_squared_to(origin))
		return candidates[0].p
	if sim.config.victory==1:
		for p in sim.map.points:
			if p.owner!=owner: return p.p
	return Vector2(sim.rng.randf_range(150,sim.map.size-150),sim.rng.randf_range(150,sim.map.size-150))

func place(kind: String,base: Dictionary,structures: Array):
	var anchor=base.p
	if kind=="refinery" and sim.has_building(owner,"refinery"):
		var dep=sim.nearest_deposit(owner,structures[-1].p)
		if not dep.is_empty():
			structures.sort_custom(func(a,b):return a.p.distance_squared_to(dep.p)<b.p.distance_squared_to(dep.p))
			anchor=structures[0].p.move_toward(dep.p,250)
	elif structures.size()>7:
		anchor=structures[sim.rng.randi_range(0,structures.size()-1)].p
	for attempt in 24:
		var p=anchor+Vector2.from_angle((build_index+attempt)*2.39996)*(120+attempt*10)
		if sim.build_error(owner,kind,p)=="":
			if sim.build(owner,kind,p):
				build_index+=1
				if kind=="refinery": expansion+=1
			return
