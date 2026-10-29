class_name PortaTeleporte
extends Node3D
## Porta-portal de uma sala. Fica trancada (grade fechada) até a sala ser
## vencida; aí o GerenciadorJogo sorteia um destino e o portal acende.
## O destino é SURPRESA: todos os portais têm a mesma cor e não mostram para
## onde levam. (Para depurar, ligue "revelar_destino" no Inspetor.)
## Atravessar o portal teleporta o Teseu para a sala sorteada.
##
## Orientação local: -Z aponta para fora da sala, +Z para dentro.

const CORES := {
	"puzzle": Color("#ffc94a"), "combate": Color("#ff5a3c"),
	"chefe": Color("#c070ff"), "inicio": Color("#6fe08a"),
}
const NOMES := {"puzzle": "ENIGMA", "combate": "COMBATE", "chefe": "MINOTAURO", "inicio": "SAÍDA"}

## Só para testes: mostra cor/nome do tipo da sala de destino.
@export var revelar_destino := false
const COR_NEUTRA := Color("#8fd0ff")

var destino: Node = null
var ativa := false
var _visual: MeshInstance3D
var _icone: Node3D
var _rotulo: Label3D
var _area: Area3D
var _cooldown := 0.0


func _ready() -> void:
	add_to_group("porta_sala")
	_visual = find_child("Portal", false, false) as MeshInstance3D
	_icone = find_child("Icone", false, false) as Node3D
	_rotulo = find_child("Rotulo", false, false) as Label3D
	_area = find_child("Passagem", false, false) as Area3D
	if _area:
		_area.body_entered.connect(_ao_atravessar)
	_mostrar(false)


func _process(delta: float) -> void:
	var antes := _cooldown
	_cooldown = max(_cooldown - delta, 0.0)
	# se o Teseu já estava parado dentro do portal quando ele acendeu
	if antes > 0.0 and _cooldown <= 0.0 and ativa and _area:
		for corpo in _area.get_overlapping_bodies():
			_ao_atravessar(corpo)
	if _icone and _icone.visible:
		_icone.rotation.y += delta * 2.0
		_icone.position.y = 2.35 + sin(Time.get_ticks_msec() * 0.004) * 0.08


## Posição (global) onde o Teseu aparece ao chegar por esta porta.
func entrada_global() -> Vector3:
	var m := find_child("Entrada", false, false) as Node3D
	return m.global_position if m else global_position


func definir_destino(area: Node) -> void:
	destino = area
	var tipo: String = area.tipo if area else ""
	var cor: Color = CORES.get(tipo, Color.WHITE) if revelar_destino else COR_NEUTRA
	if _visual:
		var mat := _visual.material_override as ShaderMaterial
		if mat:
			mat = mat.duplicate()
			mat.set_shader_parameter("cor", cor)
			_visual.material_override = mat
	if _rotulo:
		_rotulo.text = NOMES.get(tipo, "")
		_rotulo.modulate = cor.lightened(0.3)
	if _icone:
		for m in _icone.find_children("*", "MeshInstance3D", true, false):
			var sm := StandardMaterial3D.new()
			sm.albedo_color = cor
			sm.emission_enabled = true
			sm.emission = cor
			sm.emission_energy_multiplier = 1.2
			(m as MeshInstance3D).material_override = sm


func ativar(sim: bool) -> void:
	ativa = sim and destino != null
	_cooldown = 0.6
	_mostrar(ativa)


func _mostrar(sim: bool) -> void:
	if _visual:
		_visual.visible = sim
	for n in [_icone, _rotulo]:
		if n:
			n.visible = sim and revelar_destino


func _ao_atravessar(corpo: Node3D) -> void:
	if not ativa or _cooldown > 0.0 or not corpo.is_in_group("jogador"):
		return
	var jogo := get_tree().get_first_node_in_group("jogo")
	if jogo:
		_cooldown = 1.0
		jogo.teleportar(destino)
