extends Node3D
## NPC (Ariadne): animação "parado" em ciclo; anda e arremessa o novelo
## quando o GerenciadorJogo pede (abertura e final).

var _anim: AnimBoneco
var _modelo: AnimModelo
var andando := 0.0


func _ready() -> void:
	_modelo = AnimModelo.new(self)
	if not _modelo.tem():
		_anim = AnimBoneco.new(self)


func _process(delta: float) -> void:
	if _modelo and _modelo.tem():
		_modelo.atualizar(andando)
	elif _anim:
		_anim.atualizar(delta, andando)


func tocar(nome: String, velocidade := 1.0) -> void:
	if _modelo:
		_modelo.tocar(nome, velocidade)



## Gesto de pantomima (cenas): estica e encolhe / balança, sem sair do lugar
## (a posição dela é animada pela cena, então o gesto mexe só escala e giro).
func gesto(nome: String, _dur := 1.0) -> void:
	var e0 := scale
	var tw := create_tween()
	match nome:
		"sim", "vitoria":
			for i in 2:
				tw.tween_property(self, "scale", e0 * Vector3(0.92, 1.12, 0.92), 0.12)
				tw.tween_property(self, "scale", e0 * Vector3(1.08, 0.9, 1.08), 0.1)
			tw.tween_property(self, "scale", e0, 0.15).set_trans(Tween.TRANS_BACK)
		"nao":
			var r0 := rotation.y
			for i in 3:
				tw.tween_property(self, "rotation:y", r0 + 0.35, 0.1)
				tw.tween_property(self, "rotation:y", r0 - 0.35, 0.1)
			tw.tween_property(self, "rotation:y", r0, 0.1)
		"susto":
			tw.tween_property(self, "scale", e0 * Vector3(1.1, 0.82, 1.1), 0.08)
			tw.tween_property(self, "scale", e0 * Vector3(0.9, 1.15, 0.9), 0.12)
			tw.tween_property(self, "scale", e0, 0.25).set_trans(Tween.TRANS_ELASTIC)
		_:  # "chamar": balança de um lado para o outro
			var z0 := rotation.z
			for i in 2:
				tw.tween_property(self, "rotation:z", z0 + 0.12, 0.14)
				tw.tween_property(self, "rotation:z", z0 - 0.12, 0.14)
			tw.tween_property(self, "rotation:z", z0, 0.12)
