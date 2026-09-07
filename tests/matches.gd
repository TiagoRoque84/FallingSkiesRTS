extends SceneTree
const Battle=preload("res://src/battle.gd")
const AI=preload("res://src/commander_ai.gd")
var reports=[]

func _initialize(): call_deferred("run_matches")

func run_matches():
	for difficulty in 2:
		var s=Battle.new()
		s.start({"map":0,"enemies":1,"faction":0,"color":0,"enemy_factions":[1],"enemy_colors":[1],"resources":3000,"difficulty":difficulty,"superweapons":true,"cheats":false,"victory":0,"seed":83421,"neutrals":false})
		# Test driver occupies the human command slot; shipping gameplay never creates this AI.
		s.ai_agents.append(AI.new(s,0))
		var start=Time.get_ticks_msec(); var high_units=0; var max_buildings=[0,0]
		for n in 24000:
			s.tick(.05)
			high_units=maxi(high_units,s.entities.size())
			for owner in 2: max_buildings[owner]=maxi(max_buildings[owner],s.own(owner).filter(func(e):return e.building).size())
			if s.finished: break
		var report={"difficulty":difficulty,"finished":s.finished,"winner":s.winner,"game_seconds":s.clock,"wall_ms":Time.get_ticks_msec()-start,"peak_entities":high_units,"max_buildings":max_buildings,"teams":s.teams}
		reports.append(report); print("MATCH ",JSON.stringify(report))
		s.ai_agents.clear()
	FileAccess.open("res://tests/matches_report.json",FileAccess.WRITE).store_string(JSON.stringify(reports,"\t"))
	quit(0 if reports.all(func(r):return r.finished) else 1)
