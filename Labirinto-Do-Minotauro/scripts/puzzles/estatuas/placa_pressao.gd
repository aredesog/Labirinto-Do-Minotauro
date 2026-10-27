class_name PlacaPressao
extends Node3D
## Placa no chão. Fica "pressionada" quando há uma estátua em cima.

signal mudou(pressionada: bool)

@export var tolerancia: float = 0.3

var pressionada := false
var _placa: Node3D
var _luz: OmniLight3D


func _ready() -> void:
	add_to_group("placa_pressao")
	_placa = find_child("Placa", true, false) as Node3D
	_luz = find_child("Brilho", true, false) as OmniLight3D
	if _luz:
		_luz.visible = false


func atualizar(estatuas: Array[Node]) -> void:
	var tem := false
	for e in estatuas:
		var d := Vector2(e.global_position.x - global_position.x, e.global_position.z - global_position.z)
		if d.length() < tolerancia:
			tem = true
			break
	if tem == pressionada:
		return
	pressionada = tem
	if _placa:
		create_tween().tween_property(_placa, "position:y", -0.05 if tem else 0.0, 0.15)
	if _luz:
		_luz.visible = tem
	mudou.emit(tem)
