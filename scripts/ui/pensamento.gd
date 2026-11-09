class_name Pensamento
extends Control
## Balão de PENSAMENTO (nuvem com bolinhas até a cabeça) com uma mini-animação
## de quadrinhos dentro, feita com os pictogramas. É como o personagem
## "imagina" o plano — sem nenhuma palavra.
##
## Roteiros:
##   "missao" — Teseu anda até a cela, quebra a grade e o ateniense pula feliz;
##              depois golpeia o Minotauro, que cai tonto, e comemora (troféu).
##   "novelo" — um minitaurinho derruba o Teseu, o fio vermelho do novelo o
##              puxa de volta para a entrada e um dos 3 novelos se esvazia.
##
## Criado pelo HUD:  await hud.pensar(ariadne, "missao")

const DURACAO := {"missao": 7.2, "novelo": 5.0}
## A animação roda mais rápida que o roteiro em segundos (ritmo da cena).
const VELOCIDADE := 1.0
## Sons sincronizados com a animação: [segundo, som, volume, tom]
const SONS := {
	"missao": [[1.25, "espada", -4.0, 1.0], [1.55, "grade", -4.0, 1.1], [2.1, "cura", -4.0, 1.0],
		[4.5, "espada", -2.0, 0.9], [4.6, "acerto", -4.0, 0.8], [5.2, "impacto", -6.0, 1.0],
		[5.5, "resolvido", -6.0, 1.0]],
	"novelo": [[0.55, "dano", -4.0, 1.0], [1.4, "novelo", -4.0, 1.0], [3.0, "erro", -8.0, 1.2]],
}

var alvo: Node3D
var roteiro := "missao"
var altura := 2.0
var tamanho := Vector2(330, 170)

var _t := 0.0
var _escala := 0.0
var _proximo_som := 0
var _estilo: StyleBoxFlat


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_estilo = StyleBoxFlat.new()
	_estilo.bg_color = Color("#fff8e8")
	_estilo.set_corner_radius_all(60)
	_estilo.border_color = Color("#ffb0c8")
	_estilo.set_border_width_all(4)
	create_tween().tween_property(self, "_escala", 1.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func duracao() -> float:
	return DURACAO.get(roteiro, 5.0)


func terminou() -> bool:
	return _t >= duracao()


func fechar() -> void:
	var tw := create_tween()
	tw.tween_property(self, "_escala", 0.0, 0.2)
	tw.tween_callback(queue_free)


func _process(delta: float) -> void:
	if _escala >= 0.95:
		_t += delta * VELOCIDADE
		var sons: Array = SONS.get(roteiro, [])
		while _proximo_som < sons.size() and _t >= float(sons[_proximo_som][0]):
			var s: Array = sons[_proximo_som]
			Som.tocar(str(s[1]), float(s[2]), 0.0, float(s[3]))
			_proximo_som += 1
	queue_redraw()


# --------------------------------------------------------------------------
func _draw() -> void:
	if alvo == null or not is_instance_valid(alvo) or _escala <= 0.01:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var cabeca3 := alvo.global_position + Vector3.UP * altura
	if cam.is_position_behind(cabeca3):
		return
	var cabeca := cam.unproject_position(cabeca3)
	var tela := get_viewport_rect().size
	var tam := tamanho * _escala
	# a nuvem fica acima e um pouco ao lado da cabeça, sempre dentro da tela
	var centro := cabeca + Vector2(tam.x * 0.25, -tam.y * 0.5 - 70.0 * _escala)
	centro.x = clampf(centro.x, tam.x / 2.0 + 10.0, tela.x - tam.x / 2.0 - 10.0)
	centro.y = maxf(centro.y, tam.y / 2.0 + 10.0)
	var ret := Rect2(centro - tam / 2.0, tam)
	_nuvem(ret, cabeca)
	# área da cena: coordenadas de -1..1 (x) e -0.5..0.5 (y)
	var area := ret.grow(-tam.y * 0.12)
	match roteiro:
		"missao":
			_cena_missao(area)
		"novelo":
			_cena_novelo(area)


## Nuvem de pensamento: retângulo bem arredondado + "calombos" + 3 bolinhas.
func _nuvem(ret: Rect2, cabeca: Vector2) -> void:
	var borda := Color("#ffb0c8")
	var fundo := Color("#fff8e8")
	var n := 7
	for camada in 2:
		var cor := borda if camada == 0 else fundo
		var cresce := 4.0 if camada == 0 else 0.0
		for i in n:
			var x := lerpf(ret.position.x + ret.size.y * 0.3, ret.end.x - ret.size.y * 0.3, float(i) / (n - 1))
			draw_circle(Vector2(x, ret.position.y + ret.size.y * 0.12), ret.size.y * 0.22 + cresce, cor)
			draw_circle(Vector2(x, ret.end.y - ret.size.y * 0.12), ret.size.y * 0.22 + cresce, cor)
		if camada == 0:
			var sb := _estilo.duplicate() as StyleBoxFlat
			draw_style_box(sb, ret)
		else:
			draw_rect(ret.grow(-8.0 * _escala), fundo)
	# bolinhas até a cabeça (é isso que diz "pensamento" nos quadrinhos)
	var base := Vector2(clampf(cabeca.x, ret.position.x + 30, ret.end.x - 30), ret.end.y)
	for i in 3:
		var k := (i + 1) / 4.0
		var p := base.lerp(cabeca + Vector2(0, -8), k)
		var r := (12.0 - i * 3.5) * _escala
		draw_circle(p, r + 3.0, borda)
		draw_circle(p, r, fundo)


## Converte coordenadas da cena (-1..1, -0.5..0.5) para a tela.
func _p(area: Rect2, x: float, y: float) -> Vector2:
	return area.get_center() + Vector2(x * area.size.x / 2.0, y * area.size.y)


func _icone(nome: String, pos: Vector2, r: float, ang := 0.0, alfa := 1.0) -> void:
	if ang == 0.0:
		Pictograma.desenhar(self, nome, pos, r, alfa)
		return
	draw_set_transform(pos, ang, Vector2.ONE)
	Pictograma.desenhar(self, nome, Vector2.ZERO, r, alfa)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _k(t: float, ini: float, fim: float) -> float:
	return clampf((t - ini) / (fim - ini), 0.0, 1.0)


static func _suave(k: float) -> float:
	return k * k * (3.0 - 2.0 * k)


## Teseu andando: anda de x0 até x1 entre t0 e t1, pulinhos a cada passo.
func _teseu_andando(area: Rect2, x0: float, x1: float, t0: float, t1: float, r: float) -> Vector2:
	var k := _k(_t, t0, t1)
	var x := lerpf(x0, x1, _suave(k))
	var pulo := absf(sin(_t * 14.0)) * 0.08 if k > 0.0 and k < 1.0 else 0.0
	var pos := _p(area, x, 0.12 - pulo)
	_icone("teseu", pos, r)
	return pos


# --------------------------------------------------------------------------
# Roteiro "missao": libertar os atenienses e vencer o Minotauro
# --------------------------------------------------------------------------
func _cena_missao(area: Rect2) -> void:
	var r := area.size.y * 0.28
	if _t < 3.4:
		var alfa := 1.0 - _k(_t, 3.1, 3.4)
		# ateniense preso (balança de medo até ser solto, depois pula feliz)
		var livre := _t > 1.9
		var pulo := absf(sin(_t * 9.0)) * 0.18 if livre else 0.0
		var treme := 0.0 if livre else sin(_t * 18.0) * 0.12
		var pa := _p(area, 0.55, 0.12 - pulo)
		_icone("ateniense", pa, r * 0.9, treme, alfa)
		if livre:
			var kc := _k(_t, 2.0, 2.4)
			_icone("coracao", pa + Vector2(0, -r * (1.3 + kc * 0.3)), r * 0.45 * kc, 0.0, alfa)
		# grade da cela: sobe e some quando o Teseu quebra
		var ka := _k(_t, 1.55, 2.0)
		var choque := sin(_t * 60.0) * 3.0 if _t > 1.2 and _t < 1.55 else 0.0
		if ka < 1.0:
			var topo := _p(area, 0.55, -0.42) + Vector2(choque, -ka * area.size.y * 0.5)
			var cor := Color(0.35, 0.33, 0.4, (1.0 - ka) * alfa)
			draw_rect(Rect2(topo - Vector2(r * 1.1, 0), Vector2(r * 2.2, area.size.y * 0.84)), cor, false, 4.0)
			for i in 5:
				var x := topo.x - r * 1.1 + r * 2.2 * (i + 0.5) / 5.0
				draw_line(Vector2(x, topo.y), Vector2(x, topo.y + area.size.y * 0.84), cor, 4.0)
		# Teseu anda até a cela e golpeia a grade
		var pt := _teseu_andando(area, -0.8, 0.05, 0.2, 1.15, r)
		if _t > 1.15 and _t < 1.6:
			var g := _k(_t, 1.15, 1.45)
			_icone("espada", pt + Vector2(r * 0.9, -r * 0.2), r * 0.7, lerpf(-1.2, 0.9, g), alfa)
		return
	# --- parte 2: o Minotauro
	var alfa2 := _k(_t, 3.4, 3.7)
	var kq := _k(_t, 4.6, 5.2)
	var pm := _p(area, 0.55, 0.08)
	if kq <= 0.0:
		pm.y += sin(_t * 6.0) * 2.0
		_icone("minotauro", pm, r * 1.15, 0.0, alfa2)
	else:
		# cai de lado, girando em volta da base
		var ang := _suave(kq) * 1.4
		var base := pm + Vector2(0, r * 1.1)
		_icone("minotauro", base + Vector2(sin(ang), -cos(ang)) * r * 1.1, r * 1.15, ang, alfa2)
		_icone("estrelas", pm + Vector2(r * 0.6, -r * 0.4 - sin(_t * 5.0) * 4.0), r * 0.5)
	var pt2 := _teseu_andando(area, -0.8, 0.0, 3.6, 4.4, r)
	if _t > 4.4 and _t < 4.9:
		var g2 := _k(_t, 4.4, 4.65)
		_icone("espada", pt2 + Vector2(r * 0.9, -r * 0.2), r * 0.75, lerpf(-1.3, 1.0, g2))
		draw_arc(pt2 + Vector2(r * 0.6, 0), r * 1.2, -1.2, -1.2 + g2 * 2.0, 16, Color(1, 1, 1, 0.8 * (1.0 - g2)), 5.0)
	if _t > 5.3:
		# comemora pulando com o troféu
		var kt := _k(_t, 5.3, 5.6)
		_icone("trofeu", pt2 + Vector2(0, -r * 1.5 - absf(sin(_t * 8.0)) * 6.0), r * 0.6 * kt)


# --------------------------------------------------------------------------
# Roteiro "novelo": caiu? o fio te traz de volta (3 vezes)
# --------------------------------------------------------------------------
func _cena_novelo(area: Rect2) -> void:
	var r := area.size.y * 0.26
	# os 3 novelos no alto; um esvazia quando o fio é usado
	for i in 3:
		var vazio := i == 2 and _t > 3.0
		var e := 1.0 + (0.3 * (1.0 - _k(_t, 3.0, 3.3)) if i == 2 and _t > 3.0 else 0.0)
		_icone("novelo_vazio" if vazio else "novelo", _p(area, 0.35 + i * 0.25, -0.32), r * 0.45 * e)
	# o novelo na entrada (esquerda), de onde sai o fio
	var casa := _p(area, -0.78, 0.12)
	_icone("casa", casa, r * 0.7)
	# minitaurinho dá uma cabeçada no Teseu
	var km := _k(_t, 0.0, 0.55)
	var pm := _p(area, lerpf(0.85, 0.55, km) if _t < 0.8 else lerpf(0.55, 0.85, _k(_t, 0.8, 1.3)), 0.15)
	_icone("minitauro", pm, r * 0.8)
	# Teseu: cai (0,55 s), o fio puxa ele de volta (1,4–2,6 s) e ele levanta
	var caido := _k(_t, 0.55, 0.9) * (1.0 - _k(_t, 2.6, 2.9))
	var kp := _suave(_k(_t, 1.4, 2.6))
	var pt := _p(area, lerpf(0.25, -0.45, kp), 0.15)
	if _t > 1.2 and _t < 2.9:
		draw_line(casa + Vector2(r * 0.5, 0), pt, Color("#d0302a"), 4.0, true)
	_icone("teseu", pt, r, -1.4 * caido)
	if caido > 0.3:
		_icone("estrelas", pt + Vector2(0, -r * 1.1), r * 0.45)
	if _t > 2.9:
		_icone("certo", pt + Vector2(0, -r * 1.3), r * 0.4 * _k(_t, 2.9, 3.1))
