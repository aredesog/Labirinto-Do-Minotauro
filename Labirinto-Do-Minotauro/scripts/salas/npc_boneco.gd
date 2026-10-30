extends Node3D
## NPC parado (Ariadne): respira e mexe a cabeça de leve.

var _anim: AnimBoneco


func _ready() -> void:
	_anim = AnimBoneco.new(self)


func _process(delta: float) -> void:
	if _anim:
		_anim.atualizar(delta, 0.0)
