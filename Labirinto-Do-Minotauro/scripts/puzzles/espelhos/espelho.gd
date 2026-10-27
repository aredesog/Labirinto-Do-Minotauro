class_name Espelho
extends StaticBody3D
## Espelho giratório. Cada interação gira 45°. Só a face da frente (+Z local)
## reflete; a parte de trás (bronze) bloqueia a luz.

signal girou

@export var passo_graus: float = 45.0
var habilitado := false
var rotacao_inicial: float
var _girando := false


func _ready() -> void:
	add_to_group("espelho")
	add_to_group("interagivel")
	rotacao_inicial = rotation.y


func interagir(_quem: Node) -> void:
	if not habilitado or _girando:
		return
	_girando = true
	var tw := create_tween()
	tw.tween_property(self, "rotation:y", rotation.y + deg_to_rad(passo_graus), 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		_girando = false
		girou.emit())


## Normal da face espelhada, no espaço do mundo.
func normal() -> Vector3:
	return global_basis.z.normalized()


## Devolve a direção refletida, ou Vector3.ZERO se a luz bateu atrás.
## Reflexão especular:  r = d - 2 (d · n) n
func refletir(direcao: Vector3) -> Vector3:
	var n := normal()
	if direcao.dot(n) >= 0.0:
		return Vector3.ZERO
	return (direcao - 2.0 * direcao.dot(n) * n).normalized()


func voltar_ao_inicio() -> void:
	create_tween().tween_property(self, "rotation:y", rotacao_inicial, 0.3)
