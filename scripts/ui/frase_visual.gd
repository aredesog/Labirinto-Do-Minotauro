class_name FraseVisual
extends Control
## Uma "frase" feita de pictogramas, desenhada numa linha:
##   ["portal", "seta", "diamante", "diamante", "diamante", "seta", "minotauro"]
## Use "|" para um espaço maior (separa grupos, ex.: tecla | ícone).
##
## Pode ter um painel atrás (cartão) e "pular" quando aparece. É usada nos
## avisos do HUD, no rodapé de controles, no "Como jogar" e nos botões.

@export var icones: Array = []:
	set(v):
		icones = v
		_ajustar_tamanho()
		queue_redraw()
@export var raio: float = 18.0:
	set(v):
		raio = v
		_ajustar_tamanho()
		queue_redraw()
@export var com_painel := false
@export var cor_painel := Color(0.1, 0.07, 0.12, 0.86)
## Centraliza a frase no retângulo do Control (senão alinha à esquerda).
@export var centralizar := true
## O ícone de índice "destaque" balança (ex.: o passo que está sendo mostrado).
var destaque := -1
## 0..1 — transparência do desenho (aparecer/sumir).
var alfa := 1.0:
	set(v):
		alfa = v
		queue_redraw()

var _t := 0.0
var _painel: StyleBoxFlat


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_painel = StyleBoxFlat.new()
	_painel.set_corner_radius_all(18)
	_painel.border_color = Color("#ffc94a")
	_painel.set_border_width_all(3)
	_ajustar_tamanho()


func _process(delta: float) -> void:
	_t += delta
	if destaque >= 0:
		queue_redraw()


func largura_total() -> float:
	var w := 0.0
	for nome in icones:
		w += _passo(str(nome))
	return w


func _passo(nome: String) -> float:
	if nome == "|":
		return raio * 1.4
	return raio * (2.0 * Pictograma.largura(nome) + 0.5)


func _ajustar_tamanho() -> void:
	var m := Vector2(largura_total() + (raio * 1.4 if com_painel else 0.0), raio * (2.9 if com_painel else 2.3))
	custom_minimum_size = m
	if size.x < m.x or size.y < m.y:
		size = Vector2(maxf(size.x, m.x), maxf(size.y, m.y))


func _draw() -> void:
	var w := largura_total()
	var x := (size.x - w) / 2.0 if centralizar else (raio * 0.7 if com_painel else 0.0)
	var y := size.y / 2.0
	if com_painel and _painel:
		_painel.bg_color = Color(cor_painel.r, cor_painel.g, cor_painel.b, cor_painel.a * alfa)
		_painel.border_color.a = alfa
		draw_style_box(_painel, Rect2(Vector2(x - raio * 0.7, 0), Vector2(w + raio * 1.4, size.y)))
	for i in icones.size():
		var nome := str(icones[i])
		var passo := _passo(nome)
		if nome != "|":
			var c := Vector2(x + passo / 2.0, y)
			var r := raio
			if i == destaque:
				r *= 1.15 + sin(_t * 9.0) * 0.08
				c.y -= absf(sin(_t * 6.0)) * raio * 0.25
			Pictograma.desenhar(self, nome, c, r, alfa)
		x += passo



# --------------------------------------------------------------------------
# Ajudantes: trocar o texto de botões e rótulos por pictogramas
# --------------------------------------------------------------------------
## O texto vira dica (tooltip) e o botão mostra só os ícones.
static func em_botao(b: Button, lista: Array, r := 17.0) -> FraseVisual:
	if b == null:
		return null
	if b.text != "":
		b.tooltip_text = b.text
	b.text = ""
	var f := _filho(b, lista, r)
	b.custom_minimum_size.y = maxf(b.custom_minimum_size.y, r * 2.8)
	return f


static func em_rotulo(l: Label, lista: Array, r := 22.0) -> FraseVisual:
	if l == null:
		return null
	l.text = ""
	var f := _filho(l, lista, r)
	l.custom_minimum_size.y = maxf(l.custom_minimum_size.y, r * 2.6)
	return f


static func _filho(pai: Control, lista: Array, r: float) -> FraseVisual:
	var antigo := pai.get_node_or_null("Icones")
	if antigo:
		pai.remove_child(antigo)
		antigo.queue_free()
	var f := FraseVisual.new()
	f.name = "Icones"
	f.raio = r
	f.icones = lista.duplicate()
	pai.add_child(f)
	f.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return f
