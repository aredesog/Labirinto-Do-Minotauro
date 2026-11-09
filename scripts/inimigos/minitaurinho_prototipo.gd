class_name Minitaurinho
extends CharacterBody3D
## Minitaurinho provisório: persegue o Teseu e ataca de perto.
## Troque o nó "Visual" pelo .glb do minitaurinho quando estiver pronto.

signal morreu(quem: Minitaurinho)

@export var velocidade: float = 2.6
## 3 golpes de espada (o arremessador usa 2, definido na cena dele).
@export var vida: int = 3
## Tempo parado depois de surgir (dá chance ao jogador de se posicionar).
@export var espera_ao_surgir: float = 0.9
@export var dano: int = 1
@export var distancia_ataque: float = 1.1
@export var intervalo_ataque: float = 1.2

var _alvo: Node3D
var _cooldown := 0.8
var _espera := 0.0
var _atordoado := 0.0
var _morto := false

@onready var _visual: Node3D = get_node_or_null("Visual")
var _anim: AnimBoneco
## Animações de esqueleto do modelo do grupo (parado, andar, atacar, dano...).
var _modelo: AnimModelo
var _golpe := 0.0
## Cena de abertura: vira "ator" (não ataca, não conta como inimigo).
var _na_cena := false
var _correndo_cena := false
var _destino_cena := Vector3.ZERO


func _ready() -> void:
	add_to_group("inimigo")
	_alvo = get_tree().get_first_node_in_group("jogador")
	_espera = espera_ao_surgir
	if _visual:
		_anim = AnimBoneco.new(_visual)
		_modelo = AnimModelo.new(_visual)
	# surge do chão
	if _visual:
		_visual.scale = Vector3.ONE * 0.01
		create_tween().tween_property(_visual, "scale", Vector3.ONE, 0.35) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _physics_process(delta: float) -> void:
	if _morto:
		return
	if _na_cena:
		_mover_na_cena(delta)
		return
	if global_position.y < -3.0:  # caiu do mapa: conta como derrotado
		_morrer()
		return
	_cooldown = max(_cooldown - delta, 0.0)
	_atordoado = max(_atordoado - delta, 0.0)
	_espera = max(_espera - delta, 0.0)
	velocity.y = 0.0 if is_on_floor() else velocity.y - 20.0 * delta

	if _alvo == null or _atordoado > 0.0 or _espera > 0.0:
		velocity.x = move_toward(velocity.x, 0, 20 * delta)
		velocity.z = move_toward(velocity.z, 0, 20 * delta)
		move_and_slide()
		return

	var para_alvo := _alvo.global_position - global_position
	para_alvo.y = 0
	var distancia := para_alvo.length()
	var dir := para_alvo.normalized() if distancia > 0.01 else Vector3.ZERO
	if _visual and dir != Vector3.ZERO:
		_visual.rotation.y = lerp_angle(_visual.rotation.y, atan2(dir.x, dir.z), 10.0 * delta)

	_comportamento(dir, distancia, delta)
	move_and_slide()
	_animar(delta)


func _animar(delta: float) -> void:
	if _modelo and _modelo.tem():
		var hv := Vector2(velocity.x, velocity.z).length()
		_modelo.atualizar(clampf(hv / maxf(velocidade, 0.1), 0.0, 1.0))
		return
	if _anim == null:
		return
	_golpe = maxf(_golpe - delta, 0.0)
	_anim.travar_braco_d = _golpe > 0.0 or _braco_ocupado()
	if _golpe > 0.0:
		_anim.posar_braco(_anim.braco_d, -2.3 if _golpe > 0.16 else -0.3, delta, 30.0)
	var h := Vector2(velocity.x, velocity.z).length()
	_anim.atualizar(delta, clampf(h / maxf(velocidade, 0.1), 0.0, 1.0), 13.0)


## O arremessador usa o braço para erguer a pedra.
func _braco_ocupado() -> bool:
	return false


## Corpo a corpo: corre até o Teseu e dá cabeçada. (O arremessador sobrescreve.)
func _comportamento(dir: Vector3, distancia: float, _delta: float) -> void:
	if distancia > distancia_ataque * 0.85:
		velocity.x = dir.x * velocidade
		velocity.z = dir.z * velocidade
	else:
		velocity.x = 0
		velocity.z = 0
		if _cooldown <= 0.0:
			_atacar(dir)


func _atacar(dir: Vector3) -> void:
	_cooldown = intervalo_ataque
	_golpe = 0.32
	if _modelo:
		_modelo.tocar("atacar", 1.6)
	Som.tocar("grunhido", 0.0, 0.15)
	if _visual:
		var tw := create_tween()
		tw.tween_property(_visual, "position", dir * 0.35, 0.08)
		tw.tween_property(_visual, "position", Vector3.ZERO, 0.15)
	if _alvo.has_method("levar_dano"):
		_alvo.levar_dano(dano, dir)


func levar_dano(quantidade: int, direcao: Vector3 = Vector3.ZERO) -> void:
	if _morto:
		return
	vida -= quantidade
	_atordoado = 0.35
	Efeitos.piscar_branco(_visual if _visual else self)
	if _modelo:
		_modelo.tocar("dano")
	Som.tocar("acerto")
	velocity = direcao.normalized() * 6.0
	if _visual:
		var tw := create_tween()
		tw.tween_property(_visual, "scale", Vector3(1.25, 0.75, 1.25), 0.06)
		tw.tween_property(_visual, "scale", Vector3.ONE, 0.12)
	if vida <= 0:
		_morrer()


func _morrer() -> void:
	_morto = true
	remove_from_group("inimigo")
	collision_layer = 0
	morreu.emit(self)
	Som.tocar("puf")
	Efeitos.fumaca(global_position)
	var tw := create_tween()
	if _visual:
		tw.tween_property(_visual, "scale", Vector3.ONE * 0.01, 0.3).set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)



# --------------------------------------------------------------------------
# Cena de abertura: o Minotauro manda os minitaurinhos atrás do Teseu
# --------------------------------------------------------------------------
func entrar_na_cena() -> void:
	_na_cena = true
	_alvo = null
	remove_from_group("inimigo")


func correr_na_cena(destino: Vector3) -> void:
	_destino_cena = destino
	_correndo_cena = true


func _mover_na_cena(delta: float) -> void:
	velocity.y = 0.0 if is_on_floor() else velocity.y - 20.0 * delta
	var dir := Vector3.ZERO
	if _correndo_cena:
		var falta := _destino_cena - global_position
		falta.y = 0.0
		if falta.length() > 0.3:
			dir = falta.normalized()
	if _visual and dir != Vector3.ZERO:
		_visual.rotation.y = lerp_angle(_visual.rotation.y, atan2(dir.x, dir.z), 12.0 * delta)
	velocity.x = dir.x * velocidade * 1.7
	velocity.z = dir.z * velocidade * 1.7
	move_and_slide()
	_animar(delta)
