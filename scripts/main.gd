extends Node3D
## Protótipo cinza do Labirinto do Minotauro.
## O labirinto é gerado por algoritmo (scripts/gerador_labirinto.gd), no
## estilo do labirinto do Twilight Forest: corredores estreitos, becos sem
## saída, alguns ciclos, salas espalhadas e minitaurinhos andando pelos
## corredores. A sala do Minotauro fica no fundo (norte) e só abre depois
## que todas as salas de combate forem liberadas.
##
## Mudando a SEMENTE, muda o labirinto. Com 0, ele é diferente a cada partida.

const Construtor := preload("res://scripts/construtor.gd")
const GeradorScript := preload("res://scripts/gerador_labirinto.gd")
const SalaScript := preload("res://scripts/sala.gd")
const JogadorScript := preload("res://scripts/jogador.gd")
const InimigoScript := preload("res://scripts/inimigo.gd")
const HudScript := preload("res://scripts/hud.gd")
const FioScript := preload("res://scripts/fio.gd")

# --- configuração do labirinto ---------------------------------------------
const SEMENTE := 2026
const LARGURA := 17          # células
const ALTURA := 17           # células
const CELULA := 4.0          # metros por célula (corredor de ~3,4 m)
const ESPESSURA := 0.6
const ALTURA_PAREDE := 2.6
const N_SALAS_COMBATE := 4
const N_FONTES := 2
const CHANCE_CICLO := 0.08   # chance de derrubar uma parede extra entre corredores
const N_ERRANTES := 8
const N_TOCHAS_CORREDOR := 14

const OFFSET_CAMERA := Vector3(0, 15, 6)
const NOVELOS_INICIAIS := 3

const COR_MINITAURINHO := Color(0.55, 0.32, 0.18)
const COR_MINITAURINHO_RAPIDO := Color(0.7, 0.45, 0.2)
const COR_MINITAURINHO_FORTE := Color(0.4, 0.22, 0.12)
const COR_ERRANTE := Color(0.5, 0.38, 0.3)
const COR_MINOTAURO := Color(0.45, 0.08, 0.08)

var mapa: RefCounted
var salas: Array = []
var sala_minotauro: Node3D
var errantes: Array = []
var jogador: CharacterBody3D
var camera: Camera3D
var hud: CanvasLayer
var fio: MultiMeshInstance3D

var novelos := NOVELOS_INICIAIS
var checkpoint := Vector3.ZERO
var fim_de_jogo := false


func _ready() -> void:
	_registrar_controles()
	_criar_ambiente()
	mapa = GeradorScript.new()
	mapa.gerar(LARGURA, ALTURA, CELULA, SEMENTE, N_SALAS_COMBATE, N_FONTES, CHANCE_CICLO)
	_construir_labirinto()
	_criar_salas()
	_criar_errantes()
	_criar_jogador()
	_criar_camera()
	_criar_hud()
	_atualizar_hud()
	hud.mensagem("Liberte as salas de combate para abrir a porta do Minotauro, ao norte", 5.0)


func _process(delta: float) -> void:
	# Câmera de cima, seguindo o Teseu com suavidade.
	var alvo := jogador.global_position + OFFSET_CAMERA
	camera.global_position = camera.global_position.lerp(alvo, 1.0 - exp(-6.0 * delta))


func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed("reiniciar"):
		get_tree().reload_current_scene()


# --- montagem ------------------------------------------------------------

func _registrar_controles() -> void:
	# Registrados por código para o protótipo funcionar sem configurar nada.
	# Depois dá para passar isso para Projeto > Configurações > Mapa de Entrada.
	var teclas := {
		"mover_frente": [KEY_W, KEY_UP],
		"mover_tras": [KEY_S, KEY_DOWN],
		"mover_esquerda": [KEY_A, KEY_LEFT],
		"mover_direita": [KEY_D, KEY_RIGHT],
		"atacar": [KEY_SPACE, KEY_J],
		"reiniciar": [KEY_R],
	}
	for acao in teclas:
		if InputMap.has_action(acao):
			continue
		InputMap.add_action(acao)
		for tecla in teclas[acao]:
			var evento := InputEventKey.new()
			evento.physical_keycode = tecla
			InputMap.action_add_event(acao, evento)


func _criar_ambiente() -> void:
	var ambiente := Environment.new()
	ambiente.background_mode = Environment.BG_COLOR
	ambiente.background_color = Color(0.05, 0.06, 0.07)
	ambiente.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ambiente.ambient_light_color = Color(0.55, 0.62, 0.6)
	ambiente.ambient_light_energy = 0.45
	var mundo := WorldEnvironment.new()
	mundo.environment = ambiente
	add_child(mundo)

	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-62, -25, 0)
	sol.light_energy = 0.75
	sol.shadow_enabled = true
	sol.directional_shadow_max_distance = 45.0
	add_child(sol)


func _construir_labirinto() -> void:
	var raiz := Node3D.new()
	raiz.name = "Labirinto"
	add_child(raiz)

	var largura_m: float = LARGURA * CELULA
	var altura_m: float = ALTURA * CELULA

	# Chão: uma colisão única e ladrilhos só visuais (um por célula).
	var chao := Construtor.caixa(raiz, Vector3(largura_m + 2, 0.2, altura_m + 2), Vector3(0, -0.11, 0), Color(0.3, 0.3, 0.3))
	chao.get_child(0).visible = false
	var mats_corredor := _variacoes(Color(0.42, 0.43, 0.4), Color(0.36, 0.4, 0.34), 4)
	var mats_sala := {
		"entrada": Construtor.material(Color(0.62, 0.58, 0.5)),
		"combate": Construtor.material(Color(0.6, 0.55, 0.46)),
		"fonte": Construtor.material(Color(0.5, 0.56, 0.6)),
		"chefe": Construtor.material(Color(0.42, 0.28, 0.25)),
	}
	for y in ALTURA:
		for x in LARGURA:
			var c := Vector2i(x, y)
			var indice: int = mapa.sala_de[y][x]
			var mat: Material
			if indice == -1:
				mat = mats_corredor[(x * 7 + y * 13) % mats_corredor.size()]
			else:
				mat = mats_sala[mapa.salas[indice].tipo]
			var pos: Vector3 = mapa.centro(c) + Vector3(0, -0.05, 0)
			Construtor.caixa_com_material(raiz, Vector3(CELULA, 0.1, CELULA), pos, mat, false)

	# Paredes de pedra musgosa.
	var mats_parede := _variacoes(Color(0.5, 0.52, 0.48), Color(0.36, 0.47, 0.32), 5)
	var sorteio := RandomNumberGenerator.new()
	sorteio.seed = SEMENTE
	for y in ALTURA:
		for x in LARGURA:
			var c := Vector2i(x, y)
			var base: Vector3 = mapa.centro(c)
			if x < LARGURA - 1 and mapa.parede_l[y][x]:
				Construtor.caixa_com_material(raiz, Vector3(ESPESSURA, ALTURA_PAREDE, CELULA + ESPESSURA),
					base + Vector3(CELULA / 2.0, ALTURA_PAREDE / 2.0, 0), mats_parede[sorteio.randi() % mats_parede.size()])
			if y < ALTURA - 1 and mapa.parede_s[y][x]:
				Construtor.caixa_com_material(raiz, Vector3(CELULA + ESPESSURA, ALTURA_PAREDE, ESPESSURA),
					base + Vector3(0, ALTURA_PAREDE / 2.0, CELULA / 2.0), mats_parede[sorteio.randi() % mats_parede.size()])

	# Muralha externa.
	var mat_borda: Material = mats_parede[0]
	for z in [-altura_m / 2.0, altura_m / 2.0]:
		Construtor.caixa_com_material(raiz, Vector3(largura_m + ESPESSURA, ALTURA_PAREDE, ESPESSURA),
			Vector3(0, ALTURA_PAREDE / 2.0, z), mat_borda)
	for x in [-largura_m / 2.0, largura_m / 2.0]:
		Construtor.caixa_com_material(raiz, Vector3(ESPESSURA, ALTURA_PAREDE, altura_m + ESPESSURA),
			Vector3(x, ALTURA_PAREDE / 2.0, 0), mat_borda)

	# Tochas nos corredores, de preferência nos becos sem saída.
	var becos: Array[Vector2i] = []
	var outros: Array[Vector2i] = []
	for y in ALTURA:
		for x in LARGURA:
			var c := Vector2i(x, y)
			if not mapa.eh_corredor(c):
				continue
			if mapa.vizinhos_abertos(c, false).size() == 1:
				becos.append(c)
			else:
				outros.append(c)
	_embaralhar(becos, sorteio)
	_embaralhar(outros, sorteio)
	var escolhidas := becos.slice(0, N_TOCHAS_CORREDOR / 2)
	escolhidas.append_array(outros.slice(0, N_TOCHAS_CORREDOR - escolhidas.size()))
	for c in escolhidas:
		Construtor.tocha(raiz, mapa.centro(c) + Vector3(0, 2.0, 0), 6.0)


func _criar_salas() -> void:
	var contagem := {}
	for dados in mapa.salas:
		contagem[dados.tipo] = contagem.get(dados.tipo, 0) + 1
		var sala := SalaScript.new()
		var nome := "%s %d" % [dados.tipo.capitalize(), contagem[dados.tipo]]
		sala.name = nome.replace(" ", "")
		sala.configurar(nome, dados.tipo, mapa.tamanho_sala(dados))
		sala.position = mapa.centro_sala(dados)
		add_child(sala)
		salas.append(sala)
		sala.ativada.connect(_on_sala_ativada)
		sala.liberada.connect(_on_sala_liberada)
		sala.fonte_visitada.connect(_on_fonte_visitada)

		if dados.tipo == "chefe":
			sala_minotauro = sala
			sala.trancada = true
		if dados.tipo == "entrada":
			checkpoint = sala.position + Vector3(0, 0.1, 0)

		# Grades nas portas das salas de combate e do chefe.
		if sala.eh_combate():
			for porta in dados.portas:
				var d: Vector2i = porta.dir
				var na_parede: Vector3 = mapa.centro(porta.celula) + Vector3(d.x, 0, d.y) * (CELULA / 2.0)
				var local := na_parede - sala.position + Vector3(0, ALTURA_PAREDE / 2.0, 0)
				var tam := Vector3(ESPESSURA * 0.6, ALTURA_PAREDE, CELULA - ESPESSURA) if d.x != 0 \
					else Vector3(CELULA - ESPESSURA, ALTURA_PAREDE, ESPESSURA * 0.6)
				sala.adicionar_grade(local, tam)

		if dados.tipo == "combate":
			_povoar_sala(sala, dados)
		elif dados.tipo == "chefe":
			_adicionar_inimigo(sala, Vector3(0, 0.05, -2), 12, 2.4, 1.8, COR_MINOTAURO, true)

	sala_minotauro.trancar()


func _povoar_sala(sala: Node3D, dados: Dictionary) -> void:
	var rect: Rect2i = dados.rect
	var sorteio := RandomNumberGenerator.new()
	sorteio.seed = SEMENTE + rect.position.x * 31 + rect.position.y
	var quantidade := 3 if rect.get_area() >= 9 else 2
	var celulas: Array[Vector2i] = []
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			celulas.append(Vector2i(x, y))
	_embaralhar(celulas, sorteio)
	for i in quantidade:
		var local: Vector3 = mapa.centro(celulas[i]) - sala.position + Vector3(0, 0.05, 0)
		match sorteio.randi_range(0, 2):
			0:
				_adicionar_inimigo(sala, local, 2, 2.6, 1.0, COR_MINITAURINHO)
			1:
				_adicionar_inimigo(sala, local, 1, 3.6, 0.85, COR_MINITAURINHO_RAPIDO)
			_:
				_adicionar_inimigo(sala, local, 4, 2.0, 1.3, COR_MINITAURINHO_FORTE)


func _adicionar_inimigo(sala: Node3D, posicao_local: Vector3, vida: int, velocidade: float,
		escala: float, cor: Color, chefe := false) -> void:
	var inimigo := InimigoScript.new()
	inimigo.configurar(vida, velocidade, escala, cor, chefe)
	inimigo.position = posicao_local
	sala.adicionar_inimigo(inimigo)


func _criar_errantes() -> void:
	# Minitaurinhos que andam pelos corredores, longe da entrada.
	var grupo := Node3D.new()
	grupo.name = "Errantes"
	add_child(grupo)
	var entrada: Vector2i = mapa.celula_de(checkpoint)
	var candidatas: Array[Vector2i] = []
	for y in ALTURA:
		for x in LARGURA:
			var c := Vector2i(x, y)
			if mapa.eh_corredor(c) and absi(c.x - entrada.x) + absi(c.y - entrada.y) >= 6:
				candidatas.append(c)
	var sorteio := RandomNumberGenerator.new()
	sorteio.seed = SEMENTE + 7
	_embaralhar(candidatas, sorteio)
	for i in mini(N_ERRANTES, candidatas.size()):
		var inimigo := InimigoScript.new()
		inimigo.configurar(2, 2.8, 1.0, COR_ERRANTE)
		inimigo.tornar_errante(mapa)
		inimigo.position = mapa.centro(candidatas[i]) + Vector3(0, 0.05, 0)
		grupo.add_child(inimigo)
		errantes.append(inimigo)


func _criar_jogador() -> void:
	jogador = JogadorScript.new()
	jogador.name = "Teseu"
	jogador.position = checkpoint
	add_child(jogador)
	jogador.vida_mudou.connect(func(_vida): _atualizar_hud())
	jogador.morreu.connect(_on_jogador_morreu)

	fio = FioScript.new()
	fio.name = "FioDeAriadne"
	fio.alvo = jogador
	add_child(fio)


func _criar_camera() -> void:
	camera = Camera3D.new()
	camera.fov = 50.0
	add_child(camera)
	camera.global_position = jogador.global_position + OFFSET_CAMERA
	camera.look_at(jogador.global_position + Vector3(0, 0.5, 0))


func _criar_hud() -> void:
	hud = HudScript.new()
	add_child(hud)


func _variacoes(cor_a: Color, cor_b: Color, quantidade: int) -> Array:
	var lista := []
	for i in quantidade:
		lista.append(Construtor.material(cor_a.lerp(cor_b, float(i) / maxf(quantidade - 1, 1))))
	return lista


func _embaralhar(lista: Array, sorteio: RandomNumberGenerator) -> void:
	for i in range(lista.size() - 1, 0, -1):
		var j := sorteio.randi_range(0, i)
		var tmp = lista[i]
		lista[i] = lista[j]
		lista[j] = tmp


# --- regras do jogo ------------------------------------------------------

func _salas_de_combate() -> Array:
	return salas.filter(func(s): return s.tipo == "combate")


func _atualizar_hud() -> void:
	var combate := _salas_de_combate()
	var limpas := combate.filter(func(s): return s.limpa).size()
	hud.atualizar(jogador.vida, jogador.VIDA_MAX, novelos, limpas, combate.size())


func _on_sala_ativada(sala: Node3D) -> void:
	if sala == sala_minotauro:
		hud.mensagem("O Minotauro!", 2.5)
	else:
		hud.mensagem("As grades se fecharam! Derrote os minitaurinhos", 2.5)


func _on_sala_liberada(sala: Node3D) -> void:
	if sala == sala_minotauro:
		fim_de_jogo = true
		hud.mensagem("Você derrotou o Minotauro!\nAtenas está livre. Pressione R para jogar de novo.", 0.0)
		return

	checkpoint = sala.global_position + Vector3(0, 0.1, 0)
	_atualizar_hud()

	if _salas_de_combate().all(func(s): return s.limpa):
		sala_minotauro.destrancar()
		hud.mensagem("Um rugido ecoa... a porta do Minotauro se abriu, ao norte", 4.0)
	else:
		hud.mensagem("Sala liberada! Ela vira seu ponto de retorno", 2.5)


func _on_fonte_visitada(sala: Node3D) -> void:
	jogador.curar()
	var ponto := sala.global_position + Vector3(0, 0.1, 2.2)
	if not checkpoint.is_equal_approx(ponto):
		checkpoint = ponto
		hud.mensagem("A fonte restaura suas forças. Ponto de retorno marcado", 2.5)


func _on_jogador_morreu() -> void:
	for sala in salas:
		sala.resetar()
	for inimigo in errantes:
		inimigo.resetar()

	if novelos <= 0:
		fim_de_jogo = true
		_atualizar_hud()
		hud.mensagem("O fio acabou... Fim de jogo.\nPressione R para recomeçar.", 0.0)
		return

	novelos -= 1
	_atualizar_hud()
	hud.mensagem("Você segue o fio de Ariadne de volta (restam %d novelos)" % novelos, 2.5)
	await get_tree().create_timer(1.2).timeout
	jogador.reviver(checkpoint)
	fio.cortar()
