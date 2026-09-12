extends SceneTree
const Battle=preload("res://src/battle.gd")
const AI=preload("res://src/commander_ai.gd")
var checks=0
var failures=[]
var reports=[]

func options() -> Dictionary:
	return {"map":0,"enemies":1,"faction":0,"color":0,"enemy_factions":[1,2],"enemy_colors":[1,2],"resources":3000,"difficulty":1,"superweapons":true,"cheats":false,"victory":0,"seed":84391,"neutrals":false}

func expect(test: bool,name: String):
	checks+=1
	if not test: failures.append(name); push_error("ADVANCED FAIL: "+name)

func fresh():
	var b=Battle.new(); b.start(options()); b.ai_agents.clear()
	for i in b.teams.size(): b.deploy(b.own(i,"mcv")[0].id)
	return b

func _initialize(): call_deferred("run_tests")

func run_tests():
	var b=fresh()
	var base=b.own(0,"hq")[0].p
	var building=b.spawn("turret",1,base+Vector2(180,0)); building.hp=building.max_hp*.2
	var engineer=b.spawn("engineer",0,building.p+Vector2(96,0)); engineer.target=building.id; engineer.order="attack"
	b.update_vision(); b.rebuild_buckets(); b.tick(.05)
	expect(building.owner==0,"engenheiro captura estrutura danificada no alcance de parada")
	expect(b.has_building(0,"turret"),"captura atualiza disponibilidade de estrutura")
	for difficulty in 2:
		var s=fresh(); s.config.difficulty=difficulty
		var p=s.own(1,"hq")[0].p
		s.spawn("super",1,p+Vector2(150,-100)); s.spawn("power",1,p+Vector2(-130,0)); s.spawn("power",1,p+Vector2(-130,140)); s.update_economy(0)
		s.teams[1].super_charge=s.weapon_reload(1)
		var ai=AI.new(s,1); s.update_vision(); s.rebuild_buckets(); ai.update(10)
		expect(s.strikes.is_empty(),"IA não dispara através da névoa: dificuldade %d" % difficulty)
		s.own(1,"scout")[0].p=s.own(0,"hq")[0].p+Vector2(20,20)
		s.update_vision(); s.rebuild_buckets(); ai.update(10)
		expect(s.strikes.size()==1,"IA dispara superarma contra alvo visível: dificuldade %d" % difficulty)
	var c=fresh(); var target=c.own(0,"rifle")[0]
	target.hp=10000; target.max_hp=10000
	var controller=c.spawn("special",1,target.p+Vector2(30,0)); c.update_vision(); c.rebuild_buckets()
	var pop=c.population(0)
	expect(c.ability(controller.id,target.p),"habilidade de conversão ativa")
	expect(target.owner==1,"controle temporário muda a unidade de lado")
	expect(c.population(0)==pop,"conversão preserva reserva de população da origem")
	target.disabled=20
	for n in 330: c.tick(.05)
	expect(target.owner==0,"conversão termina e restaura proprietário")
	var coal=Battle.new(); var opts=options(); opts.enemies=2; opts.coalition=true; opts.victory=1; opts.domination_time=2
	coal.start(opts); coal.ai_agents.clear()
	var point=coal.map.points[0]
	coal.own(1,"rifle")[0].p=point.p; coal.own(2,"rifle")[0].p=point.p+Vector2(10,0)
	coal.rebuild_buckets()
	for n in 220: coal.tick(.05)
	expect(point.owner>0,"aliados capturam juntos sem contestação entre si")
	coal.map.points[0].owner=1; coal.map.points[1].owner=2
	for n in 50: coal.tick(.05)
	expect(not coal.finished,"domínio combinado da coalizão não causa derrota humana")
	for e in coal.own(1): coal.damage(e,99999,0,true)
	coal.tick(.05)
	expect(not coal.finished and not coal.teams[1].alive,"eliminar um adversário não elimina o restante da coalizão")
	for e in coal.own(2): coal.damage(e,99999,0,true)
	coal.tick(.05)
	expect(coal.finished and coal.winner==0,"vitória exige eliminar todos os adversários")
	var remnant=fresh(); remnant.config.difficulty=0
	remnant.damage(remnant.own(1,"hq")[0],99999,0,true); remnant.tick(.05)
	var surviving_ai=AI.new(remnant,1); surviving_ai.elapsed=400; surviving_ai.next_attack=399
	remnant.spawn("rifle",1,remnant.own(1,"rifle")[0].p+Vector2(30,0)); surviving_ai.update(10)
	expect(remnant.own(1,"rifle").any(func(e):return e.order=="attack_move"),"IA continua comandando sobreviventes sem comando central")
	var enemy_win=Battle.new(); enemy_win.start(options())
	# Human driver deliberately issues no orders; the enemy must find and defeat it normally.
	var start=Time.get_ticks_msec()
	for n in 18000:
		enemy_win.tick(.05)
		if enemy_win.finished: break
	expect(enemy_win.finished and enemy_win.winner==-1,"IA reconhece, ataca e vence jogador passivo sem cheats")
	reports.append({"scenario":"AI defeats passive human","finished":enemy_win.finished,"winner":enemy_win.winner,"seconds":enemy_win.clock,"wall_ms":Time.get_ticks_msec()-start,"collected":enemy_win.teams[1].collected,"produced":enemy_win.teams[1].produced})
	var report={"checks":checks,"failures":failures,"matches":reports}
	FileAccess.open("res://tests/advanced_report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("ADVANCED_REPORT ",JSON.stringify(report)); quit(0 if failures.is_empty() else 1)
