class_name Alavanca
extends Node3D
## Alavanca genérica: ao interagir, gira a haste e emite "acionada".

signal acionada

var _haste: Node3D
var _ligada := false


func _ready() -> void:
	add_to_group("interagivel")
	add_to_group("alavanca")
	_haste = find_child("Haste", true, false) as Node3D


func interagir(_quem: Node) -> void:
	_ligada = not _ligada
	if _haste:
		var alvo := deg_to_rad(30.0 if _ligada else -30.0)
		create_tween().tween_property(_haste, "rotation:x", alvo, 0.2).set_trans(Tween.TRANS_BACK)
	acionada.emit()
