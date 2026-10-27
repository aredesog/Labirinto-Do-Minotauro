class_name Minotauro
extends CharacterBody3D
## Chefe final: o Minotauro (corpo de cavalo, tronco e cabeça de touro).
##
## Padrões de ataque (legíveis, estilo Zelda):
##   PERSEGUIR  -> trota atrás do Teseu.
##   GOLPE      -> se o Teseu está perto: ergue o machado (aviso) e bate no
##                 chão, soltando uma onda de choque na frente.
##   INVESTIDA  -> empina e mostra uma faixa vermelha no chão (aviso), depois
##                 dispara em linha reta. Se bater em parede ou coluna, fica
##                 ATORDOADO por um tempo: é a hora de atacar (dano em dobro).
##   FASE 2     -> com metade da vida: ruge, fica mais rápido e chama 2
##                 minitaurinhos.
##
## Animação procedural: os pivôs do modelo (pernas, tronco, cabeça, braços,
## cauda) giram por código conforme o estado — nada de rig/esqueleto.

signal vida_mudou(atual: int, maximo: int)
signal derrotado

enum Estado { PARADO, INTRO, PERSEGUIR, MIRAR, INVESTIDA, ATORDOADO, ERGUER, GOLPE, RECUPERAR, MORTO }

@export var vida_maxima: int = 24
@export var velocidade_trote: float = 2.4
@export var velocidade_investida: float = 11.0
## Dano em meios corações.
@export var dano_golpe: int = 2
@export var dano_investida: int = 3
@export var distancia_golpe: float = 3.0
@export var tempo_atordoado: float = 2.4
@export var cena_minitaurinho: PackedScene
## Usado pela espada do Teseu: o Minotauro é grande, então acerta de mais longe.
@export var raio_acerto: float = 1.4

var vida: int
var estado: Estado = Estado.PARADO
var fase2 := false
var _t := 0.0          # tempo no estado atual
var _anim := 0.0       # relógio da animação
var _cooldown_investida := 3.0
var _dir_investida := Vector3.FORWARD
var _acertou_investida := false
var _distancia_investida := 0.0
var _invulneravel := 0.0
var _posicao_inicial: Vector3
var _rotacao_inicial: float
var _alvo: Node3D
var _reforcos: Array[Node] = []

var _pernas := {}
var _tronco: Node3D
var _cabeca: Node3D
var _braco_dir: Node3D
var _braco_esq: Node3D
var _cauda: Node3D
var _visual: Node3D
var _mira: MeshInstance3D
var _estrelas: Node3D
var _flash: StandardMaterial3D


func _ready() -> void:
	add_to_group("inimigo")
	add_to_group("chefe")
	vida = vida_maxima
	_posicao_inicial = position
	_rotacao_inicial = rotation.y
	_visual = get_node_or_null("Visual")
	for nome in ["PernaDE", "PernaDD", "PernaTE", "PernaTD"]:
		_pernas[nome] = find_child(nome, true, false)
	_tronco = find_child("Tronco", true, false)
	_cabeca = find_child("Cabeca", true, false)
	_braco_dir = find_child("BracoDir", true, false)
	_braco_esq = find_child("BracoEsq", true, false)
	_cauda = find_child("Cauda", true, false)
	_mira = get_node_or_null("Mira")
	if _mira:
		_mira.visible = false
	_criar_estrelas()
	_flash = StandardMaterial3D.new()
	_flash.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash.albedo_color = Color(1, 1, 1, 0.55)
	_flash.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA


# --------------------------------------------------------------------------
# Controle pela arena
# --------------------------------------------------------------------------
func comecar() -> void:
	_alvo = get_tree().get_first_node_in_group("jogador")
	_mudar(Estado.INTRO)


func resetar() -> void:
	vida = vida_maxima
	fase2 = false
	position = _posicao_inicial
	rotation = Vector3(0, _rotacao_inicial, 0)
	velocity = Vector3.ZERO
	_cooldown_investida = 3.0
	for r in _reforcos:
		if is_instance_valid(r):
			r.queue_free()
	_reforcos.clear()
	if _visual:
		_visual.rotation = Vector3.ZERO
		_visual.position = Vector3.ZERO
	_mudar(Estado.PARADO)
	vida_mudou.emit(vida, vida_maxima)


func esta_morto() -> bool:
	return estado == Estado.MORTO


func _mudar(novo: Estado) -> void:
	estado = novo
	_t = 0.0
	if _mira:
		_mira.visible = novo == Estado.MIRAR
	if _estrelas:
		_estrelas.visible = novo == Estado.ATORDOADO
	if novo == Estado.INVESTIDA:
		_acertou_investida = false
		_distancia_investida = 0.0


func _fator_fase() -> float:
	return 1.3 if fase2 else 1.0


# --------------------------------------------------------------------------
# IA
# --------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	_t += delta
	_invulneravel = max(_invulneravel - delta, 0.0)
	velocity.y = 0.0 if is_on_floor() else velocity.y - 20.0 * delta
	var plano := Vector3.ZERO
	var para_alvo := Vector3.ZERO
	var distancia := 99.0
	if _alvo:
		para_alvo = _alvo.global_position - global_position
		para_alvo.y = 0
		distancia = para_alvo.length()

	match estado:
		Estado.PARADO, Estado.MORTO:
			pass
		Estado.INTRO:
			if _t > 1.8:
				_mudar(Estado.PERSEGUIR)
		Estado.PERSEGUIR:
			_virar_para(para_alvo, delta, 4.0)
			plano = para_alvo.normalized() * velocidade_trote * _fator_fase()
			_cooldown_investida -= delta
			if distancia < distancia_golpe:
				_mudar(Estado.ERGUER)
			elif _cooldown_investida <= 0.0 and distancia > 3.5:
				_mudar(Estado.MIRAR)
		Estado.MIRAR:
			_virar_para(para_alvo, delta, 6.0)
			if _t > 0.9 / _fator_fase():
				_dir_investida = global_basis.z.normalized()
				_dir_investida.y = 0
				_mudar(Estado.INVESTIDA)
		Estado.INVESTIDA:
			plano = _dir_investida * velocidade_investida * _fator_fase()
			if not _acertou_investida and _alvo and distancia < 1.9:
				_acertou_investida = true
				if _alvo.has_method("levar_dano"):
					_alvo.levar_dano(dano_investida, _dir_investida)
		Estado.ATORDOADO:
			if _t > tempo_atordoado / _fator_fase():
				_mudar(Estado.RECUPERAR)
		Estado.ERGUER:
			_virar_para(para_alvo, delta, 5.0)
			if _t > 0.65 / _fator_fase():
				_mudar(Estado.GOLPE)
				_bater_no_chao()
		Estado.GOLPE:
			if _t > 0.5:
				_mudar(Estado.RECUPERAR)
		Estado.RECUPERAR:
			if _t > 0.6:
				_cooldown_investida = randf_range(2.5, 4.5) / _fator_fase()
				_mudar(Estado.PERSEGUIR)

	velocity.x = plano.x
	velocity.z = plano.z
	move_and_slide()

	if estado == Estado.INVESTIDA:
		_distancia_investida += plano.length() * delta
		if _bateu_em_parede() or _distancia_investida > 22.0:
			_mudar(Estado.ATORDOADO)
			_tremer_camera(0.45)
	_animar(delta)


func _virar_para(dir: Vector3, delta: float, vel: float) -> void:
	if dir.length() < 0.05:
		return
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), vel * delta)


func _bateu_em_parede() -> bool:
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var obj := col.get_collider()
		if obj and (obj as Node).is_in_group("jogador"):
			continue
		if col.get_normal().dot(_dir_investida) < -0.5:
			return true
	return false


func _bater_no_chao() -> void:
	var frente := global_basis.z.normalized()
	var impacto := global_position + frente * 2.4
	impacto.y = 0.05
	_onda_de_choque(impacto)
	_tremer_camera(0.3)
	if _alvo and _alvo.has_method("levar_dano"):
		var d := _alvo.global_position - impacto
		d.y = 0
		if d.length() < 1.9:
			_alvo.levar_dano(dano_golpe, frente)


# --------------------------------------------------------------------------
# Dano
# --------------------------------------------------------------------------
func levar_dano(quantidade: int, _direcao: Vector3 = Vector3.ZERO) -> void:
	if estado in [Estado.PARADO, Estado.INTRO, Estado.MORTO] or _invulneravel > 0.0:
		return
	if estado == Estado.ATORDOADO:
		quantidade *= 2
	vida = max(vida - quantidade, 0)
	_invulneravel = 0.15
	vida_mudou.emit(vida, vida_maxima)
	_piscar()
	if vida == 0:
		_morrer()
	elif not fase2 and vida <= vida_maxima / 2:
		_entrar_fase2()


func _entrar_fase2() -> void:
	fase2 = true
	_mudar(Estado.INTRO)
	_tremer_camera(0.5)
	var jogo := get_tree().get_first_node_in_group("jogo")
	if jogo:
		jogo.mensagem.emit("O Minotauro ruge de fúria e chama suas crias!", 2.5)
	if cena_minitaurinho == null:
		return
	for lado in [-1.0, 1.0]:
		var m := cena_minitaurinho.instantiate() as Node3D
		get_parent().add_child(m)
		m.global_position = global_position + global_basis.x * lado * 3.0 + Vector3.UP * 0.2
		_reforcos.append(m)


func _morrer() -> void:
	_mudar(Estado.MORTO)
	remove_from_group("inimigo")
	collision_layer = 0
	for r in _reforcos:
		if is_instance_valid(r) and r.has_method("levar_dano"):
			r.levar_dano(99)
	if _visual:
		var tw := create_tween()
		tw.tween_property(_visual, "rotation:z", deg_to_rad(80), 1.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(_visual, "position:y", -0.4, 1.2)
	_tremer_camera(0.6)
	await get_tree().create_timer(1.6).timeout
	derrotado.emit()


func _piscar() -> void:
	if _visual == null:
		return
	for mi in _visual.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_overlay = _flash
	await get_tree().create_timer(0.08).timeout
	for mi in _visual.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_overlay = null


func _tremer_camera(forca: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam and cam.has_method("tremer"):
		cam.tremer(forca)


# --------------------------------------------------------------------------
# Efeitos
# --------------------------------------------------------------------------
func _onda_de_choque(pos: Vector3) -> void:
	var anel := MeshInstance3D.new()
	var toro := TorusMesh.new()
	toro.inner_radius = 0.8
	toro.outer_radius = 1.0
	anel.mesh = toro
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.85, 0.5, 0.9)
	anel.material_override = mat
	anel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(anel)
	anel.global_position = pos
	anel.scale = Vector3(0.4, 0.15, 0.4)
	var tw := anel.create_tween().set_parallel()
	tw.tween_property(anel, "scale", Vector3(2.2, 0.15, 2.2), 0.35)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.35)
	tw.chain().tween_callback(anel.queue_free)


func _criar_estrelas() -> void:
	_estrelas = Node3D.new()
	_estrelas.name = "Estrelas"
	add_child(_estrelas)
	_estrelas.position = Vector3(0, 3.7, 0.6)
	for i in 3:
		var e := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.1
		s.height = 0.2
		e.mesh = s
		var m := StandardMaterial3D.new()
		m.albedo_color = Color("#ffe24a")
		m.emission_enabled = true
		m.emission = Color("#ffe24a")
		m.emission_energy_multiplier = 1.5
		e.material_override = m
		var a := TAU * i / 3.0
		e.position = Vector3(cos(a) * 0.5, 0, sin(a) * 0.5)
		_estrelas.add_child(e)
	_estrelas.visible = false


# --------------------------------------------------------------------------
# Animação procedural
# --------------------------------------------------------------------------
func _animar(delta: float) -> void:
	var correndo := estado == Estado.INVESTIDA
	var andando := estado == Estado.PERSEGUIR
	var freq := 16.0 if correndo else (7.0 if andando else 2.0)
	_anim += delta * freq
	var amp := 0.7 if correndo else (0.45 if andando else 0.0)
	var s := sin(_anim)
	# pares diagonais em fase (trote): DE+TD e DD+TE
	_rot(_pernas.get("PernaDE"), s * amp, delta)
	_rot(_pernas.get("PernaTD"), s * amp, delta)
	_rot(_pernas.get("PernaDD"), -s * amp, delta)
	_rot(_pernas.get("PernaTE"), -s * amp, delta)
	var tronco_x := 0.0
	var cabeca_x := 0.0
	var braco_dir_x := 0.0
	var braco_esq_x := sin(_anim * 0.5) * 0.15
	match estado:
		Estado.INTRO:
			tronco_x = -0.25 + sin(_t * 18.0) * 0.05   # ruge empinado
			cabeca_x = -0.35
			braco_dir_x = -0.8
			braco_esq_x = -0.8
			_rot(_pernas.get("PernaDE"), -0.5, delta)
			_rot(_pernas.get("PernaDD"), -0.5, delta)
		Estado.MIRAR:
			tronco_x = -0.35 + sin(_t * 30.0) * 0.04  # empina e treme
			cabeca_x = 0.3
			_rot(_pernas.get("PernaDE"), -0.7 + sin(_t * 20.0) * 0.2, delta)
			_rot(_pernas.get("PernaDD"), -0.7 - sin(_t * 20.0) * 0.2, delta)
			if _mira:
				var m := _mira.mesh as QuadMesh
				m.size = Vector2(1.6, 4.0 + _t * 10.0)
				_mira.position = Vector3(0, 0.06, 1.5 + m.size.y / 2.0)
		Estado.INVESTIDA:
			tronco_x = 0.35
			cabeca_x = 0.45                             # chifres para frente
		Estado.ATORDOADO:
			tronco_x = 0.5 + sin(_t * 4.0) * 0.05
			cabeca_x = 0.6
			braco_dir_x = 0.3
			braco_esq_x = 0.3
			if _estrelas:
				_estrelas.rotation.y += delta * 4.0
		Estado.ERGUER:
			tronco_x = -0.2
			braco_dir_x = -2.7 * clampf(_t / (0.65 / _fator_fase()), 0.0, 1.0)
		Estado.GOLPE:
			tronco_x = 0.3
			cabeca_x = 0.3
			braco_dir_x = -1.25
		Estado.RECUPERAR:
			braco_dir_x = -0.6
		_:
			tronco_x = sin(_anim * 2.0) * 0.04
	var vel_braco := 30.0 if estado == Estado.GOLPE else 10.0
	_rot(_tronco, tronco_x, delta, 8.0)
	_rot(_cabeca, cabeca_x, delta, 8.0)
	_rot(_braco_dir, braco_dir_x, delta, vel_braco)
	_rot(_braco_esq, braco_esq_x, delta, 8.0)
	if _cauda:
		_cauda.rotation.y = sin(_anim * 0.7) * 0.4
	if _visual and estado != Estado.MORTO:
		_visual.position.y = absf(sin(_anim)) * (0.08 if andando or correndo else 0.0)


func _rot(no: Node3D, alvo: float, delta: float, vel := 14.0) -> void:
	if no:
		no.rotation.x = lerp_angle(no.rotation.x, alvo, minf(vel * delta, 1.0))
