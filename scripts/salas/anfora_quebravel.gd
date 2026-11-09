class_name AnforaQuebravel
extends StaticBody3D
## Ânfora que quebra com a espada — o "tutorial" da entrada: a tecla de
## Espaço aparece em cima dela (HUD) e o jogador aprende a atacar fazendo,
## como na primeira fase do Angry Birds, sem ler nada.

signal quebrada

var _quebrada := false


func _ready() -> void:
	add_to_group("quebravel")


func quebrar() -> void:
	if _quebrada:
		return
	_quebrada = true
	remove_from_group("quebravel")
	collision_layer = 0
	Som.tocar("pedra", 0.0, 0.12)
	Efeitos.estilhacos(global_position + Vector3.UP * 0.5)
	Efeitos.faisca(global_position + Vector3.UP * 0.6, Color(1.0, 0.85, 0.5))
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(1.3, 0.25, 1.3), 0.08)
	tw.tween_callback(queue_free)
	quebrada.emit()
