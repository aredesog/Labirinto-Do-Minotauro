class_name GerenciadorJogo
extends Node
## Controla o estado geral da partida: novelo de Ariadne (respawns),
## prisioneiros libertados, enigmas, sorteio dos portais, teletransporte,
## reinício e o acesso ao Minotauro.
##
## Fica na cena principal (sem Autoload). Os outros scripts o encontram pelo
## grupo "jogo":  get_tree().get_first_node_in_group("jogo")
##
## Atalhos: Esc = menu (reiniciar a sala fica só no menu de pausa: o R ficava
## ao lado do E e era apertado sem querer, desfazendo os enigmas)
##
## COMUNICAÇÃO SEM TEXTO: tudo o que antes era mensagem escrita agora é um
## aviso em pictogramas (avisar([...])) e as cenas da Ariadne são pantomima
## com balões de ícones (hud.balao). Assim o jogo não depende de idioma.
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
## Aviso SEM TEXTO: uma frase de pictogramas (ver Pictograma). O HUD mostra.
signal aviso_visual(icones: Array, duracao: float)
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
## Antes de cada enigma (só na 1ª visita), um trecho de labirinto até ele.
@export var labirinto_antes_do_enigma := true
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
## O fio vermelho no chão (FioAriadne).
var _fio: FioAriadne
var _cena_queda := false
## O labirinto em volta da arena (gerado na partida).
var _labirinto: Labirinto
## Sala de enigma -> o trecho de labirinto que leva até ela.
var _corredores := {}
## Enigmas cujo labirinto já foi atravessado (não repete).
var _corredor_feito := {}


func _enter_tree() -> void:
	add_to_group("jogo")
	_registrar_controles()


func _ready() -> void:
	Engine.time_scale = 1.0
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
		_fio = FioAriadne.new()
		_fio.name = "FioAriadne"
		_fio.alvo = _jogador
		_fio.comecar(checkpoint)
		get_parent().add_child.call_deferred(_fio)
	# placas de texto 3D (nome da Ariadne, "Entrada do Labirinto") somem
	for nome in ["NomeAriadne", "Titulo"]:
		var rotulo := get_parent().find_child(nome, true, false)
		if rotulo is Label3D:
			rotulo.visible = false
	for a in _areas():
		if a.tipo == "inicio":
			area_atual = a
			a.visitada = true
			sortear_destinos(a)
			_aplicar_tilt(a)
			_montar_tutorial(a)
	_montar_labirinto()
	_montar_corredores()
	Som.musica("exploracao", 1.5)
	novelo_mudou.emit(novelo)
	prisioneiros_mudou.emit(prisioneiros_libertados, total_prisioneiros)
	puzzles_mudou.emit(0, puzzles_para_abrir_arena)
	if Config.mostrar_abertura:
		await _abertura()
	else:
		await get_tree().create_timer(0.3).timeout
		avisar(REGRA, 4.0)


func _process(_delta: float) -> void:
	Efeitos.garantir_tempo_normal()


func _unhandled_input(evento: InputEvent) -> void:
	if em_cinematica:
		if evento.is_action_pressed("pausar"):
			_pular = true
			get_viewport().set_input_as_handled()
		return


func _registrar_controles() -> void:
	Config.registrar_controles()


## A regra do jogo numa frase visual: portal -> 3 enigmas -> Minotauro.
const REGRA := ["portal", "seta", "diamante", "diamante", "diamante", "seta", "minotauro"]


## Mostra um aviso em pictogramas no HUD (no lugar das mensagens de texto).
func avisar(icones: Array, duracao := 2.6) -> void:
	aviso_visual.emit(icones, duracao)


## Balão de pantomima (só nas cenas). Devolve quando o balão fecha.
func _balao(hud: Node, quem: Node3D, icones: Array, dur := 2.3, gesto := "") -> void:
	if _pular or hud == null or quem == null:
		return
	if gesto != "" and quem.has_method("gesto"):
		quem.gesto(gesto)
	var voz := 0.85 if quem == _jogador else 1.35
	await hud.balao(quem, icones, dur, voz)


# --------------------------------------------------------------------------
# Abertura em 3 atos, sem nenhuma palavra (Esc pula tudo). Ritmo de cinema:
# emoção segura o plano, ação corta rápido; cor e trilha mudam por ato.
#   1. O LABIRINTO E OS REFÉNS — escuro com choro; plano altíssimo descendo;
#      grades em primeiro plano; close num refém chorando; as outras celas
#      em cortes rápidos; a conta  [cela][ateniense] 13
#   2. O MINOTAURO — silêncio; só a silhueta contra a luz vermelha; o casco
#      pisando; revelação dos pés ao rosto e o rugido (vertigo + música);
#      o machado em 3 planos; as crias surgem e correm para a câmera; preto
#   3. A ESPERANÇA — luz dourada; reação do Teseu; a Ariadne entra em quadro
#      e imagina o plano; contraplano no Teseu; o novelo voando em câmera
#      lenta; o pensamento do novelo; a regra; plano de herói para o portal
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
	await get_tree().create_timer(0.25).timeout
	_pular = false
	_jogador.definir_controle(false)
	var novelo_cabeca := _jogador.get_node_or_null("Visual/Novelo") as Node3D
	var escala_novelo := novelo_cabeca.scale if novelo_cabeca else Vector3.ONE
	if novelo_cabeca:
		novelo_cabeca.scale = Vector3.ONE * 0.01
	cinematica.emit(true)
	# Teseu olha para a Ariadne
	var vis := _jogador.get_node_or_null("Visual") as Node3D
	var para := ariadne.global_position - _jogador.global_position
	if vis:
		vis.rotation.y = atan2(para.x, para.z)

	_tilt_cinema(true)
	var crias: Array[Node] = []
	var luz_vermelha: OmniLight3D = null
	# Ritmo: emoção SEGURA o plano (2,5–4 s); ação CORTA rápido (0,5–1 s).
	# Cor por ato: azul frio = medo, vermelho = perigo, dourado = esperança.

	# ==== ATO 1: o labirinto e os reféns ====================================
	# 1. escuridão: só um choro baixinho e um rugido ao longe
	Som.musica("", 0.3)
	hud.preto(true)
	hud.cinema_tom(Color(0.72, 0.84, 1.1), 0.6, 0.75, 0.1)
	for k in 3:
		if not _pular:
			Som.tocar("texto", -10.0, 0.0, 0.55 + k * 0.05)
		await _esperar_cena(0.22)
	if not _pular:
		Som.tocar("rugido", -18.0, 0.0, 0.6)
	await _esperar_cena(0.6)
	var celas := get_tree().get_nodes_in_group("cela")
	if not celas.is_empty() and not _pular:
		var cela := celas[0] as Node3D
		var sala_c := cela.get_parent() as Node3D
		var centro_c := sala_c.global_position if sala_c else cela.global_position
		# 2. SOBREVOO DO LABIRINTO: enorme, com a coluna de luz vermelha e o
		#    Minotauro lá no centro. A câmera desce devagar sobre os corredores.
		Som.musica("enigma", 1.5)
		if _labirinto:
			var c0 := _labirinto.global_position
			_labirinto.mostrar_coluna(true)
			_corte_seco(cam, c0 + Vector3(-12.0, 54.0, 36.0), c0 + Vector3(0, 0, 2.0), 50.0)
			hud.preto(false, 0.8)
			if cam:
				cam.mover_plano(c0 + Vector3(-3.0, 30.0, 22.0), c0 + Vector3(0, 0, -1.0), 4.0)
			await _esperar_cena(4.0)
			_labirinto.mostrar_coluna(false)
		else:
			_corte_seco(cam, centro_c + Vector3(0, 24.0, 6.0), cela.to_global(Vector3(0, 0.5, -0.6)), 50.0)
			hud.preto(false, 0.8)
			if cam:
				cam.mover_plano(centro_c + Vector3(-1.0, 9.0, 5.0), cela.to_global(Vector3(0, 0.6, -0.6)), 3.2)
			await _esperar_cena(3.2)
		# 3. grades em primeiro plano, a câmera entra devagar entre as barras
		_corte_seco(cam, cela.to_global(Vector3(0.35, 0.95, 1.1)), cela.to_global(Vector3(0.0, 0.8, -0.8)), 45.0)
		if cam:
			cam.mover_plano(cela.to_global(Vector3(0.15, 0.9, 0.35)), cela.to_global(Vector3(0.0, 0.8, -0.8)), 2.2)
		await _esperar_cena(2.0)
		# 4. close no rosto de um refém, chorando (o plano SEGURA a emoção)
		var presos := cela.get_children().filter(func(n): return n is Prisioneiro)
		if not presos.is_empty() and not _pular:
			var p := presos[presos.size() / 2] as Node3D
			var cabeca := p.global_position + Vector3.UP * 0.75
			_corte_seco(cam, cela.to_global(p.position + Vector3(0.25, 0.85, 0.85)), cabeca, 40.0)
			if cam:
				cam.mover_plano(cela.to_global(p.position + Vector3(0.12, 0.8, 0.65)), cabeca, 2.6)
			await hud.balao(p, ["choro", "minotauro"], 2.6, 1.7, false)
	# 5. as outras celas, rápido: de lado e de cima ("são muitos")
	var outros := [[Vector3(2.8, 0.45, 1.6), Vector3(0, 0.9, -0.7), 55.0], [Vector3(0.0, 3.6, 2.2), Vector3(0, 0.3, -0.7), 55.0]]
	for i in range(1, mini(celas.size(), 3)):
		if _pular:
			break
		var cela := celas[i] as Node3D
		var ang: Array = outros[i - 1]
		_corte_seco(cam, cela.to_global(ang[0]), cela.to_global(ang[1]), ang[2])
		var presos := cela.get_children().filter(func(n): return n is Prisioneiro)
		if not presos.is_empty():
			hud.balao(presos[0], ["choro"], 1.1, 2.0, false)
		if i == mini(celas.size(), 3) - 1:
			# 6. a conta: 13 presos
			avisar(["cela", "ateniense", "num:%d" % total_prisioneiros], 2.0)
			await _esperar_cena(2.0)
		else:
			await _esperar_cena(1.2)

	# ==== ATO 2: o Minotauro ===============================================
	var mino: Node3D = null
	for a in _areas():
		if a.tipo == "chefe":
			mino = a.find_child("Minotauro", true, false) as Node3D
	if mino and mino.has_method("golpear_na_cena") and not _pular:
		var m := mino.global_transform
		# 1. silêncio total e escuro
		Som.musica("", 0.3)
		await _corte_plano(cam, m * Vector3(0.4, 0.8, 6.5), m * Vector3(0, 2.0, 0), 30.0)
		# 2. só a SILHUETA: luz vermelha atrás dele, frente quase preta
		hud.cinema_tom(Color(0.5, 0.32, 0.32), 0.5, 0.9, 0.05)
		luz_vermelha = OmniLight3D.new()
		luz_vermelha.light_color = Color(1.0, 0.18, 0.1)
		luz_vermelha.omni_range = 7.0
		luz_vermelha.light_energy = 5.0
		luz_vermelha.visible = Config.qualidade == "alta"
		mino.add_child(luz_vermelha)
		luz_vermelha.position = Vector3(0, 1.6, -2.2)
		if not _pular:
			Som.tocar("grunhido", -4.0, 0.0, 0.55)
		await _esperar_cena(2.0)
		# 3. pé no chão: câmera rente, o casco pisa e a poeira sobe (o peso dele)
		_corte_seco(cam, m * Vector3(1.0, 0.22, 1.8), m * Vector3(0.35, 0.15, 0.5), 45.0)
		if not _pular:
			Som.tocar("casco", 3.0, 0.0, 0.7)
			Efeitos.poeira(m * Vector3(0.35, 0.05, 0.6), 10, 0.5)
		await _esperar_cena(1.0)
		# 4. REVELAÇÃO: dos pés ao rosto, devagar; ele ruge — vertigo, a
		#    câmera inclina e a música do chefe entra junto com o rugido
		_corte_seco(cam, m * Vector3(0.5, 0.35, 4.2), m * Vector3(0, 0.6, 0), 40.0)
		if cam:
			cam.mover_plano(m * Vector3(0.9, 0.45, 6.2), m * Vector3(0, 2.3, 0), 1.6, 34.0)
		await _esperar_cena(1.6)
		if not _pular:
			hud.cinema_tom(Color(1.15, 0.78, 0.72), 0.85, 0.75, 0.15)
			Som.musica("chefe", 0.1)
			mino.rugir_na_cena()
			luz_vermelha.position = Vector3(0, 0.4, 1.6)
			var pulso := luz_vermelha.create_tween().set_loops()
			pulso.tween_property(luz_vermelha, "light_energy", 4.0, 0.45).set_trans(Tween.TRANS_SINE)
			pulso.tween_property(luz_vermelha, "light_energy", 1.5, 0.45).set_trans(Tween.TRANS_SINE)
			if cam:
				cam.vertigo(70.0, 2.0)
				cam.rolar(0.17, 2.0)
		await _esperar_cena(2.2)
		# 5. o machado: 3 planos rápidos (sobe / impacto / onda de cima)
		_corte_seco(cam, m * Vector3(1.6, 1.4, 2.4), m * Vector3(0.5, 3.0, 0.0), 50.0, -0.1)
		if not _pular:
			mino.golpear_na_cena()
		await _esperar_cena(0.62)
		_corte_seco(cam, m * Vector3(-2.6, 0.5, 4.2), m * Vector3(0, 0.4, 2.4), 55.0, 0.08)
		if not _pular:
			hud.flash(Color(1.0, 0.85, 0.7), 0.45)
			Efeitos.congelar(get_tree(), 0.16, 0.05)
			if cam:
				cam.tremer(0.6)
		await _esperar_cena(0.5)
		_corte_seco(cam, m * Vector3(0, 7.5, 4.0), m * Vector3(0, 0, 2.4), 55.0)
		await _esperar_cena(0.6)
		# 6. os minitaurinhos surgem da fumaça
		_corte_seco(cam, m * Vector3(4.5, 3.0, 5.8), m * Vector3(0, 0.6, 2.4), 55.0)
		if not _pular:
			crias = _crias_na_cena(mino)
		await _esperar_cena(1.4)
		# 7. eles saem pelo portão e CORREM PELOS CORREDORES do labirinto, atrás
		#    do Teseu — a câmera persegue o primeiro, de cima e de trás
		if _labirinto and not _pular:
			for c in crias:
				if is_instance_valid(c):
					c.queue_free()
			crias = _crias_no_labirinto(mino)
			var lider: Node3D = null
			if not crias.is_empty():
				lider = crias[0] as Node3D
			if lider:
				var c0 := lider.global_position
				_corte_seco(cam, c0 + Vector3(0, 5.0, -4.0), c0 + Vector3(0, 0.4, 3.0), 60.0)
				if cam:
					cam.set("mao", 1.6)
				mino.rugir_na_cena()
				var t_perseguir := 0.0
				while t_perseguir < 2.8 and not _pular and is_instance_valid(lider):
					var v := Vector3(lider.velocity.x, 0, lider.velocity.z)
					var frente := v.normalized() if v.length() > 0.3 else Vector3(0, 0, 1)
					if cam:
						cam.mover_plano(lider.global_position - frente * 4.2 + Vector3.UP * 4.2,
							lider.global_position + frente * 2.5 + Vector3.UP * 0.4, 0.3)
					await get_tree().process_frame
					t_perseguir += get_process_delta_time()
			if not _pular:
				hud.preto(true)
				Som.tocar("impacto", -4.0, 0.0, 1.3)
			await _esperar_cena(0.7)
	if mino and mino.has_method("golpear_na_cena") and not _pular and not _labirinto:
		var m := mino.global_transform
		var lente_chao := m * Vector3(-0.4, 0.45, 8.0)
		_corte_seco(cam, lente_chao, m * Vector3(0, 0.9, 2.5), 62.0, -0.09)
		if cam:
			cam.set("mao", 2.2)
		for c in crias.size():
			if is_instance_valid(crias[c]):
				var alvo_c := lente_chao if c == 1 else m * Vector3(-2.2 + c * 2.2, 0, 12.0)
				crias[c].correr_na_cena(Vector3(alvo_c.x, 0.0, alvo_c.z))
		await _esperar_cena(0.3)
		if not _pular:
			mino.rugir_na_cena()
		await _esperar_cena(1.2)
		if not _pular:
			hud.preto(true)
			Som.tocar("impacto", -4.0, 0.0, 1.3)
		await _esperar_cena(0.7)
	if cam:
		cam.set("mao", 1.0)
	if luz_vermelha and is_instance_valid(luz_vermelha):
		luz_vermelha.queue_free()
	for c in crias:
		if is_instance_valid(c):
			c.queue_free()
	crias.clear()

	# ==== ATO 3: a esperança ===============================================
	var meio := ariadne.global_position.lerp(_jogador.global_position, 0.5)
	var lado := _jogador.global_position - ariadne.global_position
	lado.y = 0.0
	lado = lado.normalized()
	var lat := Vector3(-lado.z, 0, lado.x)
	if lat.z < 0.0:
		lat = -lat   # a câmera fica do lado de "baixo" da tela, como no jogo
	var tp := _jogador.global_position
	# 1. do preto para a luz dourada da entrada
	Som.musica("titulo", 1.0)
	hud.cinema_tom(Color(1.1, 0.97, 0.82), 1.05, 0.5, 0.05)
	# 2. reação: close no Teseu, ainda assustado com o que viu
	_corte_seco(cam, tp - lado * 1.3 + lat * 0.45 + Vector3.UP * 1.0, tp + Vector3.UP * 0.95, 42.0)
	hud.preto(false, 0.6)
	if not _pular:
		_jogador.gesto("susto", 1.0)
	await _esperar_cena(2.0)
	# 3. a Ariadne entra em quadro pelo lado
	var pos_ariadne := ariadne.global_position
	_corte_seco(cam, meio + lat * 3.4 + Vector3.UP * 1.25, meio + Vector3.UP * 0.9, 48.0)
	if not _pular:
		ariadne.global_position = pos_ariadne - lado * 1.6
		ariadne.set("andando", 0.7)
		var entra := create_tween()
		entra.tween_property(ariadne, "global_position", pos_ariadne, 1.3).set_trans(Tween.TRANS_SINE)
		entra.tween_callback(func(): ariadne.set("andando", 0.0))
	await _esperar_cena(1.5)
	ariadne.global_position = pos_ariadne
	# 4. ela imagina o plano; a câmera se aproxima devagar dela
	if cam:
		cam.mover_plano(meio + lat * 2.4 - lado * 0.6 + Vector3.UP * 1.25, ariadne.global_position + Vector3.UP * 1.2, 7.0)
	if not _pular:
		ariadne.gesto("chamar")
		await hud.pensar(ariadne, "missao")
	# 5. contraplano: close no Teseu, decidido
	_corte_seco(cam, ariadne.global_position - lado * 1.1 + lat * 0.45 + Vector3.UP * 1.45,
		tp + Vector3.UP * 0.9, 42.0)
	await _balao(hud, _jogador, ["espada", "seta", "minotauro"], 2.2, "sim")
	if not _pular:
		# 6. o novelo voa: plano de lado, a câmera acompanha a bola (câmera lenta)
		var perto := tp + (ariadne.global_position - tp).normalized() * 1.1
		perto.y = ariadne.global_position.y
		var anda := create_tween()
		anda.tween_property(ariadne, "global_position", perto, 0.7).set_trans(Tween.TRANS_SINE)
		await anda.finished
		meio = ariadne.global_position.lerp(tp, 0.5)
		_corte_seco(cam, meio + lat * 2.4 + Vector3.UP * 1.4, ariadne.global_position + Vector3.UP * 1.0, 50.0)
		if cam:
			cam.mover_plano(meio + lat * 2.2 + Vector3.UP * 1.6, tp + Vector3.UP * 1.3, 1.0)
		Efeitos.congelar(get_tree(), 1.0, 0.5, true)
		await _novelo_voando(ariadne, novelo_cabeca, escala_novelo)
		# 7. o pensamento do novelo (plano médio nela) e a regra (plano a dois)
		if not _pular:
			_corte_seco(cam, ariadne.global_position + lado * 2.4 + lat * 1.0 + Vector3.UP * 1.1,
				ariadne.global_position + Vector3.UP * 1.4, 48.0)
			ariadne.gesto("sim")
			await hud.pensar(ariadne, "novelo")
		_corte_seco(cam, meio + lat * 3.2 + Vector3.UP * 1.3, meio + Vector3.UP * 0.9, 50.0)
		await _balao(hud, ariadne, REGRA, 3.2, "chamar")
		# 8. plano final de herói: câmera baixa atrás do Teseu, olhando o portal aceso
		var portal: Node3D = null
		var menor := 1e9
		for po in ini.portas():
			if po.ativa and (po as Node3D).global_position.distance_to(tp) < menor:
				menor = (po as Node3D).global_position.distance_to(tp)
				portal = po
		if portal and not _pular:
			var para_portal := portal.global_position - tp
			para_portal.y = 0.0
			para_portal = para_portal.normalized()
			if vis:
				vis.rotation.y = atan2(para_portal.x, para_portal.z)
			var l2 := Vector3(-para_portal.z, 0, para_portal.x)
			_corte_seco(cam, tp - para_portal * 1.7 + l2 * 0.45 + Vector3.UP * 0.45,
				portal.global_position + Vector3.UP * 1.3, 50.0, 0.04)
			if cam:
				cam.mover_plano(tp - para_portal * 2.4 + l2 * 0.5 + Vector3.UP * 0.6,
					portal.global_position + Vector3.UP * 1.4, 2.2)
			_jogador.gesto("sim", 0.9)
			await _esperar_cena(2.2)

	# ---- fim (também quando a cena é pulada)
	if luz_vermelha and is_instance_valid(luz_vermelha):
		luz_vermelha.queue_free()
	if cam and "mao" in cam:
		cam.set("mao", 1.0)
	Som.musica("exploracao", 1.5)
	for c in crias:
		if is_instance_valid(c):
			c.queue_free()
	if novelo_cabeca:
		novelo_cabeca.scale = escala_novelo
	if mino and mino.has_method("resetar"):
		mino.resetar()
	hud.falar_fechar()
	cinematica.emit(false)
	transicao.emit(false)
	if cam and cam.has_method("soltar"):
		cam.soltar()
		cam.encaixar()
	_tilt_cinema(false)
	em_cinematica = false
	_jogador.definir_controle(true)
	titulo_sala.emit(area_atual.nome_sala if area_atual else "Labirinto")
	avisar(REGRA, 3.5)


## Corte com fade para um plano de cinema (posição + mira + lente).
func _corte_plano(cam: Camera3D, pos: Vector3, mira: Vector3, lente: float, rolo := 0.0) -> void:
	if _pular:
		return
	transicao.emit(true)
	await get_tree().create_timer(0.22).timeout
	_corte_seco(cam, pos, mira, lente, rolo)
	transicao.emit(false)
	await get_tree().create_timer(0.2).timeout


## Corte seco (sem fade) para outro ângulo da mesma cena.
func _corte_seco(cam: Camera3D, pos: Vector3, mira: Vector3, lente: float, rolo := 0.0) -> void:
	if _pular or cam == null or not cam.has_method("plano"):
		return
	cam.plano(pos, mira, lente, rolo)


## Na cena, o tilt-shift (efeito maquete) fica bem leve: os planos são de perto.
var _tilt_estava_visivel := true


## Nas cenas o tilt-shift (efeito maquete) é DESLIGADO: os planos são de perto
## e assim só um filtro de tela roda por vez (mais leve em GPU integrada).
func _tilt_cinema(ligar: bool) -> void:
	var filtro := get_parent().find_child("Filtro", true, false) as CanvasItem
	var camada := get_parent().find_child("TiltShift", true, false)
	var alvo: Node = camada if camada else filtro
	if alvo == null:
		return
	if ligar:
		_tilt_estava_visivel = bool(alvo.get("visible"))
		alvo.set("visible", false)
	else:
		alvo.set("visible", _tilt_estava_visivel)
		_aplicar_tilt(area_atual)


## Minitaurinhos que surgem na frente do Minotauro (só atores: não atacam).
func _crias_na_cena(mino: Node3D) -> Array[Node]:
	var lista: Array[Node] = []
	var cena: PackedScene = mino.get("cena_minitaurinho")
	if cena == null:
		return lista
	for x: float in [-1.6, 0.0, 1.6]:
		var c := cena.instantiate() as Node3D
		mino.get_parent().add_child(c)
		c.global_position = mino.global_transform * Vector3(x, 0.2, 2.4 + absf(x) * -0.3)
		if c.has_method("entrar_na_cena"):
			c.entrar_na_cena()
		Efeitos.fumaca(c.global_position)
		lista.append(c)
	Som.tocar("puf", -2.0)
	return lista


## Corte de câmera com fade (cenas): escurece, pula para o ponto e clareia.
func _corte(cam: Camera3D, ponto: Vector3, zoom: float) -> void:
	if _pular:
		return
	transicao.emit(true)
	await get_tree().create_timer(0.32).timeout
	if cam and cam.has_method("focar"):
		cam.focar(ponto, zoom)
		cam.encaixar()
	transicao.emit(false)
	await get_tree().create_timer(0.35).timeout


func _esperar_cena(seg: float) -> void:
	var t := 0.0
	while t < seg and not _pular:
		await get_tree().process_frame
		t += get_process_delta_time()


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
	# a 10ª "sala" é o LABIRINTO: no centro dele fica a arena
	if _labirinto:
		arena = _labirinto
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
	# o 1º caminho até um enigma passa por um trecho de labirinto
	if labirinto_antes_do_enigma and destino.tipo == "puzzle" and destino != area_atual \
			and _corredores.has(destino) and not _corredor_feito.has(destino):
		destino = _corredores[destino]
	var vindo_do_corredor := area_atual is MiniLabirinto
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
	if _fio:
		_fio.comecar(chegada)
	# o labirinto e o enigma do outro lado contam como UMA sala
	if area_atual != destino and destino.tipo != "inicio" and not vindo_do_corredor:
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
		# o Minotauro acorda: rugido, tremor e o aviso  ◆◆◆ -> Minotauro
		Som.tocar("rugido", -2.0, 0.0, 0.85)
		var cam := get_viewport().get_camera_3d()
		if cam and cam.has_method("tremer"):
			cam.tremer(0.5)
		avisar(["diamante", "diamante", "diamante", "seta", "minotauro"], 4.0)
	else:
		# progresso: diamantes cheios e vazios (◆◆◇)
		var lista := []
		for i in puzzles_para_abrir_arena:
			lista.append("diamante" if i < puzzles_concluidos.size() else "diamante_vazio")
		avisar(lista, 3.0)


func sala_combate_vencida(sala: Node) -> void:
	var cura: int = sala.get("cura_ao_vencer") if sala else 0
	if _jogador and _jogador.has_method("curar") and cura > 0:
		_jogador.curar(cura)
		var lista := ["certo", "|", "mais"]
		for i in maxi(cura / 2, 1):
			lista.append("coracao")
		avisar(lista, 2.4)
	else:
		avisar(["certo"], 1.8)


# --------------------------------------------------------------------------
# Reinício
# --------------------------------------------------------------------------
## Recomeça a sala em andamento (inimigos e puzzle voltam ao início) sem
## gastar o novelo. Teseu volta para a porta por onde chegou.
func reiniciar_sala_atual() -> void:
	if get_tree().paused:
		get_tree().paused = false
	if sala_atual == null or not sala_atual.has_method("reiniciar"):
		avisar(["reiniciar", "errado"], 1.6)
		return
	var sala := sala_atual
	sala.reiniciar()
	if _jogador:
		_jogador.global_position = checkpoint
		_jogador.velocity = Vector3.ZERO
	avisar(["reiniciar"], 1.6)
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
	# quantas voltas do novelo sobraram (cheios e vazios)
	var lista := []
	for i in novelo_inicial:
		lista.append("novelo" if i < novelo else "novelo_vazio")
	avisar(lista, 2.8)
	# o FIO puxa o Teseu de volta pelo caminho até a porta onde ele chegou
	if _fio and _jogador and is_instance_valid(_fio):
		await get_tree().create_timer(0.35).timeout
		await _fio.puxar(_jogador, 0.85)
	if _jogador and _jogador.has_method("renascer"):
		_jogador.renascer(checkpoint)
	if _fio:
		_fio.comecar(checkpoint)
	if sala and sala.has_method("iniciar"):
		sala.iniciar()


func vitoria() -> void:
	terminou = true
	if not _cena_queda:
		Som.tocar("vitoria")   # (com a cena da queda, ela toca no momento do troféu)
	if _jogador and _jogador.has_method("definir_controle"):
		_jogador.definir_controle(false)
	await get_tree().create_timer(0.6).timeout
	var espera := 0.0
	while _cena_queda and espera < 12.0:
		await get_tree().process_frame
		espera += get_process_delta_time()
	avisar(["minotauro", "estrelas", "|", "novelo", "seta", "casa"], 2.0)
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
	if _fio:
		_fio.visible = false   # no final o caminho vira as contas vermelhas
	for anf in get_tree().get_nodes_in_group("anfora_tutorial"):
		anf.queue_free()
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
	# alguns atenienses com balão de coração (no começo, choravam nas celas)
	for k: int in [0, 4, 9]:
		if k < grupo.size() and not _pular:
			var quem := grupo[k]
			get_tree().create_timer(1.4 + k * 0.15).timeout.connect(func():
				if is_instance_valid(quem) and hud:
					hud.balao(quem, ["coracao"], 2.2, 2.0, false, 1.5))
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
	# PANTOMIMA do final
	#   Ariadne: "você voltou!"   Teseu: "e trouxe todos!"
	#   Ariadne: "vamos embora de navio"
	await get_tree().create_timer(0.4).timeout
	await _balao(hud, ariadne, ["coracao"], 2.0, "sim")
	await _balao(hud, _jogador, ["ateniense", "ateniense", "ateniense", "certo"], 2.4, "vitoria")
	await _balao(hud, ariadne, ["navio", "seta", "casa"], 2.6, "chamar")
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



# --------------------------------------------------------------------------
# Queda do Minotauro (fecha a história da abertura):
#   1. o golpe final CONGELA meio segundo em preto e branco, como uma foto
#   2. câmera lenta: ele cai, visto de 3 ângulos rápidos (baixo, lado, cima)
#   3. silêncio: plano parado de longe, ele no chão com as estrelinhas
#   4. os minitaurinhos espiam e fogem
#   5. o Teseu ergue a espada e a música entra, triunfal
# Os tempos usam relógio REAL (a câmera lenta não estica a cena).
# --------------------------------------------------------------------------
func cena_queda_minotauro(mino: Node3D) -> void:
	if mino == null or _cena_queda:
		return
	_cena_queda = true
	var cam := get_viewport().get_camera_3d()
	var hud := get_tree().get_first_node_in_group("hud")
	if _jogador:
		_jogador.definir_controle(false)
	cinematica.emit(true)
	_tilt_cinema(true)
	var arena := mino.get_parent() as Node3D
	var centro := arena.global_position if arena else mino.global_position
	var pm := mino.global_position
	var tp := _jogador.global_position if _jogador else centro
	var para_centro := centro - pm
	para_centro.y = 0.0
	if para_centro.length() < 0.5:
		para_centro = Vector3(0, 0, 1)
	para_centro = para_centro.normalized()
	var lat := Vector3(-para_centro.z, 0, para_centro.x)
	# 1. a "foto": tudo quase parado, sem cor, com flash
	Efeitos.congelar(get_tree(), 0.55, 0.02, true)
	if hud:
		hud.flash()
		hud.cinema_tom(Color(1.0, 1.0, 1.0), 0.0, 0.85, 0.05)
	_corte_seco(cam, tp + (pm - tp).normalized() * -1.2 + lat * 0.6 + Vector3.UP * 1.0, pm + Vector3.UP * 1.8, 45.0, 0.12)
	await _esperar_real(0.55)
	# 2. câmera lenta, 3 ângulos rápidos
	Efeitos.congelar(get_tree(), 1.5, 0.3, true)
	if hud:
		hud.cinema_tom(Color(0.92, 0.94, 1.05), 0.35, 0.8, 0.3)
	_corte_seco(cam, pm + para_centro * 4.2 + lat * 1.2 + Vector3.UP * 0.5, pm + Vector3.UP * 1.6, 52.0, 0.2)
	if cam and cam.has_method("rolar"):
		cam.rolar(0.0, 0.5)
	await _esperar_real(0.5)
	_corte_seco(cam, pm + lat * 4.5 + Vector3.UP * 1.2, pm + Vector3.UP * 0.9, 50.0)
	await _esperar_real(0.5)
	_corte_seco(cam, pm + Vector3.UP * 7.0 + para_centro * 1.5, pm, 50.0)
	await _esperar_real(0.6)
	# 3. silêncio: de longe, parado, ele no chão
	Som.musica("", 0.2)
	if hud:
		hud.cinema_tom(Color(0.95, 0.95, 1.0), 0.6, 0.7, 0.5)
	_corte_seco(cam, centro + para_centro * -2.0 + Vector3(0, 3.0, 0) + (centro - pm).normalized() * 6.0,
		pm + Vector3.UP * 0.6, 40.0)
	if cam:
		cam.set("mao", 0.3)
	await _esperar_real(1.6)
	# 4. as crias aparecem, se assustam e fogem para longe do Teseu
	var crias := _crias_na_cena(mino)
	var fuga := pm - tp
	fuga.y = 0.0
	fuga = fuga.normalized() if fuga.length() > 0.1 else -para_centro
	_corte_seco(cam, centro + Vector3(0, 9.0, 8.0), pm + Vector3.UP * 0.5, 55.0)
	if cam:
		cam.set("mao", 1.0)
	if hud and crias.size() > 1:
		hud.balao(crias[1], ["exclamacao"], 1.0, 2.2, false, 1.5)
	await _esperar_real(0.6)
	for i in crias.size():
		var c := crias[i] as Node3D
		var lado := Vector3(-fuga.z, 0, fuga.x) * (i - 1) * 2.0
		c.correr_na_cena(c.global_position + fuga * 9.0 + lado)
	await _esperar_real(1.2)
	# 5. o Teseu ergue a espada; música triunfal, cores douradas
	if hud:
		hud.cinema_tom(Color(1.12, 0.98, 0.8), 1.1, 0.5, 0.4)
	Som.musica("titulo", 0.3)
	Som.tocar("vitoria", -2.0)
	if _jogador:
		var d2 := centro - tp
		d2.y = 0.0
		d2 = d2.normalized() if d2.length() > 0.3 else para_centro
		var l2 := Vector3(-d2.z, 0, d2.x)
		_corte_seco(cam, tp + d2 * 2.2 + l2 * 0.6 + Vector3.UP * 0.35, tp + Vector3.UP * 1.0, 48.0, -0.05)
		if cam:
			cam.mover_plano(tp + d2 * 1.6 + l2 * 0.4 + Vector3.UP * 0.3, tp + Vector3.UP * 1.1, 2.0)
		if _jogador.has_method("gesto"):
			_jogador.gesto("vitoria", 1.4)
		if hud:
			hud.balao(_jogador, ["trofeu"], 1.8, 0.85)
	await _esperar_real(2.2)
	for c in crias:
		if is_instance_valid(c):
			c.queue_free()
	_cena_queda = false


## Espera em tempo REAL (não estica com a câmera lenta).
func _esperar_real(seg: float) -> void:
	await get_tree().create_timer(seg, true, false, true).timeout



# --------------------------------------------------------------------------
# Tutorial jogável na entrada: 3 ânforas para quebrar com a espada.
# A tecla [Espaço] aparece em cima delas (HUD); quebrar todas dá um [✓].
# --------------------------------------------------------------------------
const ANFORAS_TUTORIAL := [Vector3(2.0, 0, 2.0), Vector3(-2.1, 0, 1.9), Vector3(2.2, 0, -0.7)]


func _montar_tutorial(inicio: Node3D) -> void:
	var cena := load("res://cenas/objetos/anfora.tscn") as PackedScene
	if cena == null:
		return
	var script_anfora := load("res://scripts/salas/anfora_quebravel.gd")
	for pos: Vector3 in ANFORAS_TUTORIAL:
		var anf := cena.instantiate()
		anf.set_script(script_anfora)
		anf.name = "AnforaTutorial"
		inicio.add_child(anf)
		(anf as Node3D).position = pos
		anf.add_to_group("anfora_tutorial")
		anf.quebrada.connect(_ao_quebrar_anfora)


func _ao_quebrar_anfora() -> void:
	await get_tree().process_frame
	var restam := get_tree().get_nodes_in_group("quebravel").filter(func(n): return n.is_in_group("anfora_tutorial"))
	if restam.is_empty():
		Som.tocar("cura")
		avisar(["tecla_espaco", "espada", "|", "certo"], 1.8)



# --------------------------------------------------------------------------
# O labirinto em volta da arena
# --------------------------------------------------------------------------
func _montar_labirinto() -> void:
	var arena: Node3D = null
	for a in _areas():
		if a.tipo == "chefe":
			arena = a as Node3D
	if arena == null:
		return
	var lab := Labirinto.new()
	lab.name = "Labirinto"
	arena.get_parent().add_child(lab)
	lab.global_transform = arena.global_transform
	var rng := RandomNumberGenerator.new()
	rng.seed = randi()   # sorteado a cada partida (e fixo com a semente do teste)
	lab.montar(rng, arena)
	_labirinto = lab


## Um trecho de labirinto para cada sala de enigma, longe do resto do mapa
## (40 m ao sul de cada sala).
func _montar_corredores() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = randi()
	for a in _areas():
		if a.tipo != "puzzle":
			continue
		var mini := MiniLabirinto.new()
		mini.name = "LabirintoAte" + String(a.name)
		a.get_parent().add_child(mini)
		mini.global_position = (a as Node3D).global_position + Vector3(0, 0, 40)
		mini.montar(rng, a)
		_corredores[a] = mini


## O Teseu achou a saída do trecho de labirinto: segue para o enigma.
func sair_do_labirinto(mini: Node) -> void:
	var alvo: Node = mini.get("destino")
	if alvo == null or teleportando:
		return
	_corredor_feito[alvo] = true
	teleportar(alvo)


## O Teseu atravessou o portão no centro do labirinto: começa a luta e o
## portão se fecha atrás dele.
func entrar_na_arena(arena: Node) -> void:
	if arena == null or area_atual == arena:
		return
	area_atual = arena
	checkpoint = arena.ponto_de_chegada()
	if _fio and _jogador:
		_fio.comecar(_jogador.global_position)
	titulo_sala.emit(arena.nome_sala)
	_aplicar_tilt(arena)
	arena.ao_chegar()
	get_tree().create_timer(0.8).timeout.connect(func(): get_tree().call_group("porta_minotauro", "fechar"))



## Minitaurinhos (atores) que saem pelo portão da arena e correm pelo caminho
## do labirinto até a entrada — "atrás do Teseu".
func _crias_no_labirinto(mino: Node3D) -> Array[Node]:
	var lista: Array[Node] = []
	var cena: PackedScene = mino.get("cena_minitaurinho")
	if cena == null or _labirinto == null:
		return lista
	var volta := Array(_labirinto.caminho_solucao())
	volta.reverse()   # do portão até a entrada
	if volta.size() < 2:
		return lista
	for i in 3:
		var c := cena.instantiate() as Node3D
		_labirinto.add_child(c)
		c.global_position = (volta[0] as Vector3) + Vector3((i - 1) * 0.8, 0.2, -i * 0.3)
		if c.has_method("entrar_na_cena"):
			c.entrar_na_cena()
			c.correr_no_caminho(volta.slice(1))
		Efeitos.fumaca(c.global_position)
		lista.append(c)
	return lista
