extends Puzzle
## Sala 1 — Estátuas e placas de pressão.
## Empurre todas as estátuas de touro para cima das placas.
## A alavanca volta as estátuas para o lugar (caso alguma fique presa).

func _ready() -> void:
	for e in filhos_no_grupo("estatua"):
		e.movida.connect(_ao_mover)
	for a in filhos_no_grupo("alavanca"):
		a.acionada.connect(resetar_posicoes)
	_ao_mover(null)


func ativar() -> void:
	super.ativar()
	for e in filhos_no_grupo("estatua"):
		e.bloqueada = false


func desativar() -> void:
	super.desativar()
	for e in filhos_no_grupo("estatua"):
		e.bloqueada = true


func resetar() -> void:
	super.resetar()
	resetar_posicoes()


func resetar_posicoes() -> void:
	if concluido:
		return
	for e in filhos_no_grupo("estatua"):
		e.voltar_ao_inicio()


func _ao_mover(_estatua) -> void:
	var estatuas := filhos_no_grupo("estatua")
	var todas := true
	for p in filhos_no_grupo("placa_pressao"):
		p.atualizar(estatuas)
		if not p.pressionada:
			todas = false
	if todas and ativo:
		for e in estatuas:
			e.bloqueada = true
		_concluir()
