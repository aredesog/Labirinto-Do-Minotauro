class_name Puzzle
extends Node3D
## Base de todos os puzzles. Cada puzzle herda daqui e chama
## _concluir() quando for resolvido.
##
## DEMONSTRAÇÃO (no lugar do texto de dica): na 1ª vez que o enigma é
## liberado, uma cena curtinha (~3 s) MOSTRA o que fazer — a câmera passeia
## pelos objetos, eles brilham e um "fantasma" faz o movimento certo.
## Cada puzzle escreve o seu _roteiro_demo(). Espaço/E pula a cena.
## O enigma já fica ativo durante a cena (a cena só mostra, não mexe nele).

signal resolvido
signal erro

var ativo := false
var concluido := false
var demonstrado := false
var _pulou := false
var _efeitos_demo: Array[Node] = []


func _enter_tree() -> void:
	add_to_group("puzzle")


func ativar() -> void:
	ativo = true


func desativar() -> void:
	ativo = false


func resetar() -> void:
	concluido = false


func _concluir() -> void:
	if concluido:
		return
	concluido = true
	ativo = false
	Som.tocar("resolvido")
	resolvido.emit()


## Ajuda: lista os filhos (em qualquer nível) que estão num grupo.
func filhos_no_grupo(grupo: String) -> Array[Node]:
	var lista: Array[Node] = []
	for n in find_children("*", "", true, false):
		if n.is_in_group(grupo):
			lista.append(n)
	return lista



# --------------------------------------------------------------------------
# Demonstração sem texto
# --------------------------------------------------------------------------
## Frase de pictogramas mostrada durante a demonstração (cada puzzle troca).
func icones_dica() -> Array:
	return ["diamante"]


func demonstrar() -> void:
	if demonstrado:
		return
	demonstrado = true
	_pulou = false
	var jogo := get_tree().get_first_node_in_group("jogo")
	var teseu := get_tree().get_first_node_in_group("jogador")
	var cam := get_viewport().get_camera_3d()
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("cinema_tom"):
		hud.cinema_tom(Color(1.0, 0.97, 0.92), 1.0, 0.4, 0.1)
	if jogo:
		jogo.avisar(icones_dica(), 3.6)
		jogo.cinematica.emit(true)
	if teseu and teseu.has_method("definir_controle"):
		teseu.definir_controle(false)
	await _roteiro_demo(cam)
	for n in _efeitos_demo:
		if is_instance_valid(n):
			n.queue_free()
	_efeitos_demo.clear()
	if cam and cam.has_method("soltar"):
		cam.soltar()
	if jogo:
		jogo.cinematica.emit(false)
	if teseu and teseu.has_method("definir_controle") and int(teseu.get("vida")) > 0 \
			and not (jogo and jogo.terminou):
		teseu.definir_controle(true)
		if teseu.has_method("gesto"):
			teseu.gesto("sim", 0.8)


## Sobrescrito por cada puzzle.
func _roteiro_demo(_cam: Camera3D) -> void:
	await _esperar(1.0)


## Espera (ou para antes, se o jogador apertar Espaço/E/Esc ou o enigma acabar).
func _esperar(seg: float) -> void:
	var t := 0.0
	while t < seg and not _pulou:
		await get_tree().process_frame
		t += get_process_delta_time()
		if t > 0.3 and (Input.is_action_just_pressed("atacar") or Input.is_action_just_pressed("interagir")
				or Input.is_action_just_pressed("pausar")):
			_pulou = true
		if concluido or not is_inside_tree():
			_pulou = true


func _focar(cam: Camera3D, ponto: Vector3, zoom := 0.7) -> void:
	if cam and cam.has_method("focar") and not _pulou:
		cam.focar(ponto, zoom)


## Anel brilhante pulsando no chão (marca "o objetivo é aqui").
func _anel(pos: Vector3, cor: Color, raio := 0.55) -> Node3D:
	var anel := MeshInstance3D.new()
	var toro := TorusMesh.new()
	toro.inner_radius = raio * 0.8
	toro.outer_radius = raio
	anel.mesh = toro
	anel.material_override = _material_brilho(cor, 0.85)
	anel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(anel)
	anel.global_position = pos + Vector3.UP * 0.08
	anel.scale = Vector3(1, 0.3, 1)
	var tw := anel.create_tween().set_loops()
	tw.tween_property(anel, "scale", Vector3(1.25, 0.3, 1.25), 0.35).set_trans(Tween.TRANS_SINE)
	tw.tween_property(anel, "scale", Vector3(0.9, 0.3, 0.9), 0.35).set_trans(Tween.TRANS_SINE)
	_efeitos_demo.append(anel)
	return anel


static func _material_brilho(cor: Color, alfa: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(cor.r, cor.g, cor.b, alfa)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## Média das posições de uma lista de nós (centro da cena).
static func _centro(nos: Array) -> Vector3:
	var soma := Vector3.ZERO
	var n := 0
	for no in nos:
		if no is Node3D:
			soma += (no as Node3D).global_position
			n += 1
	return soma / maxf(n, 1)
