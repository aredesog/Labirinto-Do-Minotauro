extends Node3D
## Faz a chama e a luz da tocha tremularem.

@export var energia: float = 0.7
var _luz: OmniLight3D
var _chama: Node3D
var _t := randf() * 10.0


func _ready() -> void:
	add_to_group("tocha")
	_luz = find_child("Luz", true, false) as OmniLight3D
	_chama = find_child("Chama", true, false) as Node3D


func _process(delta: float) -> void:
	_t += delta
	var f := 1.0 + sin(_t * 17.0) * 0.06 + sin(_t * 6.1) * 0.08
	if _luz and _luz.visible:
		_luz.light_energy = energia * f
	if _chama:
		_chama.scale = Vector3(1.0, f, 1.0)
