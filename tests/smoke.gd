extends SceneTree
const Battle=preload("res://src/battle.gd")

func _initialize():
	var sim=Battle.new()
	sim.start({"map":1,"enemies":1,"faction":0,"color":0,"enemy_factions":[1],"enemy_colors":[1],"resources":3000,"difficulty":0,"superweapons":true,"cheats":true,"victory":0,"seed":83421})
	sim.deploy(sim.own(0,"mcv")[0].id)
	for i in 600: sim.tick(.1)
	print("SMOKE_OK time=",sim.clock," entities=",sim.entities.size()," AI buildings=",sim.own(1).filter(func(e):return e.building).size())
	quit()
