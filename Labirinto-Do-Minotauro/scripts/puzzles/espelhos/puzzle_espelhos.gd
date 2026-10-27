extends Puzzle
## Sala 3 — Espelhos e luz.
## Gire os espelhos (45° por vez) para levar o feixe da fonte até o cristal.

var _fontes: Array[Node] = []


func _ready() -> void:
	_fontes = filhos_no_grupo("fonte_luz")
	for f in _fontes:
		f.atingiu_cristal.connect(_ao_atingir)


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
	cristal.receber_luz()
	for e in filhos_no_grupo("espelho"):
		e.habilitado = false
	_concluir()
