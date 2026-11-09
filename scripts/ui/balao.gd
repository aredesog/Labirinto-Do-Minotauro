class_name Balao
extends Control
## Balão de fala com PICTOGRAMAS em cima de um personagem 3D (sem texto).
## Segue o personagem na tela, aparece com um "pop" e some sozinho.
## Criado pelo HUD:  await hud.balao(ariadne, ["minotauro"], 2.0)

var alvo: Node3D
var icones: Array = []
var altura := 2.0
var raio := 22.0
var cor_borda := Color("#ffc94a")

var _escala := 0.0
var _t := 0.0
var _estilo: StyleBoxFlat


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_estilo = StyleBoxFlat.new()
	_estilo.bg_color = Color("#fff8e8")
	_estilo.border_color = cor_borda
	_estilo.set_border_width_all(4)
	_estilo.set_corner_radius_all(22)
	var tw := create_tween()
	tw.tween_property(self, "_escala", 1.0, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func fechar() -> void:
	var tw := create_tween()
	tw.tween_property(self, "_escala", 0.0, 0.15)
	tw.tween_callback(queue_free)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if alvo == null or not is_instance_valid(alvo) or _escala <= 0.01:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var ponto := alvo.global_position + Vector3.UP * altura
	if cam.is_position_behind(ponto):
		return
	var base := cam.unproject_position(ponto) + Vector2(0, sin(_t * 3.0) * 3.0)
	var w := 0.0
	for nome in icones:
		w += raio * (2.0 * Pictograma.largura(str(nome)) + 0.5)
	var tam := Vector2(w + raio * 1.2, raio * 2.9) * _escala
	var ret := Rect2(base - Vector2(tam.x / 2.0, tam.y + 18.0 * _escala), tam)
	# mantém o balão dentro da tela
	var tela := get_viewport_rect().size
	ret.position.x = clampf(ret.position.x, 8.0, tela.x - ret.size.x - 8.0)
	ret.position.y = maxf(ret.position.y, 8.0)
	# rabicho apontando para o personagem
	var bx := clampf(base.x, ret.position.x + 20.0, ret.end.x - 20.0)
	var rabo := PackedVector2Array([Vector2(bx - 12 * _escala, ret.end.y - 3), Vector2(bx + 12 * _escala, ret.end.y - 3), base])
	draw_colored_polygon(rabo, cor_borda)
	draw_style_box(_estilo, ret)
	var x := ret.position.x + raio * 0.6 * _escala
	var y := ret.get_center().y
	for i in icones.size():
		var nome := str(icones[i])
		var passo := raio * (2.0 * Pictograma.largura(nome) + 0.5) * _escala
		var bob := sin(_t * 5.0 + i * 0.9) * 2.0
		Pictograma.desenhar(self, nome, Vector2(x + passo / 2.0, y + bob), raio * _escala)
		x += passo
