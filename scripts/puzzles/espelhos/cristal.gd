class_name Cristal
extends StaticBody3D
## Cristal-alvo. Acende quando o feixe de luz chega até ele.

signal iluminado

var aceso := false
var _gema: MeshInstance3D
var _luz: OmniLight3D
var _tempo := 0.0


func _ready() -> void:
	add_to_group("cristal")
	_gema = find_child("Gema", true, false) as MeshInstance3D
	_luz = find_child("Luz", true, false) as OmniLight3D
	if _luz:
		_luz.visible = false


func receber_luz() -> void:
	if aceso:
		return
	aceso = true
	if _luz:
		_luz.visible = true
	if _gema:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("#bff0ff")
		mat.emission_enabled = true
		mat.emission = Color("#7fd6ff")
		mat.emission_energy_multiplier = 1.8
		_gema.material_override = mat
	iluminado.emit()


func apagar() -> void:
	aceso = false
	if _luz:
		_luz.visible = false
	if _gema:
		_gema.material_override = null


func _process(delta: float) -> void:
	if _gema:
		_tempo += delta
		_gema.rotation.y += delta * (2.0 if aceso else 0.4)
		_gema.position.y = sin(_tempo * 2.0) * (0.05 if aceso else 0.0)
