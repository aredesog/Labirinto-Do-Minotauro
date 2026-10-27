class_name Sala
extends AreaSala
## Sala com inimigos (e, se for do tipo "puzzle", um enigma):
##   1. Teseu chega pelo portal -> as portas fecham e surgem os minitaurinhos.
##   2. Todos derrotados:
##        - sala de combate: portas abrem, Teseu recupera vida;
##        - sala de puzzle:  o enigma é liberado.
##   3. Puzzle resolvido -> a cela abre e os atenienses são libertados.
##   4. Sala vencida -> o GerenciadorJogo sorteia o destino de cada portal.
## Salas de combate podem ser sorteadas de novo: voltam com +1 inimigo.
##
## Filhos usados (encontrados por grupo):
##   "grade_sala", "porta_sala", "cela", "puzzle", "spawn_inimigo"

enum Estado { ESPERANDO, COMBATE, PUZZLE, CONCLUIDA }

@export_range(1, 8) var quantidade_inimigos: int = 3
@export var maximo_inimigos: int = 6
@export var cena_inimigo: PackedScene
@export_multiline var dica_puzzle: String = "Resolva o enigma para libertar os prisioneiros."
## Meios corações recuperados ao vencer uma sala de combate.
@export var cura_ao_vencer: int = 4

var estado: Estado = Estado.ESPERANDO
var visitas := 0
var _vivos: Array[Node] = []
var _jogo: Node


func _ready() -> void:
	_jogo = get_tree().get_first_node_in_group("jogo")
	var puzzle := _puzzle()
	if puzzle:
		puzzle.resolvido.connect(_ao_resolver_puzzle)
		puzzle.erro.connect(_ao_errar_puzzle)
		puzzle.desativar()


func esta_concluida() -> bool:
	return estado == Estado.CONCLUIDA


func _filhos_no_grupo(grupo: String) -> Array[Node]:
	var lista: Array[Node] = []
	for n in find_children("*", "", true, false):
		if n.is_in_group(grupo):
			lista.append(n)
	return lista


func _puzzle() -> Node:
	var lista := _filhos_no_grupo("puzzle")
	return lista[0] if lista.size() > 0 else null


# --------------------------------------------------------------------------
func ao_chegar() -> void:
	super.ao_chegar()
	if estado == Estado.CONCLUIDA and tipo == "combate":
		# revisita: a sala volta, um pouco mais difícil
		estado = Estado.ESPERANDO
	if estado == Estado.ESPERANDO:
		iniciar()


func iniciar() -> void:
	visitas += 1
	estado = Estado.COMBATE
	for p in portas():
		p.ativar(false)
	for g in _filhos_no_grupo("grade_sala"):
		g.fechar()
	if _jogo:
		_jogo.sala_atual = self
	var qtd := mini(quantidade_inimigos + (visitas - 1), maximo_inimigos) if tipo == "combate" \
		else quantidade_inimigos
	_gerar_inimigos(qtd)


func _gerar_inimigos(qtd: int) -> void:
	if cena_inimigo == null:
		push_warning("%s: sem cena_inimigo definida." % name)
		_verificar_combate()
		return
	var pontos := _filhos_no_grupo("spawn_inimigo")
	pontos.shuffle()
	for i in qtd:
		var inimigo := cena_inimigo.instantiate()
		add_child(inimigo)
		var p: Node3D = pontos[i % pontos.size()] if pontos.size() > 0 else self
		inimigo.global_position = p.global_position + Vector3(randf_range(-0.3, 0.3), 0.1, randf_range(-0.3, 0.3))
		inimigo.morreu.connect(_ao_inimigo_morrer)
		_vivos.append(inimigo)


func _ao_inimigo_morrer(quem: Node) -> void:
	_vivos.erase(quem)
	_verificar_combate()


func _verificar_combate() -> void:
	if not _vivos.is_empty() or estado != Estado.COMBATE:
		return
	var puzzle := _puzzle()
	if puzzle:
		estado = Estado.PUZZLE
		puzzle.ativar()
		if _jogo:
			_jogo.mensagem.emit(dica_puzzle, 4.5)
	else:
		_concluir()


func _ao_errar_puzzle() -> void:
	# Errar o puzzle chama reforços (deixa a sala mais emocionante).
	if estado == Estado.PUZZLE and _vivos.size() < 2:
		_gerar_inimigos(1)


func _ao_resolver_puzzle() -> void:
	if estado == Estado.CONCLUIDA:
		return
	for i in _vivos:
		if is_instance_valid(i):
			i.levar_dano(99)
	_vivos.clear()
	var libertados := 0
	for c in _filhos_no_grupo("cela"):
		libertados += c.abrir()
	if _jogo:
		_jogo.libertar_prisioneiros(libertados)
	await get_tree().create_timer(1.2).timeout
	_concluir()


func _concluir() -> void:
	estado = Estado.CONCLUIDA
	for g in _filhos_no_grupo("grade_sala"):
		g.abrir()
	if _jogo == null:
		return
	if _jogo.sala_atual == self:
		_jogo.sala_atual = null
	if tipo == "puzzle":
		_jogo.registrar_puzzle_concluido(nome_sala)
	else:
		_jogo.sala_combate_vencida(self)
	_jogo.sortear_destinos(self)


## Volta a sala ao estado inicial (morte do Teseu ou "reiniciar sala").
func reiniciar() -> void:
	if estado == Estado.CONCLUIDA:
		return
	for i in _vivos:
		if is_instance_valid(i):
			i.queue_free()
	_vivos.clear()
	var puzzle := _puzzle()
	if puzzle:
		puzzle.resetar()
		puzzle.desativar()
	estado = Estado.ESPERANDO
	visitas = maxi(visitas - 1, 0)
