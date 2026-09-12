extends Node2D

const Battle=preload("res://src/battle.gd")
const View=preload("res://src/battle_view.gd")
const Settings=preload("res://src/settings.gd")
const Catalog=preload("res://src/catalog.gd")
var catalog=Catalog.new()
var settings=Settings.new()
var view
var sim
var ui: Control
var overlay: Control
var hud: Control
var config={"map":1,"faction":0,"enemies":1,"difficulty":0,"color":0,"resources":3000,"speed":1.0,"victory":0,"domination_time":180,"coalition":false,"neutrals":false,"superweapons":true,"cheats":false,"regenerate":false,"seed":83421,"enemy_factions":[1,-1,-1,-1,-1,-1,-1,-1],"enemy_colors":[1,2,3,4,5,6,7,8]}
var paused=false
var hud_tab=0
var production_cards: Dictionary={}
var deploy_button: Button
var top_label: Label
var info_label: Label
var message_label: Label
var queue_label: Label
var weapon_button: Button
var message_timer=0.0
var selected: Array=[]
var groups: Dictionary={}
var mode="context"
var accumulator=0.0
var hud_timer=0.0
var waiting_key=-1
var music: AudioStreamPlayer
var players: Array=[]
var sounds: Dictionary={}
var sound_cool=0.0
var dragging_middle=false
var last_config: Dictionary
var auto_test=false
var benchmark_frames: Array=[]
var benchmark_time=0.0
var tutorial_step=0
var profile_sim_usec=0
var profile_draw_usec=0
var profile_samples=0
var report_dir="res://tests"
var bench_duration=45.0
const MINT=Color("78c9ac")
const GOLD=Color("e4a65c")
const TEXT=Color("d5e4da")
const MUTED=Color("8da79a")

func _ready():
	DisplayServer.window_set_min_size(Vector2i(1100,700))
	view=View.new(); add_child(view)
	var canvas=CanvasLayer.new(); add_child(canvas)
	ui=Control.new(); ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); ui.mouse_filter=Control.MOUSE_FILTER_IGNORE; canvas.add_child(ui)
	ui.theme=make_theme()
	settings.apply()
	setup_audio()
	show_menu()
	var args=OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--report-dir="): report_dir=arg.trim_prefix("--report-dir=")
		if arg.begins_with("--bench-seconds="): bench_duration=float(arg.trim_prefix("--bench-seconds="))
	if "--demo" in args or "--benchmark" in args or "--qa" in args:
		config.cheats=true; config.resources=6500
		if "--benchmark" in args: config.map=3; config.enemies=8; config.difficulty=1; config.neutrals=true
		start_game()
		setup_demo("--benchmark" in args)
		auto_test=true
	get_viewport().size_changed.connect(on_resize)

func make_theme() -> Theme:
	var theme=Theme.new()
	theme.default_font_size=int(15*settings.values.ui_scale)
	for name in ["normal","hover","pressed","disabled","focus"]:
		var style=StyleBoxFlat.new()
		style.bg_color=Color("203b36") if name=="hover" else (Color("2d5145") if name=="pressed" else Color("142b2b"))
		style.border_color=MINT.darkened(.35) if name in ["hover","focus"] else Color("35534a")
		style.set_border_width_all(1); style.set_corner_radius_all(3)
		style.content_margin_left=12; style.content_margin_right=12; style.content_margin_top=10; style.content_margin_bottom=10
		theme.set_stylebox(name,"Button",style)
		theme.set_stylebox(name,"OptionButton",style)
	for c in ["Label","Button","CheckButton","CheckBox","OptionButton"]:
		theme.set_color("font_color",c,TEXT)
		theme.set_color("font_hover_color",c,Color.WHITE)
	theme.set_color("font_disabled_color","Button",Color("647c70"))
	var popup_style=StyleBoxFlat.new(); popup_style.bg_color=Color("152b2a"); popup_style.set_border_width_all(1); popup_style.border_color=MINT.darkened(.4)
	theme.set_stylebox("panel","PopupMenu",popup_style)
	return theme

func setup_audio():
	for key in ["select","order","shot","blast","alert","ready"]: sounds[key]=load("res://assets/audio/"+key+".wav")
	music=AudioStreamPlayer.new(); music.stream=load("res://assets/audio/music.wav"); add_child(music)
	music.finished.connect(func():music.play()); music.volume_db=linear_to_db(maxf(.001,settings.values.music))
	if DisplayServer.get_name()!="headless": music.play()
	for n in 8:
		var player=AudioStreamPlayer.new(); add_child(player); players.append(player)

func sound(key: String):
	if key=="" or not sounds.has(key) or settings.values.effects<=0: return
	if sound_cool>0 and key in ["select","ready","shot"]: return
	for player in players:
		if not player.playing:
			player.stream=sounds[key]; player.volume_db=linear_to_db(settings.values.effects); player.play(); sound_cool=.08; return

func clear_ui():
	for child in ui.get_children(): child.queue_free()
	hud=null; overlay=null

func label(parent: Node,text: String,size: int=16,color: Color=TEXT) -> Label:
	var l=Label.new(); l.text=text; l.add_theme_font_size_override("font_size",int(size*settings.values.ui_scale)); l.add_theme_color_override("font_color",color); parent.add_child(l); return l

func button(parent: Node,text: String,callback: Callable,height: int=43) -> Button:
	var b=Button.new(); b.text=text; b.custom_minimum_size.y=height; b.size_flags_horizontal=Control.SIZE_EXPAND_FILL; b.focus_mode=Control.FOCUS_NONE
	b.pressed.connect(func():sound("select"); callback.call()); parent.add_child(b); return b

func panel(parent: Node) -> PanelContainer:
	var p=PanelContainer.new(); var style=StyleBoxFlat.new(); style.bg_color=Color(.035,.09,.093,.97); style.border_color=Color("355047"); style.set_border_width_all(1)
	style.content_margin_left=22; style.content_margin_right=22; style.content_margin_top=18; style.content_margin_bottom=18
	p.add_theme_stylebox_override("panel",style); parent.add_child(p); return p

func vbox(parent: Node,gap: int=10) -> VBoxContainer:
	var v=VBoxContainer.new(); v.add_theme_constant_override("separation",gap); parent.add_child(v); return v

func option(parent: Node,title: String,items: Array,index: int,callback: Callable) -> OptionButton:
	var row=VBoxContainer.new(); row.add_theme_constant_override("separation",5); parent.add_child(row)
	label(row,title.to_upper(),11,MUTED)
	var o=OptionButton.new(); o.custom_minimum_size.y=40; o.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	for item in items: o.add_item(str(item))
	o.selected=index; o.item_selected.connect(callback); row.add_child(o); return o

func toggle(parent: Node,title: String,checked: bool,callback: Callable) -> CheckButton:
	var c=CheckButton.new(); c.text=title; c.button_pressed=checked; c.toggled.connect(callback); parent.add_child(c); return c

func show_menu():
	if sim!=null: sim.ai_agents.clear()
	sim=null; view.sim=null; paused=false; selected.clear(); groups.clear(); clear_ui()
	var left=VBoxContainer.new(); ui.add_child(left); left.position=Vector2(70,76); left.size=Vector2(570,690); left.add_theme_constant_override("separation",18)
	label(left,"UM RTS DE SOBREVIVÊNCIA E RECONQUISTA",12,MINT)
	var spacer=Control.new(); spacer.custom_minimum_size.y=34; left.add_child(spacer)
	label(left,"FALLING\nSKIES",78,Color("e1e7d6"))
	label(left,"G U E R R A   P E L A   T E R R A",19,GOLD)
	var desc=label(left,"O céu pertence a eles.\nA resistência começa no chão.",23,MUTED)
	desc.custom_minimum_size.y=88
	label(left,"01 / IMPLANTE    02 / RECONSTRUA    03 / RETOME",11,MINT)
	var play=button(left,"PREPARAR OPERAÇÃO    →",func():show_setup(),58); play.custom_minimum_size.x=380
	button(left,"OPÇÕES E CONTROLES",func():show_options(false))
	button(left,"CRÉDITOS",func():show_credits())
	button(left,"SAIR",func():get_tree().quit())
	var foot=label(ui,"PROJETO DE FÃ  /  USO PESSOAL  /  SINGLE-PLAYER OFFLINE",11,MUTED)
	foot.position=Vector2(70,get_viewport_rect().size.y-36)
	var tag=label(ui,"TERRA OCUPADA\nCANAL 02 · SINAL ATIVO",13,MINT); tag.position=Vector2(get_viewport_rect().size.x-335,get_viewport_rect().size.y-100)

func show_setup():
	clear_ui()
	var heading=label(ui,"PREPARAR\nOPERAÇÃO",48,TEXT); heading.position=Vector2(62,75)
	var info=label(ui,"Escolha seu exército.\nDefina o campo de batalha.\nRetome o que é nosso.",21,MUTED); info.position=Vector2(65,215)
	var f=catalog.factions[config.faction]
	var faction_card=panel(ui); faction_card.position=Vector2(64,355); faction_card.size=Vector2(510,235)
	var fv=vbox(faction_card,15); label(fv,f.short,27,MINT); label(fv,f.motto,19,GOLD)
	var d=label(fv,f.description,16,MUTED); d.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label(fv,"SUPERARMA  /  "+f.weapon,13,TEXT)
	var back=button(ui,"← MENU",func():show_menu()); back.position=Vector2(65,get_viewport_rect().size.y-90); back.size.x=180
	var p=panel(ui); p.position=Vector2(620,38); p.size=Vector2(get_viewport_rect().size.x-660,get_viewport_rect().size.y-76)
	var outer=vbox(p,12)
	label(outer,"CONFIGURAÇÃO DO SKIRMISH",19,MINT)
	var scroll=ScrollContainer.new(); scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; outer.add_child(scroll)
	var box=vbox(scroll,13); box.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var map_names=[]
	for m in catalog.maps: map_names.append(m.name+" · "+m.size.capitalize()+" · até %d IAs" % m.max_enemies)
	option(box,"Cenário",map_names,config.map,func(i):config.map=i; config.enemies=mini(config.enemies,int(catalog.maps[i].max_enemies)); show_setup())
	option(box,"Seu exército",catalog.factions.map(func(x):return x.name),config.faction,func(i):config.faction=i; show_setup())
	var row=HBoxContainer.new(); row.add_theme_constant_override("separation",14); box.add_child(row)
	var sizes=[]
	for i in int(catalog.maps[config.map].max_enemies): sizes.append(str(i+1)+" IA"+("s" if i>0 else ""))
	option(row,"Adversários",sizes,config.enemies-1,func(i):config.enemies=i+1; show_setup())
	option(row,"Dificuldade",["Casual","Difícil"],config.difficulty,func(i):config.difficulty=i)
	var casual_hint=label(box,"Casual: cerca de 6 minutos para preparar a base, ondas pequenas e tecnologia inimiga mais lenta. Para aprender, use 1 IA.",12,MINT)
	casual_hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	option(box,"Relação dos adversários",["Todos contra todos","Coalizão contra você · desafio extremo"],1 if config.coalition else 0,func(i):config.coalition=i==1)
	var colors=["Jade","Coral","Violeta","Ouro","Azul","Rosa","Cobre","Oliva","Prata"]
	option(box,"Sua cor",colors,config.color,func(i):config.color=i)
	label(box,"COMANDANTES INIMIGOS",11,MINT)
	for n in config.enemies:
		var r=HBoxContainer.new(); r.add_theme_constant_override("separation",12); box.add_child(r)
		var number=n
		option(r,"IA %d · Exército" % (n+1),["Aleatório","Resistência","Espheni","Berserkers"],config.enemy_factions[n]+1,func(i):config.enemy_factions[number]=i-1)
		option(r,"Cor",colors,config.enemy_colors[n],func(i):config.enemy_colors[number]=i)
	option(box,"Suprimentos iniciais",["1.500 · Escassos","3.000 · Padrão","6.000 · Abundantes"],[1500,3000,6000].find(config.resources),func(i):config.resources=[1500,3000,6000][i])
	option(box,"Velocidade",["0,75×","1×","1,5×","2×"],[.75,1.0,1.5,2.0].find(config.speed),func(i):config.speed=[.75,1.0,1.5,2.0][i])
	var win_hint=label(box,"VITÓRIA: destrua todas as unidades e estruturas inimigas. Perder o comando não elimina um exército.",12,GOLD)
	win_hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	toggle(box,"Patrulhas neutras",config.neutrals,func(v):config.neutrals=v)
	toggle(box,"Superarmas",config.superweapons,func(v):config.superweapons=v)
	toggle(box,"Regenerar depósitos lentamente (+2/s)",config.regenerate,func(v):config.regenerate=v)
	toggle(box,"Permitir cheats nesta partida",config.cheats,func(v):config.cheats=v)
	label(box,"POPULAÇÃO: %d por comandante · um único jogador humano" % mini(60,int(270/(config.enemies+1))),12,GOLD)
	var begin=button(outer,"INICIAR OPERAÇÃO    →",func():start_game(),52); begin.add_theme_color_override("font_color",MINT)

func show_options(in_game: bool):
	var p=create_overlay("OPÇÕES E CONTROLES",Vector2(690,730))
	var scroll=ScrollContainer.new(); scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; p.add_child(scroll)
	var body=vbox(scroll,15); body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	for key in ["music","effects"]:
		var name_key=key
		label(body,"Música" if key=="music" else "Efeitos",16,TEXT)
		var slider=HSlider.new(); slider.min_value=0; slider.max_value=1; slider.step=.05; slider.value=settings.values[key]; slider.custom_minimum_size=Vector2(540,24); body.add_child(slider)
		slider.value_changed.connect(func(value):settings.values[name_key]=value; music.volume_db=linear_to_db(maxf(.001,settings.values.music)); settings.save())
	option(body,"Escala do texto",["100%","110%","120%"],int(round((settings.values.ui_scale-1)*10)),func(i):settings.values.ui_scale=1+i*.1; settings.save(); ui.theme=make_theme())
	toggle(body,"Tela cheia",settings.values.fullscreen,func(v):settings.values.fullscreen=v; settings.apply(); settings.save())
	toggle(body,"Dicas de início de partida",settings.values.tutorial,func(v):settings.values.tutorial=v; settings.save())
	label(body,"CONTROLES",14,MINT)
	var controls=label(body,"Clique / arrastar: selecionar · Shift: adicionar\nDireito: mover, atacar, coletar ou ocupar ruína\nSetas: câmera · Arrastar botão central: câmera\nRoda: zoom\nA: atacar-mover · P: patrulhar · S: parar · G: guardar\nD: implantar comando · H: voltar à base · Q: todo o exército\nF: habilidade · X: superarma · Esc: pausa/cancelar\nCtrl + 1–9: criar grupo · 1–9: selecionar grupo\nDireito com prédio selecionado: ponto de encontro",14,MUTED)
	controls.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label(body,"ATALHOS DOS CHEATS · CTRL + TECLA",12,MINT)
	var names=["Recursos","Invencibilidade","Superarma","Revelar mapa"]
	for i in 4:
		var index=i
		button(body,names[i]+" · Ctrl+"+OS.get_keycode_string(settings.values.cheat_keys[i]),func():waiting_key=index; message("Pressione uma tecla para o atalho de "+names[index]+"."); label(body,"Aguardando tecla…",13,GOLD),34)
	button(p,"VOLTAR",func():close_overlay(); if in_game: show_pause())

func show_credits():
	var box=create_overlay("CRÉDITOS",Vector2(660,490))
	var l=label(box,"Falling Skies: Guerra pela Terra\n\nProjeto pessoal de fã, sem finalidade comercial.\nProgramação, desenho vetorial e áudio sintetizado\ncriados neste projeto com assistência do Codex.\n\nMotor: Godot Engine 4.7.2, licença MIT.\nSem recursos extraídos da série ou de outros jogos.\nNomes da série pertencem aos respectivos titulares.\n\nLicenças e avisos completos: pasta LICENSES.",17,MUTED)
	l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	button(box,"VOLTAR",func():close_overlay())

func create_overlay(title: String,size: Vector2) -> VBoxContainer:
	close_overlay()
	overlay=Control.new(); overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); ui.add_child(overlay)
	var shade=ColorRect.new(); shade.color=Color(0,.025,.03,.82); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); overlay.add_child(shade)
	var p=panel(overlay); p.size=size; p.position=(get_viewport_rect().size-size)/2
	var box=vbox(p,16); label(box,title,25,MINT)
	return box

func close_overlay():
	waiting_key=-1
	if is_instance_valid(overlay): overlay.queue_free()
	overlay=null

func start_game():
	config.victory=0
	clear_ui(); paused=false; selected.clear(); groups.clear(); accumulator=0; tutorial_step=0
	if sim!=null: sim.ai_agents.clear()
	config.seed=83421+config.map*131
	last_config=config.duplicate(true)
	sim=Battle.new(); sim.notice.connect(message); sim.ended.connect(on_ended); sim.start(config)
	view.sim=sim; view.camera=sim.map.starts[0]; view.zoom=1.05; view.placing=""; view.aim_mode=""
	selected=[sim.own(0,"mcv")[0].id]; view.selected=selected
	create_hud()
	message("Selecione o comando móvel e pressione D. Depois: gerador → depósito → quartel.","ready")

func create_hud():
	if is_instance_valid(hud): hud.queue_free()
	production_cards.clear()
	deploy_button=null
	hud=Control.new(); hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); hud.mouse_filter=Control.MOUSE_FILTER_IGNORE; ui.add_child(hud)
	var top=panel(hud); top.position=Vector2.ZERO; top.size=Vector2(get_viewport_rect().size.x,66)
	var row=HBoxContainer.new(); row.add_theme_constant_override("separation",25); top.add_child(row)
	label(row,"FS /",21,GOLD)
	top_label=label(row,"",17,TEXT); top_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var speed=OptionButton.new(); for item in ["0,75×","1×","1,5×","2×"]: speed.add_item(item)
	speed.selected=[.75,1.0,1.5,2.0].find(config.speed); speed.item_selected.connect(func(i):config.speed=[.75,1.0,1.5,2.0][i]); row.add_child(speed)
	var pause_button=button(row,"Ⅱ  PAUSA",func():show_pause(),32); pause_button.size_flags_horizontal=Control.SIZE_SHRINK_END
	var right=panel(hud); right.position=Vector2(get_viewport_rect().size.x-336,259); right.size=Vector2(336,get_viewport_rect().size.y-259)
	var box=vbox(right,9)
	info_label=label(box,"",13,TEXT); info_label.custom_minimum_size.y=42; info_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var tabs=HBoxContainer.new(); tabs.add_theme_constant_override("separation",5); box.add_child(tabs)
	for i in 3:
		var index=i
		var tab=button(tabs,["BASE","TROPAS","TÁTICA"][i],func():hud_tab=index; create_hud(),33)
		if hud_tab==i: tab.add_theme_color_override("font_color",MINT)
	var scroll=ScrollContainer.new(); scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; box.add_child(scroll)
	var contents=vbox(scroll,7); contents.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	if hud_tab in [0,1]:
		deploy_button=button(contents,"D · IMPLANTAR BASE",func():
			for e in sim.own(0,"mcv"): sim.deploy(e.id)
			update_hud(),36)
		label(contents,"Escolha uma figura · role para ver mais",11,MUTED)
		var categories={"ESTRUTURAS": ["power","refinery","barracks","factory","lab","hospital"],"DEFESAS": ["turret","wall","super"]} if hud_tab==0 else {"INFANTARIA": ["rifle","scout","heavy","sniper","medic","engineer"],"VEÍCULOS E COLETA": ["worker","buggy","tank","siege"],"ELITES E HERÓIS": ["elite","hero","special"]}
		for category in categories:
			label(contents,category,11,MINT)
			var grid=GridContainer.new(); grid.columns=2; grid.add_theme_constant_override("h_separation",7); grid.add_theme_constant_override("v_separation",7); contents.add_child(grid)
			for kind in categories[category]: create_production_card(grid,kind)
	else:
		button(contents,"D · Implantar comando",func():deploy_selected())
		button(contents,"F · Habilidade do herói/especial",func():arm_mode("ability"))
		button(contents,"Pesquisar armas +15% · 500 SUP",func():
			if not sim.research(0): message("Requer laboratório, 500 SUP e pesquisa ainda não iniciada."))
		button(contents,"Cancelar último item da fila",func():
			for id in selected: sim.cancel_queue(id))
		label(contents,"Aura do herói: +20% dano / 180 m\nHabilidade: alvo a até 380 m\nHerói: recarga 55 s · Especial: 35 s\nCobertura na mata: −22% dano\nRuína ocupada: −55% dano",13,MUTED)
	queue_label=label(box,"",12,MUTED); queue_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; queue_label.custom_minimum_size.y=37
	weapon_button=button(box,"X · SUPERARMA",func():arm_mode("superweapon"),43); weapon_button.add_theme_color_override("font_color",GOLD)
	var orders=HBoxContainer.new(); orders.position=Vector2(18,get_viewport_rect().size.y-58); orders.size=Vector2(get_viewport_rect().size.x-372,42); orders.add_theme_constant_override("separation",6); hud.add_child(orders)
	for item in [["A · Atacar","attack_move"],["P · Patrulhar","patrol"],["S · Parar","stop"],["G · Guardar","hold"],["Q · Exército","army"],["H · Base","home"]]:
		var action=item[1]; button(orders,item[0],func():action_order(action),40)
	message_label=label(hud,"",16,GOLD); message_label.position=Vector2(24,get_viewport_rect().size.y-112); message_label.size=Vector2(get_viewport_rect().size.x-386,48); message_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	update_hud()

func create_production_card(parent: Node,kind: String):
	var d=catalog.definition(kind,sim.teams[0].faction)
	var b=button(parent,"",func():
		if catalog.buildings.has(kind):
			view.placing=kind; view.aim_mode=""; message("Posicione "+d.name+" no terreno. Direito/Esc cancela.")
		else: sim.train(0,kind,selected[0] if selected.size()==1 else 0)
		update_hud(),158)
	b.custom_minimum_size.x=130; b.set_meta("caption",d.name)
	var stack=VBoxContainer.new(); b.add_child(stack); stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.offset_left=7; stack.offset_right=-7; stack.offset_top=5; stack.offset_bottom=-5
	stack.add_theme_constant_override("separation",2); stack.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var picture=TextureRect.new(); picture.texture=view.art.icon(sim.teams[0].faction,kind)
	picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.custom_minimum_size.y=70; picture.mouse_filter=Control.MOUSE_FILTER_IGNORE; stack.add_child(picture)
	var role={"rifle":"RFL","scout":"»","heavy":"AT","sniper":"ALVO","medic":"+","engineer":"ENG","elite":"★","hero":"★","special":"◆","worker":"SUP","buggy":"»","tank":"AT","siege":"ART"}.get(kind,"")
	if role!="":
		var badge=label(picture,role,14,GOLD); badge.position=Vector2(2,2)
	var title=label(stack,d.name,12,TEXT); title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; title.custom_minimum_size.y=32
	var price=label(stack,"%d SUP · %d s" % [d.cost,d.time],11,GOLD); price.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var status=label(stack,"",10,MINT); status.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; status.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	var progress=ProgressBar.new(); progress.custom_minimum_size.y=4; progress.show_percentage=false; progress.mouse_filter=Control.MOUSE_FILTER_IGNORE; stack.add_child(progress)
	production_cards[kind]={"button":b,"status":status,"progress":progress,"picture":picture}
	b.tooltip_text="%s\nVida: %d · Alcance: %d\n%s" % [d.name,d.hp,d.range,d.description]

func update_production_cards():
	for kind in production_cards:
		var card=production_cards[kind]; var d=catalog.definition(kind,sim.teams[0].faction)
		var reason=""; var count=0; var progress=0.0
		var structure=catalog.buildings.has(kind)
		var required=d.get("requires","")
		if structure and not sim.has_building(0,"hq"): reason="Implante a base (D)"
		elif required!="" and not sim.has_building(0,required): reason="Requer "+catalog.definition(required,sim.teams[0].faction).name
		elif not structure and not sim.has_building(0,d.producer): reason="Requer "+catalog.definition(d.producer,sim.teams[0].faction).name
		elif not structure and sim.population(0)>=sim.pop_limit: reason="População cheia"
		elif not sim.cheats.active("resources") and sim.teams[0].money<d.cost: reason="Faltam suprimentos"
		if kind=="super":
			if not sim.config.superweapons: reason="Desativada na partida"
			elif not sim.own(0,"super").is_empty(): reason="Já construída"
		if kind=="hero" and (not sim.own(0,"hero").is_empty() or sim.teams[0].hero_ready>0): reason="Herói indisponível"
		for e in sim.own(0):
			if structure and e.kind==kind and e.build>0:
				count+=1; progress=maxf(progress,100*(1-e.build/e.d.time))
			for q in e.queue:
				if q.kind==kind:
					count+=1; progress=maxf(progress,100*(1-q.left/q.total))
		if kind=="hero" and count>0: reason="Herói na fila"
		if not structure and reason=="" and not sim.own(0,d.producer).any(func(e):return e.build<=0 and e.queue.size()<8): reason="Fila cheia"
		card.button.disabled=reason!=""
		card.picture.modulate=Color(.55,.6,.65) if reason!="" else Color.WHITE
		card.status.text=("%d na fila · %d%%" % [count,progress]) if count>0 else (reason if reason!="" else ("Clique no terreno" if view.placing==kind else "Disponível"))
		card.progress.value=progress
		card.button.tooltip_text="%s\n%d SUP · %d s\n%s\n%s" % [d.name,d.cost,d.time,d.description,reason if reason!="" else "Clique para construir" if structure else "Clique para recrutar"]

func update_hud():
	if sim==null or not is_instance_valid(top_label): return
	if is_instance_valid(deploy_button): deploy_button.visible=not sim.own(0,"mcv").is_empty()
	update_production_cards()
	var team=sim.teams[0]
	var flags=[]
	for key in sim.cheats.flags:
		if sim.cheats.active(key): flags.append({"resources":"SUP ∞","invincible":"ESCUDO","superweapon":"ARMA ∞","reveal":"VISÃO"}[key])
	top_label.text="SUP  %s     ENERGIA  %d/%d     TROPAS  %d/%d     %02d:%02d  %s" % ["∞" if sim.cheats.active("resources") else str(int(team.money)),team.power,team.use,sim.population(0,false),sim.pop_limit,int(sim.clock)/60,int(sim.clock)%60,"  ".join(flags)]
	selected=selected.filter(func(id):return not sim.get_entity(id).is_empty() and sim.get_entity(id).owner==0)
	view.selected=selected
	if selected.size()==1:
		var e=sim.get_entity(selected[0])
		info_label.text="%s\nVIDA %d/%d  ·  %s" % [e.d.name,maxi(0,int(e.hp)),e.max_hp,state_name(e)]
		if e.kind in ["hero","special"]: info_label.text+="\nF: "+("pronto" if e.ability<=0 else "%d s" % e.ability)
		queue_label.text="FILA: "+("vazia" if e.queue.is_empty() else "%s · %d s · +%d" % [catalog.definition(e.queue[0].kind,team.faction).name,ceil(e.queue[0].left),e.queue.size()-1])
	elif selected.size()>1: info_label.text="%d UNIDADES SELECIONADAS\nDireito: ordem contextual" % selected.size(); queue_label.text="Ctrl + 1–9: salvar grupo"
	else: info_label.text=catalog.factions[team.faction].short+"\nSelecione uma unidade ou estrutura"; queue_label.text="Clique ou arraste no terreno."
	weapon_button.text="X · "+("SUPERARMA PRONTA" if sim.weapon_ready(0) else "SUPERARMA  %d / %d s" % [team.super_charge,sim.weapon_reload(0)])
	if config.victory==1: queue_label.text+="\nDOMÍNIO: %d / %d s" % [team.domination,config.domination_time]
	if team.power<team.use: queue_label.text+="\nENERGIA BAIXA: produção a 30%."

func state_name(e: Dictionary) -> String:
	if e.build>0: return "CONSTRUÇÃO"
	if e.disabled>0: return "DESATIVADO"
	if e.garrison>=0: return "GUARNECIDO"
	return {"idle":"PRONTO","moving":"MOVENDO","attacking":"COMBATE","gathering":"COLETANDO","returning":"RETORNANDO"}.get(e.state,"PRONTO")

func message(text: String,key: String=""):
	message_timer=9.0
	if is_instance_valid(message_label): message_label.text=text
	sound(key)

func arm_mode(action: String):
	view.placing=""; view.aim_mode=action
	message("Clique no alvo visível. Direito/Esc cancela." if action=="superweapon" else "Selecione um herói/especial e clique no alvo a até 380 m.")

func action_order(action: String):
	if action in ["stop","hold"]: sim.command(selected,Vector2.ZERO,action); mode="context"
	elif action=="army": selected=sim.own(0).filter(func(e):return not e.building and e.kind not in ["worker","mcv"]).map(func(e):return e.id); view.selected=selected
	elif action=="home": view.camera=sim.map.starts[0]
	else: mode=action; view.placing=""; view.aim_mode=""; message("Clique no destino: "+("atacar-mover" if action=="attack_move" else "patrulhar")+".")

func deploy_selected():
	for id in selected.duplicate(): sim.deploy(id)

func show_pause():
	if sim==null: return
	paused=true
	var box=create_overlay("OPERAÇÃO PAUSADA",Vector2(590,640 if sim.cheats.allowed else 450))
	button(box,"CONTINUAR",func():paused=false; close_overlay())
	button(box,"OPÇÕES E CONTROLES",func():show_options(true))
	if sim.cheats.allowed:
		label(box,"CHEATS · VÁLIDOS SOMENTE NESTA PARTIDA",12,GOLD)
		for key in sim.cheats.flags:
			var flag=key
			toggle(box,sim.cheats.NAMES[key],sim.cheats.active(key),func(_value):toggle_cheat(flag))
	button(box,"REINICIAR OPERAÇÃO",func():config=last_config.duplicate(true); start_game())
	button(box,"ABANDONAR E VOLTAR AO MENU",func():show_menu())

func toggle_cheat(key: String):
	if sim.cheats.toggle(key):
		message(sim.cheats.NAMES[key]+": "+("ATIVADO" if sim.cheats.active(key) else "DESATIVADO"),"ready")
		update_hud()

func on_ended(result: int):
	paused=true
	var box=create_overlay("VITÓRIA" if result==0 else "DERROTA",Vector2(780,650))
	label(box,("A Terra ainda tem quem lute por ela." if result==0 else "A resistência perdeu este setor."),20,TEXT)
	label(box,"Duração: %02d:%02d · %s" % [int(sim.clock)/60,int(sim.clock)%60,"Partida com cheats" if sim.cheats.used else "Partida normal"],15,GOLD)
	var scroll=ScrollContainer.new(); scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; box.add_child(scroll)
	var scores=vbox(scroll,12)
	for i in sim.teams.size():
		var t=sim.teams[i]
		label(scores,sim.team_name(i)+( " · ELIMINADO" if not t.alive else ""),17,catalog.color_for(t.color))
		label(scores,"Coletado: %d  ·  Gasto: %d  ·  Produzidas: %d  ·  Perdas: %d  ·  Abates: %d" % [t.collected,t.spent,t.produced,t.lost,t.kills],13,MUTED)
	button(box,"JOGAR NOVAMENTE",func():config=last_config.duplicate(true); start_game())
	button(box,"MENU PRINCIPAL",func():show_menu())

func _process(dt: float):
	sound_cool=maxf(0,sound_cool-dt)
	if sim==null: return
	view.mouse_world=view.screen_to_world(get_viewport().get_mouse_position())
	if not paused and not sim.finished:
		var sim_start=Time.get_ticks_usec()
		accumulator+=minf(dt,.15)*config.speed
		var steps=0
		while accumulator>=.05 and steps<6:
			sim.tick(.05); accumulator-=.05; steps+=1
		profile_sim_usec+=Time.get_ticks_usec()-sim_start
		var direction=Vector2.ZERO
		if Input.is_physical_key_pressed(KEY_LEFT): direction.x-=1
		if Input.is_physical_key_pressed(KEY_RIGHT): direction.x+=1
		if Input.is_physical_key_pressed(KEY_UP): direction.y-=1
		if Input.is_physical_key_pressed(KEY_DOWN): direction.y+=1
		view.camera+=direction*dt*750/view.zoom
		view.camera=view.camera.clamp(Vector2.ZERO,Vector2.ONE*sim.map.size)
		if sim.effects.any(func(fx):return fx.type=="shot" and sim.visible(0,fx.p) and view.area().has_point(view.world_to_screen(fx.p))): sound("shot")
	message_timer-=dt
	if message_timer<=0 and is_instance_valid(message_label):
		message_label.text="D: implantar  ·  Direito: ordens  ·  Roda: zoom  ·  Setas: câmera  ·  Esc: pausa"
		if settings.values.tutorial: tutorial_hint()
	hud_timer-=dt
	if hud_timer<=0: update_hud(); hud_timer=.2
	if auto_test:
		benchmark_time+=dt; benchmark_frames.append(dt*1000)
		profile_draw_usec+=view.draw_usec; profile_samples+=1
		if benchmark_time>12 and benchmark_time<12.2 and DisplayServer.get_name()!="headless":
			get_viewport().get_texture().get_image().save_png(report_dir+"/gameplay_capture.png")
		if benchmark_time>=bench_duration:
			benchmark_frames.sort()
			var report={"frames":benchmark_frames.size(),"p50_ms":benchmark_frames[int(benchmark_frames.size()*.5)],"p95_ms":benchmark_frames[int(benchmark_frames.size()*.95)],"units":sim.entities.size(),"renderer":RenderingServer.get_video_adapter_name(),"seconds":benchmark_time,"sim_ms_per_frame":profile_sim_usec/float(profile_samples)/1000,"draw_script_ms":profile_draw_usec/float(profile_samples)/1000,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}
			report["view_sections"]=view.profile; report["sim_sections"]=sim.profile
			FileAccess.open(report_dir+"/graphics_report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
			print("GRAPHICS_BENCHMARK ",JSON.stringify(report)); sim.ai_agents.clear(); get_tree().quit()

func tutorial_hint():
	if not sim.own(0,"mcv").is_empty(): message_label.text="PRIMEIRO PASSO  /  Selecione o veículo inicial e pressione D para implantar."
	elif not sim.has_building(0,"power"): message_label.text="ENERGIA  /  Na aba BASE, escolha Gerador e clique perto do comando."
	elif not sim.has_building(0,"refinery"): message_label.text="ECONOMIA  /  Construa um Depósito. Coletores transportam suprimentos automaticamente."
	elif not sim.has_building(0,"barracks"): message_label.text="DEFESA  /  Construa um Quartel e recrute combatentes na aba TROPAS."
	elif sim.clock<160: message_label.text="EXPLORE  /  Envie o batedor. A + clique avança combatendo. Capture bandeiras por 10 s."

func _input(event: InputEvent):
	if waiting_key>=0 and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode not in [KEY_CTRL,KEY_SHIFT,KEY_ALT]:
			var keys=settings.values.cheat_keys
			if not keys.has(event.keycode) or keys[waiting_key]==event.keycode:
				keys[waiting_key]=event.keycode; settings.save(); waiting_key=-1; show_options(sim!=null)
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent):
	if sim==null:
		if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE: close_overlay()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_ESCAPE:
			if view.placing!="" or view.aim_mode!="" or mode!="context": view.placing=""; view.aim_mode=""; mode="context"
			elif paused and not sim.finished: close_overlay(); paused=false
			else: show_pause()
			return
		if event.ctrl_pressed and sim.cheats.allowed:
			for i in 4:
				if event.keycode==settings.values.cheat_keys[i]: toggle_cheat(["resources","invincible","superweapon","reveal"][i]); return
		if paused: return
		if event.keycode>=KEY_1 and event.keycode<=KEY_9:
			var number=event.keycode-KEY_0
			if event.ctrl_pressed: groups[number]=selected.duplicate(); message("Grupo %d salvo." % number)
			else: selected=groups.get(number,[]).duplicate(); view.selected=selected
		match event.keycode:
			KEY_D: deploy_selected()
			KEY_A: action_order("attack_move")
			KEY_P: action_order("patrol")
			KEY_S: action_order("stop")
			KEY_G: action_order("hold")
			KEY_Q: action_order("army")
			KEY_H: action_order("home")
			KEY_F: arm_mode("ability")
			KEY_X: arm_mode("superweapon")
	if paused: return
	if event is InputEventMouseButton:
		var p=event.position
		if view.minimap_rect().has_point(p) and event.pressed:
			var world=(p-view.minimap_rect().position)/view.minimap_rect().size*sim.map.size
			if event.button_index==MOUSE_BUTTON_LEFT: view.camera=world
			elif event.button_index==MOUSE_BUTTON_RIGHT: sim.command(selected,world,"move")
			return
		if not view.area().has_point(p): return
		if event.button_index==MOUSE_BUTTON_WHEEL_UP and event.pressed: view.zoom=minf(1.65,view.zoom*1.12)
		if event.button_index==MOUSE_BUTTON_WHEEL_DOWN and event.pressed: view.zoom=maxf(.42,view.zoom/1.12)
		if event.button_index==MOUSE_BUTTON_MIDDLE: dragging_middle=event.pressed
		if event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:
			if view.placing!="" or view.aim_mode!="" or mode!="context": view.placing=""; view.aim_mode=""; mode="context"; return
			var world=view.screen_to_world(p); sim.command(selected,world,"context",pick(world,false)); sound("order")
		if event.button_index==MOUSE_BUTTON_LEFT:
			if event.pressed:
				var world=view.screen_to_world(p)
				if view.placing!="":
					if sim.build(0,view.placing,world): view.placing=""
					return
				if view.aim_mode!="":
					if view.aim_mode=="superweapon": sim.launch_weapon(0,world)
					else:
						for id in selected: sim.ability(id,world)
					view.aim_mode=""; return
				if mode!="context": sim.command(selected,world,mode); mode="context"; sound("order"); return
				view.drag_start=p; view.drag_end=p; view.dragging=true
			elif view.dragging:
				view.dragging=false
				if not event.shift_pressed: selected.clear()
				if p.distance_to(view.drag_start)>6:
					var rect=Rect2(view.screen_to_world(view.drag_start),view.screen_to_world(p)-view.screen_to_world(view.drag_start)).abs()
					for e in sim.own(0):
						if not e.building and rect.has_point(e.p) and not selected.has(e.id): selected.append(e.id)
				else:
					var id=pick(view.screen_to_world(p),true)
					if id>0 and not selected.has(id): selected.append(id)
				view.selected=selected; sound("select"); update_hud()
	if event is InputEventMouseMotion:
		if dragging_middle: view.camera-=event.relative/view.zoom
		if view.dragging: view.drag_end=event.position

func pick(p: Vector2,friendly_only: bool) -> int:
	var result=0; var distance=INF
	for e in sim.entities:
		if (friendly_only and e.owner!=0) or not sim.visible(0,e.p): continue
		var gap=e.p.distance_to(p)
		var hit=e.d.radius+16
		if not e.building:
			var faction=sim.teams[e.owner].faction if e.owner>=0 else 1
			var width=view.unit_width(e,faction)
			gap=(e.p+Vector2(0,-width*.26)).distance_to(p)
			hit=maxf(hit,width*.42)
		if gap<hit and gap<distance: result=e.id; distance=gap
	return result

func on_resize():
	if sim!=null and not paused: create_hud()

func setup_demo(stress: bool):
	for owner in sim.teams.size():
		for e in sim.own(owner,"mcv"): sim.deploy(e.id)
		var p: Vector2=sim.map.starts[owner]
		for entry in [["power",Vector2(140,-100)],["refinery",Vector2(-140,-120)],["barracks",Vector2(160,90)],["factory",Vector2(-155,55)],["lab",Vector2(0,-210)]]:
			sim.spawn(entry[0],owner,p+entry[1])
		if stress:
			while sim.population(owner)<sim.pop_limit:
				var kind=["rifle","tank","heavy","medic","buggy"][sim.population(owner)%5]
				var u=sim.spawn(kind,owner,p+Vector2(sim.rng.randf_range(-130,130),sim.rng.randf_range(100,250)))
				sim.move_order(u,Vector2.ONE*sim.map.size/2,"attack_move")
		else:
			for n in 12: sim.spawn(["rifle","heavy","buggy"][n%3],owner,p+Vector2((n%4)*35,140+(n/4)*30))
	sim.update_vision(); sim.rebuild_buckets()
	selected=sim.own(0,"rifle").map(func(e):return e.id); view.selected=selected
	if stress:
		sim.cheats.toggle("reveal"); view.camera=Vector2.ONE*sim.map.size/2; view.zoom=.42
	else: view.camera=sim.map.starts[0]+Vector2(80,30)
	message("Operação de demonstração · todas as mecânicas estão disponíveis.")

func _exit_tree():
	if music!=null: music.stop(); music.stream=null
	for player in players: player.stop(); player.stream=null
	if sim!=null: sim.ai_agents.clear()
