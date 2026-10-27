class_name Prisioneiro
extends Node3D
## Jovem ateniense preso. Fica aflito na cela, comemora ao ser libertado e
## depois some (volta pelo fio de Ariadne).

var _livre := false
var _tempo := 0.0
var _fase := randf() * TAU


func definir_cor(cor: Color) -> void:
	var corpo := find_child("Corpo", true, false) as MeshInstance3D
	if corpo == null:
		return
	for i in corpo.mesh.get_surface_count():
		var mat := corpo.mesh.surface_get_material(i)
		if mat and mat.resource_name == "tunica":
			var novo := (mat as StandardMaterial3D).duplicate()
			novo.albedo_color = cor
			corpo.set_surface_override_material(i, novo)


func _process(delta: float) -> void:
	_tempo += delta
	if not _livre:
		# balança de nervoso dentro da cela
		rotation.z = sin(_tempo * 3.0 + _fase) * 0.08


func libertar(atraso: float) -> void:
	_livre = true
	rotation.z = 0
	var tw := create_tween()
	tw.tween_interval(atraso)
	for i in 3:
		tw.tween_property(self, "position:y", 0.45, 0.16).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "position:y", 0.05, 0.16).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "position:z", position.z + 1.6, 0.6)
	tw.parallel().tween_property(self, "rotation:y", PI, 0.3)
	tw.tween_property(self, "scale", Vector3.ONE * 0.01, 0.4).set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)
