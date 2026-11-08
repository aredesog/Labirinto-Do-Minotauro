class_name GerenciadorJogo
extends Node
## Controla o estado geral da partida: novelo de Ariadne (respawns),
## prisioneiros libertados, enigmas, sorteio dos portais, teletransporte,
## reinício e o acesso ao Minotauro.
##
## Fica na cena principal (sem Autoload). Os outros scripts o encontram pelo
## grupo "jogo":  get_tree().get_first_node_in_group("jogo")
##
## Atalhos: R = reiniciar a sala atual | Esc = menu
##
## SORTEIO DOS PORTAIS (quando uma sala é vencida). O jogador NÃO vê o destino.
## A partida tem sempre 10 salas: a 10ª é a arena do Minotauro.
##   - saindo da 9ª sala: todos os portais levam ao Minotauro;
##   - se faltam tantos enigmas quanto salas antes da arena: todos os portais
##     levam a enigmas (assim os 3 enigmas sempre ficam prontos até a 9ª);
##   - senão: pelo menos 1 portal leva a um enigma pendente (se houver) e os
##     outros a salas de combate (às vezes outro enigma);
##   - um portal nunca leva para a própria sala nem a enigma já resolvido.

signal novelo_mudou(restante: int)
signal prisioneiros_mudou(libertados: int, total: int)
signal puzzles_mudou(concluidos: int, total: int)
signal mensagem(texto: String, duracao: float)
signal titulo_sala(texto: String)
signal transicao(escurecer: bool)
signal chefe_apareceu(chefe: Node)
signal fim_de_jogo(vitoria: bool)
## Liga/desliga as faixas pretas de cinema (cena da Ariadne).
signal cinematica(ligada: bool)
## Número da sala atual na partida (1 a 10).
signal salas_mudou(numero: int, total: int)

## Comprimento do novelo de Ariadne = quantas vezes Teseu pode voltar.
@export var novelo_inicial: int = 3
## Quantas salas de puzzle precisam ser concluídas para liberar o Minotauro.
@export var puzzles_para_abrir_arena: int = 3
## Total de jovens atenienses presos (7 rapazes + 7 moças, menos Teseu).
@export var total_prisioneiros: int = 13
## Em qual sala da partida fica o Minotauro (a entrada não conta).
@export var sala_do_minotauro: int = 10
## Chance de uma porta "extra" levar a outro enigma em vez de combate.
@export_range(0.0, 1.0) var chance_enigma_extra: float = 0.3
## Semente do sorteio (0 = aleatório a cada partida).
@export var semente: int = 0
## Cena da tela de título (para o botão "Menu inicial").
@export_file("*.tscn") var cena_titulo: String = "res://cenas/titulo.tscn"
## Intensidade padrão do tilt-shift (cada sala multiplica pelo seu "tilt_shift").
@export var desfoque_tilt: float = 1.6

var novelo: int
var prisioneiros_libertados: int = 0
var puzzles_concluidos: Array[String] = []
## Quantas salas o Teseu já atravessou (a entrada não conta).
var salas_visitadas: int = 0
var checkpoint: Vector3 = Vector3.ZERO
var sala_atual: Node = null
var area_atual: Node = null
var teleportando := false
var em_cinematica := false
var terminou := false
var _jogador: Node3D
var _pular := false


func _enter_tree() -> void:
	add_to_group("jogo")
	_registrar_controles()


func _ready() -> void:
	if semente != 0:
		seed(semente)
	else:
		randomize()
	novelo = novelo_inicial
	await get_tree().process_frame
	Config.aplicar_qualidade(get_parent())
	Toon.instalar(get_tree())
	# F1: modo Raio-X de CG (colisões, normais, vetores da reflexão)
	var rx := RaioX.new()
	rx.name = "RaioX"
	get_parent().add_child.call_deferred(rx)
	_jogador = get_tree().get_first_node_in_group("jogador")
	if _jogador:
		checkpoint = _jogador.global_position
	for a in _areas():
		if a.tipo == "inicio":
			area_atual = a
			a.visitada = true
			sortear_destinos(a)
			_aplicar_tilt(a)
	Som.musica("exploracao", 1.5)
	novelo_mudou.emit(novelo)
	prisioneiros_mudou.emit(prisioneiros_libertados, total_prisioneiros)
	puzzles_mudou.emit(0, puzzles_para_abrir_arena)
	if Config.mostrar_abertura:
		await _abertura()
	else:
		await get_tree().create_timer(0.3).timeout
		mensagem.emit("Os portais levam a salas ao acaso: resolva os 3 enigmas e enfrente o Minotauro!", 4.0)


func _unhandled_input(evento: InputEvent) -> void:
	if em_cinematica:
		if evento.is_action_pressed("pausar"):
			_pular = true
			get_viewport().set_input_as_handled()
		return
	if evento.is_action_pressed("reiniciar_sala") and not terminou:
		reiniciar_sala_atual()


func _registrar_controles() -> void:
	Config.registrar_controles()


# --------------------------------------------------------------------------
# Abertura: Ariadne entrega o novelo (Esc pula)
# --------------------------------------------------------------------------
func _abertura() -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	var ini: Node3D = area_atual
	var ariadne := ini.find_child("Ariadne", true, false) as Node3D if ini else null
	var cam := get_viewport().get_camera_3d()
	if hud == null or ariadne == null or _jogador == null:
		return
	em_cinematica = true
	_jogador.definir_controle(false)
	# espera o HUD terminar de se conectar aos sinais
	await get_tree().create_timer(0.4).timeout
	_pular = false
	_jogador.definir_controle(false)
	var novelo_cabeca := _jogador.get_node_or_null("Visual/Novelo") as Node3D
	var escala_novelo := novelo_cabeca.scale if novelo_cabeca else Vector3.ONE
	if novelo_cabeca:
		novelo_cabeca.scale = Vector3.ONE * 0.01
	cinematica.emit(true)
	if cam and cam.has_method("focar"):
		cam.focar(ariadne.global_position.lerp(_jogador.global_position, 0.5), 0.55)
	# Teseu olha para a Ariadne
	var vis := _jogador.get_node_or_null("Visual") as Node3D
	var para := ariadne.global_position - _jogador.global_position
	if vis:
		vis.rotation.y = atan2(para.x, para.z)
	var falas := [
		["Ariadne", "Teseu! Meu pai, o rei Minos, vai jogar vocês ao Minotauro."],
		["Teseu", "Vim de Atenas para acabar com esse tributo. Os outros 13 jovens já estão lá dentro."],
		["Ariadne", "O labirinto de Dédalo engana: cada porta é um portal para uma sala ao acaso."],
		["Ariadne", "Leve este novelo. Se você cair, o fio te traz de volta... mas ele só dá 3 voltas."],
	]
	for f in falas:
		await hud.falar(f[0], f[1])
		if _pular:
			break
	# a Ariadne anda até o Teseu e o novelo voa para a cabeça dele
	if not _pular:
		var perto := _jogador.global_position + (ariadne.global_position - _jogador.global_position).normalized() * 1.1
		perto.y = ariadne.global_position.y
		var tw := create_tween()
		tw.tween_property(ariadne, "global_position", perto, 0.7).set_trans(Tween.TRANS_SINE)
		await tw.finished
		await _novelo_voando(ariadne, novelo_cabeca, escala_novelo)
		for f in [["Teseu", "Obrigado, Ariadne. Vou libertar os atenienses e voltar."],
				["Ariadne", "Resolva os 3 enigmas para abrir o caminho até o Minotauro.\nE erga o escudo (Shift) contra as pedras!"]]:
			if _pular:
				break
			await hud.falar(f[0], f[1])
	if novelo_cabeca:
		novelo_cabeca.scale = escala_novelo
	hud.falar_fechar()
	cinematica.emit(false)
	if cam and cam.has_method("soltar"):
		cam.soltar()
	em_cinematica = false
	_jogador.definir_controle(true)
	titulo_sala.emit(area_atual.nome_sala if area_atual else "Labirinto")
	mensagem.emit("Atravesse um portal. Espaço = espada · Shift = escudo · E = usar", 4.0)


func _novelo_voando(ariadne: Node3D, alvo: Node3D, escala_final: Vector3) -> void:
	if alvo == null:
		return
	Som.tocar("novelo")
	var bola := MeshInstance3D.new()
	var esfera := SphereMesh.new()
	esfera.radius = 0.15
	esfera.height = 0.3
	bola.mesh = esfera
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("#c0302a")
	m.emission_enabled = true
	m.emission = Color("#ff5a40")
	m.emission_energy_multiplier = 0.6
	bola.material_override = m
	get_parent().add_child(bola)
	# o carretel fica na mão esquerda dela
	var ini := ariadne.to_global(Vector3(0.17, 0.4, 0.12))
	if ariadne.has_method("tocar"):
		ariadne.tocar("arremessar")
	var na_mao := ariadne.find_child("NoveloMao", true, false) as Node3D
	if na_mao:
		ini = na_mao.global_position
		na_mao.visible = false
	bola.global_position = ini
	var tw := create_tween()
	tw.tween_method(func(k: float):
		var fim := alvo.global_position
		bola.global_position = ini.lerp(fim, k) + Vector3.UP * sin(k * PI) * 1.2
		bola.rotation.x = k * 12.0, 0.0, 1.0, 0.9).set_trans(Tween.TRANS_SINE)
	await tw.finished
	bola.queue_free()
	if na_mao and is_instance_valid(na_mao):
		na_mao.visible = true
	Efeitos.faisca(alvo.global_position, Color(1.0, 0.5, 0.4))
	var tw2 := create_tween()
	tw2.tween_property(alvo, "scale", escala_final * 1.4, 0.12)
	tw2.tween_property(alvo, "scale", escala_final, 0.25).set_trans(Tween.TRANS_BACK)
	await tw2.finished


## Tilt-shift por sala: a arena usa menos desfoque para a luta ficar nítida.
func _aplicar_tilt(area: Node) -> void:
	var filtro := get_parent().find_child("Filtro", true, false) as CanvasItem
	if filtro == null or not (filtro.material is ShaderMaterial):
		return
	var k: float = area.get("tilt_shift") if area and area.get("tilt_shift") != null else 1.0
	var mat := filtro.material as ShaderMaterial
	mat.set_shader_parameter("desfoque_max", desfoque_tilt * k)
	mat.set_shader_parameter("largura_foco", lerpf(0.42, 0.34, clampf(k, 0.0, 1.0)))


func _areas() -> Array[Node]:
	return get_tree().get_nodes_in_group("area_sala")


# --------------------------------------------------------------------------
# Sorteio dos portais e teletransporte
# --------------------------------------------------------------------------
func puzzles_pendentes(excluir: Node = null) -> Array[Node]:
	var lista: Array[Node] = []
	for a in _areas():
		if a.tipo == "puzzle" and not a.esta_concluida() and a != excluir:
			lista.append(a)
	return lista


func sortear_destinos(sala: Node) -> void:
	var portas: Array = sala.portas()
	if portas.is_empty():
		return
	portas.shuffle()
	var combates: Array[Node] = []
	var arena: Node = null
	for a in _areas():
		if a.tipo == "combate" and a != sala:
			combates.append(a)
		elif a.tipo == "chefe":
			arena = a
	var pendentes := puzzles_pendentes(sala)
	pendentes.shuffle()
	combates.shuffle()
	var proxima := salas_visitadas + 1                  # número da sala de destino
	var vagas := sala_do_minotauro - proxima            # salas que ainda cabem antes da arena
	for i in portas.size():
		var destino: Node = null
		if proxima >= sala_do_minotauro and arena:
			destino = arena
		elif not pendentes.is_empty() and (i == 0 or pendentes.size() >= vagas):
			# um portal sempre leva a enigma; se o tempo está acabando, todos levam
			destino = pendentes[i % pendentes.size()]
		elif pendentes.size() > 1 and randf() < chance_enigma_extra:
			destino = pendentes[i % pendentes.size()]
		if destino == null and not combates.is_empty():
			destino = combates[i % combates.size()]
		if destino == null and not pendentes.is_empty():
			destino = pendentes[0]
		portas[i].definir_destino(destino)
		portas[i].ativar(destino != null)


func teleportar(destino: Node) -> void:
	if teleportando or destino == null:
		return
	teleportando = true
	Som.tocar("portal")
	transicao.emit(true)
	await get_tree().create_timer(0.35).timeout
	# desliga os portais da sala de onde saiu (serão sorteados de novo depois)
	if area_atual and area_atual != destino:
		for p in area_atual.portas():
			p.ativar(false)
	var chegada: Vector3 = destino.ponto_de_chegada()
	if _jogador:
		_jogador.global_position = chegada
		_jogador.velocity = Vector3.ZERO
	checkpoint = chegada
	if area_atual != destino and destino.tipo != "inicio":
		salas_visitadas += 1
		salas_mudou.emit(salas_visitadas, sala_do_minotauro)
	area_atual = destino
	var cam := get_viewport().get_camera_3d()
	if cam and cam.has_method("encaixar"):
		cam.encaixar()
	titulo_sala.emit(destino.nome_sala)
	_aplicar_tilt(destino)
	if destino.tipo == "inicio":
		Som.musica("exploracao")
	destino.ao_chegar()
	transicao.emit(false)
	teleportando = false


# --------------------------------------------------------------------------
# Progresso
# --------------------------------------------------------------------------
func definir_checkpoint(pos: Vector3) -> void:
	checkpoint = pos


func libertar_prisioneiros(quantidade: int) -> void:
	prisioneiros_libertados += quantidade
	prisioneiros_mudou.emit(prisioneiros_libertados, total_prisioneiros)


func registrar_puzzle_concluido(nome: String) -> void:
	if nome in puzzles_concluidos:
		return
	puzzles_concluidos.append(nome)
	puzzles_mudou.emit(puzzles_concluidos.size(), puzzles_para_abrir_arena)
	if puzzles_concluidos.size() >= puzzles_para_abrir_arena:
		var faltam_salas := sala_do_minotauro - salas_visitadas - 1
		if faltam_salas <= 0:
			mensagem.emit("Um rugido ecoa pelo labirinto...\nTodos os portais levam ao Minotauro!", 4.0)
		else:
			mensagem.emit("Um rugido ecoa pelo labirinto...\nO Minotauro espera na sala %d." % sala_do_minotauro, 4.0)
	else:
		var faltam := puzzles_para_abrir_arena - puzzles_concluidos.size()
		mensagem.emit("%s libertada! Faltam %d enigma(s)." % [nome, faltam], 3.5)


func sala_combate_vencida(sala: Node) -> void:
	var cura: int = sala.get("cura_ao_vencer") if sala else 0
	if _jogador and _jogador.has_method("curar") and cura > 0:
		_jogador.curar(cura)
		mensagem.emit("Sala vencida! Teseu recupera %d corações." % (cura / 2), 2.5)
	else:
		mensagem.emit("Sala vencida!", 2.0)


# --------------------------------------------------------------------------
# Reinício
# --------------------------------------------------------------------------
## Recomeça a sala em andamento (inimigos e puzzle voltam ao início) sem
## gastar o novelo. Teseu volta para a porta por onde chegou.
func reiniciar_sala_atual() -> void:
	if get_tree().paused:
		get_tree().paused = false
	if sala_atual == null or not sala_atual.has_method("reiniciar"):
		mensagem.emit("Nenhuma sala em andamento para reiniciar.", 2.0)
		return
	var sala := sala_atual
	sala.reiniciar()
	if _jogador:
		_jogador.global_position = checkpoint
		_jogador.velocity = Vector3.ZERO
	mensagem.emit("Sala reiniciada.", 2.0)
	sala.iniciar()


func reiniciar_jogo() -> void:
	get_tree().paused = false
	Som.musica("")
	# a abertura só aparece na primeira vez
	Config.mostrar_abertura = false
	if get_tree().current_scene == null:
		push_warning("reiniciar_jogo: sem current_scene (modo de teste)")
		return
	get_tree().reload_current_scene()


func ir_para_titulo() -> void:
	get_tree().paused = false
	Config.mostrar_abertura = true
	if ResourceLoader.exists(cena_titulo):
		get_tree().change_scene_to_file(cena_titulo)
	else:
		reiniciar_jogo()


# --------------------------------------------------------------------------
# Morte e respawn (o novelo encurta a cada volta)
# --------------------------------------------------------------------------
func jogador_morreu() -> void:
	var sala := sala_atual
	if sala and sala.has_method("reiniciar"):
		sala.reiniciar()
	if novelo <= 0:
		# tela de GAME OVER (hud.gd): tentar de novo ou voltar ao título
		terminou = true
		Som.musica("", 0.5)
		Som.tocar("game_over")
		fim_de_jogo.emit(false)
		return
	novelo -= 1
	novelo_mudou.emit(novelo)
	mensagem.emit("Teseu segue o fio de volta. Restam %d voltas no novelo." % novelo, 3.0)
	if _jogador and _jogador.has_method("renascer"):
		_jogador.renascer(checkpoint)
	if sala and sala.has_method("iniciar"):
		sala.iniciar()


func vitoria() -> void:
	terminou = true
	Som.tocar("vitoria")
	if _jogador and _jogador.has_method("definir_controle"):
		_jogador.definir_controle(false)
	mensagem.emit("O Minotauro caiu! Agora é seguir o fio de volta...", 2.6)
	await get_tree().create_timer(2.8).timeout
	await _final()
	fim_de_jogo.emit(true)


# --------------------------------------------------------------------------
# Final: o fio leva o Teseu e os 13 atenienses de volta à entrada, onde a
# Ariadne espera; depois sobem os créditos (Esc pula tudo).
# --------------------------------------------------------------------------
static var _mesh_conta: SphereMesh
static var _mat_conta: StandardMaterial3D


func _final() -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	var ini: Node3D = null
	for a in _areas():
		if a.tipo == "inicio":
			ini = a
	if ini == null or _jogador == null or hud == null:
		return
	em_cinematica = true
	_pular = false
	transicao.emit(true)
	await get_tree().create_timer(0.6).timeout
	Som.musica("titulo", 1.5)
	for p in ini.portas():
		p.ativar(false)
	var ariadne := ini.find_child("Ariadne", true, false) as Node3D
	var c := ini.global_position
	var saida := c + Vector3(2.1, 0.1, 2.1)
	var destino := c + Vector3(-0.3, 0.1, -0.2)
	_jogador.global_position = saida
	_jogador.velocity = Vector3.ZERO
	area_atual = ini
	cinematica.emit(true)
	var cam := get_viewport().get_camera_3d()
	if cam and cam.has_method("encaixar"):
		cam.encaixar()
	if cam and cam.has_method("focar"):
		cam.focar(c + Vector3(0.2, 0, 0.3), 0.8)
	titulo_sala.emit("Saída do Labirinto")
	_aplicar_tilt(ini)
	# os 13 atenienses (rapazes e moças se alternando)
	var cenas := [load("res://cenas/objetos/prisioneiro.tscn"), load("res://cenas/objetos/prisioneira.tscn")]
	var grupo: Array[Node3D] = []
	for i in total_prisioneiros:
		var p := (cenas[i % 2] as PackedScene).instantiate() as Node3D
		p.name = "Ateniense%d" % i
		ini.add_child(p)
		p.global_position = saida - Vector3(0, 0.1, 0)
		p.scale = Vector3.ONE * 0.01
		if p.has_method("comemorar"):
			p.comemorar()
		grupo.append(p)
	var fio := Node3D.new()
	fio.name = "FioFinal"
	ini.add_child(fio)
	transicao.emit(false)
	await get_tree().create_timer(0.5).timeout
	# o Teseu anda até a Ariadne deixando o fio vermelho no chão
	var t := 0.0
	var ultimo := saida
	_conta_do_fio(fio, saida)
	while t < 4.0 and not _pular:
		var falta := destino - _jogador.global_position
		falta.y = 0.0
		if falta.length() < 0.2:
			break
		_jogador.direcao_cinematica = falta.normalized()
		if _jogador.global_position.distance_to(ultimo) > 0.16:
			ultimo = _jogador.global_position
			_conta_do_fio(fio, ultimo)
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	_jogador.direcao_cinematica = Vector3.ZERO
	var vis := _jogador.get_node_or_null("Visual") as Node3D
	if vis and ariadne:
		var para := ariadne.global_position - _jogador.global_position
		vis.rotation.y = atan2(para.x, para.z)
	# os atenienses saem do portal e se espalham em arco atrás do Teseu
	var longe := Vector3(1, 0, 1).normalized()
	if ariadne:
		longe = destino - ariadne.global_position
		longe.y = 0.0
		longe = longe.normalized()
	var base_ang := atan2(longe.x, longe.z)
	for i in grupo.size():
		var linha := 0 if i < 6 else 1
		var n_linha := 6 if linha == 0 else grupo.size() - 6
		var k := i if linha == 0 else i - 6
		var ang := base_ang + lerpf(-1.45, 1.45, float(k) / maxf(n_linha - 1, 1))
		var raio := 1.3 if linha == 0 else 2.2
		var alvo := destino + Vector3(sin(ang), 0, cos(ang)) * raio
		alvo.x = clampf(alvo.x, c.x - 2.5, c.x + 2.5)
		alvo.z = clampf(alvo.z, c.z - 2.5, c.z + 2.5)
		alvo.y = c.y + 0.05
		var p := grupo[i]
		var dir := alvo - p.global_position
		p.rotation.y = atan2(dir.x, dir.z)
		var tw := p.create_tween()
		tw.tween_interval(0.12 * i)
		tw.tween_property(p, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK)
		tw.tween_property(p, "global_position", alvo, 0.9).set_trans(Tween.TRANS_SINE)
		var olhar := atan2(destino.x - alvo.x, destino.z - alvo.z)
		tw.tween_property(p, "rotation:y", olhar, 0.2)
	if not _pular:
		await get_tree().create_timer(0.6).timeout
	# a Ariadne vem receber o Teseu
	if ariadne and not _pular:
		var perto := _jogador.global_position + (ariadne.global_position - _jogador.global_position).normalized() * 1.1
		perto.y = ariadne.global_position.y
		var para := perto - ariadne.global_position
		ariadne.rotation.y = atan2(para.x, para.z)
		ariadne.set("andando", 0.7)
		var tw2 := create_tween()
		tw2.tween_property(ariadne, "global_position", perto, 0.7).set_trans(Tween.TRANS_SINE)
		tw2.tween_callback(func(): ariadne.set("andando", 0.0))
	var falas := [
		["Ariadne", "Teseu! O fio te trouxe de volta... e você trouxe todos eles!"],
		["Teseu", "O Minotauro caiu. Nenhum jovem de Atenas vai mais ser jogado neste labirinto."],
		["Ariadne", "Então vamos embora de Creta antes que meu pai descubra. O navio espera no porto!"],
	]
	for f in falas:
		if _pular:
			break
		await hud.falar(f[0], f[1])
	hud.falar_fechar()
	if not _pular:
		Som.tocar("vitoria")
		await hud.rolar_creditos()
	em_cinematica = false


func _conta_do_fio(pai: Node3D, pos: Vector3) -> void:
	if _mesh_conta == null:
		_mesh_conta = SphereMesh.new()
		_mesh_conta.radius = 0.055
		_mesh_conta.height = 0.11
		_mesh_conta.radial_segments = 8
		_mesh_conta.rings = 4
		_mat_conta = StandardMaterial3D.new()
		_mat_conta.albedo_color = Color("#c0302a")
		_mat_conta.emission_enabled = true
		_mat_conta.emission = Color("#ff4a36")
		_mat_conta.emission_energy_multiplier = 0.5
	var m := MeshInstance3D.new()
	m.mesh = _mesh_conta
	m.material_override = _mat_conta
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pai.add_child(m)
	m.global_position = Vector3(pos.x, pai.global_position.y + 0.06, pos.z)
