extends Puzzle
## Sala 2 — Braseiros na ordem certa.
## O mosaico na parede mostra a sequência de símbolos. Acender fora da ordem
## apaga todos e chama um minitaurinho de reforço.
##
## A cada partida a ORDEM do mosaico e a POSIÇÃO de cada símbolo nos
## braseiros são sorteadas (desligue "sortear" para usar a ordem fixa abaixo).

@export var ordem: Array[String] = ["sol", "lua", "onda", "raio"]
## Sorteia a ordem e qual braseiro tem qual símbolo ao iniciar.
@export var sortear := true
## Nó onde as placas do mosaico são colocadas (da esquerda para a direita).
@export var mosaico: Node3D
@export var espacamento_mosaico: float = 0.7

var _progresso := 0


func _ready() -> void:
	if mosaico == null:
		mosaico = get_node_or_null("Mosaico") as Node3D
	for b in filhos_no_grupo("braseiro"):
		b.aceso.connect(_ao_acender)
	if sortear:
		sortear_enigma()
	_montar_mosaico()


## Embaralha a ordem do mosaico e troca os símbolos de lugar nos braseiros.
func sortear_enigma() -> void:
	var braseiros := filhos_no_grupo("braseiro")
	var simbolos: Array[String] = []
	for b in braseiros:
		simbolos.append(b.simbolo)
	simbolos.shuffle()
	for i in braseiros.size():
		braseiros[i].simbolo = simbolos[i]
	var nova := ordem.duplicate()
	while nova == ordem and ordem.size() > 1:
		nova.shuffle()
	ordem = nova


func _montar_mosaico() -> void:
	if mosaico == null:
		return
	for c in mosaico.get_children():
		c.queue_free()
	for i in ordem.size():
		var caminho: String = Braseiro.CENAS_SIMBOLO.get(ordem[i], "")
		if caminho == "":
			continue
		var placa := (load(caminho) as PackedScene).instantiate() as Node3D
		mosaico.add_child(placa)
		placa.position.x = (i - (ordem.size() - 1) / 2.0) * espacamento_mosaico


func ativar() -> void:
	super.ativar()
	for b in filhos_no_grupo("braseiro"):
		b.habilitado = true


func desativar() -> void:
	super.desativar()
	for b in filhos_no_grupo("braseiro"):
		b.habilitado = false


func resetar() -> void:
	super.resetar()
	_progresso = 0
	for b in filhos_no_grupo("braseiro"):
		b.apagar(true)


func _ao_acender(b: Braseiro) -> void:
	if not ativo:
		return
	if _progresso < ordem.size() and b.simbolo == ordem[_progresso]:
		_progresso += 1
		if _progresso < ordem.size():
			Som.tocar("sino", -2.0, 0.0, [1.0, 1.122, 1.26, 1.5][mini(_progresso - 1, 3)])
		if _progresso >= ordem.size():
			_concluir()
		return
	# errou a ordem: tudo apaga
	_progresso = 0
	Som.tocar("erro")
	for outro in filhos_no_grupo("braseiro"):
		outro.apagar()
		outro.piscar_erro()
	var jogo := get_tree().get_first_node_in_group("jogo")
	if jogo:
		jogo.mensagem.emit("Ordem errada! As chamas se apagam...", 2.0)
	erro.emit()
