class_name Braseiro
extends Node3D
## Braseiro com um símbolo (sol, lua, onda, raio). Acende ao interagir.
## O símbolo aparece na estela e grande no chão, e a chama acende na cor dele.

signal aceso(braseiro: Braseiro)

const CENAS_SIMBOLO := {
	"sol": "res://assets/modelos/puzzles/simbolo_sol.glb",
	"lua": "res://assets/modelos/puzzles/simbolo_lua.glb",
	"onda": "res://assets/modelos/puzzles/simbolo_onda.glb",
	"raio": "res://assets/modelos/puzzles/simbolo_raio.glb",
}
const CORES := {
	"sol": Color("#f2c230"), "lua": Color("#6fa8ff"),
	"onda": Color("#3cc9b0"), "raio": Color("#b06cff"),
}
## A placa do .glb tem o centro 1,3 m acima da origem.
const ALTURA_PLACA := 1.3

@export_enum("sol", "lua", "onda", "raio") var simbolo: String = "sol":
	set(valor):
		simbolo = valor
		if is_inside_tree():
			_montar_simbolo()

var esta_aceso := false
var habilitado := false
var _fogo: Node3D
var _luz: OmniLight3D
var _brasas: MeshInstance3D
var _tempo := 0.0


func _ready() -> void:
	add_to_group("interagivel")
	add_to_group("braseiro")
	_fogo = find_child("Fogo", true, false) as Node3D
	_luz = find_child("Luz", true, false) as OmniLight3D
	_brasas = find_child("Brasas", true, false) as MeshInstance3D
	_montar_simbolo()
	apagar(true)


func cor() -> Color:
	return CORES.get(simbolo, Color.ORANGE)


func _montar_simbolo() -> void:
	var cena := load(CENAS_SIMBOLO[simbolo]) as PackedScene
	# placa na estela (de pé)
	var estela := find_child("SuporteSimbolo", true, false) as Node3D
	# placa deitada no chão, na frente do braseiro (lida de cima pela câmera)
	var chao := find_child("SuporteChao", true, false) as Node3D
	for suporte in [estela, chao]:
		if suporte == null or cena == null:
			continue
		for c in suporte.get_children():
			c.queue_free()
		var placa := cena.instantiate() as Node3D
		suporte.add_child(placa)
		if suporte == chao:
			placa.position = Vector3(0, -ALTURA_PLACA, 0)
	_pintar_fogo()


func _pintar_fogo() -> void:
	if _fogo == null:
		return
	var c := cor()
	for m in _fogo.find_children("*", "MeshInstance3D", true, false):
		var mat := StandardMaterial3D.new()
		var tom := c.lightened(0.45) if m.name == "ChamaDentro" else c
		mat.albedo_color = tom
		mat.emission_enabled = true
		mat.emission = tom
		mat.emission_energy_multiplier = 1.4
		(m as MeshInstance3D).material_override = mat
	if _luz:
		_luz.light_color = c


func _process(delta: float) -> void:
	if not esta_aceso:
		return
	_tempo += delta
	if _fogo:
		var s := 1.0 + sin(_tempo * 13.0) * 0.08 + sin(_tempo * 7.3) * 0.06
		_fogo.scale = Vector3(1.0, s, 1.0)
	if _luz:
		_luz.light_energy = 1.2 + sin(_tempo * 11.0) * 0.2


func interagir(_quem: Node) -> void:
	if not habilitado or esta_aceso:
		return
	acender()
	aceso.emit(self)


func acender() -> void:
	esta_aceso = true
	Som.tocar("fogo")
	if _fogo:
		_fogo.visible = true
		_fogo.scale = Vector3.ONE * 0.1
		create_tween().tween_property(_fogo, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK)
	if _luz:
		_luz.visible = true
	_cor_brasas(cor(), 1.5)


func apagar(instantaneo := false) -> void:
	esta_aceso = false
	if _luz:
		_luz.visible = false
	_cor_brasas(Color("#2e211b"), 0.0)
	if _fogo == null:
		return
	if instantaneo:
		_fogo.visible = false
	else:
		var tw := create_tween()
		tw.tween_property(_fogo, "scale", Vector3.ONE * 0.05, 0.2)
		tw.tween_callback(func(): _fogo.visible = false)


func piscar_erro() -> void:
	_cor_brasas(Color("#ff2020"), 3.0)
	await get_tree().create_timer(0.35).timeout
	if not esta_aceso:
		_cor_brasas(Color("#2e211b"), 0.0)


func _cor_brasas(c: Color, emissao: float) -> void:
	if _brasas == null:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mat.emission_enabled = emissao > 0.0
	mat.emission = c
	mat.emission_energy_multiplier = emissao
	_brasas.material_override = mat
