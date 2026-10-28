extends Control
## Desenho do HUD no estilo Zelda: Link's Awakening (tudo vetorial, sem imagens).
##  - corações com meio coração (canto superior esquerdo), piscando com vida baixa;
##  - novelos de Ariadne logo abaixo (cinza quando gastos);
##  - botões de item redondos (canto superior direito): espada [Espaço], ação [E]
##    e escudo [Shift] (acende enquanto o escudo está erguido);
##  - 3 "instrumentos" = enigmas resolvidos, abaixo dos botões;
##  - contador de atenienses no canto inferior direito, como as rúpias.

const VERMELHO := Color("#e8322b")
const VERMELHO_ESCURO := Color("#7a1410")
const CONTORNO := Color("#2a1210")
const VAZIO := Color("#4a3434")
const CREME := Color("#fff3d6")
const OURO := Color("#ffc94a")

var vida := 10
var vida_maxima := 10
var novelo := 3
var novelo_total := 3
var enigmas := 0
var enigmas_total := 3
var atenienses := 0
var atenienses_total := 13
var chefe_vida := 0
var chefe_maximo := 0
var chefe_ativo := false
var _chefe_mostrado := 0.0

var _tempo := 0.0
var _pulo_coracao := 0.0
var _pulo_contador := 0.0
var _pulo_enigma := 0.0
var _contador_mostrado := 0.0
var _fonte: Font
var _jogador: Node


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fonte = ThemeDB.fallback_font


func _process(delta: float) -> void:
	_tempo += delta
	_pulo_coracao = max(_pulo_coracao - delta * 3.0, 0.0)
	_pulo_contador = max(_pulo_contador - delta * 3.0, 0.0)
	_pulo_enigma = max(_pulo_enigma - delta * 1.5, 0.0)
	_contador_mostrado = move_toward(_contador_mostrado, atenienses, delta * 8.0)
	_chefe_mostrado = move_toward(_chefe_mostrado, chefe_vida, delta * 12.0)
	if _jogador == null or not is_instance_valid(_jogador):
		_jogador = get_tree().get_first_node_in_group("jogador")
	queue_redraw()


# --------------------------------------------------------------------------
func definir_vida(v: int, m: int) -> void:
	if v < vida:
		_pulo_coracao = 1.0
	vida = v
	vida_maxima = m


func definir_novelo(n: int, total: int) -> void:
	novelo = n
	novelo_total = total


func definir_enigmas(n: int, total: int) -> void:
	if n > enigmas:
		_pulo_enigma = 1.0
	enigmas = n
	enigmas_total = total


func definir_chefe(vida_atual: int, maximo: int) -> void:
	chefe_ativo = vida_atual > 0
	if chefe_maximo == 0 or vida_atual == maximo:
		_chefe_mostrado = vida_atual
	chefe_vida = vida_atual
	chefe_maximo = maximo


func definir_atenienses(n: int, total: int) -> void:
	if n > atenienses:
		_pulo_contador = 1.0
	atenienses = n
	atenienses_total = total


# --------------------------------------------------------------------------
func _draw() -> void:
	_desenhar_coracoes(Vector2(30, 30))
	_desenhar_novelos(Vector2(32, 72))
	_desenhar_itens(Vector2(size.x - 60, 52))
	_desenhar_enigmas(Vector2(size.x - 146, 140))
	_desenhar_contador(Vector2(size.x - 40, size.y - 44))
	if chefe_ativo:
		_desenhar_barra_chefe()


## Curva paramétrica do coração:  x = 16 sen³t,  y = 13 cos t − 5 cos 2t − 2 cos 3t − cos 4t
func _pontos_coracao(c: Vector2, escala: float, so_metade := false) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := 40
	for i in n + 1:
		var t := TAU * i / n
		var x := 16.0 * pow(sin(t), 3)
		var y := -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))
		if so_metade and x > 0.0:
			x = 0.0
		pts.append(c + Vector2(x, y) * escala)
	return pts


func _desenhar_coracoes(origem: Vector2) -> void:
	var total := int(ceil(vida_maxima / 2.0))
	var baixa := vida <= 2
	for i in total:
		var c := origem + Vector2(i * 38, 0)
		var meios := clampi(vida - i * 2, 0, 2)
		var e := 0.95
		if i == int((vida) / 2.0) and _pulo_coracao > 0.0:
			e += _pulo_coracao * 0.25
		if baixa and meios > 0:
			e += sin(_tempo * 10.0) * 0.06
		draw_colored_polygon(_pontos_coracao(c, e * 1.12), CONTORNO)
		draw_colored_polygon(_pontos_coracao(c, e), VAZIO)
		if meios == 2:
			draw_colored_polygon(_pontos_coracao(c, e), VERMELHO)
		elif meios == 1:
			draw_colored_polygon(_pontos_coracao(c, e, true), VERMELHO)
		if meios > 0:
			draw_circle(c + Vector2(-7, -5) * e, 3.0 * e, Color(1, 1, 1, 0.75))


func _desenhar_novelos(origem: Vector2) -> void:
	for i in novelo_total:
		var c := origem + Vector2(i * 32, 0)
		var cheio := i < novelo
		var base := Color("#c0302a") if cheio else Color("#5a4a4a")
		var fio := Color("#7e1a15") if cheio else Color("#3a3030")
		draw_circle(c, 13.0, CONTORNO)
		draw_circle(c, 11.0, base)
		for k in 3:
			draw_arc(c + Vector2(-2 + k * 2, 0), 8.0 - k * 2.0, -0.8 + k * 0.6, 1.6 + k * 0.6, 10, fio, 2.0)
		if cheio:
			# ponta solta do fio
			draw_polyline(PackedVector2Array([c + Vector2(9, 6), c + Vector2(15, 12), c + Vector2(19, 10)]), fio, 2.0)
			draw_circle(c + Vector2(-4, -5), 2.5, Color(1, 1, 1, 0.5))


func _botao(c: Vector2, tecla: String, aceso := false) -> void:
	draw_circle(c, 31.0, CONTORNO)
	draw_circle(c, 28.0, Color("#3a4f86") if aceso else Color("#1e2a4a"))
	draw_arc(c, 28.0, 0, TAU, 40, OURO if aceso else Color("#8aa0d8"), 3.5 if aceso else 2.5)
	var largura := _fonte.get_string_size(tecla, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 12
	var pos := c + Vector2(-largura / 2.0, 24)
	draw_rect(Rect2(pos, Vector2(largura, 20)), CONTORNO)
	draw_rect(Rect2(pos + Vector2(2, 2), Vector2(largura - 4, 16)), CREME)
	draw_string(_fonte, pos + Vector2(6, 15), tecla, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, CONTORNO)


func _desenhar_itens(c_espada: Vector2) -> void:
	# botão da espada [Espaço]
	_botao(c_espada, "Espaço")
	var lam := PackedVector2Array([c_espada + Vector2(-3, 8), c_espada + Vector2(-3, -16),
		c_espada + Vector2(0, -21), c_espada + Vector2(3, -16), c_espada + Vector2(3, 8)])
	draw_colored_polygon(lam, Color("#dfe6f0"))
	draw_line(c_espada + Vector2(0, -18), c_espada + Vector2(0, 6), Color("#9aa6b8"), 1.5)
	draw_rect(Rect2(c_espada + Vector2(-10, 8), Vector2(20, 4)), OURO)
	draw_rect(Rect2(c_espada + Vector2(-2, 12), Vector2(4, 8)), Color("#8a5a2b"))
	# botão de ação [E]: mão/brilho (alavanca, braseiro, espelho)
	var c := c_espada + Vector2(-78, 0)
	_botao(c, "E")
	var estrela := PackedVector2Array()
	for i in 10:
		var a := -PI / 2 + TAU * i / 10.0
		var r := 14.0 if i % 2 == 0 else 6.0
		estrela.append(c + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(estrela, OURO)
	# botão do escudo [Shift]: hoplon redondo com o "lambda" de bronze
	var ce := c_espada + Vector2(-156, 0)
	var erguido: bool = _jogador != null and bool(_jogador.get("defendendo"))
	_botao(ce, "Shift", erguido)
	var r_esc := 15.0 * (1.12 if erguido else 1.0)
	draw_circle(ce, r_esc + 2.0, CONTORNO)
	draw_circle(ce, r_esc, Color("#c98a3a"))
	draw_circle(ce, r_esc * 0.72, Color("#b8342c"))
	draw_polyline(PackedVector2Array([ce + Vector2(-6, 7), ce + Vector2(0, -7), ce + Vector2(6, 7)]), OURO, 2.5)


func _desenhar_enigmas(origem: Vector2) -> void:
	draw_string(_fonte, origem + Vector2(-6, -10), "ENIGMAS", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, CREME)
	for i in enigmas_total:
		var c := origem + Vector2(i * 34 + 12, 14)
		var feito := i < enigmas
		var e := 1.0
		if feito and i == enigmas - 1 and _pulo_enigma > 0.0:
			e += _pulo_enigma * 0.5
		draw_rect(Rect2(c - Vector2(15, 15), Vector2(30, 30)), CONTORNO)
		draw_rect(Rect2(c - Vector2(13, 13), Vector2(26, 26)), Color("#1e2a4a"))
		var d := PackedVector2Array([c + Vector2(0, -10) * e, c + Vector2(9, 0) * e,
			c + Vector2(0, 10) * e, c + Vector2(-9, 0) * e])
		draw_colored_polygon(d, OURO if feito else Color("#3a3a50"))
		if feito:
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -10) * e, c + Vector2(4, -2) * e,
				c + Vector2(-4, -2) * e]), Color(1, 1, 1, 0.6))


func _desenhar_contador(direita: Vector2) -> void:
	var texto := "%02d" % int(round(_contador_mostrado))
	var tam := 34 + int(_pulo_contador * 10)
	var largura := _fonte.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
	var total := "/%d" % atenienses_total
	var largura_total := _fonte.get_string_size(total, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	var x := direita.x - largura - largura_total - 4
	draw_string_outline(_fonte, Vector2(x, direita.y), texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, 8, CONTORNO)
	draw_string(_fonte, Vector2(x, direita.y), texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, CREME)
	draw_string_outline(_fonte, Vector2(direita.x - largura_total, direita.y), total,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 6, CONTORNO)
	draw_string(_fonte, Vector2(direita.x - largura_total, direita.y), total,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#d8c8a8"))
	# ícone: jovem ateniense (cabeça + túnica)
	var c := Vector2(x - 26, direita.y - 12)
	draw_circle(c + Vector2(0, -9), 9.0, CONTORNO)
	draw_circle(c + Vector2(0, -9), 7.0, Color("#f2c49b"))
	draw_arc(c + Vector2(0, -11), 7.0, PI, TAU, 12, Color("#4a2e1e"), 4.0)
	var tunica := PackedVector2Array([c + Vector2(-8, 14), c + Vector2(-5, 0), c + Vector2(5, 0), c + Vector2(8, 14)])
	draw_colored_polygon(tunica, CONTORNO)
	var tunica2 := PackedVector2Array([c + Vector2(-6, 12), c + Vector2(-4, 2), c + Vector2(4, 2), c + Vector2(6, 12)])
	draw_colored_polygon(tunica2, Color("#9cc5e8"))


## Barra de vida do Minotauro (no alto, ao centro).
func _desenhar_barra_chefe() -> void:
	var largura := 460.0
	var pos := Vector2((size.x - largura) / 2.0, 96)
	var nome := "MINOTAURO"
	var tw := _fonte.get_string_size(nome, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	draw_string_outline(_fonte, Vector2(size.x / 2.0 - tw / 2.0, pos.y - 6), nome, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 6, CONTORNO)
	draw_string(_fonte, Vector2(size.x / 2.0 - tw / 2.0, pos.y - 6), nome, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#ffb0a0"))
	draw_rect(Rect2(pos - Vector2(4, 4), Vector2(largura + 8, 26)), CONTORNO)
	draw_rect(Rect2(pos, Vector2(largura, 18)), Color("#3a1414"))
	var frac := clampf(_chefe_mostrado / maxf(chefe_maximo, 1), 0.0, 1.0)
	var frac_real := clampf(float(chefe_vida) / maxf(chefe_maximo, 1), 0.0, 1.0)
	draw_rect(Rect2(pos, Vector2(largura * frac, 18)), Color("#ffd27a"))   # dano recente
	draw_rect(Rect2(pos, Vector2(largura * frac_real, 18)), VERMELHO)
	draw_rect(Rect2(pos, Vector2(largura * frac_real, 6)), Color(1, 1, 1, 0.25))
	for i in range(1, 8):  # divisões
		var x := pos.x + largura * i / 8.0
		draw_line(Vector2(x, pos.y), Vector2(x, pos.y + 18), Color(0, 0, 0, 0.35), 2.0)
	# marca da fase 2 (metade)
	draw_line(Vector2(pos.x + largura / 2.0, pos.y - 4), Vector2(pos.x + largura / 2.0, pos.y + 22), OURO, 2.0)
