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
## SORTEIO DOS PORTAIS (quando uma sala é vencida). O jogador NÃO vê o destino;
## as regras abaixo só garantem que o jogo sempre pode ser terminado:
##   - se ainda falta enigma: pelo menos 1 porta leva a um enigma pendente;
##   - com os 3 enigmas feitos: 1 porta leva ao Minotauro;
##   - as outras portas: sala de combate aleatória (às vezes outro enigma).

signal novelo_mudou(restante: int)
signal prisioneiros_mudou(libertados: int, total: int)
signal puzzles_mudou(concluidos: int, total: int)
signal mensagem(texto: String, duracao: float)
signal titulo_sala(texto: String)
signal transicao(escurecer: bool)
signal chefe_apareceu(chefe: Node)
signal fim_de_jogo(vitoria: bool)

## Comprimento do novelo de Ariadne = quantas vezes Teseu pode voltar.
@export var novelo_inicial: int = 3
## Quantas salas de puzzle precisam ser concluídas para liberar o Minotauro.
@export var puzzles_para_abrir_arena: int = 3
## Total de jovens atenienses presos (7 rapazes + 7 moças, menos Teseu).
@export var total_prisioneiros: int = 13
## Chance de uma porta "extra" levar a outro enigma em vez de combate.
@export_range(0.0, 1.0) var chance_enigma_extra: float = 0.3
## Semente do sorteio (0 = aleatório a cada partida).
@export var semente: int = 0

var novelo: int
var prisioneiros_libertados: int = 0
var puzzles_concluidos: Array[String] = []
var checkpoint: Vector3 = Vector3.ZERO
var sala_atual: Node = null
var area_atual: Node = null
var teleportando := false
var _jogador: Node3D


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
	_jogador = get_tree().get_first_node_in_group("jogador")
	if _jogador:
		checkpoint = _jogador.global_position
	for a in _areas():
		if a.tipo == "inicio":
			area_atual = a
			a.visitada = true
			sortear_destinos(a)
	await get_tree().create_timer(0.3).timeout
	novelo_mudou.emit(novelo)
	prisioneiros_mudou.emit(prisioneiros_libertados, total_prisioneiros)
	puzzles_mudou.emit(0, puzzles_para_abrir_arena)
	mensagem.emit("Ariadne te entrega um novelo de lã.\nOs portais levam a salas ao acaso: resolva os 3 enigmas e enfrente o Minotauro!", 5.0)


func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed("reiniciar_sala"):
		reiniciar_sala_atual()


func _registrar_controles() -> void:
	var mapa := {
		"mover_cima": [KEY_W, KEY_UP],
		"mover_baixo": [KEY_S, KEY_DOWN],
		"mover_esquerda": [KEY_A, KEY_LEFT],
		"mover_direita": [KEY_D, KEY_RIGHT],
		"atacar": [KEY_SPACE, KEY_J],
		"interagir": [KEY_E, KEY_K],
		"reiniciar_sala": [KEY_R],
		"pausar": [KEY_ESCAPE, KEY_P],
	}
	for acao in mapa:
		if InputMap.has_action(acao):
			continue
		InputMap.add_action(acao)
		for tecla in mapa[acao]:
			var ev := InputEventKey.new()
			ev.physical_keycode = tecla
			InputMap.action_add_event(acao, ev)


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
	for i in portas.size():
		var destino: Node = null
		if i == 0:
			if not pendentes.is_empty():
				destino = pendentes[0]
			elif arena:
				destino = arena
		elif pendentes.size() > 1 and randf() < chance_enigma_extra:
			destino = pendentes[i % pendentes.size()]
		if destino == null and not combates.is_empty():
			destino = combates[i % combates.size()]
		if destino == null and arena and pendentes.is_empty():
			destino = arena
		portas[i].definir_destino(destino)
		portas[i].ativar(destino != null)


func teleportar(destino: Node) -> void:
	if teleportando or destino == null:
		return
	teleportando = true
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
	area_atual = destino
	var cam := get_viewport().get_camera_3d()
	if cam and cam.has_method("encaixar"):
		cam.encaixar()
	titulo_sala.emit(destino.nome_sala)
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
		mensagem.emit("Um rugido ecoa pelo labirinto...\nAgora um dos portais leva ao Minotauro.", 4.0)
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
	get_tree().reload_current_scene()


# --------------------------------------------------------------------------
# Morte e respawn (o novelo encurta a cada volta)
# --------------------------------------------------------------------------
func jogador_morreu() -> void:
	var sala := sala_atual
	if sala and sala.has_method("reiniciar"):
		sala.reiniciar()
	if novelo <= 0:
		mensagem.emit("O fio acabou...\nTeseu se perdeu no labirinto.", 4.0)
		fim_de_jogo.emit(false)
		await get_tree().create_timer(4.0).timeout
		reiniciar_jogo()
		return
	novelo -= 1
	novelo_mudou.emit(novelo)
	mensagem.emit("Teseu segue o fio de volta. Restam %d voltas no novelo." % novelo, 3.0)
	if _jogador and _jogador.has_method("renascer"):
		_jogador.renascer(checkpoint)
	if sala and sala.has_method("iniciar"):
		sala.iniciar()


func vitoria() -> void:
	mensagem.emit("O Minotauro caiu! Teseu segue o fio de Ariadne de volta\ncom os atenienses. Atenas está livre do tributo!", 6.0)
	fim_de_jogo.emit(true)
