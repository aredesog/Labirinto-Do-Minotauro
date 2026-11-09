class_name Minotauro
extends CharacterBody3D
## Chefe final: o Minotauro (corpo de cavalo, tronco e cabeça de touro).
##
## Padrões de ataque (legíveis, estilo Zelda):
##   PERSEGUIR  -> trota atrás do Teseu.
##   GOLPE      -> se o Teseu está perto: ergue o machado (aviso) e bate no
##                 chão, soltando uma onda de choque na frente.
##   INVESTIDA  -> empina e mostra uma faixa vermelha no chão (aviso), depois
##                 dispara em linha reta.
##                 - ACERTOU o Teseu: joga ele para o lado e FREIA (sem atordoar).
##                 - ERROU e bateu em parede/coluna: fica ATORDOADO, a hora de
##                   atacar (dano em dobro).
##   FASE 2     -> com metade da vida: ruge, fica mais rápido e chama 2
##                 minitaurinhos.
##
## Animação procedural: os pivôs do modelo (pernas, tronco, cabeça, braços,
## cauda) giram por código conforme o estado — nada de rig/esqueleto.

signal vida_mudou(atual: int, maximo: int)
signal derrotado
## Emitido no golpe final, quando ele começa a cair (cena de câmera lenta).
signal caiu

## CENA = anda sozinho numa direção (cena de abertura: ele some no labirinto).
## (fica no fim para não mudar os números dos outros estados)
enum Estado { PARADO, INTRO, PERSEGUIR, MIRAR, INVESTIDA, ATORDOADO, ERGUER, GOLPE, RECUPERAR, MORTO, FREAR, CENA }

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
## Força com que a investida joga o Teseu para o lado.
@export var forca_arremesso: float = 13.0
## Fração da vida máxima que ele recupera quando o Teseu morre na arena.
@export_range(0.0, 1.0) var recuperacao_ao_vencer: float = 0.25

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
var _t_casco := 0.0
# destravar: se ele quer andar mas não sai do lugar (preso em pilastra/canto)
var _t_preso := 0.0
var _desvio := Vector3.ZERO
var _t_desvio := 0.0
## Modelo do grupo com esqueleto: uma animação por estado da IA.
var _modelo: AnimModelo
var _estado_anim := -1
const ANIM_DO_ESTADO := {
	Estado.PARADO: "parado", Estado.INTRO: "rugir", Estado.PERSEGUIR: "andar",
	Estado.MIRAR: "mirar", Estado.INVESTIDA: "correr", Estado.ATORDOADO: "atordoado",
	Estado.ERGUER: "erguer", Estado.GOLPE: "golpe", Estado.RECUPERAR: "parado",
	Estado.MORTO: "morrer", Estado.FREAR: "frear", Estado.CENA: "andar",
}
## Na cena de abertura ele só ruge e anda — não ataca ninguém.
var _na_cena := false
var _dir_cena := Vector3.FORWARD


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
	_modelo = AnimModelo.new(_visual)
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
	_na_cena = false
	_alvo = get_tree().get_first_node_in_group("jogador")
	_mudar(Estado.INTRO)


func resetar() -> void:
	_na_cena = false
	vida = vida_maxima
	fase2 = false
	_voltar_ao_inicio()


## O Teseu morreu na arena: o Minotauro NÃO volta com a vida cheia, só
## recupera um pouco (25% da vida máxima). A fase 2 continua se já tinha começado.
func recuperar_parcial() -> void:
	vida = mini(vida + int(round(vida_maxima * recuperacao_ao_vencer)), vida_maxima)
	_voltar_ao_inicio()


func _voltar_ao_inicio() -> void:
	position = _posicao_inicial
	rotation = Vector3(0, _rotacao_inicial, 0)
	velocity = Vector3.ZERO
	_cooldown_investida = 3.0
	_t_desvio = 0.0
	_t_preso = 0.0
	for r in _reforcos:
		if is_instance_valid(r):
			r.queue_free()
	_reforcos.clear()
	if _visual:
		_visual.rotation = Vector3.ZERO
		_visual.position = Vector3.ZERO
	_estado_anim = -1
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
	if novo == Estado.INTRO:
		Som.tocar("rugido", 0.0, 0.03, 1.0 if not fase2 else 0.9)
	elif novo == Estado.MIRAR:
		Som.tocar("casco", 2.0)
		Efeitos.poeira(global_position, 6, 0.5)


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
				_mudar(Estado.PARADO if _na_cena else Estado.PERSEGUIR)
		Estado.CENA:
			_virar_para(_dir_cena, delta, 5.0)
			plano = _dir_cena * velocidade_trote
		Estado.PERSEGUIR:
			var rumo := para_alvo.normalized()
			if _t_desvio > 0.0:
				_t_desvio -= delta
				rumo = _desvio
			_virar_para(rumo, delta, 4.0 if _t_desvio <= 0.0 else 8.0)
			plano = rumo * velocidade_trote * _fator_fase()
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
				_acertar_investida(para_alvo)
		Estado.FREAR:
			# derrapa até parar depois de atropelar o Teseu
			var k := clampf(1.0 - _t / 0.45, 0.0, 1.0)
			plano = _dir_investida * velocidade_investida * 0.5 * k
			if _t > 0.9:
				_cooldown_investida = randf_range(2.5, 4.0) / _fator_fase()
				_mudar(Estado.PERSEGUIR)
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
				_mudar(Estado.PARADO if _na_cena else Estado.PERSEGUIR)

	velocity.x = plano.x
	velocity.z = plano.z
	move_and_slide()
	_som_cascos(delta)

	if estado == Estado.PERSEGUIR:
		_verificar_preso(plano, delta)
	if estado == Estado.INVESTIDA:
		_distancia_investida += plano.length() * delta
		if _bateu_em_parede() or _distancia_investida > 22.0:
			_mudar(Estado.ATORDOADO)
			_tremer_camera(0.45)
			Som.tocar("parede")
			Efeitos.poeira(global_position + _dir_investida * 1.6 + Vector3.UP * 0.6, 16, 0.7)
	_animar(delta)


## Investida acertou: o Teseu é jogado para o lado em que estava e o
## Minotauro freia (não bate na parede, então não fica atordoado).
func _acertar_investida(para_alvo: Vector3) -> void:
	var lado := Vector3(-_dir_investida.z, 0, _dir_investida.x)
	if para_alvo.dot(lado) < 0.0:
		lado = -lado
	var empurrao := (lado * 0.85 + _dir_investida * 0.35).normalized()
	if _alvo.has_method("levar_dano"):
		_alvo.levar_dano(dano_investida, empurrao)
	if _alvo.has_method("arremessar"):
		_alvo.arremessar(empurrao * forca_arremesso)
	_tremer_camera(0.35)
	Som.tocar("impacto", -3.0)
	Efeitos.poeira(global_position + _dir_investida * 1.2, 12, 0.6)
	_mudar(Estado.FREAR)


## Se ele tenta andar e quase não sai do lugar por um tempo (preso num canto
## atrás de uma pilastra), escolhe um rumo de fuga: afasta da parede/pilastra
## e contorna para o lado do Teseu.
func _verificar_preso(plano: Vector3, delta: float) -> void:
	if plano.length() < 0.5 or _t_desvio > 0.0:
		_t_preso = 0.0
		return
	var andou := get_real_velocity()
	andou.y = 0
	if andou.length() > plano.length() * 0.35:
		_t_preso = maxf(_t_preso - delta, 0.0)
		return
	_t_preso += delta
	if _t_preso < 0.3:
		return
	_t_preso = 0.0
	var normal := Vector3.ZERO
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var obj := col.get_collider()
		if obj and (obj as Node).is_in_group("jogador"):
			continue
		var n := col.get_normal()
		n.y = 0
		normal += n
	if normal.length() < 0.01:
		normal = -plano
	normal = normal.normalized()
	var lado := Vector3(-normal.z, 0, normal.x)
	if _alvo and (_alvo.global_position - global_position).dot(lado) < 0.0:
		lado = -lado
	_desvio = (normal * 0.7 + lado).normalized()
	_t_desvio = 0.8


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


## Trote: um casco a cada passo; na investida, poeira levantando atrás.
func _som_cascos(delta: float) -> void:
	if estado != Estado.PERSEGUIR and estado != Estado.INVESTIDA and estado != Estado.CENA:
		return
	_t_casco -= delta
	if _t_casco > 0.0:
		return
	if estado == Estado.INVESTIDA:
		_t_casco = 0.09
		Som.tocar("casco", 0.0, 0.12)
		Efeitos.poeira(global_position - _dir_investida * 0.8, 3, 0.5)
	else:
		_t_casco = 0.3 / _fator_fase()
		Som.tocar("casco", -3.0, 0.12)


func _bater_no_chao() -> void:
	var frente := global_basis.z.normalized()
	var impacto := global_position + frente * 2.4
	impacto.y = 0.05
	Som.tocar("impacto")
	Efeitos.poeira(impacto, 14, 0.6)
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
	Som.tocar("acerto", 0.0, 0.06, 0.8)
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
		jogo.avisar(["minotauro", "mais", "minitauro", "minitauro"], 2.2)
	if cena_minitaurinho == null:
		return
	for lado in [-1.0, 1.0]:
		var m := cena_minitaurinho.instantiate() as Node3D
		get_parent().add_child(m)
		m.global_position = _ponto_dentro_da_arena(global_position + global_basis.x * lado * 3.0) + Vector3.UP * 0.2
		_reforcos.append(m)
		Efeitos.fumaca(m.global_position)


## Prende o ponto dentro da arena (longe das paredes). Antes as crias podiam
## nascer do lado de fora quando o Minotauro estava encostado numa parede.
func _ponto_dentro_da_arena(p: Vector3) -> Vector3:
	var arena := get_parent() as Node3D
	var meio := Vector2(6.0, 6.0)
	if arena and arena.get("meio_tamanho") != null:
		meio = arena.get("meio_tamanho")
	var centro := arena.global_position if arena else Vector3.ZERO
	var margem := 1.3
	var local := p - centro
	local.x = clampf(local.x, -meio.x + margem, meio.x - margem)
	local.z = clampf(local.z, -meio.y + margem, meio.y - margem)
	return Vector3(centro.x + local.x, global_position.y, centro.z + local.z)


func _morrer() -> void:
	_mudar(Estado.MORTO)
	caiu.emit()   # a cena da queda (gerenciador) cuida da câmera lenta
	remove_from_group("inimigo")
	collision_layer = 0
	for r in _reforcos:
		if is_instance_valid(r) and r.has_method("levar_dano"):
			r.levar_dano(99)
	if _visual and not (_modelo and _modelo.tem()):
		var tw := create_tween()
		tw.tween_property(_visual, "rotation:z", deg_to_rad(80), 1.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(_visual, "position:y", -0.4, 1.2)
	_tremer_camera(0.6)
	Som.tocar("rugido", 0.0, 0.0, 0.7)
	Som.musica("", 2.0)
	await get_tree().create_timer(1.0).timeout
	Som.tocar("impacto")
	Efeitos.poeira(global_position, 20, 0.8)
	# caído e tonto: estrelinhas girando em cima dele
	if _estrelas:
		_estrelas.position = Vector3(0, 1.4, 0.6)
		_estrelas.visible = true
		var giro := _estrelas.create_tween().set_loops()
		giro.tween_property(_estrelas, "rotation:y", TAU, 1.0).from(0.0)
	await get_tree().create_timer(0.6).timeout
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
	if _modelo and _modelo.tem():
		_animar_modelo(delta)
		return
	var correndo := estado == Estado.INVESTIDA
	var andando := estado == Estado.PERSEGUIR or estado == Estado.CENA
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
		Estado.FREAR:
			tronco_x = -0.3                             # empina freando
			cabeca_x = -0.2
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


## Animações do Blender: troca quando o estado muda. O tempo de "erguer"
## acompanha o tempo do estado ERGUER (mais rápido na fase 2).
func _animar_modelo(delta: float) -> void:
	if estado != _estado_anim:
		_estado_anim = estado
		var nome: String = ANIM_DO_ESTADO.get(estado, "parado")
		var vel := _fator_fase()
		var mistura := 0.15
		match estado:
			Estado.ERGUER:
				var dur := _modelo.ap.get_animation("erguer").length if _modelo.ap.has_animation("erguer") else 0.6
				vel = dur / (0.65 / _fator_fase())
				mistura = 0.08
			Estado.GOLPE:
				vel = 2.2
				mistura = 0.02
			Estado.INVESTIDA:
				vel = 1.2 * _fator_fase()
				mistura = 0.1
			Estado.MORTO:
				vel = 0.9
		_modelo.trocar(nome, vel, mistura)
	if estado == Estado.MIRAR and _mira:
		var m := _mira.mesh as QuadMesh
		m.size = Vector2(1.6, 4.0 + _t * 10.0)
		_mira.position = Vector3(0, 0.06, 1.5 + m.size.y / 2.0)
	if estado == Estado.ATORDOADO and _estrelas:
		_estrelas.rotation.y += delta * 4.0


func _rot(no: Node3D, alvo: float, delta: float, vel := 14.0) -> void:
	if no:
		no.rotation.x = lerp_angle(no.rotation.x, alvo, minf(vel * delta, 1.0))



# --------------------------------------------------------------------------
# Cena de abertura (pantomima): ruge e bate o machado no chão, mandando os
# minitaurinhos atrás do Teseu
# --------------------------------------------------------------------------
func rugir_na_cena() -> void:
	_na_cena = true
	_alvo = null
	_mudar(Estado.INTRO)
	_tremer_camera(0.45)


## Vira e anda para "dir" (para longe da câmera = para dentro do labirinto).
func andar_na_cena(dir: Vector3) -> void:
	_na_cena = true
	_dir_cena = Vector3(dir.x, 0, dir.z).normalized()
	_mudar(Estado.CENA)


func parar_na_cena() -> void:
	_mudar(Estado.PARADO)


## Ergue o machado e bate no chão (o "vão!" para os minitaurinhos).
func golpear_na_cena() -> void:
	_na_cena = true
	_alvo = null
	_mudar(Estado.ERGUER)
