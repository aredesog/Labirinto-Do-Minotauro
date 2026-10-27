class_name AreaSala
extends Node3D
## Qualquer cômodo do mapa (início, sala de puzzle, sala de combate, arena).
## As salas não são ligadas por corredores: cada porta é um portal que
## teleporta para uma sala sorteada pelo GerenciadorJogo.

@export var nome_sala: String = "Sala"
@export_enum("inicio", "puzzle", "combate", "chefe") var tipo: String = "combate"
## Metade da largura (x) e profundidade (z) do piso, em metros (para a câmera).
@export var meio_tamanho: Vector2 = Vector2(5, 5)
## Afasta a câmera nesta sala (1 = normal). A arena usa mais para enquadrar a luta.
@export var zoom_camera: float = 1.0

var visitada := false


func _enter_tree() -> void:
	add_to_group("area_sala")


func contem(pos: Vector3, folga := 0.0) -> bool:
	var p := pos - global_position
	return absf(p.x) <= meio_tamanho.x + folga and absf(p.z) <= meio_tamanho.y + folga


func portas() -> Array[Node]:
	var lista: Array[Node] = []
	for n in find_children("*", "", true, false):
		if n.is_in_group("porta_sala"):
			lista.append(n)
	return lista


## Ponto de chegada: na frente de uma porta sorteada (ou num marcador "Chegada").
func ponto_de_chegada() -> Vector3:
	var lista := portas()
	if lista.is_empty():
		var m := find_child("Chegada", true, false) as Node3D
		return m.global_position if m else global_position + Vector3.UP * 0.1
	return lista[randi() % lista.size()].entrada_global()


## Chamado logo depois do teleporte. A Sala começa o combate aqui.
func ao_chegar() -> void:
	visitada = true


## Sobrescrito pela Sala. Para o início nada precisa ser "vencido".
func esta_concluida() -> bool:
	return tipo == "inicio"
