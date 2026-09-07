extends SceneTree

var app
var failures=[]
var checks=0

func _initialize(): call_deferred("run_flow")

func expect(value: bool,name: String):
	checks+=1
	if not value: failures.append(name); push_error("UI FAIL: "+name)

func find_button(node: Node,prefix: String):
	if node is Button and node.text.begins_with(prefix) and not node.is_queued_for_deletion(): return node
	for child in node.get_children():
		var result=find_button(child,prefix)
		if result!=null: return result
	return null

func key(code: int,ctrl: bool=false):
	var event=InputEventKey.new(); event.keycode=code; event.physical_keycode=code; event.ctrl_pressed=ctrl; event.pressed=true
	app._unhandled_input(event)

func click(pos: Vector2,which: int=MOUSE_BUTTON_LEFT):
	for pressed in [true,false]:
		var event=InputEventMouseButton.new(); event.position=pos; event.button_index=which; event.pressed=pressed
		app._unhandled_input(event)

func capture(name: String):
	await process_frame
	await process_frame
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/"+name+".png")

func run_flow():
	app=load("res://scenes/main.tscn").instantiate(); root.add_child(app)
	await capture("menu_capture")
	expect(find_button(app.ui,"PREPARAR")!=null,"menu inicial tem entrada jogável")
	find_button(app.ui,"PREPARAR").pressed.emit()
	await capture("setup_capture")
	expect(find_button(app.ui,"INICIAR")!=null,"configuração tem botão iniciar")
	app.config.map=0; app.config.enemies=8; app.config.cheats=true; app.config.resources=6000
	find_button(app.ui,"INICIAR").pressed.emit()
	await process_frame
	expect(app.sim.teams.size()==3,"início respeita limite do mapa pequeno")
	expect(app.selected.size()==1 and app.sim.get_entity(app.selected[0]).kind=="mcv","comando móvel começa selecionado")
	key(KEY_D)
	expect(app.sim.has_building(0,"hq"),"tecla D implanta base")
	app.sim.update_vision()
	find_button(app.ui,"Gerador").pressed.emit()
	expect(app.view.placing=="power","botão de construção arma posicionamento")
	click(app.view.world_to_screen(app.sim.map.starts[0]+Vector2(150,-80)))
	expect(app.sim.own(0,"power").size()==1,"clique no terreno inicia construção")
	for n in 260: app.sim.tick(.05)
	expect(app.sim.has_building(0,"power"),"construção pela UI termina")
	var soldier=app.sim.own(0,"rifle")[0]
	click(app.view.world_to_screen(soldier.p))
	expect(app.selected.has(soldier.id),"clique seleciona unidade")
	key(KEY_1,true); app.selected=[]; key(KEY_1)
	expect(app.selected.has(soldier.id),"Ctrl+1 salva e 1 recupera seleção")
	var destination=soldier.p+Vector2(200,80)
	click(app.view.world_to_screen(destination),MOUSE_BUTTON_RIGHT)
	expect(soldier.order=="move" and not soldier.path.is_empty(),"clique direito emite movimento")
	key(KEY_A); click(app.view.world_to_screen(destination+Vector2(80,0)))
	expect(soldier.order=="attack_move","A e clique emitem atacar-mover")
	key(KEY_G); expect(soldier.order=="hold","G guarda posição")
	key(KEY_P); click(app.view.world_to_screen(destination))
	expect(soldier.order=="patrol","P e clique iniciam patrulha")
	key(KEY_ESCAPE)
	expect(app.paused,"Esc pausa partida")
	var inv=find_button(app.ui,"Invencibilidade")
	expect(inv!=null,"pausa expõe cheats autorizados")
	if inv!=null: inv.button_pressed=true
	expect(app.sim.cheats.active("invincible"),"toggle da UI ativa cheat")
	await capture("pause_capture")
	key(KEY_ESCAPE); expect(not app.paused,"Esc retoma partida")
	key(KEY_F1,true); expect(app.sim.cheats.active("resources"),"atalho ativa recursos infinitos")
	key(KEY_F1,true); expect(not app.sim.cheats.active("resources"),"atalho desativa recursos infinitos")
	key(KEY_F3,true); key(KEY_F4,true)
	expect(app.sim.weapon_ready(0),"atalho disponibiliza superarma")
	key(KEY_X); click(app.view.world_to_screen(soldier.p))
	expect(app.sim.strikes.size()==1,"X e clique disparam superarma com aviso")
	key(KEY_ESCAPE)
	find_button(app.ui,"REINICIAR").pressed.emit()
	await process_frame
	expect(not app.sim.cheats.used and not app.sim.cheats.active("invincible"),"reiniciar limpa cheats")
	app.setup_demo(false); app.view.zoom=1.1
	await capture("final_gameplay")
	app.sim.damage(app.sim.own(0,"hq")[0],99999,1,true); app.sim.tick(.05)
	await capture("result_capture")
	expect(app.sim.finished and find_button(app.ui,"JOGAR NOVAMENTE")!=null,"derrota abre placar final")
	find_button(app.ui,"MENU PRINCIPAL").pressed.emit()
	await process_frame
	expect(app.sim==null and find_button(app.ui,"PREPARAR")!=null,"abandonar retorna ao menu")
	var report={"checks":checks,"failures":failures}
	FileAccess.open("res://tests/ui_report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("UI_REPORT ",JSON.stringify(report))
	app.free(); quit(0 if failures.is_empty() else 1)
