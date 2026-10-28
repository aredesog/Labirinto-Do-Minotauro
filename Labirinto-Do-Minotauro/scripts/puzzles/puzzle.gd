class_name Puzzle
extends Node3D
## Base de todos os puzzles. Cada puzzle herda daqui e chama
## _concluir() quando for resolvido.

signal resolvido
signal erro

var ativo := false
var concluido := false


func _enter_tree() -> void:
	add_to_group("puzzle")


func ativar() -> void:
	ativo = true


func desativar() -> void:
	ativo = false


func resetar() -> void:
	concluido = false


func _concluir() -> void:
	if concluido:
		return
	concluido = true
	ativo = false
	Som.tocar("resolvido")
	resolvido.emit()


## Ajuda: lista os filhos (em qualquer nível) que estão num grupo.
func filhos_no_grupo(grupo: String) -> Array[Node]:
	var lista: Array[Node] = []
	for n in find_children("*", "", true, false):
		if n.is_in_group(grupo):
			lista.append(n)
	return lista
