extends Node3D
## Protótipo cinza do Labirinto do Minotauro (THDL-69).
## Monta o labirinto inteiro por código: salas, corredores, Teseu,
## minitaurinhos, o Minotauro, câmera e HUD.
##
## Mapa (N para cima):
##
##                [ Minotauro ]
##                      |
##   [ Oeste ] --- [ Pilares ] --- [ Leste ]
##                      |
##                 [ Entrada ]

const Construtor := preload("res://scripts/construtor.gd")
const SalaScript := preload("res://scripts/sala.gd")
const JogadorScript := preload("res://scripts/jogador.gd")
const InimigoScript := preload("res://scripts/inimigo.gd")
const HudScript := preload("res://scripts/hud.gd")

const LARGURA_CORREDOR := 2.0
const OFFSET_CAMERA := Vector3(0, 10, 7.5)
const NOVELOS_INICIAIS := 3

const COR_MINITAURINHO := Color(0.55, 0.32, 0.18)
const COR_MINITAURINHO_RAPIDO := Color(0.7, 0.45, 0.2)
const COR_MINITAURINHO_FORTE := Color(0.4, 0.22, 0.12)
const COR_MINOTAURO := Color(0.45, 0.08, 0.08)

var salas: Array = []
var sala_minotauro: Node3D
var jogador: CharacterBody3D
var camera: Camera3D
var hud: CanvasLayer

var novelos := NOVELOS_INICIAIS
var checkpoint := Vector3(0, 0.1, 2)
var fim_de_jogo := false


func _ready() -> void:
	_registrar_controles()
	_criar_ambiente()
	_criar_labirinto()
	_criar_jogador()
	_criar_camera()
	_criar_hud()
	_atualizar_hud()
	hud.mensagem("Liberte as três salas para abrir a porta do Minotauro", 4.0)


func _process(delta: float) -> void:
	# Câmera de cima em 3/4, seguindo o Teseu com suavidade.
	var alvo := jogador.global_position + OFFSET_CAMERA
	camera.global_position = camera.global_position.lerp(alvo, 1.0 - exp(-6.0 * delta))


func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed("reiniciar"):
		get_tree().reload_current_scene()


# --- montagem ------------------------------------------------------------

func _registrar_controles() -> void:
	# Registrados por código para o protótipo funcionar sem configurar nada.
	# Depois dá para passar isso para Projeto > Configurações > Mapa de Entrada.
	var mapa := {
		"mover_frente": [KEY_W, KEY_UP],
		"mover_tras": [KEY_S, KEY_DOWN],
		"mover_esquerda": [KEY_A, KEY_LEFT],
		"mover_direita": [KEY_D, KEY_RIGHT],
		"atacar": [KEY_SPACE, KEY_J],
		"reiniciar": [KEY_R],
	}
	for acao in mapa:
		if InputMap.has_action(acao):
			continue
		InputMap.add_action(acao)
		for tecla in mapa[acao]:
			var evento := InputEventKey.new()
			evento.physical_keycode = tecla
			InputMap.action_add_event(acao, evento)


func _criar_ambiente() -> void:
	var ambiente := Environment.new()
	ambiente.background_mode = Environment.BG_COLOR
	ambiente.background_color = Color(0.07, 0.06, 0.09)
	ambiente.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ambiente.ambient_light_color = Color(0.6, 0.6, 0.72)
	ambiente.ambient_light_energy = 0.55
	var mundo := WorldEnvironment.new()
	mundo.environment = ambiente
	add_child(mundo)

	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-55, -30, 0)
	sol.light_energy = 0.9
	sol.shadow_enabled = true
	add_child(sol)


func _criar_labirinto() -> void:
	var entrada := _criar_sala("Entrada", Vector3(0, 0, 0), Vector2(8, 8), ["N"], false)
	var pilares := _criar_sala("Pilares", Vector3(0, 0, -16), Vector2(8, 8), ["S", "N", "L", "O"])
	var leste := _criar_sala("Leste", Vector3(16, 0, -16), Vector2(8, 8), ["O"])
	var oeste := _criar_sala("Oeste", Vector3(-16, 0, -16), Vector2(8, 8), ["L"])
	sala_minotauro = _criar_sala("Minotauro", Vector3(0, 0, -35), Vector2(14, 14), ["S"])
	sala_minotauro.eh_chefe = true
	sala_minotauro.trancar()

	_conectar(entrada, pilares)
	_conectar(pilares, leste)
	_conectar(pilares, oeste)
	_conectar(pilares, sala_minotauro)

	# Pilares no meio da primeira sala de combate.
	for x in [-2.5, 2.5]:
		Construtor.caixa(pilares, Vector3(1, 2, 1), Vector3(x, 1, 0), Color(0.62, 0.6, 0.56))

	# Minitaurinhos: (vida, velocidade, escala, cor)
	_adicionar_inimigo(pilares, Vector3(0, 0.05, -2.5), 2, 2.6, 1.0, COR_MINITAURINHO)
	_adicionar_inimigo(pilares, Vector3(0, 0.05, 2.0), 2, 2.6, 1.0, COR_MINITAURINHO)

	_adicionar_inimigo(leste, Vector3(-1, 0.05, -2), 2, 2.6, 1.0, COR_MINITAURINHO)
	_adicionar_inimigo(leste, Vector3(1.5, 0.05, 0), 2, 2.6, 1.0, COR_MINITAURINHO)
	_adicionar_inimigo(leste, Vector3(-1, 0.05, 2), 2, 2.6, 1.0, COR_MINITAURINHO)

	_adicionar_inimigo(oeste, Vector3(-2, 0.05, -2), 1, 3.6, 0.85, COR_MINITAURINHO_RAPIDO)
	_adicionar_inimigo(oeste, Vector3(-2, 0.05, 2), 1, 3.6, 0.85, COR_MINITAURINHO_RAPIDO)
	_adicionar_inimigo(oeste, Vector3(-1, 0.05, 0), 4, 2.0, 1.3, COR_MINITAURINHO_FORTE)

	_adicionar_inimigo(sala_minotauro, Vector3(0, 0.05, -3), 12, 2.4, 1.8, COR_MINOTAURO, true)


func _criar_sala(nome: String, posicao: Vector3, tamanho: Vector2, portas: Array[String], combate := true) -> Node3D:
	var sala := SalaScript.new()
	sala.name = "Sala" + nome
	sala.configurar(nome, tamanho, portas, combate)
	sala.position = posicao
	add_child(sala)
	sala.ativada.connect(_on_sala_ativada)
	sala.liberada.connect(_on_sala_liberada)
	salas.append(sala)
	return sala


func _adicionar_inimigo(sala: Node3D, posicao_local: Vector3, vida: int, velocidade: float,
		escala: float, cor: Color, chefe := false) -> void:
	var inimigo := InimigoScript.new()
	inimigo.configurar(vida, velocidade, escala, cor, chefe)
	inimigo.position = posicao_local
	sala.adicionar_inimigo(inimigo)


## Liga duas salas alinhadas (mesmo X ou mesmo Z) com um corredor reto.
func _conectar(a: Node3D, b: Node3D) -> void:
	var pa: Vector3 = a.position
	var pb: Vector3 = b.position
	var t: float = SalaScript.ESPESSURA
	var altura: float = SalaScript.ALTURA_PAREDE
	var cor_chao := Color(0.68, 0.62, 0.52)
	var cor_parede := Color(0.5, 0.48, 0.45)

	var corredor := Node3D.new()
	corredor.name = "Corredor_%s_%s" % [a.nome_sala, b.nome_sala]
	add_child(corredor)

	if is_equal_approx(pa.x, pb.x):
		var sinal := signf(pb.z - pa.z)
		var inicio: float = pa.z + sinal * (a.tamanho.y / 2.0 + t)
		var fim: float = pb.z - sinal * (b.tamanho.y / 2.0 + t)
		var comprimento := absf(fim - inicio)
		var centro := Vector3(pa.x, 0, (inicio + fim) / 2.0)
		Construtor.caixa(corredor, Vector3(LARGURA_CORREDOR, 0.2, comprimento), centro + Vector3(0, -0.1, 0), cor_chao)
		for lado in [-1.0, 1.0]:
			Construtor.caixa(corredor, Vector3(t, altura, comprimento),
				centro + Vector3(lado * (LARGURA_CORREDOR / 2.0 + t / 2.0), altura / 2.0, 0), cor_parede)
	elif is_equal_approx(pa.z, pb.z):
		var sinal := signf(pb.x - pa.x)
		var inicio: float = pa.x + sinal * (a.tamanho.x / 2.0 + t)
		var fim: float = pb.x - sinal * (b.tamanho.x / 2.0 + t)
		var comprimento := absf(fim - inicio)
		var centro := Vector3((inicio + fim) / 2.0, 0, pa.z)
		Construtor.caixa(corredor, Vector3(comprimento, 0.2, LARGURA_CORREDOR), centro + Vector3(0, -0.1, 0), cor_chao)
		for lado in [-1.0, 1.0]:
			Construtor.caixa(corredor, Vector3(comprimento, altura, t),
				centro + Vector3(0, altura / 2.0, lado * (LARGURA_CORREDOR / 2.0 + t / 2.0)), cor_parede)
	else:
		push_error("Salas %s e %s não estão alinhadas" % [a.nome_sala, b.nome_sala])


func _criar_jogador() -> void:
	jogador = JogadorScript.new()
	jogador.name = "Teseu"
	jogador.position = checkpoint
	add_child(jogador)
	jogador.vida_mudou.connect(func(_vida): _atualizar_hud())
	jogador.morreu.connect(_on_jogador_morreu)


func _criar_camera() -> void:
	camera = Camera3D.new()
	camera.fov = 50.0
	add_child(camera)
	camera.global_position = jogador.global_position + OFFSET_CAMERA
	camera.look_at(jogador.global_position + Vector3(0, 0.5, 0))


func _criar_hud() -> void:
	hud = HudScript.new()
	add_child(hud)


# --- regras do jogo ------------------------------------------------------

func _salas_de_combate() -> Array:
	return salas.filter(func(s): return s.tem_combate and s != sala_minotauro)


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

	# O fio de Ariadne: a última sala liberada vira o ponto de retorno.
	checkpoint = sala.global_position + Vector3(0, 0.1, 0)
	_atualizar_hud()

	var combate := _salas_de_combate()
	if combate.all(func(s): return s.limpa):
		sala_minotauro.destrancar()
		hud.mensagem("Um rugido ecoa... a porta do Minotauro se abriu ao norte", 4.0)
	else:
		hud.mensagem("Sala liberada! O fio de Ariadne marca este ponto", 2.5)


func _on_jogador_morreu() -> void:
	for sala in salas:
		sala.resetar()

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
