extends CharacterBody3D
## Teseu (por enquanto, uma cápsula azul).
## WASD/setas para andar, Espaço ou J para atacar com a xiphos.

signal morreu
signal vida_mudou(vida: int)

const Construtor := preload("res://scripts/construtor.gd")

const VELOCIDADE := 5.0
const VIDA_MAX := 3
const ALCANCE_ATAQUE := 1.6
const RECARGA_ATAQUE := 0.35
const TEMPO_INVULNERAVEL := 1.0

var vida := VIDA_MAX
var vivo := true

var _recarga := 0.0
var _invulneravel := 0.0
var _direcao_olhar := Vector3.FORWARD
var _gravidade: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var _pivo: Node3D
var _corpo: MeshInstance3D
var _espada: Node3D


func _ready() -> void:
	add_to_group("jogador")

	var forma := CollisionShape3D.new()
	var capsula := CapsuleShape3D.new()
	capsula.radius = 0.4
	capsula.height = 1.8
	forma.shape = capsula
	forma.position.y = 0.9
	add_child(forma)

	# O visual fica num pivô, que gira para a direção do movimento.
	_pivo = Node3D.new()
	add_child(_pivo)

	_corpo = MeshInstance3D.new()
	var malha := CapsuleMesh.new()
	malha.radius = 0.4
	malha.height = 1.8
	malha.material = Construtor.material(Color(0.25, 0.45, 0.9))
	_corpo.mesh = malha
	_corpo.position.y = 0.9
	_pivo.add_child(_corpo)

	# "Nariz" para mostrar para onde o Teseu está olhando.
	Construtor.caixa(_pivo, Vector3(0.2, 0.2, 0.3), Vector3(0, 1.45, -0.4), Color(0.95, 0.85, 0.7), false)

	_espada = Construtor.caixa(_pivo, Vector3(0.12, 0.12, 1.0), Vector3(0.35, 1.0, -0.8), Color(0.85, 0.85, 0.9), false)
	_espada.visible = false


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravidade * delta

	var horizontal := Vector3.ZERO
	if vivo:
		var entrada := Input.get_vector("mover_esquerda", "mover_direita", "mover_frente", "mover_tras")
		horizontal = Vector3(entrada.x, 0, entrada.y) * VELOCIDADE
		if entrada.length() > 0.1:
			_direcao_olhar = Vector3(entrada.x, 0, entrada.y).normalized()
			_pivo.rotation.y = atan2(-_direcao_olhar.x, -_direcao_olhar.z)
		if Input.is_action_just_pressed("atacar") and _recarga <= 0.0:
			_atacar()

	velocity.x = horizontal.x
	velocity.z = horizontal.z
	move_and_slide()

	_recarga -= delta
	if _invulneravel > 0.0:
		_invulneravel -= delta
		# Pisca enquanto está invulnerável.
		_corpo.visible = int(_invulneravel * 12.0) % 2 == 0 or _invulneravel <= 0.0


func levar_dano(quantidade: int) -> void:
	if not vivo or _invulneravel > 0.0:
		return
	vida = maxi(vida - quantidade, 0)
	vida_mudou.emit(vida)
	_invulneravel = TEMPO_INVULNERAVEL
	if vida == 0:
		vivo = false
		_corpo.visible = true
		_pivo.rotation.x = -PI / 2.0  # "cai" no chão
		morreu.emit()


func curar() -> void:
	if vivo and vida < VIDA_MAX:
		vida = VIDA_MAX
		vida_mudou.emit(vida)


func reviver(posicao: Vector3) -> void:
	global_position = posicao
	velocity = Vector3.ZERO
	vida = VIDA_MAX
	vivo = true
	_pivo.rotation.x = 0.0
	_invulneravel = 1.5
	vida_mudou.emit(vida)


func _atacar() -> void:
	_recarga = RECARGA_ATAQUE
	_espada.visible = true
	get_tree().create_timer(0.15).timeout.connect(func(): _espada.visible = false)

	for inimigo in get_tree().get_nodes_in_group("inimigos"):
		if not inimigo.vivo:
			continue
		var para: Vector3 = inimigo.global_position - global_position
		para.y = 0.0
		var distancia := para.length()
		if distancia > ALCANCE_ATAQUE + inimigo.raio:
			continue
		# Só acerta o que está na frente (num cone de ~140°).
		if distancia > 0.01 and _direcao_olhar.dot(para / distancia) < 0.35:
			continue
		inimigo.levar_dano(1, _direcao_olhar)
