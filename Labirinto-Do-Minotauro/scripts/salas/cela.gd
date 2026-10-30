class_name Cela
extends Node3D
## Cela com jovens atenienses. A grade desce para dentro do chão ao abrir
## e os prisioneiros comemoram e saem.

@export_range(1, 7) var quantidade_prisioneiros: int = 4
@export var cena_prisioneiro: PackedScene
## Moças e rapazes se alternam na cela (7 + 7 no total, menos o Teseu).
@export var cena_prisioneira: PackedScene
@export var cores_tunica: Array[Color] = [
	Color("#f4ecd8"), Color("#9cc5e8"), Color("#e8a3a3"), Color("#b9d99a"),
	Color("#f2d27a"), Color("#c9a8e0"), Color("#f0b98a"),
]

var aberta := false
var _prisioneiros: Array[Node3D] = []
var _grade: Node3D
var _bloqueio: CollisionShape3D


func _ready() -> void:
	add_to_group("cela")
	_grade = find_child("Grade", true, false) as Node3D
	_bloqueio = find_child("BloqueioGrade", true, false) as CollisionShape3D
	_criar_prisioneiros()


func _criar_prisioneiros() -> void:
	if cena_prisioneiro == null:
		return
	var n := quantidade_prisioneiros
	for i in n:
		var cena := cena_prisioneira if i % 2 == 1 and cena_prisioneira else cena_prisioneiro
		var p := cena.instantiate() as Node3D
		add_child(p)
		# Distribui na largura da cela (2,5 m), em duas fileiras.
		var x := -1.0 + 2.0 * (float(i) / maxi(n - 1, 1))
		var z := -0.55 if i % 2 == 0 else -0.95
		p.position = Vector3(x, 0.05, z)
		if p.has_method("definir_cor"):
			p.definir_cor(cores_tunica[i % cores_tunica.size()])
		_prisioneiros.append(p)


## Abre a cela e devolve quantos prisioneiros foram libertados.
func abrir() -> int:
	if aberta:
		return 0
	aberta = true
	if _bloqueio:
		_bloqueio.set_deferred("disabled", true)
	Som.tocar("grade", 2.0, 0.0, 0.8)
	if _grade:
		var tw := create_tween()
		tw.tween_property(_grade, "position:y", -1.8, 0.9).set_trans(Tween.TRANS_SINE)
	for i in _prisioneiros.size():
		var p := _prisioneiros[i]
		if p.has_method("libertar"):
			p.libertar(0.6 + i * 0.15)
	return _prisioneiros.size()
