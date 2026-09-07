extends SceneTree
const Battle=preload("res://src/battle.gd")
var checks=0
var failures: Array=[]
var results: Array=[]

func expect(value: bool,name: String):
	checks+=1
	if not value: failures.append(name); push_error("FAIL: "+name)

func options(faction: int=0) -> Dictionary:
	return {"map":1,"enemies":1,"faction":faction,"color":0,"enemy_factions":[1,2,0,1,2,0,1,2],"enemy_colors":[1,2,3,4,5,6,7,8],"resources":6000,"difficulty":0,"superweapons":true,"cheats":true,"victory":0,"seed":83421,"neutrals":false}

func fresh(faction: int=0):
	var s=Battle.new(); s.start(options(faction)); s.ai_agents.clear()
	for i in s.teams.size(): s.deploy(s.own(i,"mcv")[0].id)
	s.update_vision(); s.rebuild_buckets()
	return s

func run_seconds(s,seconds: float):
	for i in int(seconds/.05): s.tick(.05)

func _initialize():
	call_deferred("run_tests")

func run_tests():
	var start=Time.get_ticks_msec()
	var s=fresh()
	expect(s.teams.size()==2,"um humano e uma IA")
	expect(s.has_building(0,"hq") and s.own(0,"mcv").is_empty(),"implantação troca veículo por comando")
	expect(not s.cheats.used and not s.cheats.active("resources"),"cheats desligados inicialmente")
	var base=s.own(0,"hq")[0].p
	var cash=s.teams[0].money
	expect(s.build(0,"power",base+Vector2(150,-80)),"construção válida aceita")
	expect(s.teams[0].money==cash-250,"construção debita custo")
	expect(not s.build(0,"power",base+Vector2(150,-80)),"construções não se sobrepõem")
	expect(not s.build(0,"lab",base+Vector2(-130,0)),"pré-requisito de laboratório respeitado")
	run_seconds(s,13)
	expect(s.has_building(0,"power"),"obra concluída após tempo")
	expect(s.teams[0].power==90,"energia é soma das estruturas prontas")
	expect(s.build(0,"refinery",base+Vector2(-150,-80)),"construção de refinaria")
	run_seconds(s,19)
	expect(s.own(0,"worker").size()==2,"refinaria entrega coletor adicional")
	var collected=s.teams[0].collected
	run_seconds(s,55)
	expect(s.teams[0].collected>collected,"coleta transporta carga e credita suprimentos")
	expect(s.map.deposits.any(func(d):return d.amount<d.max),"depósito é consumido")
	s.spawn("barracks",0,base+Vector2(100,180)); s.update_economy(0)
	cash=s.teams[0].money
	expect(s.train(0,"rifle"),"recrutamento entra na fila")
	expect(s.teams[0].money==cash-100,"recrutamento debita custo")
	var barracks=s.own(0,"barracks")[0]
	s.cancel_queue(barracks.id)
	expect(s.teams[0].money==cash and barracks.queue.is_empty(),"cancelamento reembolsa custo real")
	s.cheats.toggle("resources")
	s.train(0,"rifle")
	expect(s.teams[0].money==cash,"recurso infinito preserva saldo na fila")
	s.cancel_queue(barracks.id)
	expect(s.teams[0].money==cash,"cancelar fila gratuita não cria dinheiro")
	s.cheats.toggle("resources")
	var n=s.own(0,"rifle").size(); s.train(0,"rifle"); run_seconds(s,6)
	expect(s.own(0,"rifle").size()==n+1,"fila produz unidade")
	s.spawn("super",0,base+Vector2(0,-230)); s.spawn("factory",0,base+Vector2(-230,100)); s.update_economy(0)
	expect(s.energy_factor(0)<1,"déficit de energia reduz velocidade")
	var hq=s.own(0,"hq")[0]; var hp=hq.hp
	s.cheats.toggle("invincible"); s.damage(hq,9999,1,true)
	expect(hq.hp==hp,"invencibilidade bloqueia dano estrutural")
	var enemy=s.own(1,"hq")[0]; hp=enemy.hp; s.damage(enemy,10,0,true)
	expect(enemy.hp<hp,"invencibilidade não beneficia inimigo")
	s.cheats.toggle("invincible"); hp=hq.hp; s.damage(hq,10,1,true)
	expect(hq.hp<hp,"desativar invencibilidade restaura dano")
	expect(not s.visible(0,enemy.p),"base inimiga inicialmente oculta")
	var enemy_view=s.vision[1].duplicate()
	s.cheats.toggle("reveal")
	expect(s.visible(0,enemy.p),"revelação mostra mapa ao humano")
	expect(s.vision[1]==enemy_view,"revelação não altera visão da IA")
	s.cheats.toggle("reveal")
	expect(not s.visible(0,enemy.p),"desativar revelação restaura névoa")
	var unit=s.own(0,"rifle")[0]; var origin: Vector2=unit.p
	s.command([unit.id],origin+Vector2(230,0),"move"); run_seconds(s,5)
	expect(unit.p.distance_to(origin)>80,"ordem de movimento desloca unidade")
	s.command([unit.id],Vector2.ZERO,"hold"); origin=unit.p; run_seconds(s,1)
	expect(unit.p.distance_to(origin)<1,"guardar mantém posição")
	s.command([unit.id],Vector2.ZERO,"stop"); expect(unit.path.is_empty(),"parar esvazia caminho")
	var ruin=s.map.ruins[0]; unit.p=s.map.walkable(ruin.p); s.command([unit.id],ruin.p); run_seconds(s,2)
	expect(unit.garrison==0,"infantaria ocupa edifício abandonado")
	s.command([unit.id],ruin.p+Vector2(100,100),"move")
	expect(unit.garrison==-1 and ruin.occupant==0,"ordem de saída libera edifício")
	s.spawn("lab",0,base+Vector2(200,-160))
	expect(s.train(0,"hero"),"herói pode ser recrutado com laboratório")
	expect(not s.train(0,"hero"),"segundo herói bloqueado enquanto está na fila")
	s.cancel_queue(barracks.id)
	var hero=s.spawn("hero",0,base+Vector2(30,60)); s.update_vision()
	expect(s.ability(hero.id,hero.p),"habilidade do herói ativa")
	expect(not s.ability(hero.id,hero.p),"habilidade respeita recarga")
	s.damage(hero,9999,1,true); s.remove_entity(hero,true)
	expect(s.teams[0].hero_ready==90,"herói abatido entra em recuperação")
	expect(not s.train(0,"hero"),"recrutamento respeita recuperação do herói")
	for f in 3:
		var w=fresh(f); w.cheats.toggle("superweapon"); w.cheats.toggle("reveal")
		expect(w.weapon_ready(0),"superarma via cheat sem estrutura: facção %d" % f)
		var e=w.own(1,"hq")[0]; var health=e.hp
		expect(w.launch_weapon(0,e.p),"disparo de superarma: facção %d" % f)
		expect(w.strikes.size()==1 and w.strikes[0].left==7,"aviso de sete segundos: facção %d" % f)
		expect(e.hp==health,"superarma não causa dano antes do aviso: facção %d" % f)
		run_seconds(w,7.2)
		expect(e.hp<health and e.hp>0,"impacto danifica HQ sem destruir sozinho: facção %d" % f)
		if f==1: expect(e.disabled>0,"nêutrons desativam estrutura")
		else: expect(w.zones.size()==1,"superarma cria área persistente: facção %d" % f)
		w.cheats.toggle("invincible"); var own_hq=w.own(0,"hq")[0]; health=own_hq.hp
		w.launch_weapon(0,own_hq.p); run_seconds(w,8)
		expect(own_hq.hp==health,"invencibilidade contra superarma própria: facção %d" % f)
		w.cheats.toggle("superweapon"); expect(not w.weapon_ready(0),"desativar cheat exige estrutura: facção %d" % f)
	var conv=fresh(1); var special=conv.spawn("special",1,conv.map.starts[0]+Vector2(75,60))
	var victim=conv.own(0,"rifle")[0]; conv.update_vision(); conv.rebuild_buckets(); conv.cheats.toggle("invincible")
	conv.ability(special.id,victim.p)
	expect(victim.owner==0,"invencibilidade bloqueia conversão")
	var capture=fresh(); var point=capture.map.points[0]
	var soldier=capture.own(0,"rifle")[0]; soldier.p=point.p; soldier.order="hold"; run_seconds(capture,11)
	expect(point.owner==0,"ponto é capturado após presença contínua")
	capture.config.victory=1; capture.config.domination_time=2
	for p in capture.map.points: p.owner=0
	run_seconds(capture,3); expect(capture.finished and capture.winner==0,"vitória territorial conclui partida")
	var victory=fresh(); victory.damage(victory.own(1,"hq")[0],99999,0,true); run_seconds(victory,.1)
	expect(victory.finished and victory.winner==0,"destruir último comando dá vitória")
	var defeat=fresh(); defeat.damage(defeat.own(0,"hq")[0],99999,1,true); run_seconds(defeat,.1)
	expect(defeat.finished and defeat.winner==-1,"perder comando dá derrota")
	var reset=fresh(); expect(not reset.cheats.used and not reset.cheats.active("invincible"),"nova partida limpa cheats e histórico")
	reset.cheats.reset(false); expect(not reset.cheats.toggle("resources"),"cheats bloqueados quando configuração não permite")
	for map_index in 6:
		var opts=options(); opts.map=map_index; opts.enemies=8
		var m=Battle.new(); m.start(opts); m.ai_agents.clear()
		expect(m.config.enemies==m.catalog.maps[map_index].max_enemies,"limite do mapa %d" % map_index)
		expect(m.map.deposits.size()>=m.teams.size()*2,"recursos por base no mapa %d" % map_index)
		for p in m.map.starts:
			expect(not m.map.path(p,Vector2.ONE*m.map.size/2).is_empty(),"rota base-centro mapa %d" % map_index)
		expect(m.pop_limit*m.teams.size()<=270,"limite global de unidades mapa %d" % map_index)
	var population=fresh(); population.cheats.toggle("resources")
	population.spawn("barracks",0,population.map.starts[0]+Vector2(100,150))
	while population.population(0)<population.pop_limit: population.spawn("rifle",0,population.map.starts[0]+Vector2(80,120))
	expect(not population.train(0,"rifle"),"produção respeita teto de população")
	var report={"checks":checks,"failures":failures,"elapsed_ms":Time.get_ticks_msec()-start,"engine":Engine.get_version_info().string}
	FileAccess.open("res://tests/rules_report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("RULES_REPORT ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
