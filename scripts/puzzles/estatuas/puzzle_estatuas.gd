extends Puzzle
## Sala 1 — Estátuas e placas de pressão.
## Empurre todas as estátuas de touro para cima das placas.
## A alavanca volta as estátuas para o lugar (caso alguma fique presa).

## A cada partida sorteia se o enigma aparece espelhado (esquerda <-> direita).
@export var sortear := true
var espelhado := false


func _ready() -> void:
	for e in filhos_no_grupo("estatua"):
		e.movida.connect(_ao_mover)
	for a in filhos_no_grupo("alavanca"):
		a.acionada.connect(resetar_posicoes)
	if sortear and randf() < 0.5:
		espelhar()
	_ao_mover(null)


## Espelha estátuas, placas e alavanca no eixo X da sala: o enigma continua
## com solução, mas o caminho muda.
func espelhar() -> void:
	espelhado = not espelhado
	for n in filhos_no_grupo("estatua") + filhos_no_grupo("placa_pressao") + filhos_no_grupo("alavanca"):
		var o := n as Node3D
		o.position.x = -o.position.x
		if n.is_in_group("estatua"):
			n.posicao_inicial = o.position


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



# --------------------------------------------------------------------------
# Demonstração (sem texto): as placas brilham e "fantasmas" das estátuas
# deslizam até elas, em L (como o Teseu empurra: só nas 4 direções).
# --------------------------------------------------------------------------
func icones_dica() -> Array:
	return ["teseu", "seta", "estatua", "seta", "placa"]


func _roteiro_demo(cam: Camera3D) -> void:
	var estatuas := filhos_no_grupo("estatua")
	var placas := filhos_no_grupo("placa_pressao")
	if estatuas.is_empty() or placas.is_empty():
		return
	_focar(cam, _centro(estatuas + placas), 0.8)
	for p in placas:
		_anel((p as Node3D).global_position, Color("#ffc94a"), 0.5)
	await _esperar(0.7)
	var livres: Array = placas.duplicate()
	var mat := _material_brilho(Color("#d8f0ff"), 0.55)
	if not _pulou:
		Som.tocar("arrastar")
	for e in estatuas:
		if livres.is_empty():
			break
		var e3 := e as Node3D
		var melhor: Node3D = livres[0]
		for p in livres:
			if (p as Node3D).global_position.distance_to(e3.global_position) < melhor.global_position.distance_to(e3.global_position):
				melhor = p
		livres.erase(melhor)
		var f := _fantasma(e3, mat)
		var destino := Vector3(melhor.global_position.x, e3.global_position.y, melhor.global_position.z)
		var meio := Vector3(destino.x, e3.global_position.y, e3.global_position.z)
		var tw := f.create_tween()
		tw.tween_property(f, "global_position", meio, 0.5).set_trans(Tween.TRANS_SINE)
		tw.tween_property(f, "global_position", destino, 0.5).set_trans(Tween.TRANS_SINE)
	await _esperar(1.1)
	if not _pulou:
		Som.tocar("sino", -4.0, 0.0, 1.26)
	create_tween().tween_property(mat, "albedo_color:a", 0.0, 0.5)
	await _esperar(0.7)


## Cópia translúcida só das malhas da estátua (sem colisão).
func _fantasma(estatua: Node3D, mat: Material) -> Node3D:
	var f := Node3D.new()
	f.name = "Fantasma"
	add_child(f)
	f.global_transform = estatua.global_transform
	for mi in estatua.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var g := MeshInstance3D.new()
		g.mesh = m.mesh
		g.material_override = mat
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		f.add_child(g)
		g.global_transform = m.global_transform
	_efeitos_demo.append(f)
	return f
