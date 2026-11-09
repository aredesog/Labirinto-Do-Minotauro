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



# --------------------------------------------------------------------------
# Demonstração (sem texto): a câmera mostra a fonte de luz, o cristal (com
# um anel azul: "a luz tem que chegar aqui") e os espelhos, cada um com uma
# bolinha girando em volta ("gire este").
# --------------------------------------------------------------------------
func icones_dica() -> Array:
	return ["tecla:E", "espelho", "|", "luz", "seta", "espelho", "seta", "cristal"]


func _roteiro_demo(cam: Camera3D) -> void:
	var cristais := filhos_no_grupo("cristal")
	var espelhos := filhos_no_grupo("espelho")
	if not _fontes.is_empty():
		_focar(cam, (_fontes[0] as Node3D).global_position, 0.6)
		await _esperar(0.8)
	if not cristais.is_empty():
		var c3 := cristais[0] as Node3D
		_focar(cam, c3.global_position, 0.6)
		_anel(c3.global_position, Color("#7fd6ff"), 0.6)
		if not _pulou:
			Som.tocar("sino", -4.0, 0.0, 1.5)
		await _esperar(0.9)
	_focar(cam, _centro(espelhos), 0.8)
	for e in espelhos:
		_orbita((e as Node3D).global_position + Vector3.UP * 1.9)
	if not _pulou:
		Som.tocar("girar", -4.0)
	await _esperar(1.3)


## Bolinha dourada girando num anel: "este gira".
func _orbita(pos: Vector3) -> void:
	var piv := Node3D.new()
	add_child(piv)
	piv.global_position = pos
	var anel := MeshInstance3D.new()
	var toro := TorusMesh.new()
	toro.inner_radius = 0.42
	toro.outer_radius = 0.48
	anel.mesh = toro
	anel.material_override = _material_brilho(Color("#ffc94a"), 0.5)
	piv.add_child(anel)
	var bola := MeshInstance3D.new()
	var esfera := SphereMesh.new()
	esfera.radius = 0.1
	esfera.height = 0.2
	bola.mesh = esfera
	bola.material_override = _material_brilho(Color("#fff3d6"), 1.0)
	bola.position = Vector3(0.45, 0, 0)
	piv.add_child(bola)
	var tw := piv.create_tween().set_loops()
	tw.tween_property(piv, "rotation:y", TAU, 0.8).from(0.0)
	_efeitos_demo.append(piv)
