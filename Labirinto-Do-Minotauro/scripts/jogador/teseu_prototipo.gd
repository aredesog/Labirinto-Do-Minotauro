class_name Teseu
extends CharacterBody3D
## Teseu provisório. Quando o modelo final ficar pronto, troque só o nó
## "Visual" pelo .glb do Teseu — a lógica continua a mesma.
##
## Controles: WASD/setas = andar | Espaço/J = atacar | E/K = interagir
## Empurrar estátua: ande contra ela por um instante.
##
## O novelo de Ariadne fica na cabeça (nó "Visual/Novelo") e encolhe a cada
## volta gasta.

signal vida_mudou(atual: int, maximo: int)

@export var velocidade: float = 4.5
## Vida em MEIOS corações (10 = 5 corações, como no Zelda). Cada golpe
## de minitaurinho tira meio coração.
@export var vida_maxima: int = 10
@export var dano_ataque: int = 1
@export var alcance_interacao: float = 1.4
@export var tempo_para_empurrar: float = 0.25
## Força do empurrão ao levar dano (aplicada pela física: não atravessa paredes).
@export var forca_empurrao: float = 7.0
## Se cair abaixo desta altura, volta ao checkpoint sem perder vida.
@export var altura_minima: float = -3.0

var vida: int
var _direcao_olhar := Vector3.BACK
var _tempo_empurrando := 0.0
var _cooldown_ataque := 0.0
var _invulneravel := 0.0
var _controle_ativo := true
var _empurrao := Vector3.ZERO
var _rastro: MeshInstance3D
## Posição da espada em descanso (ponta para frente e para baixo).
const ESPADA_DESCANSO := Vector3(0.45, -1.05, 0.0)

@onready var _visual: Node3D = get_node_or_null("Visual")
@onready var _espada: Node3D = get_node_or_null("Visual/Espada")
@onready var _novelo: Node3D = get_node_or_null("Visual/Novelo")


func _ready() -> void:
	add_to_group("jogador")
	vida = vida_maxima
	vida_mudou.emit(vida, vida_maxima)
	_criar_rastro()
	if _espada:
		_espada.rotation = ESPADA_DESCANSO
	await get_tree().process_frame
	var jogo := get_tree().get_first_node_in_group("jogo")
	if jogo:
		jogo.novelo_mudou.connect(_atualizar_novelo)
		_atualizar_novelo(jogo.novelo, true)


func _physics_process(delta: float) -> void:
	_cooldown_ataque = max(_cooldown_ataque - delta, 0.0)
	_invulneravel = max(_invulneravel - delta, 0.0)
	if _visual:
		_visual.visible = _invulneravel <= 0.0 or int(_invulneravel * 12.0) % 2 == 0

	if global_position.y < altura_minima:
		_resgatar_do_vazio()
		return

	var entrada := Vector2.ZERO
	if _controle_ativo:
		entrada = Input.get_vector("mover_esquerda", "mover_direita", "mover_cima", "mover_baixo")
	# A câmera olha para -Z, então "cima" na tela é -Z no mundo.
	var direcao := Vector3(entrada.x, 0.0, entrada.y)
	if direcao.length() > 0.1:
		direcao = direcao.normalized()
		_direcao_olhar = direcao
		if _visual:
			var alvo := atan2(direcao.x, direcao.z)
			_visual.rotation.y = lerp_angle(_visual.rotation.y, alvo, 15.0 * delta)

	# o empurrão entra na velocidade e é resolvido pelo move_and_slide,
	# então a parede segura o Teseu (antes ele era teleportado e atravessava)
	_empurrao = _empurrao.move_toward(Vector3.ZERO, 30.0 * delta)
	velocity.x = direcao.x * velocidade + _empurrao.x
	velocity.z = direcao.z * velocidade + _empurrao.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - 20.0 * delta
	move_and_slide()
	_verificar_empurrao(direcao, delta)

	if not _controle_ativo:
		return
	if Input.is_action_just_pressed("atacar") and _cooldown_ataque <= 0.0:
		_atacar()
	if Input.is_action_just_pressed("interagir"):
		_interagir()


# --------------------------------------------------------------------------
func _verificar_empurrao(direcao: Vector3, delta: float) -> void:
	var empurravel: Node = null
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var obj := col.get_collider()
		if obj and obj.is_in_group("empurravel") and direcao.dot(-col.get_normal()) > 0.7:
			empurravel = obj
			break
	if empurravel == null:
		_tempo_empurrando = 0.0
		return
	_tempo_empurrando += delta
	if _tempo_empurrando >= tempo_para_empurrar:
		_tempo_empurrando = 0.0
		# Empurra só nas 4 direções da grade.
		var eixo := Vector3(signf(direcao.x), 0, 0) if absf(direcao.x) > absf(direcao.z) \
			else Vector3(0, 0, signf(direcao.z))
		empurravel.empurrar(eixo)


func _atacar() -> void:
	_cooldown_ataque = 0.32
	# golpe em arco (da direita para a esquerda), com rastro de corte
	if _espada:
		var tw := create_tween()
		_espada.rotation = Vector3(0.0, -1.7, 0.0)
		tw.tween_property(_espada, "rotation:y", 1.5, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.05)
		tw.tween_property(_espada, "rotation", ESPADA_DESCANSO, 0.12)
	if _rastro:
		_rastro.visible = true
		var mat := _rastro.material_override as StandardMaterial3D
		mat.albedo_color.a = 0.55
		var tr := create_tween()
		tr.tween_property(mat, "albedo_color:a", 0.0, 0.22).set_delay(0.06)
		tr.tween_callback(func(): _rastro.visible = false)
	# acerta tudo num arco de ~200° à frente
	for inimigo in get_tree().get_nodes_in_group("inimigo"):
		var alvo := inimigo as Node3D
		if alvo == null or not alvo.has_method("levar_dano"):
			continue
		var d := alvo.global_position - global_position
		d.y = 0
		var extra = alvo.get("raio_acerto")
		var raio := 1.55 + (float(extra) if extra != null else 0.0)
		if d.length() < raio and (d.length() < 0.5 or _direcao_olhar.dot(d.normalized()) > -0.2):
			alvo.levar_dano(dano_ataque, d.normalized() if d.length() > 0.01 else _direcao_olhar)


## Malha em meia-lua do rastro do golpe (criada uma vez, por código).
func _criar_rastro() -> void:
	if _visual == null:
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 24
	var ini := -1.7
	var fim := 1.5
	for i in n:
		var a0 := lerpf(ini, fim, float(i) / n)
		var a1 := lerpf(ini, fim, float(i + 1) / n)
		var f0 := float(i) / n
		var f1 := float(i + 1) / n
		var p0i := Vector3(sin(a0), 0, cos(a0)) * 0.55
		var p0e := Vector3(sin(a0), 0, cos(a0)) * 1.15
		var p1i := Vector3(sin(a1), 0, cos(a1)) * 0.55
		var p1e := Vector3(sin(a1), 0, cos(a1)) * 1.15
		for par in [[p0i, f0], [p0e, f0], [p1e, f1], [p0i, f0], [p1e, f1], [p1i, f1]]:
			st.set_color(Color(1, 1, 1, par[1] * par[1]))
			st.add_vertex(par[0])
	_rastro = MeshInstance3D.new()
	_rastro.name = "Rastro"
	_rastro.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(0.82, 0.92, 1.0, 0.0)
	_rastro.material_override = mat
	_rastro.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rastro.position = Vector3(0, 0.45, 0)
	_rastro.visible = false
	_visual.add_child(_rastro)


func _interagir() -> void:
	var melhor: Node3D = null
	var menor := alcance_interacao
	for n in get_tree().get_nodes_in_group("interagivel"):
		var obj := n as Node3D
		if obj == null:
			continue
		var d := obj.global_position.distance_to(global_position)
		if d < menor:
			menor = d
			melhor = obj
	if melhor and melhor.has_method("interagir"):
		melhor.interagir(self)


# --------------------------------------------------------------------------
func levar_dano(quantidade: int, direcao: Vector3 = Vector3.ZERO) -> void:
	if _invulneravel > 0.0 or vida <= 0:
		return
	vida = max(vida - quantidade, 0)
	_invulneravel = 1.0
	vida_mudou.emit(vida, vida_maxima)
	if direcao != Vector3.ZERO:
		var d := Vector3(direcao.x, 0, direcao.z).normalized()
		_empurrao = d * forca_empurrao
	if vida == 0:
		_controle_ativo = false
		var jogo := get_tree().get_first_node_in_group("jogo")
		if jogo:
			jogo.jogador_morreu()


func curar(quantidade: int) -> void:
	vida = mini(vida + quantidade, vida_maxima)
	vida_mudou.emit(vida, vida_maxima)


func renascer(posicao: Vector3) -> void:
	global_position = posicao
	velocity = Vector3.ZERO
	_empurrao = Vector3.ZERO
	vida = vida_maxima
	_invulneravel = 1.5
	_controle_ativo = true
	vida_mudou.emit(vida, vida_maxima)


## Rede de segurança: se algo empurrar o Teseu para fora do mapa,
## ele volta ao último checkpoint sem gastar o novelo.
func _resgatar_do_vazio() -> void:
	var jogo := get_tree().get_first_node_in_group("jogo")
	global_position = jogo.checkpoint if jogo else Vector3(0, 1, 0)
	velocity = Vector3.ZERO
	_empurrao = Vector3.ZERO
	_invulneravel = 1.0


## O novelo na cabeça encolhe conforme as voltas acabam.
func _atualizar_novelo(restante: int, instantaneo := false) -> void:
	if _novelo == null:
		return
	var jogo := get_tree().get_first_node_in_group("jogo")
	var total: int = jogo.novelo_inicial if jogo else 3
	var alvo := Vector3.ONE * (0.35 + 0.65 * float(restante) / float(max(total, 1)))
	if restante <= 0:
		alvo = Vector3.ONE * 0.01
	if instantaneo:
		_novelo.scale = alvo
		return
	var tw := create_tween()
	tw.tween_property(_novelo, "scale", alvo * 1.3, 0.12)
	tw.tween_property(_novelo, "scale", alvo, 0.25).set_trans(Tween.TRANS_BACK)
