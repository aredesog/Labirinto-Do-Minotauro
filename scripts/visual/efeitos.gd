class_name Efeitos
extends RefCounted
## Partículas de uma vez só (CPUParticles3D, funcionam no renderizador
## Compatibilidade). Cada efeito se apaga sozinho quando termina.
##     Efeitos.faisca(posicao)   faíscas da espada / do escudo
##     Efeitos.poeira(posicao)   poeira dos cascos e da investida
##     Efeitos.fumaca(posicao)   fumaça quando um minitaurinho some
##     Efeitos.estilhacos(pos)   pedra quebrando

static var _malha: QuadMesh
static var _materiais := {}


static func _material(cor: Color, aditivo: bool) -> StandardMaterial3D:
	var chave := "%s_%s" % [cor.to_html(), aditivo]
	if _materiais.has(chave):
		return _materiais[chave]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_color = cor
	if aditivo:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.no_depth_test = false
	_materiais[chave] = m
	return m


static func _criar(pos: Vector3, qtd: int, vida: float, cor: Color, aditivo := false) -> CPUParticles3D:
	var arvore := Engine.get_main_loop() as SceneTree
	if arvore == null:
		return null
	var pai: Node = arvore.current_scene if arvore.current_scene else arvore.root
	if _malha == null:
		_malha = QuadMesh.new()
		_malha.size = Vector2(1, 1)
	var p := CPUParticles3D.new()
	p.mesh = _malha
	p.material_override = _material(cor, aditivo)
	p.amount = qtd
	p.lifetime = vida
	p.one_shot = true
	p.explosiveness = 0.95
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pai.add_child(p)
	p.global_position = pos
	# some sozinho depois de terminar
	arvore.create_timer(vida + 0.3, false).timeout.connect(p.queue_free)
	return p


static func _curva_some() -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0, 1))
	c.add_point(Vector2(1, 0))
	return c


static func _gradiente(a: Color, b: Color) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, a)
	g.set_color(1, b)
	return g


static func faisca(pos: Vector3, cor := Color(1.0, 0.85, 0.4)) -> void:
	var p := _criar(pos, 14, 0.35, Color.WHITE, true)
	if p == null:
		return
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 6.5
	p.gravity = Vector3(0, -14, 0)
	p.scale_amount_min = 0.05
	p.scale_amount_max = 0.1
	p.scale_amount_curve = _curva_some()
	p.color_ramp = _gradiente(cor, Color(cor.r, cor.g * 0.4, 0.0, 0.0))
	p.emitting = true


static func poeira(pos: Vector3, qtd := 10, tamanho := 0.45) -> void:
	var p := _criar(pos + Vector3.UP * 0.1, qtd, 0.8, Color.WHITE)
	if p == null:
		return
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 0.8
	p.initial_velocity_max = 2.0
	p.gravity = Vector3(0, -0.6, 0)
	p.damping_min = 1.5
	p.damping_max = 2.5
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.35
	p.scale_amount_min = tamanho * 0.6
	p.scale_amount_max = tamanho
	var c := Curve.new()
	c.add_point(Vector2(0, 0.4))
	c.add_point(Vector2(0.3, 1))
	c.add_point(Vector2(1, 0.8))
	p.scale_amount_curve = c
	p.color_ramp = _gradiente(Color(0.78, 0.7, 0.58, 0.6), Color(0.78, 0.7, 0.58, 0.0))
	p.emitting = true


static func fumaca(pos: Vector3) -> void:
	var p := _criar(pos + Vector3.UP * 0.4, 16, 0.9, Color.WHITE)
	if p == null:
		return
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 2.4
	p.gravity = Vector3(0, 1.2, 0)
	p.damping_min = 2.0
	p.damping_max = 3.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.3
	p.scale_amount_min = 0.35
	p.scale_amount_max = 0.6
	var c := Curve.new()
	c.add_point(Vector2(0, 0.5))
	c.add_point(Vector2(0.4, 1))
	c.add_point(Vector2(1, 0.2))
	p.scale_amount_curve = c
	p.color_ramp = _gradiente(Color(0.95, 0.93, 0.9, 0.85), Color(0.6, 0.55, 0.65, 0.0))
	p.emitting = true


static func estilhacos(pos: Vector3) -> void:
	var p := _criar(pos, 10, 0.6, Color.WHITE)
	if p == null:
		return
	p.direction = Vector3.UP
	p.spread = 75.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 4.0
	p.gravity = Vector3(0, -15, 0)
	p.scale_amount_min = 0.08
	p.scale_amount_max = 0.16
	p.color_ramp = _gradiente(Color(0.55, 0.5, 0.45, 1.0), Color(0.45, 0.4, 0.35, 0.0))
	p.emitting = true
	poeira(pos - Vector3.UP * 0.3, 5, 0.3)



# --------------------------------------------------------------------------
# "Peso" nos golpes (game feel)
# --------------------------------------------------------------------------
static var _fim_congela_ms := 0
static var _flash: StandardMaterial3D


## Hitstop / câmera lenta: o tempo do jogo anda devagar por "dur" segundos
## REAIS. A volta à velocidade normal é GARANTIDA: o timer confere o relógio
## e, se ainda faltar um pouquinho, agenda de novo (antes, um timer que
## disparava alguns ms adiantado deixava o jogo preso em câmera lenta).
## Além disso, garantir_tempo_normal() é chamado todo quadro pelo jogo.
## forcar = true troca a velocidade atual (ex.: sair do "congelado" para a câmera lenta).
static func congelar(arvore: SceneTree, dur := 0.07, escala := 0.05, forcar := false) -> void:
	if arvore == null:
		return
	_fim_congela_ms = maxi(_fim_congela_ms, Time.get_ticks_msec() + int(dur * 1000.0))
	Engine.time_scale = escala if forcar else minf(Engine.time_scale, escala)
	_agendar_volta(arvore, dur)


static func _agendar_volta(arvore: SceneTree, seg: float) -> void:
	var t := arvore.create_timer(maxf(seg, 0.01), true, false, true)
	t.timeout.connect(func():
		var falta := _fim_congela_ms - Time.get_ticks_msec()
		if falta <= 0:
			Engine.time_scale = 1.0
		else:
			_agendar_volta(arvore, falta / 1000.0))


## Rede de segurança: se passou do prazo e o tempo ainda está lento, volta ao normal.
static func garantir_tempo_normal() -> void:
	if Engine.time_scale < 1.0 and Time.get_ticks_msec() > _fim_congela_ms + 150:
		Engine.time_scale = 1.0


## Pisca branco (overlay em todas as malhas do nó) — "levou o golpe".
static func piscar_branco(no: Node, dur := 0.08) -> void:
	if no == null or not no.is_inside_tree():
		return
	if _flash == null:
		_flash = StandardMaterial3D.new()
		_flash.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flash.albedo_color = Color(1, 1, 1, 0.6)
		_flash.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var malhas := no.find_children("*", "MeshInstance3D", true, false)
	for m in malhas:
		(m as MeshInstance3D).material_overlay = _flash
	var t := no.get_tree().create_timer(dur, true, false, true)
	t.timeout.connect(func():
		for m in malhas:
			if is_instance_valid(m):
				(m as MeshInstance3D).material_overlay = null)
