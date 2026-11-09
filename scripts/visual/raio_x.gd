class_name RaioX
extends Node3D
## Modo "Raio-X de CG": mostra a Computação Gráfica que está por trás do jogo.
##
##   F1  liga/desliga o Raio-X
##   F2  liga/desliga o tilt-shift (pós-processamento de miniatura)
##   F3  troca cel shading (toon.gdshader) <-> iluminação PBR padrão
##
## Com o Raio-X ligado:
##   - formas de colisão (verde = cenário, ciano = Teseu, vermelho = inimigos)
##   - normais dos vértices dos personagens (azul)
##   - em cada espelho: vetor incidente d (amarelo), normal n (verde) e
##     refletido r (magenta), com o ângulo de incidência = ângulo de reflexão
##   - painel com FPS, draw calls, primitivas e as técnicas da sala

const COR_CENARIO := Color(0.3, 1.0, 0.4)
const COR_JOGADOR := Color(0.3, 0.9, 1.0)
const COR_INIMIGO := Color(1.0, 0.35, 0.3)
const COR_NORMAL := Color(0.45, 0.55, 1.0)
const COR_D := Color(1.0, 0.85, 0.2)
const COR_N := Color(0.3, 1.0, 0.4)
const COR_R := Color(1.0, 0.3, 0.9)
const NORMAIS_POR_MALHA := 160

var ativo := false
var _malha: ImmediateMesh
var _mi: MeshInstance3D
var _painel: Label
var _fundo: PanelContainer
var _rotulos: Array[Label3D] = []
var _cache_normais := {}   # Mesh -> [PackedVector3Array posições, normais]


func _ready() -> void:
	add_to_group("raio_x")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_malha = ImmediateMesh.new()
	_mi = MeshInstance3D.new()
	_mi.mesh = _malha
	_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.no_depth_test = true
	m.render_priority = 10
	_mi.material_override = m
	_mi.set_meta("toon", true)
	_mi.top_level = true
	add_child(_mi)
	var camada := CanvasLayer.new()
	camada.layer = 50
	add_child(camada)
	_fundo = PanelContainer.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.03, 0.05, 0.08, 0.82)
	estilo.border_color = Color(0.3, 0.9, 1.0, 0.8)
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(6)
	estilo.set_content_margin_all(9)
	_fundo.add_theme_stylebox_override("panel", estilo)
	_fundo.position = Vector2(16, 100)
	_fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camada.add_child(_fundo)
	_painel = Label.new()
	_painel.add_theme_font_size_override("font_size", 13)
	_painel.add_theme_color_override("font_color", Color(0.8, 1.0, 0.95))
	_fundo.add_child(_painel)
	_fundo.visible = false


func _unhandled_input(evento: InputEvent) -> void:
	var k := evento as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	match k.keycode:
		KEY_F1:
			alternar()
		KEY_F2:
			_alternar_tilt()
		KEY_F3:
			Toon.definir(not Toon.ligado)
		_:
			return
	get_viewport().set_input_as_handled()


func alternar() -> void:
	ativo = not ativo
	_fundo.visible = ativo
	_malha.clear_surfaces()
	for r in _rotulos:
		r.visible = false
	Som.tocar("menu_mover", -4.0, 0.0)


func _alternar_tilt() -> void:
	var tilt := get_parent().find_child("TiltShift", true, false) as CanvasLayer
	if tilt:
		tilt.visible = not tilt.visible


func _tilt_ligado() -> bool:
	var tilt := get_parent().find_child("TiltShift", true, false) as CanvasLayer
	return tilt != null and tilt.visible


func _process(_delta: float) -> void:
	if not ativo:
		return
	_malha.clear_surfaces()
	_malha.surface_begin(Mesh.PRIMITIVE_LINES)
	var jogo := get_tree().get_first_node_in_group("jogo")
	var area: Node3D = jogo.area_atual if jogo else null
	var n_formas := _desenhar_colisoes(area)
	var n_normais := _desenhar_normais()
	var n_reflexoes := _desenhar_espelhos()
	# ImmediateMesh não aceita superfície vazia
	_linha(Vector3.ZERO, Vector3.ZERO, Color.BLACK)
	_malha.surface_end()
	_atualizar_painel(area, n_formas, n_normais, n_reflexoes)


func _linha(a: Vector3, b: Vector3, cor: Color) -> void:
	_malha.surface_set_color(cor)
	_malha.surface_add_vertex(a)
	_malha.surface_set_color(cor)
	_malha.surface_add_vertex(b)


func _seta(origem: Vector3, vetor: Vector3, cor: Color) -> void:
	var fim := origem + vetor
	_linha(origem, fim, cor)
	var dir := vetor.normalized()
	var lado := dir.cross(Vector3.UP)
	if lado.length() < 0.01:
		lado = Vector3.RIGHT
	lado = lado.normalized() * 0.12
	_linha(fim, fim - dir * 0.22 + lado, cor)
	_linha(fim, fim - dir * 0.22 - lado, cor)


func _circulo(centro: Vector3, base: Basis, raio: float, cor: Color, eixo := 1) -> void:
	var seg := 20
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		var p0: Vector3
		var p1: Vector3
		if eixo == 1:
			p0 = Vector3(cos(a0), 0, sin(a0))
			p1 = Vector3(cos(a1), 0, sin(a1))
		elif eixo == 0:
			p0 = Vector3(0, cos(a0), sin(a0))
			p1 = Vector3(0, cos(a1), sin(a1))
		else:
			p0 = Vector3(cos(a0), sin(a0), 0)
			p1 = Vector3(cos(a1), sin(a1), 0)
		_linha(centro + base * (p0 * raio), centro + base * (p1 * raio), cor)


# ---------------------------------------------------------------- colisões
func _desenhar_colisoes(area: Node3D) -> int:
	var total := 0
	for n in get_parent().find_children("*", "CollisionShape3D", true, false):
		var cs := n as CollisionShape3D
		if cs.disabled or cs.shape == null or not cs.is_visible_in_tree():
			continue
		var p := cs.global_position
		if area and area.has_method("contem") and not area.contem(p, 1.5):
			continue
		var dono := cs.get_parent()
		var cor := COR_CENARIO
		if dono and dono.is_in_group("jogador"):
			cor = COR_JOGADOR
		elif dono and (dono.is_in_group("inimigo") or dono.is_in_group("chefe")):
			cor = COR_INIMIGO
		elif dono is Area3D:
			cor = Color(1.0, 1.0, 1.0, 0.6)
		_forma(cs.shape, cs.global_transform, cor)
		total += 1
		if total > 220:
			break
	return total


func _forma(s: Shape3D, t: Transform3D, cor: Color) -> void:
	if s is BoxShape3D:
		var h := (s as BoxShape3D).size * 0.5
		var c := []
		for i in 8:
			c.append(t * Vector3(h.x * (1 if i & 1 else -1), h.y * (1 if i & 2 else -1), h.z * (1 if i & 4 else -1)))
		for par in [[0, 1], [2, 3], [4, 5], [6, 7], [0, 2], [1, 3], [4, 6], [5, 7], [0, 4], [1, 5], [2, 6], [3, 7]]:
			_linha(c[par[0]], c[par[1]], cor)
	elif s is CapsuleShape3D:
		var cap := s as CapsuleShape3D
		var meio := cap.height * 0.5 - cap.radius
		for y in [-meio, meio]:
			_circulo(t * Vector3(0, y, 0), t.basis, cap.radius, cor)
		for ang in [0.0, PI * 0.5, PI, PI * 1.5]:
			var off := Vector3(cos(ang), 0, sin(ang)) * cap.radius
			_linha(t * (off + Vector3(0, -meio, 0)), t * (off + Vector3(0, meio, 0)), cor)
		_circulo(t * Vector3(0, meio, 0), t.basis, cap.radius * 0.7, cor)
		_circulo(t * Vector3(0, -meio, 0), t.basis, cap.radius * 0.7, cor)
	elif s is CylinderShape3D:
		var cil := s as CylinderShape3D
		var h2 := cil.height * 0.5
		for y in [-h2, h2]:
			_circulo(t * Vector3(0, y, 0), t.basis, cil.radius, cor)
		for ang in [0.0, PI * 0.5, PI, PI * 1.5]:
			var off := Vector3(cos(ang), 0, sin(ang)) * cil.radius
			_linha(t * (off + Vector3(0, -h2, 0)), t * (off + Vector3(0, h2, 0)), cor)
	elif s is SphereShape3D:
		var r := (s as SphereShape3D).radius
		for e in 3:
			_circulo(t.origin, t.basis, r, cor, e)


# ---------------------------------------------------------------- normais
func _desenhar_normais() -> int:
	var total := 0
	var corpos: Array = get_tree().get_nodes_in_group("jogador") + get_tree().get_nodes_in_group("inimigo")
	for corpo in corpos:
		if not (corpo is Node3D) or not corpo.is_visible_in_tree():
			continue
		for n in (corpo as Node).find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			if mi.mesh == null or not mi.is_visible_in_tree() or mi.mesh is ImmediateMesh:
				continue
			var dados: Array = _normais_da_malha(mi.mesh)
			var pos: PackedVector3Array = dados[0]
			var nor: PackedVector3Array = dados[1]
			var t := mi.global_transform
			for i in pos.size():
				var p := t * pos[i]
				_linha(p, p + (t.basis * nor[i]).normalized() * 0.09, COR_NORMAL)
			total += pos.size()
	return total


func _normais_da_malha(m: Mesh) -> Array:
	if _cache_normais.has(m):
		return _cache_normais[m]
	var pos := PackedVector3Array()
	var nor := PackedVector3Array()
	var todos_p := PackedVector3Array()
	var todos_n := PackedVector3Array()
	for s in m.get_surface_count():
		var arr := m.surface_get_arrays(s)
		if arr.is_empty() or arr[Mesh.ARRAY_NORMAL] == null:
			continue
		todos_p.append_array(arr[Mesh.ARRAY_VERTEX])
		todos_n.append_array(arr[Mesh.ARRAY_NORMAL])
	var passo := maxi(1, todos_p.size() / NORMAIS_POR_MALHA)
	for i in range(0, todos_p.size(), passo):
		pos.append(todos_p[i])
		nor.append(todos_n[i])
	_cache_normais[m] = [pos, nor]
	return _cache_normais[m]


# ---------------------------------------------------------------- espelhos
func _desenhar_espelhos() -> int:
	var usados := 0
	for f in get_tree().get_nodes_in_group("fonte_luz"):
		if not f.is_visible_in_tree():
			continue
		for ref in f.reflexoes:
			var p: Vector3 = ref[0] + Vector3.UP * 0.05
			var d: Vector3 = ref[1]
			var n: Vector3 = ref[2]
			var r: Vector3 = ref[3]
			_seta(p - d * 1.3, d * 1.3, COR_D)
			_seta(p, n * 1.0, COR_N)
			_seta(p, r * 1.3, COR_R)
			var ang := rad_to_deg(acos(clampf(-d.dot(n), -1.0, 1.0)))
			var rot := _rotulo(usados)
			rot.text = "θi = θr = %.0f°\nr = d − 2(d·n)n" % ang
			rot.global_position = p + Vector3.UP * 1.1
			rot.visible = true
			usados += 1
	for i in range(usados, _rotulos.size()):
		_rotulos[i].visible = false
	return usados


func _rotulo(i: int) -> Label3D:
	while _rotulos.size() <= i:
		var l := Label3D.new()
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.font_size = 30
		l.outline_size = 8
		l.modulate = Color(1.0, 0.85, 1.0)
		l.top_level = true
		add_child(l)
		_rotulos.append(l)
	return _rotulos[i]


# ---------------------------------------------------------------- painel
func _atualizar_painel(area: Node3D, formas: int, normais: int, reflexoes: int) -> void:
	var fps := Performance.get_monitor(Performance.TIME_FPS)
	var draws := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var prims := Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	var t := "RAIO-X DE CG  [F1]\n"
	t += "%d FPS · %d draw calls · %d triângulos\n" % [fps, draws, prims]
	t += "[F2] tilt-shift: %s\n" % ("ligado" if _tilt_ligado() else "DESLIGADO")
	t += "[F3] luz: %s\n" % ("cel shading (toon)" if Toon.ligado else "PBR padrão")
	t += "verde: colisões (%d) · ciano: Teseu\nvermelho: inimigos · azul: normais (%d)\n" % [formas, normais]
	if reflexoes > 0:
		t += "\nEspelhos: r = d − 2(d·n)n\n"
		t += "amarelo d · verde n · magenta r\n"
	if area and area.get("tipo") == "arena":
		t += "\nMinotauro: máquina de estados\n+ steering para desviar das colunas\n"
	_painel.text = t
