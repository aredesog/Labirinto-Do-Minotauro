class_name PedraArremessada
extends Node3D
## Pedra jogada pelo MinitaurinhoArremessador. Anda em linha reta (com um
## pequeno arco visual) e quebra ao bater em parede, no escudo ou na espada.

## Em meios corações: 2 = um coração inteiro. O escudo bloqueia tudo.
@export var dano: int = 2
@export var duracao_max: float = 3.0

var _dir := Vector3.FORWARD
var _vel := 7.5
var _vida := 0.0
var _malha: MeshInstance3D
var _sombra: MeshInstance3D
var _quebrada := false

static var _mesh_pedra: SphereMesh
static var _mat_pedra: StandardMaterial3D
static var _mesh_sombra: QuadMesh
static var _mat_sombra: StandardMaterial3D


func _ready() -> void:
	add_to_group("projetil")
	if _mesh_pedra == null:
		_mesh_pedra = SphereMesh.new()
		_mesh_pedra.radius = 0.17
		_mesh_pedra.height = 0.3
		_mesh_pedra.radial_segments = 8
		_mesh_pedra.rings = 4
		_mat_pedra = StandardMaterial3D.new()
		_mat_pedra.albedo_color = Color("#8c8378")
		_mat_pedra.roughness = 0.9
		_mesh_sombra = QuadMesh.new()
		_mesh_sombra.size = Vector2(0.4, 0.4)
		_mat_sombra = StandardMaterial3D.new()
		_mat_sombra.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat_sombra.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat_sombra.albedo_color = Color(0, 0, 0, 0.35)
	_malha = MeshInstance3D.new()
	_malha.mesh = _mesh_pedra
	_malha.material_override = _mat_pedra
	add_child(_malha)
	# sombra no chão: ajuda a ler para onde a pedra vai (vista de cima)
	_sombra = MeshInstance3D.new()
	_sombra.mesh = _mesh_sombra
	_sombra.material_override = _mat_sombra
	_sombra.rotation_degrees = Vector3(-90, 0, 0)
	_sombra.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_sombra)


func lancar(direcao: Vector3, velocidade: float) -> void:
	_dir = direcao
	_vel = velocidade


func _physics_process(delta: float) -> void:
	if _quebrada:
		return
	_vida += delta
	if _vida > duracao_max:
		quebrar()
		return
	var antes := global_position
	var depois := antes + _dir * _vel * delta
	# bateu no cenário?
	var consulta := PhysicsRayQueryParameters3D.create(antes, depois + _dir * 0.17, 1)
	if not get_world_3d().direct_space_state.intersect_ray(consulta).is_empty():
		quebrar()
		return
	global_position = depois
	# arco visual (a posição lógica fica numa altura só)
	_malha.position.y = sin(clampf(_vida / 0.9, 0.0, 1.0) * PI) * 0.35
	_malha.rotation.x += delta * 12.0
	_sombra.global_position = Vector3(global_position.x, 0.03, global_position.z)
	# acertou o Teseu?
	var jogador := get_tree().get_first_node_in_group("jogador") as Node3D
	if jogador:
		var d := jogador.global_position + Vector3.UP * 0.6 - global_position
		d.y *= 0.5
		if d.length() < 0.55:
			jogador.levar_dano(dano, _dir, true)
			quebrar()


func quebrar() -> void:
	if _quebrada:
		return
	_quebrada = true
	remove_from_group("projetil")
	Som.tocar("pedra")
	Efeitos.estilhacos(_malha.global_position)
	queue_free()
