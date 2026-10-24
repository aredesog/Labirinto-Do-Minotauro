extends CanvasLayer
## Interface do protótipo: vida, novelos, salas liberadas e mensagens.

var _status: Label
var _mensagem: Label
var _ajuda: Label
var _id_mensagem := 0


func _ready() -> void:
	_status = _criar_label(22)
	_status.position = Vector2(16, 12)

	_ajuda = _criar_label(16)
	_ajuda.text = "WASD/setas: andar   Espaço/J: atacar   R: recomeçar"
	_ajuda.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 16)

	_mensagem = _criar_label(30)
	_mensagem.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_mensagem.offset_top = 60
	_mensagem.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_mensagem.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func atualizar(vida: int, vida_max: int, novelos: int, salas_limpas: int, total_salas: int) -> void:
	_status.text = "Vida: %d/%d     Novelos: %d     Salas liberadas: %d/%d" % [
		vida, vida_max, novelos, salas_limpas, total_salas]


## Mostra uma mensagem no topo. Com duracao <= 0 ela fica até ser trocada.
func mensagem(texto: String, duracao := 3.0) -> void:
	_id_mensagem += 1
	var id := _id_mensagem
	_mensagem.text = texto
	_mensagem.visible = true
	if duracao > 0.0:
		await get_tree().create_timer(duracao).timeout
		if id == _id_mensagem:
			_mensagem.visible = false


func _criar_label(tamanho_fonte: int) -> Label:
	var label := Label.new()
	var estilo := LabelSettings.new()
	estilo.font_size = tamanho_fonte
	estilo.outline_size = 6
	estilo.outline_color = Color(0, 0, 0, 0.85)
	label.label_settings = estilo
	add_child(label)
	return label
