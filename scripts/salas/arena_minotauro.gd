class_name ArenaMinotauro
extends AreaSala
## Arena final. Ao chegar, o portão fica trancado e a luta começa.
## Se o Teseu morrer aqui, a luta recomeça (o novelo diminui) e o Minotauro
## recupera só 25% da vida, não a vida toda.

var _chefe: Minotauro
var _vencida := false
var _luta_comecou := false


func _ready() -> void:
	_chefe = find_child("Minotauro", true, false) as Minotauro
	if _chefe:
		_chefe.derrotado.connect(_ao_derrotar)
		_chefe.caiu.connect(_ao_cair)


func esta_concluida() -> bool:
	return _vencida


func ao_chegar() -> void:
	super.ao_chegar()
	if not _vencida:
		iniciar()


func iniciar() -> void:
	var jogo := get_tree().get_first_node_in_group("jogo")
	if jogo:
		jogo.sala_atual = self
		jogo.chefe_apareceu.emit(_chefe)
		# dica visual: Minotauro -> coluna -> tonto (estrelas)
		jogo.avisar(["minotauro", "seta", "coluna", "estrelas"], 3.5)
	Som.musica("chefe", 0.6)
	if _chefe:
		if not _luta_comecou:
			_chefe.resetar()
		_luta_comecou = true
		_chefe.comecar()


func reiniciar() -> void:
	if _vencida:
		return
	for i in get_tree().get_nodes_in_group("inimigo"):
		if i != _chefe and is_instance_valid(i):
			i.queue_free()
	if _chefe:
		_chefe.recuperar_parcial()


func _ao_derrotar() -> void:
	_vencida = true
	var jogo := get_tree().get_first_node_in_group("jogo")
	if jogo:
		jogo.sala_atual = null
		jogo.vitoria()



## Golpe final: a cena de cinema da queda (câmera lenta, vários ângulos).
func _ao_cair() -> void:
	var jogo := get_tree().get_first_node_in_group("jogo")
	if jogo and jogo.has_method("cena_queda_minotauro"):
		jogo.cena_queda_minotauro(_chefe)
