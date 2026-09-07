extends Node2D

var sim
var camera=Vector2.ZERO
var zoom=0.85
var selected: Array=[]
var drag_start=Vector2.ZERO
var drag_end=Vector2.ZERO
var dragging=false
var placing=""
var aim_mode=""
var mouse_world=Vector2.ZERO
var menu_time=0.0
var font: Font=ThemeDB.fallback_font
var terrain_texture: ImageTexture
var fog_texture: ImageTexture
var mini_texture: ImageTexture
var cache_map
var fog_timer=0.0
var draw_usec=0
var art=preload("res://src/sprite_bank.gd").new()
var world_root: Node2D
var ground_sprite: Sprite2D
var fog_sprite: Sprite2D
var unit_batch
var utility_batch
var scenery_batch
var building_batches: Array=[]
var menu_texture: Texture2D
var profile={}
var base_mini: Image
var cached_fog_key=-1
const Batch=preload("res://src/sprite_batch.gd")
const INK=Color("101d20")
const MINT=Color("78c9ac")
const GOLD=Color("e4a65c")

func viewport_size() -> Vector2:
	return get_viewport_rect().size

func area() -> Rect2:
	return Rect2(0,66,viewport_size().x-336,viewport_size().y-66)

func minimap_rect() -> Rect2:
	return Rect2(viewport_size().x-314,108,292,196)

func world_to_screen(p: Vector2) -> Vector2:
	return (p-camera)*zoom+area().get_center()

func screen_to_world(p: Vector2) -> Vector2:
	return (p-area().get_center())/zoom+camera

func _process(dt: float):
	menu_time+=dt
	if sim!=null:
		if cache_map!=sim.map: cache_map=sim.map; make_terrain(); setup_batches(); fog_timer=0; cached_fog_key=-1
		fog_timer-=dt
		if fog_timer<=0: make_fog(); fog_timer=.3
		world_root.visible=true
		world_root.position=area().get_center()-camera*zoom; world_root.scale=Vector2.ONE*zoom
		update_batches()
	elif world_root!=null: world_root.visible=false
	queue_redraw()

func setup_batches():
	if world_root!=null: world_root.free()
	world_root=Node2D.new(); add_child(world_root)
	ground_sprite=Sprite2D.new(); ground_sprite.texture=terrain_texture; ground_sprite.centered=false
	ground_sprite.scale=Vector2.ONE*sim.map.size/terrain_texture.get_width(); ground_sprite.z_index=-9; world_root.add_child(ground_sprite)
	ground_sprite.modulate=Color(.8,.84,.76) if sim.map.map_id!="torre" else Color(.85,.83,.88)
	scenery_batch=Batch.new(); scenery_batch.configure(art.environment,2500); scenery_batch.z_index=-6; world_root.add_child(scenery_batch)
	scenery_batch.begin()
	for d in sim.map.decorations:
		var tile=(6 if sim.map.map_id=="torre" else (4 if int(d.p.x)%2==0 else 5)) if d.kind==1 else 7
		var width=(62 if d.kind==1 else 37)*d.scale
		scenery_batch.put(d.p+Vector2(0,-width*.3),Vector2.ONE*width,uv_region(tile,3,3))
	for r in sim.map.ruins:
		var tile=2 if sim.map.map_id=="fazenda" else (1 if r.style==10 else 0)
		scenery_batch.put(r.p+Vector2(0,-32),Vector2.ONE*108,uv_region(tile,3,3),Color(.85,.86,.82))
	for d in sim.map.deposits: scenery_batch.put(d.p+Vector2(0,-14),Vector2.ONE*112,uv_region(3,3,3))
	scenery_batch.finish()
	building_batches.clear()
	for f in 3:
		var batch=Batch.new(); batch.configure(art.building_sheets[f],180); batch.z_index=-5; world_root.add_child(batch); building_batches.append(batch)
	unit_batch=Batch.new(); unit_batch.configure(art.units,360); unit_batch.z_index=-4; world_root.add_child(unit_batch)
	utility_batch=Batch.new(); utility_batch.configure(art.utility,360); utility_batch.z_index=-4; world_root.add_child(utility_batch)
	fog_sprite=Sprite2D.new(); fog_sprite.centered=false; fog_sprite.z_index=-2; world_root.add_child(fog_sprite)

func uv_region(index: int,cols: int,rows: int) -> Rect2:
	return Rect2(Vector2(index%cols,index/cols)/Vector2(cols,rows),Vector2.ONE/Vector2(cols,rows))

func update_batches():
	unit_batch.begin()
	utility_batch.begin()
	for batch in building_batches: batch.begin()
	for e in sim.entities:
		if e.owner!=0 and not sim.visible(0,e.p): continue
		var faction=sim.teams[e.owner].faction if e.owner>=0 else 1
		if e.building:
			if e.kind=="wall": continue
			var width=150.0 if e.kind in ["hq","factory","super"] else (105.0 if e.kind=="turret" else 132.0)
			building_batches[faction].put(e.p+Vector2(0,-width*.28),Vector2.ONE*width,uv_region(art.BUILDING_ORDER.find(e.kind),3,3),Color(.58,.63,.57,.8) if e.build>0 else Color.WHITE)
		else:
			var width=unit_width(e,faction)
			var bob=sin(menu_time*12+e.id) if e.state=="moving" else 0.0
			var row=faction+(0 if e.d.get("biological",false) else 3)
			var direction=posmod(roundi(e.angle/(TAU/8)),8)
			if e.kind in ["mcv","worker","buggy"]:
				row=faction+(3 if e.kind=="buggy" else 0)
				utility_batch.put(e.p+Vector2(0,-width*.26+bob),Vector2.ONE*width,uv_region(row*8+direction,8,6))
			else:
				unit_batch.put(e.p+Vector2(0,-width*.26+bob),Vector2.ONE*width,uv_region(row*8+direction,8,6))
	unit_batch.finish()
	utility_batch.finish()
	for batch in building_batches: batch.finish()

func unit_width(e: Dictionary,faction: int) -> float:
	if not e.d.get("biological",false): return 82.0 if e.kind in ["tank","mcv","siege"] else 65.0
	if e.kind=="hero": return 49.0
	return 47.0 if faction==1 else 40.0

func make_terrain():
	var resolution=32
	var img=Image.create(sim.map.cells*resolution,sim.map.cells*resolution,false,Image.FORMAT_RGB8)
	var source=art.terrain.get_image()
	var alien=sim.map.map_id=="torre"
	for y in sim.map.cells:
		for x in sim.map.cells:
			var t=sim.map.terrain[y*sim.map.cells+x]
			var shade=(sin(x*34.1+y*12.7)+1)*.012
			var col=Color(.17+shade,.23+shade,.21+shade) if not alien else Color(.21+shade,.19+shade,.26+shade)
			if t==1: col=Color("22362d") if not alien else Color("302939")
			if t==2: col=Color("343d3b")
			var tile=5 if alien else (1 if sim.map.map_id in ["escola","fazenda","estrada"] else 0)
			if t==2: tile=2
			if sim.map.map_id=="subterranea" and t!=2: tile=3
			var sx=tile%3*512+posmod(x*32,480)
			var sy=tile/3*512+posmod(y*32,480)
			img.blit_rect(source,Rect2i(sx,sy,32,32),Vector2i(x*32,y*32))
			if t==2:
				img.fill_rect(Rect2i(x*32,y*32+15,12,1),Color("9c9170"))
	terrain_texture=ImageTexture.create_from_image(img)

func make_fog():
	var started=Time.get_ticks_usec()
	var reveal=sim.cheats.active("reveal")
	var fog_key=1 if reveal else hash(sim.vision[0])+hash(sim.explored[0])
	if fog_key!=cached_fog_key:
		cached_fog_key=fog_key
		var fog=Image.create(sim.map.cells,sim.map.cells,false,Image.FORMAT_RGBA8)
		base_mini=Image.create(sim.map.cells,sim.map.cells,false,Image.FORMAT_RGB8)
		var current_field: PackedByteArray=sim.vision[0]
		var known_field: PackedByteArray=sim.explored[0]
		var terrain_field: PackedByteArray=sim.map.terrain
		for y in sim.map.cells:
			for x in sim.map.cells:
				var i=y*sim.map.cells+x
				var was_seen=known_field[i]==1 or reveal
				var current=current_field[i]==1 or reveal
				fog.set_pixel(x,y,Color(.018,.03,.035,0 if current else (.68 if was_seen else .995)))
				var col=Color("2e4b3c") if terrain_field[i]!=2 else Color("697668")
				if not current: col=col.darkened(.6)
				if not was_seen: col=Color("091717")
				base_mini.set_pixel(x,y,col)
		if fog_texture==null or fog_texture.get_width()!=sim.map.cells: fog_texture=ImageTexture.create_from_image(fog)
		else: fog_texture.update(fog)
		base_mini.resize(sim.map.cells*4,sim.map.cells*4,Image.INTERPOLATE_NEAREST)
	var mini=base_mini.duplicate()
	for d in sim.map.deposits:
		if sim.seen(0,d.p) and d.amount>0:
			var c=mini_cell(d.p); mini.fill_rect(Rect2i(c,Vector2i(2,2)),GOLD)
	for point in sim.map.points:
		var c=mini_cell(point.p); mini.fill_rect(Rect2i(c-Vector2i.ONE,Vector2i(4,4)),GOLD if point.owner<0 else team_color(point.owner))
	for old in sim.memory[0].values():
		var c=mini_cell(old.p); mini.fill_rect(Rect2i(c,Vector2i(3,3)),team_color(old.owner).darkened(.45))
	for e in sim.entities:
		if e.owner!=0 and not sim.visible(0,e.p): continue
		var c=mini_cell(e.p); mini.fill_rect(Rect2i(c,Vector2i.ONE*(3 if e.building else 2)),team_color(e.owner))
	if mini_texture==null or mini_texture.get_width()!=sim.map.cells*4: mini_texture=ImageTexture.create_from_image(mini)
	else: mini_texture.update(mini)
	fog_sprite.texture=fog_texture; fog_sprite.scale=Vector2.ONE*sim.map.size/sim.map.cells
	profile.fog_update_ms=(Time.get_ticks_usec()-started)/1000.0

func mini_cell(p: Vector2) -> Vector2i:
	return Vector2i((p/16).clamp(Vector2.ONE*2,Vector2.ONE*(sim.map.cells*4-4)))

func _draw():
	var draw_start=Time.get_ticks_usec()
	if sim==null: draw_menu(); return
	var region=Rect2(screen_to_world(area().position)-Vector2.ONE*100,area().size/zoom+Vector2.ONE*200)
	var offset=area().get_center()-camera*zoom
	draw_set_transform(offset,0,Vector2.ONE*zoom)
	# Static ground and scenery plus mobile sprites are submitted in GPU batches.
	var alien=sim.map.map_id=="torre"
	for ruin in sim.map.ruins:
		if ruin.occupant!=0 and region.has_point(ruin.p) and sim.visible(0,ruin.p): draw_circle(ruin.p+Vector2(0,-60),4,MINT)
	for d in sim.map.deposits:
		if not region.has_point(d.p): continue
		if sim.visible(0,d.p): text_at(d.p+Vector2(-31,40),"SUP %d" % d.amount,12,Color("ccb98d"))
	for crate in sim.map.crates:
		if crate.amount<=0 or not region.has_point(crate.p) or not sim.visible(0,crate.p): continue
		draw_rect(Rect2(crate.p-Vector2.ONE*9,Vector2.ONE*18),Color("8f8760"))
		draw_line(crate.p-Vector2(7,0),crate.p+Vector2(7,0),GOLD,2)
	for point in sim.map.points:
		var col=GOLD if point.owner<0 else team_color(point.owner)
		draw_arc(point.p,72,0,TAU,40,Color(col,.25),2)
		draw_colored_polygon(PackedVector2Array([point.p+Vector2(0,-22),point.p+Vector2(25,0),point.p+Vector2(0,22),point.p+Vector2(-25,0)]),Color("162a29"))
		draw_line(point.p,point.p+Vector2(0,-63),col,3)
		draw_colored_polygon(PackedVector2Array([point.p+Vector2(0,-63),point.p+Vector2(30,-54),point.p+Vector2(0,-42)]),col)
		if point.progress>0: draw_arc(point.p,32,-PI/2,-PI/2+TAU*point.progress/10,32,col,3)
	for old in sim.memory[0].values():
		if sim.visible(0,old.p) or not region.has_point(old.p): continue
		draw_rect(Rect2(old.p-Vector2(26,20),Vector2(52,40)),Color("46544e"),false,2)
		text_at(old.p+Vector2(-20,4),"?",22,Color("86998d"))
	var visible_entities=sim.entities.filter(func(e):return region.has_point(e.p) and (e.owner==0 or sim.visible(0,e.p)))
	var marker_start=Time.get_ticks_usec()
	for e in visible_entities:
		draw_set_transform(offset+e.p*zoom,0,Vector2.ONE*zoom)
		draw_entity(e)
	profile.markers_ms=(Time.get_ticks_usec()-marker_start)/1000.0
	draw_set_transform(offset,0,Vector2.ONE*zoom)
	for zone in sim.zones:
		var col=Color("80aa45") if zone.faction==0 else Color("e56f32")
		draw_circle(zone.p,zone.radius,Color(col,.13))
		for n in 18:
			var pos=zone.p+Vector2.from_angle(n*2.399)*zone.radius*sqrt(n/18.0)
			draw_circle(pos,10+sin(menu_time*4+n)*4,Color(col,.35))
	for fx in sim.effects:
		if not sim.visible(0,fx.p): continue
		var progress=1-fx.life/fx.max
		match fx.type:
			"shot":
				draw_line(fx.p+Vector2(0,-12),fx.to+Vector2(0,-9),Color(team_color(fx.owner).lightened(.45),1-progress),2)
			"blast", "super":
				var col=Color("d7a05a")
				if fx.get("faction",0)==1: col=Color("b899f2")
				draw_circle(fx.p,fx.radius*progress,Color(col,(1-progress)*.6))
				draw_arc(fx.p,fx.radius*progress,0,TAU,36,Color(col,1-progress),3)
			"heal":
				draw_line(fx.p-Vector2(5,14),fx.p+Vector2(5,-14),MINT,2)
				text_at(fx.p+Vector2(-5,-17-progress*20),"+",19,MINT)
			"ability": draw_arc(fx.p,fx.radius*progress,0,TAU,40,Color(MINT,1-progress),3)
	for strike in sim.strikes:
		draw_arc(strike.p,strike.radius,0,TAU,64,Color("f17761"),3)
		draw_line(strike.p-Vector2(35,0),strike.p+Vector2(35,0),Color("f17761"),2)
		draw_line(strike.p-Vector2(0,35),strike.p+Vector2(0,35),Color("f17761"),2)
		text_at(strike.p+Vector2(-30,-25),"%0.1f s" % strike.left,20,Color("ffb89b"))
	if placing!="":
		var ok=sim.build_error(0,placing,mouse_world)==""
		var col=MINT if ok else Color("ee746e")
		draw_rect(Rect2(mouse_world-Vector2(35,29),Vector2(70,58)),Color(col,.25))
		draw_rect(Rect2(mouse_world-Vector2(35,29),Vector2(70,58)),col,false,2)
		draw_arc(mouse_world,470,0,TAU,80,Color(col,.12),1)
	if aim_mode=="superweapon" or aim_mode=="ability":
		draw_arc(mouse_world,200 if aim_mode=="superweapon" else 160,0,TAU,64,GOLD,2)
	for id in selected:
		var e=sim.get_entity(id)
		if e.is_empty(): continue
		if e.building:
			draw_line(e.p,e.rally,Color(MINT,.4),1)
			draw_circle(e.rally,5,MINT)
		if e.d.range>0 and selected.size()==1: draw_arc(e.p,e.d.range,0,TAU,70,Color(MINT,.15),1)
	draw_set_transform(Vector2.ZERO)
	if dragging:
		var box=Rect2(drag_start,drag_end-drag_start).abs()
		draw_rect(box,Color(MINT,.10)); draw_rect(box,MINT,false,1)
	var mini_start=Time.get_ticks_usec()
	draw_minimap()
	profile.minimap_ms=(Time.get_ticks_usec()-mini_start)/1000.0
	draw_usec=Time.get_ticks_usec()-draw_start

func draw_entity(e: Dictionary):
	if e.kind=="wall":
		draw_texture_rect_region(art.environment,Rect2(-40,-40,80,80),art.region(art.environment,8,3,3))
	draw_sprite_markers(e)

func draw_minimap():
	var r=minimap_rect()
	draw_rect(Rect2(Vector2(viewport_size().x-336,66),Vector2(336,253)),INK)
	text_at(r.position+Vector2(0,-15),"REDE TÁTICA",12,MINT)
	text_at(r.position+Vector2(176,-15),"SETOR / AO VIVO",10,Color("708d83"))
	draw_rect(r,Color("172a27"))
	if mini_texture!=null: draw_texture_rect(mini_texture,r,false)
	for strike in sim.strikes: draw_arc(r.position+strike.p/sim.map.size*r.size,9+sin(menu_time*8)*3,0,TAU,24,Color("ff8b70"),2)
	var camera_rect=Rect2(r.position+screen_to_world(area().position)/sim.map.size*r.size,area().size/zoom/sim.map.size*r.size).intersection(r)
	draw_rect(camera_rect,Color("c2dec4"),false,1)
	draw_rect(r,Color("547569"),false,1)

func draw_sprite_markers(e: Dictionary):
	var chosen=selected.has(e.id)
	var col=team_color(e.owner)
	var faction=sim.teams[e.owner].faction if e.owner>=0 else 1
	var width=140.0 if e.building else unit_width(e,faction)
	if chosen: draw_arc(Vector2.ZERO,e.d.radius+9,0,TAU,20,col,1.5)
	if e.kind=="mcv": text_at(Vector2(-7,-width*.74),"D",15,col)
	if chosen and not e.building:
		var badge={"heavy":"▲","medic":"+","hero":"★","special":"◆","worker":"S"}.get(e.kind,"")
		if badge!="": text_at(Vector2(-4,-width*.74-3),badge,10,GOLD if e.kind=="hero" else col)
	if e.disabled>0: text_at(Vector2(-12,-width*.75),"EMP",11,Color("c0a3f4"))
	if chosen or e.hp<e.max_hp or e.build>0:
		var w=60 if e.building else 28
		var y=-width*.8
		draw_rect(Rect2(-w/2,y,w,3),Color("0b1617"))
		draw_rect(Rect2(-w/2,y,w*maxf(0,e.hp/e.max_hp),3),col if e.hp/e.max_hp>.3 else Color("e97963"))
		if e.build>0:
			draw_rect(Rect2(-w/2,y+5,w*(1-e.build/e.d.time),3),GOLD)
			text_at(Vector2(-15,y-7),"%d s" % ceil(e.build),12,GOLD)
		elif chosen and selected.size()==1: text_at(Vector2(-40,y-6),e.d.name,12,TEXT_COLOR)

const TEXT_COLOR=Color("e0e8da")

func team_color(owner: int) -> Color:
	return Color("b9a9a2") if owner<0 else sim.catalog.color_for(sim.teams[owner].color)

func text_at(p: Vector2,text: String,size: int,color: Color):
	draw_string(font,p,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func draw_menu():
	var v=viewport_size()
	if menu_texture==null and ResourceLoader.exists("res://assets/sprites/menu_background.png"): menu_texture=load("res://assets/sprites/menu_background.png")
	if menu_texture!=null:
		draw_texture_rect(menu_texture,Rect2(Vector2.ZERO,v),false)
		for n in 16:
			var p=Vector2(fmod(n*137.0+menu_time*4,v.x),fmod(n*89.0-menu_time*8+v.y,v.y))
			draw_circle(p,1,Color(.9,.65,.3,.18))
		return
	draw_rect(Rect2(Vector2.ZERO,v),Color("101f23"))
