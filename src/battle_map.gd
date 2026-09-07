extends RefCounted

const CELL = 64
var size = 3072
var cells = 48
var terrain = PackedByteArray()
var starts: Array[Vector2] = []
var deposits: Array = []
var ruins: Array = []
var points: Array = []
var crates: Array = []
var decorations: Array = []
var nav = AStarGrid2D.new()
var rng = RandomNumberGenerator.new()
var map_id = "boston"

func generate(info: Dictionary, commanders: int, seed_value: int):
	map_id = info.id
	size = {"pequeno": 2304, "medio": 3072, "grande": 3840, "gigante": 4608}[info.size]
	cells = size / CELL
	rng.seed = seed_value
	terrain.resize(cells*cells)
	var center = Vector2.ONE * size/2.0
	for i in commanders:
		var angle = PI + i*TAU/commanders
		starts.append(center + Vector2.from_angle(angle)*size*.345)
	for y in cells:
		for x in cells:
			var p = Vector2(x+.5,y+.5)*CELL
			var road = absi(x-cells/2)<2 or absi(y-cells/2)<2
			road = road or absf(p.distance_to(center)-size*.345)<65
			if map_id=="boston": road=road or x%10==0 or y%10==0
			if map_id=="escola": road=road or ((absi(x-cells/2)==5 and absi(y-cells/2)<=5) or (absi(y-cells/2)==5 and absi(x-cells/2)<=5))
			if map_id == "estrada": road = road or absi(y-x)<2
			var forest = sin(x*.51+y*.12)+cos(y*.43-x*.21)>.75
			if map_id == "torre": forest = sin(x*.6)*cos(y*.4)>.55
			if map_id=="subterranea": forest=false; road=road or x%12<2 or y%12<2
			terrain[y*cells+x] = 2 if road else (1 if forest else 0)
	for i in starts.size():
		var p = starts[i]
		clear_area(p, 240)
		add_deposit(p+Vector2(140,115).rotated(i*.6),5500)
		add_deposit(p+Vector2(-150,210).rotated(i*.6),3200)
		crates.append({"p":p+Vector2(280,-130),"amount":180})
	var sectors = 12 if size<3500 else 24
	for i in sectors:
		var angle = TAU*i/sectors
		var p = center+Vector2.from_angle(angle)*size*(.18 if i%2==0 else .43)
		add_deposit(p,8000 if i%2==0 else 4200)
		clear_area(p,90)
	var point_count = 3 if size<3500 else 5
	for i in point_count:
		var p = center if i==0 else center+Vector2.from_angle(i*TAU/(point_count-1))*size*.19
		points.append({"p":p,"owner":-1,"progress":0.0,"capturing":-1})
		clear_area(p,140)
	for i in (60 if size<3500 else 110):
		var p = Vector2(rng.randf_range(180,size-180),rng.randf_range(180,size-180))
		var allowed = true
		for start in starts:
			if start.distance_to(p)<360: allowed=false
		for d in deposits:
			if d.p.distance_to(p)<145: allowed=false
		for point in points:
			if point.p.distance_to(p)<180: allowed=false
		if at(p)==2 or not allowed: continue
		var c = cell(p)
		terrain[c.y*cells+c.x]=3
		ruins.append({"p":Vector2(c)*CELL+Vector2.ONE*32,"occupant":0,"style":rng.randi_range(0,3)})
	if map_id=="escola":
		var c=cell(center+Vector2(-192,-192)); terrain[c.y*cells+c.x]=3
		ruins.append({"p":Vector2(c)*CELL+Vector2.ONE*32,"occupant":0,"style":10})
	for i in int(size/4):
		var p = Vector2(rng.randf_range(30,size-30),rng.randf_range(30,size-30))
		if at(p)==1: decorations.append({"p":p,"scale":rng.randf_range(.65,1.35),"kind":1})
		elif rng.randf()<.13: decorations.append({"p":p,"scale":rng.randf_range(.5,1.3),"kind":0})
	nav.region=Rect2i(0,0,cells,cells)
	nav.cell_size=Vector2.ONE*CELL
	nav.offset=Vector2.ONE*CELL/2
	nav.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	nav.default_compute_heuristic=AStarGrid2D.HEURISTIC_OCTILE
	nav.default_estimate_heuristic=AStarGrid2D.HEURISTIC_OCTILE
	nav.update()
	for y in cells:
		for x in cells:
			var t=terrain[y*cells+x]
			nav.set_point_solid(Vector2i(x,y),t==3)
			nav.set_point_weight_scale(Vector2i(x,y),1.4 if t==1 else 1.0)

func clear_area(p: Vector2,radius: float):
	var a=cell(p-Vector2.ONE*radius)
	var b=cell(p+Vector2.ONE*radius)
	for y in range(a.y,b.y+1):
		for x in range(a.x,b.x+1): terrain[y*cells+x]=0

func add_deposit(p: Vector2,amount: int):
	deposits.append({"id":deposits.size(),"p":p,"amount":float(amount),"max":float(amount)})

func cell(p: Vector2) -> Vector2i:
	return Vector2i(clampi(int(p.x/CELL),0,cells-1),clampi(int(p.y/CELL),0,cells-1))

func at(p: Vector2) -> int:
	var c=cell(p)
	return terrain[c.y*cells+c.x]

func walkable(p: Vector2) -> Vector2:
	var c=cell(p)
	if not nav.is_point_solid(c): return p.clamp(Vector2.ONE*24,Vector2.ONE*(size-24))
	for r in range(1,8):
		for y in range(-r,r+1):
			for x in range(-r,r+1):
				var n=c+Vector2i(x,y)
				if nav.is_in_boundsv(n) and not nav.is_point_solid(n): return Vector2(n)*CELL+Vector2.ONE*32
	return Vector2(c)*CELL+Vector2.ONE*32

func path(from: Vector2,to: Vector2) -> PackedVector2Array:
	var a=cell(walkable(from))
	var end=walkable(to)
	var b=cell(end)
	var result=nav.get_point_path(a,b)
	if result.size()>0:
		result.remove_at(0)
		result.append(end)
	return result

func set_building(p: Vector2,blocked: bool):
	var c=cell(p)
	if at(p)!=3: nav.set_point_solid(c,blocked)
