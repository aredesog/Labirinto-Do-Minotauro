extends MultiMeshInstance3D
## O fio de Ariadne: um fio vermelho que o Teseu vai desenrolando pelo chão.
## Cada trecho é uma instância de uma caixinha fina num MultiMesh, o que
## permite milhares de trechos sem pesar.

const MAX_TRECHOS := 6000
const PASSO := 0.6        # distância mínima entre dois pontos do fio
const ALTURA := 0.04

var alvo: Node3D
var _ultimo := Vector3.INF
var _proximo := 0


func _ready() -> void:
	var caixa := BoxMesh.new()
	caixa.size = Vector3(0.07, 0.02, 1.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.1, 0.12)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	caixa.material = mat

	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = caixa
	multimesh.instance_count = MAX_TRECHOS
	multimesh.visible_instance_count = 0
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _process(_delta: float) -> void:
	if alvo == null or not alvo.vivo:
		return
	var ponto := alvo.global_position
	ponto.y = ALTURA
	if _ultimo == Vector3.INF:
		_ultimo = ponto
		return
	var trecho := ponto - _ultimo
	if trecho.length() < PASSO:
		return
	var meio := (_ultimo + ponto) / 2.0
	var base := Basis(Vector3.UP, atan2(-trecho.x, -trecho.z)) * Basis.from_scale(Vector3(1, 1, trecho.length()))
	multimesh.set_instance_transform(_proximo % MAX_TRECHOS, Transform3D(base, meio))
	_proximo += 1
	multimesh.visible_instance_count = mini(_proximo, MAX_TRECHOS)
	_ultimo = ponto


## Começa um novo pedaço de fio (ao reaparecer no checkpoint).
func cortar() -> void:
	_ultimo = Vector3.INF
