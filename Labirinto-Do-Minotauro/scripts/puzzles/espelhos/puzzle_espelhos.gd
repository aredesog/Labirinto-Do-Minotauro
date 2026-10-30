extends Puzzle
## Sala 3 — Espelhos e luz.
## Gire os espelhos (45° por vez) para levar o feixe da fonte até o cristal.

## Gira cada espelho uma quantidade sorteada de cliques ao iniciar a partida.
@export var sortear := true

var _fontes: Array[Node] = []


func _ready() -> void:
	_fontes = filhos_no_grupo("fonte_luz")
	for f in _fontes:
		f.atingiu_cristal.connect(_ao_atingir)
	if sortear:
		sortear_enigma()


## Muda a rotação inicial de cada espelho (múltiplos de 45°). A solução
## continua a mesma (os ângulos finais), só muda quantos cliques faltam.
## Nenhum espelho começa já na posição certa.
func sortear_enigma() -> void:
	for e in filhos_no_grupo("espelho"):
		var falta: int = e.cliques_ate_solucao()
		var novo := falta
		while novo == 0 or novo == falta:
			novo = randi_range(1, 7)
		e.definir_cliques_ate_solucao(novo)


func ativar() -> void:
	super.ativar()
	for e in filhos_no_grupo("espelho"):
		e.habilitado = true


func desativar() -> void:
	super.desativar()
	for e in filhos_no_grupo("espelho"):
		e.habilitado = false


func resetar() -> void:
	super.resetar()
	for e in filhos_no_grupo("espelho"):
		e.voltar_ao_inicio()
	for c in filhos_no_grupo("cristal"):
		c.apagar()


func _ao_atingir(cristal: Node) -> void:
	if not ativo:
		return
	# só vale com os espelhos parados num ângulo de 45°: durante o giro o feixe
	# passa por ângulos intermediários e podia acertar o cristal "de raspão"
	for e in filhos_no_grupo("espelho"):
		if e.esta_girando():
			return
	cristal.receber_luz()
	for e in filhos_no_grupo("espelho"):
		e.habilitado = false
	_concluir()
