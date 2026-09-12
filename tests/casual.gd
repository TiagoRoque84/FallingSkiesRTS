extends SceneTree

const Battle=preload("res://src/battle.gd")
var failures=[]
var checks=0

func expect(value: bool,message: String):
	checks+=1
	if not value: failures.append(message); push_error(message)

func _initialize(): call_deferred("run")

func run():
	var sim=Battle.new()
	sim.start({"map":0,"enemies":1,"faction":0,"color":0,"enemy_factions":[1],"enemy_colors":[1],"resources":3000,"difficulty":0,"superweapons":true,"cheats":false,"victory":0,"seed":84391,"neutrals":false})
	sim.deploy(sim.own(0,"mcv")[0].id)
	for n in 6000: sim.tick(.05)
	expect(not sim.finished,"Casual permite cinco minutos de preparação ao jogador passivo")
	expect(sim.own(0,"hq")[0].hp==sim.own(0,"hq")[0].max_hp,"Base humana intacta antes da primeira onda")
	expect(sim.own(1,"scout").all(func(e):return e.order=="idle"),"Batedores não antecipam o ataque no casual")
	expect(sim.own(1,"lab").is_empty(),"Casual não libera laboratório antes de cinco minutos")
	var ai=sim.ai_agents[0]
	# Isolate a fully supplied army to measure the wave independently of pathfinding.
	sim.ai_agents.clear()
	var base=sim.own(1,"hq")[0].p
	for n in 12: sim.spawn("rifle",1,base+Vector2(n*12,90))
	for e in sim.own(1):
		if not e.building: e.order="idle"; e.target=0; e.path.clear()
	ai.elapsed=366; ai.decision=0; ai.update(2)
	var attackers=sim.own(1).filter(func(e):return not e.building and e.kind!="scout" and e.order=="attack_move")
	expect(attackers.size()==6,"Primeira onda casual limitada a seis unidades")
	for e in attackers: e.path.clear(); e.target=0
	ai.elapsed=ai.next_attack+1; ai.decision=0; ai.update(.1)
	expect(attackers.any(func(e):return not e.path.is_empty()),"Tropas que chegaram ao destino recebem nova ordem na próxima onda")
	var report={"checks":checks,"failures":failures}
	FileAccess.open("res://tests/casual_report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("CASUAL_REPORT ",JSON.stringify(report)); quit(0 if failures.is_empty() else 1)
