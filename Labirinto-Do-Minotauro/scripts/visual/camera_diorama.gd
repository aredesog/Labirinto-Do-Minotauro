class_name CameraDiorama
extends Camera3D
## Câmera de cima em 3/4 (visual de maquete), no estilo Binding of Isaac:
##  - dentro de uma sala pequena, trava no centro da sala (enquadra tudo);
##  - em corredores e na arena grande, segue o Teseu.
## Também marca as salas visitadas (para o minimapa).

@export var alvo: Node3D
@export var altura: float = 12.0
@export var distancia: float = 9.5
@export var suavidade: float = 6.0
## Salas com metade do tamanho até este valor ficam com a câmera travada.
@export var travar_ate: float = 7.5

var area_atual: Node = null
var _tremor := 0.0


func _ready() -> void:
	if alvo == null:
		alvo = get_tree().get_first_node_in_group("jogador")
	if alvo:
		global_position = _posicao_desejada()
		look_at(_foco() + Vector3.UP * 0.5, Vector3.UP)


func _foco() -> Vector3:
	area_atual = null
	for a in get_tree().get_nodes_in_group("area_sala"):
		if a.contem(alvo.global_position, 0.3):
			area_atual = a
			a.visitada = true
			break
	if area_atual and area_atual.meio_tamanho.x <= travar_ate and area_atual.meio_tamanho.y <= travar_ate:
		return area_atual.global_position
	return alvo.global_position


func _posicao_desejada() -> Vector3:
	var foco := _foco()
	var zoom: float = area_atual.zoom_camera if area_atual else 1.0
	return foco + Vector3(0, altura, distancia) * zoom


## Chacoalha a câmera (golpes e investidas do Minotauro).
func tremer(forca: float) -> void:
	_tremor = maxf(_tremor, forca)


func _process(delta: float) -> void:
	if alvo == null:
		return
	global_position = global_position.lerp(_posicao_desejada(), 1.0 - exp(-suavidade * delta))
	if _tremor > 0.0:
		_tremor = maxf(_tremor - delta * 1.5, 0.0)
		global_position += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _tremor * 0.3


## Pula direto para a posição (usado ao renascer/teleportar).
func encaixar() -> void:
	if alvo:
		global_position = _posicao_desejada()
