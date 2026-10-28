class_name GradePorta
extends Node3D
## Grade de ferro que tranca a passagem. Anima o nó "Grade" do modelo
## e liga/desliga a colisão "Bloqueio".

@export var comeca_fechada: bool = false
@export var duracao: float = 0.5

var fechada := false
var _grade: Node3D
var _bloqueio: CollisionShape3D
var _altura_aberta := 1.6


func _ready() -> void:
	_grade = find_child("Grade", true, false) as Node3D
	_bloqueio = find_child("Bloqueio", true, false) as CollisionShape3D
	_aplicar(comeca_fechada, true)


func fechar() -> void:
	_aplicar(true)


func abrir() -> void:
	_aplicar(false)


func _aplicar(fechar_: bool, instantaneo := false) -> void:
	fechada = fechar_
	if _bloqueio:
		_bloqueio.set_deferred("disabled", not fechada)
	if _grade == null:
		return
	var y := 0.0 if fechada else _altura_aberta
	if instantaneo:
		_grade.position.y = y
	else:
		Som.tocar("grade", 0.0, 0.05, 1.0 if fechada else 1.15)
		var tw := create_tween()
		tw.tween_property(_grade, "position:y", y, duracao) \
			.set_trans(Tween.TRANS_BOUNCE if fechada else Tween.TRANS_SINE) \
			.set_ease(Tween.EASE_OUT)
