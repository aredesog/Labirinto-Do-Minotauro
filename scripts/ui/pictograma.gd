class_name Pictograma
extends RefCounted
## Pictogramas desenhados por código (vetoriais, sem imagens), no mesmo
## estilo dos corações do HUD. São a "língua" do jogo: no lugar de texto,
## o jogo mostra frases visuais como  [portal] → [◆◆◆] → [minotauro].
##
## Uso, dentro do _draw() de qualquer Control/CanvasItem:
##   Pictograma.desenhar(self, "minotauro", centro, raio)
##
## Nomes: coracao novelo novelo_vazio fio_partido diamante diamante_vazio
##   minotauro minitauro teseu ariadne ateniense cela portal espada escudo
##   estatua placa chama espelho cristal luz coluna estrelas seta mais menos
##   certo errado reiniciar casa jogar pausa navio musica som qualidade_alta
##   qualidade_baixa trofeu ajuda sair creditos olho setas tecla_espaco
##   simbolo_sol simbolo_lua simbolo_onda simbolo_raio (os 4 dos braseiros)
##   exclamacao choro usar tecla_shift tecla:<letra>  (ex.: "tecla:E", "tecla:Esc")  engrenagem voltar
##   num:<texto>  (números, ex.: "num:13/13" — algarismos são universais)
## Um nome desconhecido desenha um "?" (para achar erro de digitação).

const CONTORNO := Color("#2a1210")
const CREME := Color("#fff3d6")
const OURO := Color("#ffc94a")
const VERMELHO := Color("#e8322b")
const PELE := Color("#f2c49b")
const CABELO := Color("#4a2e1e")
const AZUL := Color("#8fd0ff")
const VERDE := Color("#5ccf6a")
const CINZA := Color("#5a4a4a")

static var _alfa := 1.0


## alfa: transparência do desenho todo (para aparecer/sumir suave).
static func desenhar(ci: CanvasItem, nome: String, c: Vector2, r: float, alfa := 1.0) -> void:
	_alfa = alfa
	if nome.begins_with("tecla:"):
		_tecla(ci, c, r, nome.substr(6), 1.0)
		_alfa = 1.0
		return
	if nome.begins_with("num:"):
		_numero(ci, c, r, nome.substr(4))
		_alfa = 1.0
		return
	match nome:
		"coracao": _coracao(ci, c, r)
		"novelo": _novelo(ci, c, r, true)
		"novelo_vazio": _novelo(ci, c, r, false)
		"fio_partido": _fio_partido(ci, c, r)
		"diamante": _diamante(ci, c, r, true)
		"diamante_vazio": _diamante(ci, c, r, false)
		"minotauro": _touro(ci, c, r, Color("#7a4a2a"), true)
		"minitauro": _touro(ci, c + Vector2(0, r * 0.1), r * 0.8, Color("#b07a48"), false)
		"teseu": _cabeca_pessoa(ci, c, r, true)
		"ariadne": _cabeca_pessoa(ci, c, r, false)
		"ateniense": _ateniense(ci, c, r)
		"cela": _cela(ci, c, r)
		"portal": _portal(ci, c, r)
		"espada": _espada(ci, c, r)
		"escudo": _escudo(ci, c, r)
		"estatua": _estatua(ci, c, r)
		"placa": _placa(ci, c, r)
		"chama": _chama(ci, c, r)
		"espelho": _espelho(ci, c, r)
		"cristal": _cristal(ci, c, r)
		"luz": _luz(ci, c, r)
		"coluna": _coluna(ci, c, r)
		"estrelas": _estrelas(ci, c, r)
		"seta": _seta(ci, c, r)
		"mais": _mais(ci, c, r, true)
		"menos": _mais(ci, c, r, false)
		"certo": _certo(ci, c, r)
		"errado": _errado(ci, c, r)
		"reiniciar": _reiniciar(ci, c, r)
		"casa": _casa(ci, c, r)
		"jogar": _jogar(ci, c, r)
		"pausa": _pausa(ci, c, r)
		"navio": _navio(ci, c, r)
		"musica": _musica(ci, c, r)
		"som": _som(ci, c, r)
		"qualidade_alta": _qualidade(ci, c, r, 3)
		"qualidade_baixa": _qualidade(ci, c, r, 1)
		"trofeu": _trofeu(ci, c, r)
		"ajuda": _ajuda(ci, c, r)
		"sair": _sair(ci, c, r)
		"creditos": _creditos(ci, c, r)
		"olho": _olho(ci, c, r)
		"setas": _setas(ci, c, r)
		"tecla_espaco": _tecla(ci, c, r, "", 2.2)
		"tecla_shift": _tecla_shift(ci, c, r)
		"engrenagem": _engrenagem(ci, c, r)
		"usar": _usar(ci, c, r)
		"exclamacao": _exclamacao(ci, c, r)
		"choro": _choro(ci, c, r)
		"simbolo_sol": _simbolo(ci, c, r, "sol")
		"simbolo_lua": _simbolo(ci, c, r, "lua")
		"simbolo_onda": _simbolo(ci, c, r, "onda")
		"simbolo_raio": _simbolo(ci, c, r, "raio")
		"voltar": _voltar(ci, c, r)
		_: _ajuda(ci, c, r)
	_alfa = 1.0


## Largura relativa (em raios) de cada pictograma — teclas largas ocupam mais.
static func largura(nome: String) -> float:
	if nome == "tecla_espaco":
		return 2.4
	if nome.begins_with("tecla:") and nome.length() > 7:
		return 1.6
	if nome == "seta":
		return 0.8
	if nome.begins_with("num:"):
		return 0.3 + 0.42 * (nome.length() - 4)
	return 1.0


# ==========================================================================
# Ajudantes
# ==========================================================================
static func _cor(cor: Color) -> Color:
	return Color(cor.r, cor.g, cor.b, cor.a * _alfa)


static func _pts(c: Vector2, r: float, lista: Array, ang := 0.0) -> PackedVector2Array:
	var p := PackedVector2Array()
	for v: Vector2 in lista:
		p.append(c + (v as Vector2).rotated(ang) * r)
	return p


static func _poly(ci: CanvasItem, c: Vector2, r: float, lista: Array, cor: Color, contorno := true, ang := 0.0) -> void:
	var p := _pts(c, r, lista, ang)
	ci.draw_colored_polygon(p, _cor(cor))
	if contorno:
		var fechado := p.duplicate()
		fechado.append(p[0])
		ci.draw_polyline(fechado, _cor(CONTORNO), maxf(r * 0.09, 1.5), true)


static func _circ(ci: CanvasItem, c: Vector2, raio: float, cor: Color, contorno := true) -> void:
	if contorno:
		ci.draw_circle(c, raio + maxf(raio * 0.12, 1.5), _cor(CONTORNO))
	ci.draw_circle(c, raio, _cor(cor))


static func _elipse(c: Vector2, rx: float, ry: float, n := 24) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		p.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return p


static func _linha(ci: CanvasItem, a: Vector2, b: Vector2, cor: Color, w: float) -> void:
	ci.draw_line(a, b, _cor(cor), w, true)


static func _estrela_pts(c: Vector2, r_ext: float, r_int: float, pontas := 5) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in pontas * 2:
		var a := -PI / 2 + PI * i / pontas
		p.append(c + Vector2(cos(a), sin(a)) * (r_ext if i % 2 == 0 else r_int))
	return p


# ==========================================================================
# Pictogramas
# ==========================================================================
## Curva paramétrica do coração (a mesma do HUD).
static func _coracao(ci: CanvasItem, c: Vector2, r: float) -> void:
	for camada: Array in [[1.14, CONTORNO], [1.0, VERMELHO]]:
		var p := PackedVector2Array()
		for i in 41:
			var t := TAU * i / 40.0
			var x := 16.0 * pow(sin(t), 3)
			var y := -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))
			p.append(c + Vector2(x, y + 1.5) * r / 17.0 * float(camada[0]))
		ci.draw_colored_polygon(p, _cor(camada[1]))
	ci.draw_circle(c + Vector2(-0.4, -0.3) * r, r * 0.16, _cor(Color(1, 1, 1, 0.7)))


static func _novelo(ci: CanvasItem, c: Vector2, r: float, cheio: bool) -> void:
	var base := Color("#c0302a") if cheio else CINZA
	var fio := Color("#7e1a15") if cheio else Color("#3a3030")
	_circ(ci, c, r * 0.8, base)
	for k in 3:
		ci.draw_arc(c + Vector2(-0.15 + k * 0.15, 0) * r, r * (0.6 - k * 0.15), -0.8 + k * 0.6, 1.6 + k * 0.6, 12, _cor(fio), maxf(r * 0.1, 1.5))
	if cheio:
		ci.draw_polyline(_pts(c, r, [Vector2(0.6, 0.45), Vector2(0.95, 0.85), Vector2(1.15, 0.7)]), _cor(fio), maxf(r * 0.1, 1.5))
		ci.draw_circle(c + Vector2(-0.3, -0.35) * r, r * 0.15, _cor(Color(1, 1, 1, 0.5)))


static func _fio_partido(ci: CanvasItem, c: Vector2, r: float) -> void:
	_novelo(ci, c + Vector2(-0.25, 0) * r, r * 0.8, false)
	var fio := _cor(Color("#c0302a"))
	ci.draw_polyline(_pts(c, r, [Vector2(0.35, 0.2), Vector2(0.6, 0.0), Vector2(0.7, 0.25)]), fio, r * 0.12)
	ci.draw_polyline(_pts(c, r, [Vector2(0.85, 0.05), Vector2(1.0, 0.3), Vector2(1.15, 0.1)]), fio, r * 0.12)


static func _diamante(ci: CanvasItem, c: Vector2, r: float, feito: bool) -> void:
	_poly(ci, c, r, [Vector2(0, -0.95), Vector2(0.7, 0), Vector2(0, 0.95), Vector2(-0.7, 0)],
		OURO if feito else Color("#3a3a50"))
	if feito:
		_poly(ci, c, r, [Vector2(0, -0.95), Vector2(0.3, -0.2), Vector2(-0.3, -0.2)], Color(1, 1, 1, 0.55), false)


## Cabeça de touro: o Minotauro (bravo, olhos vermelhos) ou um minitaurinho (fofo).
static func _touro(ci: CanvasItem, c: Vector2, r: float, cor: Color, bravo: bool) -> void:
	var osso := Color("#f2ead6")
	for lado: float in [-1.0, 1.0]:
		_poly(ci, c, r, [Vector2(0.35 * lado, -0.35), Vector2(0.85 * lado, -0.55), Vector2(1.0 * lado, -0.95),
			Vector2(0.72 * lado, -0.75), Vector2(0.4 * lado, -0.6)], osso)
	for lado: float in [-1.0, 1.0]:  # orelhas
		_poly(ci, c, r, [Vector2(0.5 * lado, -0.2), Vector2(0.95 * lado, -0.15), Vector2(0.55 * lado, 0.05)], cor)
	var cabeca := _elipse(c + Vector2(0, 0.05) * r, r * 0.6, r * 0.68)
	var borda := _elipse(c + Vector2(0, 0.05) * r, r * 0.68, r * 0.76)
	ci.draw_colored_polygon(borda, _cor(CONTORNO))
	ci.draw_colored_polygon(cabeca, _cor(cor))
	var focinho := Color("#e0a880") if not bravo else Color("#c9926a")
	ci.draw_colored_polygon(_elipse(c + Vector2(0, 0.45) * r, r * 0.42, r * 0.28), _cor(focinho))
	for lado: float in [-1.0, 1.0]:
		ci.draw_circle(c + Vector2(0.16 * lado, 0.45) * r, r * 0.07, _cor(CONTORNO))
	if bravo:
		for lado: float in [-1.0, 1.0]:
			ci.draw_circle(c + Vector2(0.26 * lado, -0.08) * r, r * 0.1, _cor(Color("#ff3a2a")))
			_linha(ci, c + Vector2(0.1 * lado, -0.12) * r, c + Vector2(0.45 * lado, -0.25) * r, CONTORNO, r * 0.1)
		ci.draw_arc(c + Vector2(0, 0.72) * r, r * 0.13, 0.2, PI - 0.2, 10, _cor(OURO), r * 0.07)
	else:
		for lado: float in [-1.0, 1.0]:
			ci.draw_circle(c + Vector2(0.24 * lado, -0.05) * r, r * 0.12, _cor(Color.WHITE))
			ci.draw_circle(c + Vector2(0.26 * lado, -0.03) * r, r * 0.07, _cor(CONTORNO))


static func _cabeca_pessoa(ci: CanvasItem, c: Vector2, r: float, e_teseu: bool) -> void:
	if not e_teseu:  # cabelo comprido atrás
		ci.draw_colored_polygon(_elipse(c + Vector2(0, 0.2) * r, r * 0.78, r * 0.8), _cor(Color("#2e1c14")))
	_circ(ci, c + Vector2(0, 0.1) * r, r * 0.62, PELE)
	var cab := CABELO if e_teseu else Color("#2e1c14")
	if e_teseu:  # cachos
		for i in 6:
			var a := PI + PI * i / 5.0
			ci.draw_circle(c + Vector2(cos(a) * 0.55, sin(a) * 0.5 - 0.05) * r, r * 0.2, _cor(cab))
		for i in 7:  # coroa de louros
			var a := PI + 0.25 + (PI - 0.5) * i / 6.0
			ci.draw_colored_polygon(_elipse(c + Vector2(cos(a) * 0.68, sin(a) * 0.62 - 0.05) * r, r * 0.12, r * 0.07, 10), _cor(OURO))
	else:
		ci.draw_arc(c + Vector2(0, 0.05) * r, r * 0.55, PI, TAU, 16, _cor(cab), r * 0.25)
		ci.draw_circle(c + Vector2(0.5, -0.35) * r, r * 0.16, _cor(Color("#ff7aa8")))  # fita
	for lado: float in [-1.0, 1.0]:
		ci.draw_circle(c + Vector2(0.22 * lado, 0.12) * r, r * 0.08, _cor(CONTORNO))
		ci.draw_circle(c + Vector2(0.36 * lado, 0.32) * r, r * 0.09, _cor(Color(1.0, 0.55, 0.55, 0.6)))
	ci.draw_arc(c + Vector2(0, 0.3) * r, r * 0.14, 0.3, PI - 0.3, 8, _cor(CONTORNO), maxf(r * 0.06, 1.2))


static func _ateniense(ci: CanvasItem, c: Vector2, r: float) -> void:
	_poly(ci, c, r, [Vector2(-0.55, 0.95), Vector2(-0.35, 0.05), Vector2(0.35, 0.05), Vector2(0.55, 0.95)], Color("#9cc5e8"))
	_circ(ci, c + Vector2(0, -0.4) * r, r * 0.4, PELE)
	ci.draw_arc(c + Vector2(0, -0.48) * r, r * 0.36, PI, TAU, 12, _cor(CABELO), r * 0.18)


static func _cela(ci: CanvasItem, c: Vector2, r: float) -> void:
	_ateniense(ci, c + Vector2(0, 0.05) * r, r * 0.8)
	ci.draw_rect(Rect2(c - Vector2(0.9, 0.9) * r, Vector2(1.8, 1.8) * r), _cor(CONTORNO), false, r * 0.14)
	for i in 4:
		var x := -0.54 + i * 0.36
		_linha(ci, c + Vector2(x, -0.9) * r, c + Vector2(x, 0.9) * r, Color("#6f6a78"), r * 0.12)


static func _portal(ci: CanvasItem, c: Vector2, r: float) -> void:
	var arco := func(raio: float) -> Array:
		var l := [Vector2(-raio, 0.95)]
		for i in 13:
			var a := PI + PI * i / 12.0
			l.append(Vector2(cos(a) * raio, -0.15 + sin(a) * raio))
		l.append(Vector2(raio, 0.95))
		return l
	_poly(ci, c, r, arco.call(0.85), Color("#9b8cb0"))
	_poly(ci, c, r, arco.call(0.58), AZUL, false)
	for k in 3:
		ci.draw_arc(c + Vector2(0, 0.25) * r, r * (0.42 - k * 0.12), k * 1.3, k * 1.3 + 3.6, 12, _cor(Color(1, 1, 1, 0.8)), maxf(r * 0.07, 1.2))


static func _espada(ci: CanvasItem, c: Vector2, r: float) -> void:
	var ang := PI / 4
	_poly(ci, c, r, [Vector2(-0.13, 0.35), Vector2(-0.13, -0.75), Vector2(0, -0.98), Vector2(0.13, -0.75), Vector2(0.13, 0.35)], Color("#dfe6f0"), true, ang)
	_poly(ci, c, r, [Vector2(-0.45, 0.35), Vector2(0.45, 0.35), Vector2(0.45, 0.5), Vector2(-0.45, 0.5)], OURO, true, ang)
	_poly(ci, c, r, [Vector2(-0.1, 0.5), Vector2(0.1, 0.5), Vector2(0.1, 0.92), Vector2(-0.1, 0.92)], Color("#8a5a2b"), true, ang)


static func _escudo(ci: CanvasItem, c: Vector2, r: float) -> void:
	_circ(ci, c, r * 0.9, Color("#c98a3a"))
	ci.draw_circle(c, r * 0.65, _cor(Color("#b8342c")))
	ci.draw_polyline(_pts(c, r, [Vector2(-0.35, 0.4), Vector2(0, -0.4), Vector2(0.35, 0.4)]), _cor(OURO), r * 0.15)


static func _estatua(ci: CanvasItem, c: Vector2, r: float) -> void:
	var pedra := Color("#a9a39a")
	_poly(ci, c, r, [Vector2(-0.9, 0.6), Vector2(0.9, 0.6), Vector2(0.9, 0.95), Vector2(-0.9, 0.95)], Color("#837d74"))
	_poly(ci, c, r, [Vector2(-0.45, -0.05), Vector2(0.75, -0.05), Vector2(0.75, 0.6), Vector2(-0.45, 0.6)], pedra)
	_circ(ci, c + Vector2(-0.45, -0.25) * r, r * 0.33, pedra)
	_poly(ci, c, r, [Vector2(-0.6, -0.5), Vector2(-0.85, -0.85), Vector2(-0.5, -0.6)], Color("#ece4d3"))
	_poly(ci, c, r, [Vector2(-0.3, -0.5), Vector2(-0.1, -0.85), Vector2(-0.2, -0.5)], Color("#ece4d3"))


static func _placa(ci: CanvasItem, c: Vector2, r: float) -> void:
	_poly(ci, c, r, [Vector2(-0.9, 0.0), Vector2(0, -0.55), Vector2(0.9, 0.0), Vector2(0, 0.55)], Color("#a8916b"))
	_poly(ci, c, r, [Vector2(-0.6, 0.0), Vector2(0, -0.37), Vector2(0.6, 0.0), Vector2(0, 0.37)], OURO, false)
	for i in 3:  # brilho subindo
		_linha(ci, c + Vector2(-0.4 + i * 0.4, -0.45) * r, c + Vector2(-0.4 + i * 0.4, -0.85) * r, Color(1, 0.9, 0.5, 0.8), r * 0.08)


static func _chama(ci: CanvasItem, c: Vector2, r: float) -> void:
	var forma := [Vector2(0, -1), Vector2(0.35, -0.45), Vector2(0.62, 0.1), Vector2(0.55, 0.55), Vector2(0.28, 0.88),
		Vector2(0, 0.95), Vector2(-0.28, 0.88), Vector2(-0.55, 0.55), Vector2(-0.62, 0.1), Vector2(-0.25, -0.3)]
	_poly(ci, c, r, forma, Color("#f2753a"))
	_poly(ci, c + Vector2(0, 0.32) * r, r * 0.55, forma, Color("#ffd04a"), false)


static func _espelho(ci: CanvasItem, c: Vector2, r: float) -> void:
	_linha(ci, c + Vector2(0, 0.5) * r, c + Vector2(0, 0.95) * r, CONTORNO, r * 0.18)
	_linha(ci, c + Vector2(-0.4, 0.95) * r, c + Vector2(0.4, 0.95) * r, CONTORNO, r * 0.18)
	var aro := _elipse(c + Vector2(0, -0.15) * r, r * 0.6, r * 0.75)
	ci.draw_colored_polygon(_elipse(c + Vector2(0, -0.15) * r, r * 0.68, r * 0.83), _cor(CONTORNO))
	ci.draw_colored_polygon(aro, _cor(Color("#c9923a")))
	ci.draw_colored_polygon(_elipse(c + Vector2(0, -0.15) * r, r * 0.46, r * 0.6), _cor(Color("#e6eaf0")))
	_linha(ci, c + Vector2(-0.2, -0.45) * r, c + Vector2(0.15, -0.1) * r, Color.WHITE, r * 0.1)


static func _cristal(ci: CanvasItem, c: Vector2, r: float) -> void:
	_poly(ci, c, r, [Vector2(0, -1), Vector2(0.5, -0.4), Vector2(0.4, 0.7), Vector2(0, 1), Vector2(-0.4, 0.7), Vector2(-0.5, -0.4)], Color("#7fd6ff"))
	_poly(ci, c, r, [Vector2(0, -1), Vector2(0.18, -0.35), Vector2(0, 0.9), Vector2(-0.18, -0.35)], Color(1, 1, 1, 0.45), false)


static func _luz(ci: CanvasItem, c: Vector2, r: float) -> void:
	for i in 8:
		var a := TAU * i / 8.0
		_linha(ci, c + Vector2(cos(a), sin(a)) * r * 0.55, c + Vector2(cos(a), sin(a)) * r * 0.95, OURO, r * 0.14)
	_circ(ci, c, r * 0.42, Color("#ffe58a"))


static func _coluna(ci: CanvasItem, c: Vector2, r: float) -> void:
	var marmore := Color("#ece4d3")
	_poly(ci, c, r, [Vector2(-0.6, -0.95), Vector2(0.6, -0.95), Vector2(0.6, -0.72), Vector2(-0.6, -0.72)], marmore)
	_poly(ci, c, r, [Vector2(-0.38, -0.72), Vector2(0.38, -0.72), Vector2(0.38, 0.72), Vector2(-0.38, 0.72)], marmore)
	_poly(ci, c, r, [Vector2(-0.6, 0.72), Vector2(0.6, 0.72), Vector2(0.6, 0.95), Vector2(-0.6, 0.95)], marmore)
	for x: float in [-0.15, 0.15]:
		_linha(ci, c + Vector2(x, -0.65) * r, c + Vector2(x, 0.65) * r, Color("#cfc5b0"), r * 0.08)


static func _estrelas(ci: CanvasItem, c: Vector2, r: float) -> void:
	for i in 3:
		var p := c + Vector2(-0.6 + i * 0.6, -0.1 + (0.25 if i == 1 else 0.0)) * r
		var e := _estrela_pts(p, r * 0.38, r * 0.16)
		ci.draw_colored_polygon(e, _cor(Color("#ffe24a")))
		var f := e.duplicate()
		f.append(e[0])
		ci.draw_polyline(f, _cor(CONTORNO), maxf(r * 0.06, 1.2))


static func _seta(ci: CanvasItem, c: Vector2, r: float) -> void:
	_poly(ci, c, r * 0.7, [Vector2(-0.8, -0.22), Vector2(0.15, -0.22), Vector2(0.15, -0.6), Vector2(0.9, 0),
		Vector2(0.15, 0.6), Vector2(0.15, 0.22), Vector2(-0.8, 0.22)], CREME)


static func _mais(ci: CanvasItem, c: Vector2, r: float, positivo: bool) -> void:
	var cor := VERDE if positivo else VERMELHO
	_linha(ci, c - Vector2(0.6, 0) * r, c + Vector2(0.6, 0) * r, CONTORNO, r * 0.42)
	_linha(ci, c - Vector2(0.55, 0) * r, c + Vector2(0.55, 0) * r, cor, r * 0.26)
	if positivo:
		_linha(ci, c - Vector2(0, 0.6) * r, c + Vector2(0, 0.6) * r, CONTORNO, r * 0.42)
		_linha(ci, c - Vector2(0, 0.55) * r, c + Vector2(0, 0.55) * r, cor, r * 0.26)


static func _certo(ci: CanvasItem, c: Vector2, r: float) -> void:
	var p := _pts(c, r, [Vector2(-0.7, 0.0), Vector2(-0.2, 0.55), Vector2(0.75, -0.6)])
	ci.draw_polyline(p, _cor(CONTORNO), r * 0.45, true)
	ci.draw_polyline(p, _cor(VERDE), r * 0.28, true)


static func _errado(ci: CanvasItem, c: Vector2, r: float) -> void:
	for d: Vector2 in [Vector2(0.62, 0.62), Vector2(0.62, -0.62)]:
		_linha(ci, c - d * r, c + d * r, CONTORNO, r * 0.45)
	for d: Vector2 in [Vector2(0.58, 0.58), Vector2(0.58, -0.58)]:
		_linha(ci, c - d * r, c + d * r, VERMELHO, r * 0.28)


static func _reiniciar(ci: CanvasItem, c: Vector2, r: float) -> void:
	ci.draw_arc(c, r * 0.6, -PI * 0.3, PI * 1.4, 24, _cor(CONTORNO), r * 0.38)
	ci.draw_arc(c, r * 0.6, -PI * 0.3, PI * 1.4, 24, _cor(CREME), r * 0.22)
	var ponta := c + Vector2(cos(-PI * 0.3), sin(-PI * 0.3)) * r * 0.6
	_poly(ci, ponta, r, [Vector2(-0.35, -0.3), Vector2(0.3, -0.25), Vector2(0.15, 0.4)], CREME)


static func _casa(ci: CanvasItem, c: Vector2, r: float) -> void:
	_poly(ci, c, r, [Vector2(-0.7, -0.05), Vector2(0.7, -0.05), Vector2(0.7, 0.9), Vector2(-0.7, 0.9)], Color("#ece4d3"))
	_poly(ci, c, r, [Vector2(-0.95, 0.0), Vector2(0, -0.9), Vector2(0.95, 0.0)], Color("#c46a3a"))
	_poly(ci, c, r, [Vector2(-0.2, 0.35), Vector2(0.2, 0.35), Vector2(0.2, 0.9), Vector2(-0.2, 0.9)], Color("#8a6033"), false)


static func _jogar(ci: CanvasItem, c: Vector2, r: float) -> void:
	_poly(ci, c, r, [Vector2(-0.5, -0.8), Vector2(0.85, 0), Vector2(-0.5, 0.8)], VERDE)


static func _pausa(ci: CanvasItem, c: Vector2, r: float) -> void:
	for x: float in [-0.32, 0.32]:
		_poly(ci, c, r, [Vector2(x - 0.18, -0.75), Vector2(x + 0.18, -0.75), Vector2(x + 0.18, 0.75), Vector2(x - 0.18, 0.75)], CREME)


static func _navio(ci: CanvasItem, c: Vector2, r: float) -> void:
	_linha(ci, c + Vector2(0, -0.95) * r, c + Vector2(0, 0.35) * r, CONTORNO, r * 0.1)
	_poly(ci, c, r, [Vector2(0.06, -0.85), Vector2(0.75, 0.25), Vector2(0.06, 0.25)], CREME)
	_poly(ci, c, r, [Vector2(-0.06, -0.6), Vector2(-0.06, 0.25), Vector2(-0.55, 0.25)], Color("#e8322b"))
	_poly(ci, c, r, [Vector2(-0.95, 0.35), Vector2(0.95, 0.35), Vector2(0.6, 0.75), Vector2(-0.6, 0.75)], Color("#8a6033"))
	for i in 3:
		ci.draw_arc(c + Vector2(-0.6 + i * 0.6, 0.95) * r, r * 0.3, PI, TAU, 8, _cor(AZUL), r * 0.1)


static func _musica(ci: CanvasItem, c: Vector2, r: float) -> void:
	for x: float in [-0.45, 0.45]:
		_circ(ci, c + Vector2(x - 0.15, 0.55) * r, r * 0.25, CREME)
		_linha(ci, c + Vector2(x + 0.08, 0.55) * r, c + Vector2(x + 0.08, -0.6) * r, CONTORNO, r * 0.14)
	_linha(ci, c + Vector2(-0.37, -0.65) * r, c + Vector2(0.53, -0.8) * r, CONTORNO, r * 0.28)


static func _som(ci: CanvasItem, c: Vector2, r: float) -> void:
	_poly(ci, c, r, [Vector2(-0.85, -0.3), Vector2(-0.45, -0.3), Vector2(0.0, -0.75), Vector2(0.0, 0.75), Vector2(-0.45, 0.3), Vector2(-0.85, 0.3)], CREME)
	for k in 2:
		ci.draw_arc(c + Vector2(0.05, 0) * r, r * (0.4 + k * 0.32), -0.8, 0.8, 10, _cor(CREME), r * 0.13)


static func _qualidade(ci: CanvasItem, c: Vector2, r: float, barras: int) -> void:
	for i in 3:
		var h := 0.5 + i * 0.4
		var ligada := i < barras
		_poly(ci, c, r, [Vector2(-0.8 + i * 0.6, 0.85 - h), Vector2(-0.4 + i * 0.6, 0.85 - h),
			Vector2(-0.4 + i * 0.6, 0.85), Vector2(-0.8 + i * 0.6, 0.85)], OURO if ligada else CINZA)


static func _trofeu(ci: CanvasItem, c: Vector2, r: float) -> void:
	for lado: float in [-1.0, 1.0]:  # coroa de louros
		for i in 6:
			var a := PI / 2 + lado * (0.35 + i * 0.42)
			var p := c + Vector2(cos(a), sin(a)) * r * 0.75
			ci.draw_colored_polygon(_elipse(p, r * 0.2, r * 0.11, 10), _cor(Color("#6fae4a")))
	var e := _estrela_pts(c, r * 0.5, r * 0.22)
	ci.draw_colored_polygon(e, _cor(OURO))
	var f := e.duplicate()
	f.append(e[0])
	ci.draw_polyline(f, _cor(CONTORNO), maxf(r * 0.07, 1.2))


static func _ajuda(ci: CanvasItem, c: Vector2, r: float) -> void:
	_circ(ci, c, r * 0.85, Color("#3a4f86"))
	ci.draw_arc(c + Vector2(0, -0.2) * r, r * 0.3, PI, TAU + 0.6, 12, _cor(CREME), r * 0.18)
	_linha(ci, c + Vector2(0.12, 0.05) * r, c + Vector2(0, 0.3) * r, CREME, r * 0.18)
	ci.draw_circle(c + Vector2(0, 0.55) * r, r * 0.11, _cor(CREME))


static func _sair(ci: CanvasItem, c: Vector2, r: float) -> void:
	_poly(ci, c, r, [Vector2(-0.8, -0.9), Vector2(0.1, -0.9), Vector2(0.1, 0.9), Vector2(-0.8, 0.9)], Color("#8a6033"))
	ci.draw_circle(c + Vector2(-0.05, 0.05) * r, r * 0.08, _cor(OURO))
	_seta(ci, c + Vector2(0.45, 0) * r, r * 0.7)


static func _creditos(ci: CanvasItem, c: Vector2, r: float) -> void:
	_ateniense(ci, c + Vector2(-0.45, 0.1) * r, r * 0.7)
	_ateniense(ci, c + Vector2(0.45, 0.1) * r, r * 0.7)
	var e := _estrela_pts(c + Vector2(0, -0.7) * r, r * 0.3, r * 0.13)
	ci.draw_colored_polygon(e, _cor(OURO))


static func _olho(ci: CanvasItem, c: Vector2, r: float) -> void:
	ci.draw_colored_polygon(_elipse(c, r * 0.95, r * 0.55), _cor(CONTORNO))
	ci.draw_colored_polygon(_elipse(c, r * 0.85, r * 0.45), _cor(Color.WHITE))
	_circ(ci, c, r * 0.32, Color("#3a7ad8"), false)
	ci.draw_circle(c, r * 0.16, _cor(CONTORNO))


## Tecla do teclado. texto vazio = barra de espaço (larga).
static func _tecla(ci: CanvasItem, c: Vector2, r: float, texto: String, largura_rel: float) -> void:
	var w := r * 1.7 * (largura_rel if texto == "" else (1.0 if texto.length() <= 1 else 1.5))
	var h := r * 1.6
	var ret := Rect2(c - Vector2(w, h) / 2.0, Vector2(w, h))
	ci.draw_rect(ret.grow(maxf(r * 0.1, 1.5)), _cor(CONTORNO))
	ci.draw_rect(ret, _cor(Color("#b8ab92")))
	ci.draw_rect(Rect2(ret.position, Vector2(w, h * 0.82)), _cor(CREME))
	if texto == "":
		_linha(ci, c + Vector2(-w * 0.3, h * 0.1), c + Vector2(w * 0.3, h * 0.1), Color("#8a7a62"), maxf(r * 0.1, 1.2))
		return
	var fonte := ThemeDB.fallback_font
	var tam := int(r * (1.0 if texto.length() <= 1 else 0.7))
	var ts := fonte.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam)
	ci.draw_string(fonte, c + Vector2(-ts.x / 2.0, tam * 0.3), texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, _cor(CONTORNO))


static func _tecla_shift(ci: CanvasItem, c: Vector2, r: float) -> void:
	_tecla(ci, c, r, "", 1.3)
	var seta := [Vector2(0, -0.5), Vector2(0.4, -0.05), Vector2(0.18, -0.05), Vector2(0.18, 0.35),
		Vector2(-0.18, 0.35), Vector2(-0.18, -0.05), Vector2(-0.4, -0.05)]
	var p := _pts(c + Vector2(0, -0.05) * r, r, seta)
	var f := p.duplicate()
	f.append(p[0])
	ci.draw_polyline(f, _cor(CONTORNO), maxf(r * 0.1, 1.5), true)


## As 4 setas do teclado (ou WASD): andar.
static func _setas(ci: CanvasItem, c: Vector2, r: float) -> void:
	var s := r * 0.48
	for d: Vector2 in [Vector2(0, -1), Vector2(-1, 0), Vector2(1, 0), Vector2(0, 0)]:
		var p := c + Vector2(d.x * s * 1.15, d.y * s * 1.15 + s * 0.55)
		ci.draw_rect(Rect2(p - Vector2(s, s) / 2.0, Vector2(s, s)).grow(1.5), _cor(CONTORNO))
		ci.draw_rect(Rect2(p - Vector2(s, s) / 2.0, Vector2(s, s)), _cor(CREME))
		var dir: Vector2 = d if d != Vector2.ZERO else Vector2(0, 1)
		var tri := PackedVector2Array([p + dir * s * 0.32, p + dir.orthogonal() * s * 0.25 - dir * s * 0.15,
			p - dir.orthogonal() * s * 0.25 - dir * s * 0.15])
		ci.draw_colored_polygon(tri, _cor(CONTORNO))


static func _numero(ci: CanvasItem, c: Vector2, r: float, texto: String) -> void:
	var fonte := ThemeDB.fallback_font
	var tam := int(r * 1.5)
	var ts := fonte.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam)
	var pos := c + Vector2(-ts.x / 2.0, tam * 0.35)
	ci.draw_string_outline(fonte, pos, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, int(maxf(r * 0.35, 4.0)), _cor(CONTORNO))
	ci.draw_string(fonte, pos, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, _cor(CREME))


static func _engrenagem(ci: CanvasItem, c: Vector2, r: float) -> void:
	var p := PackedVector2Array()
	for i in 32:
		var a := TAU * i / 32.0
		var dente := (i / 2) % 2 == 0
		p.append(c + Vector2(cos(a), sin(a)) * r * (0.92 if dente else 0.7))
	var f := p.duplicate()
	f.append(p[0])
	ci.draw_colored_polygon(p, _cor(Color("#b8c0d0")))
	ci.draw_polyline(f, _cor(CONTORNO), maxf(r * 0.08, 1.5))
	_circ(ci, c, r * 0.28, Color("#3a4f86"))


static func _voltar(ci: CanvasItem, c: Vector2, r: float) -> void:
	_poly(ci, c, r * 0.8, [Vector2(0.8, -0.22), Vector2(-0.15, -0.22), Vector2(-0.15, -0.6), Vector2(-0.9, 0),
		Vector2(-0.15, 0.6), Vector2(-0.15, 0.22), Vector2(0.8, 0.22)], CREME)


## Brilho de "usar" (o mesmo do botão E do HUD).
static func _usar(ci: CanvasItem, c: Vector2, r: float) -> void:
	var e := _estrela_pts(c, r * 0.95, r * 0.4)
	ci.draw_colored_polygon(e, _cor(OURO))
	var f := e.duplicate()
	f.append(e[0])
	ci.draw_polyline(f, _cor(CONTORNO), maxf(r * 0.08, 1.5))


## Os 4 símbolos dos braseiros, nas mesmas cores das chamas (Braseiro.CORES).
static func _simbolo(ci: CanvasItem, c: Vector2, r: float, qual: String) -> void:
	var cores := {"sol": Color("#f2c230"), "lua": Color("#6fa8ff"), "onda": Color("#3cc9b0"), "raio": Color("#b06cff")}
	_circ(ci, c, r * 0.9, Color("#2e2638"))
	var cor: Color = cores.get(qual, OURO)
	match qual:
		"sol":
			for i in 8:
				var a := TAU * i / 8.0
				_linha(ci, c + Vector2(cos(a), sin(a)) * r * 0.42, c + Vector2(cos(a), sin(a)) * r * 0.72, cor, r * 0.12)
			ci.draw_circle(c, r * 0.32, _cor(cor))
		"lua":
			ci.draw_circle(c, r * 0.55, _cor(cor))
			ci.draw_circle(c + Vector2(0.25, -0.15) * r, r * 0.45, _cor(Color("#2e2638")))
		"onda":
			for k in 2:
				var pts := PackedVector2Array()
				for i in 13:
					var x := -0.6 + 1.2 * i / 12.0
					pts.append(c + Vector2(x, -0.15 + k * 0.32 + sin(x * 6.0) * 0.12) * r)
				ci.draw_polyline(pts, _cor(cor), r * 0.14, true)
		"raio":
			_poly(ci, c, r, [Vector2(0.15, -0.7), Vector2(-0.35, 0.05), Vector2(-0.02, 0.05), Vector2(-0.18, 0.7),
				Vector2(0.38, -0.12), Vector2(0.05, -0.12)], cor, false)


## "!" de alerta / pedido de socorro.
static func _exclamacao(ci: CanvasItem, c: Vector2, r: float) -> void:
	_circ(ci, c, r * 0.85, Color("#e8322b"))
	_poly(ci, c, r, [Vector2(-0.13, -0.6), Vector2(0.13, -0.6), Vector2(0.08, 0.15), Vector2(-0.08, 0.15)], CREME, false)
	ci.draw_circle(c + Vector2(0, 0.42) * r, r * 0.12, _cor(CREME))


## Carinha chorando (emoji): olhos fechados tristes, boca para baixo, lágrimas.
static func _choro(ci: CanvasItem, c: Vector2, r: float) -> void:
	_circ(ci, c, r * 0.88, Color("#ffd04a"))
	var w := maxf(r * 0.1, 1.5)
	for lado: float in [-1.0, 1.0]:
		ci.draw_arc(c + Vector2(0.32 * lado, -0.12) * r, r * 0.16, PI + 0.3, TAU - 0.3, 8, _cor(CONTORNO), w)
		_linha(ci, c + Vector2(0.18 * lado, -0.42) * r, c + Vector2(0.48 * lado, -0.32) * r, CONTORNO, w)
		ci.draw_colored_polygon(_elipse(c + Vector2(0.36 * lado, 0.22) * r, r * 0.11, r * 0.2, 12), _cor(Color("#5ab0ff")))
		ci.draw_colored_polygon(_elipse(c + Vector2(0.42 * lado, 0.58) * r, r * 0.09, r * 0.15, 12), _cor(Color("#5ab0ff")))
	ci.draw_arc(c + Vector2(0, 0.58) * r, r * 0.28, PI + 0.4, TAU - 0.4, 10, _cor(CONTORNO), w * 1.3)
