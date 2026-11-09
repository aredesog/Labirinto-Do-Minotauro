class_name PortaoMinotauro
extends Node3D
## Porta da arena. Abre quando o GerenciadorJogo chama o grupo "porta_minotauro".

var aberto := false


func _ready() -> void:
	add_to_group("porta_minotauro")


func abrir() -> void:
	if aberto:
		return
	aberto = true
	var bloqueio := find_child("Bloqueio", true, false) as CollisionShape3D
	if bloqueio:
		bloqueio.set_deferred("disabled", true)
	var esq := find_child("FolhaEsq", true, false) as Node3D
	var dir := find_child("FolhaDir", true, false) as Node3D
	var tw := create_tween().set_parallel()
	if esq:
		tw.tween_property(esq, "rotation:y", deg_to_rad(100), 1.4).set_trans(Tween.TRANS_SINE)
	if dir:
		tw.tween_property(dir, "rotation:y", deg_to_rad(-100), 1.4).set_trans(Tween.TRANS_SINE)



## Fecha atrás do Teseu quando ele entra na arena (não dá para fugir).
func fechar() -> void:
	if not aberto:
		return
	aberto = false
	var bloqueio := find_child("Bloqueio", true, false) as CollisionShape3D
	if bloqueio:
		bloqueio.set_deferred("disabled", false)
	var esq := find_child("FolhaEsq", true, false) as Node3D
	var dir := find_child("FolhaDir", true, false) as Node3D
	var tw := create_tween().set_parallel()
	if esq:
		tw.tween_property(esq, "rotation:y", 0.0, 0.9).set_trans(Tween.TRANS_BACK)
	if dir:
		tw.tween_property(dir, "rotation:y", 0.0, 0.9).set_trans(Tween.TRANS_BACK)
	Som.tocar("impacto", -4.0, 0.0, 0.7)
