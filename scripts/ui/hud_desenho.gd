extends Control
## Desenho do HUD no estilo Zelda: Link's Awakening (tudo vetorial, sem imagens).
##  - corações com meio coração (canto superior esquerdo), piscando com vida baixa;
##  - novelos de Ariadne logo abaixo (cinza quando gastos);
##  - botões de item redondos (canto superior direito): espada [Espaço], ação [E]
##    e escudo [Shift] (acende enquanto o escudo está erguido);
##  - 3 "instrumentos" = enigmas resolvidos, abaixo dos botões;
##  - contador de atenienses no canto inferior direito, como as rúpias;
##  - trilha de salas (bolinhas) até a cabeça do Minotauro (sala 10);
##  - SEM TEXTO: as teclas aparecem desenhadas (Pictograma) e uma tecla [E]
##    flutua em cima do objeto que dá para usar; setas pulam em cima dos
##    portais abertos para mostrar "é por aqui".

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
var sala_numero := 0
var sala_total := 10
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
## Tutorial: as setas somem depois que o Teseu anda um pouco.
var _pos_ini: Variant = null
var _andou := false


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


func definir_sala(n: int, total: int) -> void:
	sala_numero = n
	sala_total = total


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
	if sala_numero > 0:
		_desenhar_trilha_salas(Vector2(size.x - 176, 196))
	_desenhar_contador(Vector2(size.x - 40, size.y - 44))
	if chefe_ativo:
		_desenhar_barra_chefe()
	_desenhar_dicas_no_mundo()


## Trilha de bolinhas: salas já atravessadas (cheias), a atual (pulsando) e,
## no fim, a cabeça do Minotauro. Substitui o texto "SALA 3 / 10".
func _desenhar_trilha_salas(origem: Vector2) -> void:
	var passo := 15.0
	for i in sala_total - 1:
		var c := origem + Vector2(i * passo, 0)
		var n := i + 1
		var r := 4.5
		var cor := Color("#4a3a50")
		if n < sala_numero:
			cor = CREME
		elif n == sala_numero:
			cor = OURO
			r = 6.0 + sin(_tempo * 6.0) * 1.0
		draw_circle(c, r + 1.5, CONTORNO)
		draw_circle(c, r, cor)
	var fim := origem + Vector2((sala_total - 1) * passo + 6, 0)
	var e := 1.0 + (sin(_tempo * 6.0) * 0.12 if sala_numero >= sala_total else 0.0)
	Pictograma.desenhar(self, "minotauro", fim, 11.0 * e, 1.0 if sala_numero >= sala_total - 1 else 0.6)


## Dicas desenhadas no mundo 3D (projetadas na tela):
##  - tecla [E] em cima do objeto mais perto que dá para usar;
##  - setas pulando em cima dos portais abertos da sala atual.
func _desenhar_dicas_no_mundo() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or _jogador == null or not is_instance_valid(_jogador):
		return
	if not bool(_jogador.get("_controle_ativo")):
		return
	var pj: Vector3 = _jogador.global_position
	_dicas_tutorial(cam, pj)
	# [E] no objeto usável mais perto
	var alcance: float = _jogador.get("alcance_interacao") if _jogador.get("alcance_interacao") != null else 1.4
	var melhor: Node3D = null
	var menor := alcance
	for n in get_tree().get_nodes_in_group("interagivel"):
		var obj := n as Node3D
		if obj == null or not obj.is_visible_in_tree():
			continue
		if obj.get("habilitado") == false or obj.get("esta_aceso") == true or obj.get("_girando") == true:
			continue
		var d := obj.global_position.distance_to(pj)
		if d < menor:
			menor = d
			melhor = obj
	if melhor:
		var p3 := melhor.global_position + Vector3.UP * 1.9
		if not cam.is_position_behind(p3):
			var p := cam.unproject_position(p3) + Vector2(0, -absf(sin(_tempo * 5.0)) * 8.0)
			Pictograma.desenhar(self, "tecla:E", p, 15.0)
	# setas sobre os portais abertos
	var jogo := get_tree().get_first_node_in_group("jogo")
	var area: Node = jogo.get("area_atual") if jogo else null
	if area == null or not area.has_method("portas") or bool(jogo.get("teleportando")):
		return
	# trecho de labirinto: seta dourada sobre a saída, com o enigma que espera lá
	if area.has_method("saida_global"):
		var sg: Vector3 = area.saida_global()
		var topo_s := sg + Vector3.UP * 3.4
		if Vector2(sg.x - pj.x, sg.z - pj.z).length() > 1.6 and not cam.is_position_behind(topo_s):
			var ts := cam.unproject_position(topo_s) + Vector2(0, absf(sin(_tempo * 4.0)) * 10.0)
			var seta_s := PackedVector2Array([ts + Vector2(-13, -16), ts + Vector2(13, -16), ts + Vector2(13, -2),
				ts + Vector2(22, -2), ts + Vector2(0, 18), ts + Vector2(-22, -2), ts + Vector2(-13, -2)])
			var fechada_s := seta_s.duplicate()
			fechada_s.append(seta_s[0])
			draw_colored_polygon(seta_s, Color(1.0, 0.79, 0.29, 0.95))
			draw_polyline(fechada_s, CONTORNO, 3.0, true)
			var hud := get_tree().get_first_node_in_group("hud")
			var ics: Array = hud.icones_da_sala(area.get("destino")) if hud else []
			for k in ics.size():
				Pictograma.desenhar(self, String(ics[k]), ts + Vector2((k - (ics.size() - 1) / 2.0) * 32.0, -42.0), 13.0)
	for porta in area.portas():
		if not porta.ativa:
			continue
		var pp: Vector3 = porta.global_position
		if Vector2(pp.x - pj.x, pp.z - pj.z).length() < 1.6:
			continue
		var topo := pp + Vector3.UP * 3.2
		if cam.is_position_behind(topo):
			continue
		var t := cam.unproject_position(topo) + Vector2(0, absf(sin(_tempo * 4.0 + pp.x)) * 10.0)
		var seta := PackedVector2Array([t + Vector2(-13, -16), t + Vector2(13, -16), t + Vector2(13, -2),
			t + Vector2(22, -2), t + Vector2(0, 18), t + Vector2(-22, -2), t + Vector2(-13, -2)])
		var fechada := seta.duplicate()
		fechada.append(seta[0])
		draw_colored_polygon(seta, Color(0.56, 0.82, 1.0, 0.95))
		draw_polyline(fechada, CONTORNO, 3.0, true)


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


## Botão redondo com a TECLA desenhada embaixo (Pictograma, sem palavras).
func _botao(c: Vector2, tecla: String, aceso := false) -> void:
	draw_circle(c, 31.0, CONTORNO)
	draw_circle(c, 28.0, Color("#3a4f86") if aceso else Color("#1e2a4a"))
	draw_arc(c, 28.0, 0, TAU, 40, OURO if aceso else Color("#8aa0d8"), 3.5 if aceso else 2.5)
	Pictograma.desenhar(self, tecla, c + Vector2(0, 33), 9.0)


func _desenhar_itens(c_espada: Vector2) -> void:
	# botão da espada [Espaço]
	_botao(c_espada, "tecla_espaco")
	var lam := PackedVector2Array([c_espada + Vector2(-3, 8), c_espada + Vector2(-3, -16),
		c_espada + Vector2(0, -21), c_espada + Vector2(3, -16), c_espada + Vector2(3, 8)])
	draw_colored_polygon(lam, Color("#dfe6f0"))
	draw_line(c_espada + Vector2(0, -18), c_espada + Vector2(0, 6), Color("#9aa6b8"), 1.5)
	draw_rect(Rect2(c_espada + Vector2(-10, 8), Vector2(20, 4)), OURO)
	draw_rect(Rect2(c_espada + Vector2(-2, 12), Vector2(4, 8)), Color("#8a5a2b"))
	# botão de ação [E]: mão/brilho (alavanca, braseiro, espelho)
	var c := c_espada + Vector2(-78, 0)
	_botao(c, "tecla:E")
	var estrela := PackedVector2Array()
	for i in 10:
		var a := -PI / 2 + TAU * i / 10.0
		var r := 14.0 if i % 2 == 0 else 6.0
		estrela.append(c + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(estrela, OURO)
	# botão do escudo [Shift]: hoplon redondo com o "lambda" de bronze
	var ce := c_espada + Vector2(-156, 0)
	var erguido: bool = _jogador != null and bool(_jogador.get("defendendo"))
	_botao(ce, "tecla_shift", erguido)
	var r_esc := 15.0 * (1.12 if erguido else 1.0)
	draw_circle(ce, r_esc + 2.0, CONTORNO)
	draw_circle(ce, r_esc, Color("#c98a3a"))
	draw_circle(ce, r_esc * 0.72, Color("#b8342c"))
	draw_polyline(PackedVector2Array([ce + Vector2(-6, 7), ce + Vector2(0, -7), ce + Vector2(6, 7)]), OURO, 2.5)


func _desenhar_enigmas(origem: Vector2) -> void:
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
	Pictograma.desenhar(self, "minotauro", pos + Vector2(-26, 9), 20.0)
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



## Dicas de controle que aparecem SÓ quando servem (tutorial sem texto):
##  - setas em cima do Teseu até ele andar um pouco;
##  - [Espaço] em cima da ânfora/inimigo mais perto (inimigos: só nos 3
##    primeiros acertos);
##  - [Shift][escudo] em cima do Teseu quando vem pedra e ele nunca bloqueou.
func _dicas_tutorial(cam: Camera3D, pj: Vector3) -> void:
	var bob := absf(sin(_tempo * 5.0)) * 8.0
	if not _andou:
		if _pos_ini == null:
			_pos_ini = pj
		elif pj.distance_to(_pos_ini) > 1.5:
			_andou = true
		if not _andou:
			_icone_mundo(cam, pj + Vector3.UP * 2.3, ["setas"], 20.0, bob)
	var acertos := int(_jogador.get("acertos_total")) if _jogador.get("acertos_total") != null else 99
	var alvo: Node3D = null
	var menor := 2.4
	var grupos := ["quebravel", "inimigo"] if acertos < 3 else ["quebravel"]
	for g in grupos:
		for n in get_tree().get_nodes_in_group(g):
			var o := n as Node3D
			if o == null or o.is_in_group("chefe"):
				continue
			var d := o.global_position.distance_to(pj)
			if d < menor:
				menor = d
				alvo = o
	if alvo:
		_icone_mundo(cam, alvo.global_position + Vector3.UP * 1.7, ["tecla_espaco"], 13.0, bob)
	var bloqueios := int(_jogador.get("bloqueios_total")) if _jogador.get("bloqueios_total") != null else 99
	if bloqueios == 0:
		for p in get_tree().get_nodes_in_group("projetil"):
			if (p as Node3D).global_position.distance_to(pj) < 5.5:
				_icone_mundo(cam, pj + Vector3.UP * 2.4, ["tecla_shift", "escudo"], 15.0, bob)
				break


func _icone_mundo(cam: Camera3D, p3: Vector3, nomes: Array, r: float, bob := 0.0) -> void:
	if cam.is_position_behind(p3):
		return
	var c := cam.unproject_position(p3) + Vector2(0, -bob)
	var w := 0.0
	for nome in nomes:
		w += r * (2.0 * Pictograma.largura(str(nome)) + 0.4)
	var x := c.x - w / 2.0
	for nome in nomes:
		var passo := r * (2.0 * Pictograma.largura(str(nome)) + 0.4)
		Pictograma.desenhar(self, str(nome), Vector2(x + passo / 2.0, c.y), r)
		x += passo
