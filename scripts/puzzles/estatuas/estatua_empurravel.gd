class_name EstatuaEmpurravel
extends StaticBody3D
## Estátua de touro que anda de 1 em 1 metro quando o Teseu a empurra.
## Não atravessa paredes, colunas nem outras estátuas.

signal movida(estatua: EstatuaEmpurravel)

@export var passo: float = 1.0
@export var duracao: float = 0.22

var bloqueada := true
var posicao_inicial: Vector3
var _movendo := false


func _ready() -> void:
	add_to_group("empurravel")
	add_to_group("estatua")
	posicao_inicial = position


func empurrar(direcao: Vector3) -> void:
	if bloqueada or _movendo:
		return
	var destino := global_position + direcao * passo
	if not _livre(destino):
		_tremer(direcao)
		return
	_movendo = true
	Som.tocar("arrastar")
	Efeitos.poeira(global_position, 4, 0.35)
	var tw := create_tween()
	tw.tween_property(self, "global_position", destino, duracao) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		_movendo = false
		movida.emit(self))


## Testa se a célula de destino está vazia (camada 1 = cenário e objetos sólidos).
func _livre(destino: Vector3) -> bool:
	var forma := BoxShape3D.new()
	forma.size = Vector3(0.8, 0.7, 0.8)
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = forma
	consulta.transform = Transform3D(Basis.IDENTITY, destino + Vector3.UP * 0.6)
	consulta.collision_mask = 1
	consulta.exclude = [get_rid()]
	var resultado := get_world_3d().direct_space_state.intersect_shape(consulta, 4)
	return resultado.is_empty()


func _tremer(direcao: Vector3) -> void:
	_movendo = true
	var base := global_position
	var tw := create_tween()
	tw.tween_property(self, "global_position", base + direcao * 0.06, 0.05)
	tw.tween_property(self, "global_position", base, 0.08)
	tw.tween_callback(func(): _movendo = false)


func voltar_ao_inicio() -> void:
	_movendo = true
	var tw := create_tween()
	tw.tween_property(self, "position", posicao_inicial, 0.4).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func():
		_movendo = false
		movida.emit(self))
