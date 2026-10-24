extends CharacterBody3D
## Minitaurinho (ou o Minotauro, com `eh_chefe = true`).
## Fica parado até a sala ser ativada; depois persegue o Teseu.
## Antes de golpear, ele "prepara" o ataque (fica mais claro), o que dá
## tempo de o jogador desviar.

signal morreu(inimigo: Node3D)

const Construtor := preload("res://scripts/construtor.gd")

const TEMPO_PREPARO := 0.45
const RECARGA_GOLPE := 1.1

var vida_max := 2
var velocidade := 2.6
var escala := 1.0
var cor := Color(0.55, 0.32, 0.18)
var eh_chefe := false

var vida := 2
var vivo := true
var acordado := false
var raio := 0.45

var _posicao_inicial := Vector3.ZERO
var _recarga := 0.0
var _preparo := -1.0
var _empurrao := Vector3.ZERO
var _piscar := 0.0
# Investida do chefe
var _tempo_ate_investida := 3.0
var _investida := 0.0
var _direcao_investida := Vector3.ZERO

var _gravidade: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _pivo: Node3D
var _forma: CollisionShape3D
var _material: StandardMaterial3D


## Chame antes de adicionar na árvore.
func configurar(p_vida: int, p_velocidade: float, p_escala: float, p_cor: Color, p_chefe := false) -> void:
	vida_max = p_vida
	velocidade = p_velocidade
	escala = p_escala
	cor = p_cor
	eh_chefe = p_chefe


func _ready() -> void:
	add_to_group("inimigos")
	_posicao_inicial = position
	vida = vida_max
	raio = 0.45 * escala

	_forma = CollisionShape3D.new()
	var capsula := CapsuleShape3D.new()
	capsula.radius = raio
	capsula.height = 1.6 * escala
	_forma.shape = capsula
	_forma.position.y = 0.8 * escala
	add_child(_forma)

	_pivo = Node3D.new()
	add_child(_pivo)

	var corpo := MeshInstance3D.new()
	var malha := CapsuleMesh.new()
	malha.radius = raio
	malha.height = 1.6 * escala
	_material = Construtor.material(cor)
	malha.material = _material
	corpo.mesh = malha
	corpo.position.y = 0.8 * escala
	_pivo.add_child(corpo)

	# Chifres, para ler como "touro" de cima.
	var cor_chifre := Color(0.95, 0.9, 0.8)
	for lado in [-1.0, 1.0]:
		Construtor.caixa(_pivo, Vector3(0.12, 0.12, 0.35) * escala,
			Vector3(lado * 0.3, 1.5, -0.15) * escala, cor_chifre, false)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravidade * delta

	var horizontal := Vector3.ZERO
	var jogador := get_tree().get_first_node_in_group("jogador")

	if vivo and acordado and jogador and jogador.vivo:
		var para: Vector3 = jogador.global_position - global_position
		para.y = 0.0
		var distancia := para.length()
		var alcance := raio + 0.4 + 0.5
		if distancia > 0.01:
			_pivo.rotation.y = atan2(-para.x, -para.z)

		if _investida > 0.0:
			# Chefe avançando em linha reta.
			_investida -= delta
			horizontal = _direcao_investida * velocidade * 3.0
			if distancia <= alcance:
				jogador.levar_dano(1)
		elif _preparo >= 0.0:
			# Parado, preparando o golpe.
			_preparo -= delta
			if _preparo < 0.0:
				if distancia <= alcance + 0.3:
					jogador.levar_dano(1)
				_recarga = RECARGA_GOLPE
				_material.albedo_color = cor
		else:
			if distancia > alcance - 0.2:
				horizontal = para / distancia * velocidade
			if distancia <= alcance and _recarga <= 0.0:
				_preparo = TEMPO_PREPARO
				_material.albedo_color = cor.lightened(0.5)
			if eh_chefe:
				_tempo_ate_investida -= delta
				if _tempo_ate_investida <= 0.0 and distancia > 3.0:
					_investida = 0.6
					_direcao_investida = para / distancia
					_tempo_ate_investida = randf_range(3.0, 5.0)

	horizontal += _empurrao
	_empurrao = _empurrao.move_toward(Vector3.ZERO, 25.0 * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	move_and_slide()

	_recarga -= delta
	if _piscar > 0.0:
		_piscar -= delta
		if _piscar <= 0.0 and _preparo < 0.0:
			_material.albedo_color = cor


func acordar() -> void:
	acordado = true


func levar_dano(quantidade: int, direcao: Vector3) -> void:
	if not vivo:
		return
	vida -= quantidade
	var forca := 3.0 if eh_chefe else 7.0
	_empurrao = direcao * forca
	_preparo = -1.0  # golpe interrompido
	_material.albedo_color = Color.WHITE
	_piscar = 0.1
	if vida <= 0:
		_morrer()


func resetar() -> void:
	vivo = true
	acordado = false
	vida = vida_max
	position = _posicao_inicial
	velocity = Vector3.ZERO
	_empurrao = Vector3.ZERO
	_preparo = -1.0
	_recarga = 0.0
	_investida = 0.0
	_tempo_ate_investida = 3.0
	_material.albedo_color = cor
	visible = true
	_forma.set_deferred("disabled", false)


func _morrer() -> void:
	vivo = false
	visible = false
	_forma.set_deferred("disabled", true)
	morreu.emit(self)
