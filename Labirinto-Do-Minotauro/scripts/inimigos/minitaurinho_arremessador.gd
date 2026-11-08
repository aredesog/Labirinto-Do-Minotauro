class_name MinitaurinhoArremessador
extends Minitaurinho
## Minitaurinho que arremessa pedras: fica de longe, ergue a pedra acima da
## cabeça (aviso) e joga na direção do Teseu.
##   - A pedra é bloqueada pelo ESCUDO (Shift) e quebrada pela ESPADA.
##   - De perto ele foge, então é preciso encurralá-lo.

@export var distancia_ideal: float = 5.0
@export var tempo_mira: float = 0.6
@export var intervalo_arremesso: float = 2.6
@export var velocidade_pedra: float = 7.5

var _mirando := 0.0
var _lado := 1.0
var _pedra_mao: Node3D
var _pedra_pos := Vector3.ZERO


func _ready() -> void:
	super._ready()
	_cooldown = randf_range(1.2, 2.0)
	_lado = 1.0 if randf() < 0.5 else -1.0
	_pedra_mao = get_node_or_null("Visual/Pedra")
	if _pedra_mao:
		_pedra_pos = _pedra_mao.position


func _comportamento(dir: Vector3, distancia: float, delta: float) -> void:
	if _mirando > 0.0:
		# parado, com a pedra erguida (tremendo um pouco)
		velocity.x = 0
		velocity.z = 0
		_mirando -= delta
		if _visual:
			_visual.position.x = sin(_mirando * 60.0) * 0.03
		if _mirando <= 0.0:
			_arremessar()
		return
	var lateral := Vector3(-dir.z, 0, dir.x) * _lado
	var mov := Vector3.ZERO
	if distancia < distancia_ideal - 1.5:
		mov = -dir + lateral * 0.3       # recua
	elif distancia > distancia_ideal + 1.5:
		mov = dir                         # aproxima
	else:
		mov = lateral * 0.6               # anda de lado
	if is_on_wall():
		_lado = -_lado
	mov = mov.normalized() * velocidade * 0.85
	velocity.x = mov.x
	velocity.z = mov.z
	if _cooldown <= 0.0 and distancia < 9.0 and _linha_livre():
		_comecar_mira()


func _braco_ocupado() -> bool:
	if _mirando > 0.0 and _anim:
		_anim.posar_braco(_anim.braco_d, -2.8, get_physics_process_delta_time())
		return true
	return false


func _linha_livre() -> bool:
	var consulta := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.8,
		_alvo.global_position + Vector3.UP * 0.8, 1)
	return get_world_3d().direct_space_state.intersect_ray(consulta).is_empty()


func _comecar_mira() -> void:
	_mirando = tempo_mira
	_cooldown = intervalo_arremesso
	Som.tocar("grunhido", 2.0, 0.05, 1.25)
	if _modelo:
		_modelo.segurar("erguer")
	if _pedra_mao:
		var tw := create_tween()
		tw.tween_property(_pedra_mao, "position", Vector3(0, 1.25, 0.05), 0.2).set_trans(Tween.TRANS_BACK)
		tw.parallel().tween_property(_pedra_mao, "scale", Vector3.ONE * 1.3, 0.2)


func _arremessar() -> void:
	if _modelo:
		_modelo.tocar("arremessar", 1.4)
	if _visual:
		_visual.position = Vector3.ZERO
	if _pedra_mao:
		_pedra_mao.visible = false
		_pedra_mao.position = _pedra_pos
		_pedra_mao.scale = Vector3.ONE
		get_tree().create_timer(0.8, false).timeout.connect(func():
			if is_instance_valid(_pedra_mao):
				_pedra_mao.visible = true)
	if _alvo == null:
		return
	var origem := global_position + Vector3.UP * 1.2
	var alvo := _alvo.global_position + Vector3.UP * 0.6
	var dir := alvo - origem
	dir.y = 0
	var pedra := PedraArremessada.new()
	get_parent().add_child(pedra)
	pedra.global_position = origem
	pedra.lancar(dir.normalized(), velocidade_pedra)
	Som.tocar("arremesso")


func levar_dano(quantidade: int, direcao: Vector3 = Vector3.ZERO) -> void:
	_mirando = 0.0  # apanhar interrompe o arremesso
	if _modelo:
		_modelo.liberar()
	if _visual:
		_visual.position = Vector3.ZERO
	if _pedra_mao:
		_pedra_mao.position = _pedra_pos
		_pedra_mao.scale = Vector3.ONE
	super.levar_dano(quantidade, direcao)
