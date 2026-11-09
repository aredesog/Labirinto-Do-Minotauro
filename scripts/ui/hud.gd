extends CanvasLayer
## HUD no estilo Zelda: Link's Awakening.
##   - Desenho (hud_desenho.gd): corações, novelos, botões, enigmas, atenienses
##   - Dialogo: caixa de texto embaixo, com o texto sendo "digitado"
##     (também usada nas falas da Ariadne, com o nome de quem fala)
##   - Faixas de cinema (cena de abertura)
##   - Banner: nome da sala ao chegar
##   - Fade: tela preta do teletransporte
##   - Menu de pausa (Esc): continuar / reiniciar sala / reiniciar jogo / menu inicial
##   - Telas de vitória e de game over
##
## SEM TEXTO: tudo o que o jogador precisa saber aparece em PICTOGRAMAS
## (Pictograma / FraseVisual / Balao):
##   - aviso(): cartão com uma "frase visual" no alto da tela
##   - balao(): balão de fala sobre um personagem (abertura e final)
##   - banner da sala: ícone do tipo de sala
##   - rodapé: teclas desenhadas + o que cada uma faz
##   - pausa / vitória / game over: botões com ícones
## A caixa de diálogo antiga (texto) continua existindo, mas o jogo não a usa.

@onready var _desenho: Control = $Desenho
@onready var _dialogo: Control = $Dialogo
@onready var _texto: Label = $Dialogo/Coluna/Texto
@onready var _nome: Label = $Dialogo/Coluna/Nome
@onready var _seta: Label = $Dialogo/Seta
@onready var _banner: Label = $Banner
@onready var _fade: ColorRect = $Fade
@onready var _menu: Control = $Menu
@onready var _vitoria: Control = $Vitoria
@onready var _game_over: Control = $GameOver
@onready var _faixa_cima: ColorRect = $FaixaCima
@onready var _faixa_baixo: ColorRect = $FaixaBaixo
@onready var _ajuda: Control = $Ajuda

var _tween_msg: Tween
var _tween_banner: Tween
var _tween_aviso: Tween
var _aviso: FraseVisual
var _banner_icones: FraseVisual
var _balao_atual: Balao
## Filtro de cinema (cor, vinheta, granulação) e flash de tela.
var _cinema: ColorRect
var _mat_cinema: ShaderMaterial
var _flash: ColorRect
var _tw_cinema: Tween
var _jogo: Node
var _falando := false


func _enter_tree() -> void:
	add_to_group("hud")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_menu.visible = false
	_vitoria.visible = false
	_game_over.visible = false
	_dialogo.modulate.a = 0.0
	_seta.visible = false
	_nome.visible = false
	_banner.modulate.a = 0.0
	_fade.color.a = 0.0
	_faixa_cima.visible = false
	_faixa_baixo.visible = false
	$Vitoria/Caixa/Coluna/JogarDeNovo.pressed.connect(func(): _jogo.reiniciar_jogo())
	$Vitoria/Caixa/Coluna/MenuInicial.pressed.connect(func(): _jogo.ir_para_titulo())
	$GameOver/Caixa/Coluna/TentarDeNovo.pressed.connect(func(): _jogo.reiniciar_jogo())
	$GameOver/Caixa/Coluna/MenuInicial.pressed.connect(func(): _jogo.ir_para_titulo())
	$Menu/Caixa/Botoes/Continuar.pressed.connect(_fechar_menu)
	$Menu/Caixa/Botoes/ReiniciarSala.pressed.connect(func():
		_fechar_menu()
		_jogo.reiniciar_sala_atual())
	$Menu/Caixa/Botoes/ReiniciarJogo.pressed.connect(func(): _jogo.reiniciar_jogo())
	$Menu/Caixa/Botoes/MenuInicial.pressed.connect(func(): _jogo.ir_para_titulo())
	# som em todos os botões (mover o foco e confirmar)
	for b in find_children("*", "Button", true, false):
		(b as Button).focus_entered.connect(func(): Som.tocar("menu_mover", 0.0, 0.0))
		(b as Button).pressed.connect(func(): Som.tocar("menu_ok", 0.0, 0.0))
	_montar_pictogramas()
	_montar_cinema()
	await get_tree().process_frame
	_jogo = get_tree().get_first_node_in_group("jogo")
	if _jogo:
		_jogo.novelo_mudou.connect(func(n): _desenho.definir_novelo(n, _jogo.novelo_inicial))
		_jogo.prisioneiros_mudou.connect(_desenho.definir_atenienses)
		_jogo.puzzles_mudou.connect(_desenho.definir_enigmas)
		_jogo.mensagem.connect(mostrar_mensagem)
		_jogo.aviso_visual.connect(aviso)
		_jogo.titulo_sala.connect(mostrar_banner)
		_jogo.transicao.connect(_ao_transicionar)
		_jogo.chefe_apareceu.connect(_ao_aparecer_chefe)
		_jogo.fim_de_jogo.connect(_ao_terminar)
		_jogo.cinematica.connect(_ao_cinematica)
		_jogo.salas_mudou.connect(_desenho.definir_sala)
		_desenho.definir_novelo(_jogo.novelo, _jogo.novelo_inicial)
		_desenho.definir_atenienses(_jogo.prisioneiros_libertados, _jogo.total_prisioneiros)
		_desenho.definir_enigmas(_jogo.puzzles_concluidos.size(), _jogo.puzzles_para_abrir_arena)
	var jogador := get_tree().get_first_node_in_group("jogador")
	if jogador:
		jogador.vida_mudou.connect(_desenho.definir_vida)
		_desenho.definir_vida(jogador.vida, jogador.vida_maxima)


func _unhandled_input(evento: InputEvent) -> void:
	if not evento.is_action_pressed("pausar"):
		return
	# na cena de abertura o Esc pula a cena (quem trata é o GerenciadorJogo)
	if _jogo and (_jogo.em_cinematica or _jogo.terminou):
		return
	if _menu.visible:
		_fechar_menu()
	else:
		_menu.visible = true
		get_tree().paused = true
		$Menu/Caixa/Botoes/Continuar.grab_focus()
	get_viewport().set_input_as_handled()


func _fechar_menu() -> void:
	_menu.visible = false
	get_tree().paused = false


# --------------------------------------------------------------------------
# Caixa de diálogo
# --------------------------------------------------------------------------
## Mensagem do jogo: o texto aparece letra por letra e some sozinho.
func mostrar_mensagem(texto: String, duracao: float = 3.0) -> void:
	if _falando:
		return
	_nome.visible = false
	_seta.visible = false
	_texto.text = texto
	_texto.visible_ratio = 0.0
	if _tween_msg:
		_tween_msg.kill()
	Som.tocar("texto", 0.0, 0.0)
	_tween_msg = create_tween()
	_tween_msg.tween_property(_dialogo, "modulate:a", 1.0, 0.15)
	_tween_msg.tween_property(_texto, "visible_ratio", 1.0, clampf(texto.length() * 0.018, 0.2, 1.2))
	_tween_msg.tween_interval(duracao)
	_tween_msg.tween_property(_dialogo, "modulate:a", 0.0, 0.3)


## Fala de personagem (cena de abertura). Espera o jogador apertar
## Espaço/E (ou 7 s). Esc pula a cena inteira.
func falar(quem: String, texto: String) -> void:
	_falando = true
	if _tween_msg:
		_tween_msg.kill()
	_nome.text = quem
	_nome.visible = true
	_nome.add_theme_color_override("font_color", Color("#ffb0c8") if quem == "Ariadne" else Color("#ffc94a"))
	_texto.text = texto
	_texto.visible_ratio = 0.0
	_seta.visible = false
	_dialogo.modulate.a = 1.0
	var total := texto.length()
	var t := 0.0
	var mostrado := 0
	# "digita" o texto, com bip a cada poucas letras
	while _texto.visible_ratio < 1.0:
		await get_tree().process_frame
		if _jogo and _jogo._pular:
			return
		t += get_process_delta_time()
		var n := mini(int(t / 0.028), total)
		if n != mostrado:
			if n / 3 != mostrado / 3:
				Som.tocar("texto", 0.0, 0.08)
			mostrado = n
		_texto.visible_ratio = float(n) / float(maxi(total, 1))
		if _confirmou() and t > 0.15:
			_texto.visible_ratio = 1.0
	_seta.visible = true
	var espera := 0.0
	while espera < 7.0:
		await get_tree().process_frame
		if _jogo and _jogo._pular:
			return
		espera += get_process_delta_time()
		_seta.modulate.a = 0.55 + 0.45 * sin(espera * 7.0)
		if _confirmou() and espera > 0.12:
			Som.tocar("menu_mover", -4.0, 0.0)
			break
	_seta.visible = false


func falar_fechar() -> void:
	_falando = false
	_nome.visible = false
	_seta.visible = false
	create_tween().tween_property(_dialogo, "modulate:a", 0.0, 0.2)


func _confirmou() -> bool:
	return Input.is_action_just_pressed("atacar") or Input.is_action_just_pressed("interagir") \
		or Input.is_action_just_pressed("ui_accept")


func _ao_cinematica(ligada: bool) -> void:
	cinema(ligada)
	# faixas no formato de cinema (2.39:1)
	var tela := get_viewport().get_visible_rect().size
	var altura := maxf((tela.y - tela.x / 2.39) / 2.0, 60.0)
	_faixa_cima.visible = true
	_faixa_baixo.visible = true
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_faixa_cima, "offset_bottom", altura if ligada else 0.0, 0.4)
	tw.tween_property(_faixa_baixo, "offset_top", -altura if ligada else 0.0, 0.4)
	tw.tween_property(_desenho, "modulate:a", 0.0 if ligada else 1.0, 0.3)
	tw.tween_property(_ajuda, "modulate:a", 0.0 if ligada else 0.75, 0.3)
	if not ligada:
		tw.chain().tween_callback(func():
			_faixa_cima.visible = false
			_faixa_baixo.visible = false)


## Ao chegar numa sala: em vez do nome, o ÍCONE do que tem nela
## (o texto recebido fica só como dica do nó, para depuração).
func mostrar_banner(texto: String) -> void:
	_banner.text = ""
	_banner.tooltip_text = texto
	var area: Node = _jogo.area_atual if _jogo else null
	_banner_icones.icones = icones_da_sala(area)
	if _tween_banner:
		_tween_banner.kill()
	_banner.modulate.a = 0.0
	_banner_icones.scale = Vector2.ONE * 0.6
	_tween_banner = create_tween()
	_tween_banner.tween_property(_banner, "modulate:a", 1.0, 0.3)
	_tween_banner.parallel().tween_property(_banner_icones, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK)
	_tween_banner.tween_interval(1.6)
	_tween_banner.tween_property(_banner, "modulate:a", 0.0, 0.6)


## Ícones que representam cada tipo de sala.
static func icones_da_sala(area: Node) -> Array:
	if area == null:
		return ["portal"]
	match String(area.get("tipo")):
		"inicio":
			return ["casa"]
		"chefe":
			return ["minotauro"]
		"combate":
			return ["espada", "minitauro"]
		"puzzle":
			for n in area.find_children("*", "", true, false):
				if n.is_in_group("estatua"):
					return ["estatua", "seta", "placa"]
				if n.is_in_group("braseiro"):
					return ["chama", "chama", "chama"]
				if n.is_in_group("espelho"):
					return ["luz", "espelho", "cristal"]
			return ["diamante"]
	return ["portal"]


# --------------------------------------------------------------------------
# Pictogramas (comunicação sem texto)
# --------------------------------------------------------------------------
## Cartão no alto da tela com uma frase visual. Some sozinho.
func aviso(icones: Array, duracao := 2.6) -> void:
	if _aviso == null:
		return
	_aviso.icones = icones
	_aviso.alfa = 0.0
	var tela := get_viewport().get_visible_rect().size
	_aviso.position = Vector2((tela.x - _aviso.size.x) / 2.0, 132.0)
	_aviso.pivot_offset = _aviso.size / 2.0
	_aviso.scale = Vector2.ONE * 0.5
	_aviso.visible = true
	if _tween_aviso:
		_tween_aviso.kill()
	_tween_aviso = create_tween()
	_tween_aviso.tween_property(_aviso, "alfa", 1.0, 0.15)
	_tween_aviso.parallel().tween_property(_aviso, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween_aviso.tween_interval(duracao)
	_tween_aviso.tween_property(_aviso, "alfa", 0.0, 0.35)
	_tween_aviso.tween_callback(func(): _aviso.visible = false)


## Balão de pantomima sobre um personagem. Espera "duracao" segundos (ou o
## jogador apertar Espaço/E). voz = tom da "voz" (bipes tipo Animal Crossing).
## exclusivo = false deixa vários balões ao mesmo tempo (ex.: reféns chorando).
## altura < 0 = automática (acima da cabeça).
func balao(alvo: Node3D, icones: Array, duracao := 2.4, voz := 1.0, exclusivo := true, altura := -1.0) -> void:
	if alvo == null:
		return
	if exclusivo and _balao_atual and is_instance_valid(_balao_atual):
		_balao_atual.fechar()
	var b := Balao.new()
	b.alvo = alvo
	b.icones = icones
	if altura > 0.0:
		b.altura = altura
	else:
		b.altura = 2.1 if alvo.is_in_group("jogador") else (1.5 if alvo is Prisioneiro else 1.9)
	b.cor_borda = Color("#ffb0c8") if String(alvo.name).begins_with("Ariadne") \
		else (Color("#8fc8ff") if alvo is Prisioneiro else Color("#ffc94a"))
	add_child(b)
	move_child(b, _fade.get_index())
	if exclusivo:
		_balao_atual = b
	_falando = true
	_voz(voz, icones.size())
	var t := 0.0
	while t < duracao:
		await get_tree().process_frame
		if _jogo and _jogo._pular:
			break
		t += get_process_delta_time()
		if t > 0.45 and _confirmou():
			Som.tocar("menu_mover", -4.0, 0.0)
			break
	if is_instance_valid(b):
		b.fechar()
	_falando = false


## Balão de PENSAMENTO com uma mini-animação de quadrinhos (Pensamento).
## Espera a animação acabar (Espaço/E pula depois de 1 s; Esc pula a cena).
func pensar(alvo: Node3D, roteiro: String) -> void:
	if alvo == null:
		return
	if _balao_atual and is_instance_valid(_balao_atual):
		_balao_atual.fechar()
	var p := Pensamento.new()
	p.alvo = alvo
	p.roteiro = roteiro
	add_child(p)
	move_child(p, _fade.get_index())
	_falando = true
	var t := 0.0
	while p._t < p.duracao() + 0.6:
		await get_tree().process_frame
		if _jogo and _jogo._pular:
			break
		t += get_process_delta_time()
		if t > 1.0 and _confirmou():
			Som.tocar("menu_mover", -4.0, 0.0)
			break
	if is_instance_valid(p):
		p.fechar()
	_falando = false
	await get_tree().create_timer(0.2).timeout


## "Voz" sem palavras: uns bipes com tom sorteado (uma sílaba por ícone).
func _voz(tom: float, silabas: int) -> void:
	for i in clampi(silabas + 2, 3, 6):
		Som.tocar("texto", -1.0, 0.0, tom * randf_range(0.85, 1.3))
		await get_tree().create_timer(0.075).timeout


func _montar_pictogramas() -> void:
	# banner da sala: ícones grandes no alto
	_banner_icones = FraseVisual.new()
	_banner_icones.name = "Icones"
	_banner_icones.raio = 24.0
	_banner_icones.com_painel = true
	_banner.add_child(_banner_icones)
	_banner_icones.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_banner.custom_minimum_size.y = 70
	_banner_icones.resized.connect(func(): _banner_icones.pivot_offset = _banner_icones.size / 2.0)
	# cartão de aviso
	_aviso = FraseVisual.new()
	_aviso.name = "Aviso"
	_aviso.raio = 26.0
	_aviso.com_painel = true
	_aviso.visible = false
	add_child(_aviso)
	move_child(_aviso, _fade.get_index())
	# rodapé de controles: tecla -> o que faz
	_ajuda.text = ""
	var linha := FraseVisual.new()
	linha.name = "Icones"
	linha.raio = 12.0
	linha.centralizar = false
	linha.icones = ["setas", "teseu", "|", "tecla_espaco", "espada", "|", "tecla_shift", "escudo", "|",
		"tecla:E", "usar", "|", "tecla:Esc", "pausa"]
	_ajuda.add_child(linha)
	linha.position = Vector2(0, -14)
	# menu de pausa
	FraseVisual.em_rotulo($Menu/Caixa/Botoes/Titulo, ["pausa"], 30.0)
	FraseVisual.em_botao($Menu/Caixa/Botoes/Continuar, ["jogar"])
	FraseVisual.em_botao($Menu/Caixa/Botoes/ReiniciarSala, ["reiniciar"])
	FraseVisual.em_botao($Menu/Caixa/Botoes/ReiniciarJogo, ["reiniciar", "novelo", "novelo", "novelo"])
	FraseVisual.em_botao($Menu/Caixa/Botoes/MenuInicial, ["casa"])
	# vitória
	FraseVisual.em_rotulo($Vitoria/Caixa/Coluna/Titulo, ["trofeu"], 46.0)
	FraseVisual.em_rotulo($Vitoria/Caixa/Coluna/Texto, ["teseu", "ariadne", "ateniense", "seta", "navio"], 26.0)
	FraseVisual.em_botao($Vitoria/Caixa/Coluna/JogarDeNovo, ["reiniciar"])
	FraseVisual.em_botao($Vitoria/Caixa/Coluna/MenuInicial, ["casa"])
	# game over
	FraseVisual.em_rotulo($GameOver/Caixa/Coluna/Titulo, ["fio_partido"], 46.0)
	FraseVisual.em_rotulo($GameOver/Caixa/Coluna/Texto, ["novelo_vazio", "novelo_vazio", "novelo_vazio"], 22.0)
	FraseVisual.em_botao($GameOver/Caixa/Coluna/TentarDeNovo, ["reiniciar"])
	FraseVisual.em_botao($GameOver/Caixa/Coluna/MenuInicial, ["casa"])


func _ao_transicionar(escurecer: bool) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0 if escurecer else 0.0, 0.3 if escurecer else 0.45)


func _ao_aparecer_chefe(chefe: Node) -> void:
	if chefe == null:
		return
	if not chefe.vida_mudou.is_connected(_desenho.definir_chefe):
		chefe.vida_mudou.connect(_desenho.definir_chefe)
	# a vida atual (depois de morrer na arena ele só recupera 25%, não tudo)
	_desenho.definir_chefe(chefe.vida, chefe.vida_maxima)


# --------------------------------------------------------------------------
# Fim de jogo
# --------------------------------------------------------------------------
func _ao_terminar(venceu: bool) -> void:
	_desenho.chefe_ativo = false
	var j := get_tree().get_first_node_in_group("jogo")
	if not venceu:
		if _tween_msg:
			_tween_msg.kill()
		create_tween().tween_property(_dialogo, "modulate:a", 0.0, 0.3)
	if not venceu:
		await get_tree().create_timer(1.2).timeout
		if j:
			FraseVisual.em_rotulo($GameOver/Caixa/Coluna/Detalhe, ["ateniense", "num:%d/%d" % [
				j.prisioneiros_libertados, j.total_prisioneiros], "|", "diamante", "num:%d/%d" % [
				j.puzzles_concluidos.size(), j.puzzles_para_abrir_arena]], 18.0)
		_abrir_tela(_game_over, $GameOver/Caixa/Coluna/TentarDeNovo)
		return
	await get_tree().create_timer(0.8).timeout
	if j:
		FraseVisual.em_rotulo($Vitoria/Caixa/Coluna/Detalhe, ["ateniense", "num:%d/%d" % [
			j.prisioneiros_libertados, j.total_prisioneiros], "|", "novelo", "num:%d" % j.novelo], 18.0)
	_abrir_tela(_vitoria, $Vitoria/Caixa/Coluna/JogarDeNovo)


func _abrir_tela(tela: Control, foco: Button) -> void:
	tela.modulate.a = 0.0
	tela.visible = true
	create_tween().tween_property(tela, "modulate:a", 1.0, 0.8)
	foco.grab_focus()


## Créditos subindo na tela (final do jogo). Espaço/E acelera, Esc pula.
func rolar_creditos() -> void:
	var fundo := ColorRect.new()
	fundo.name = "Creditos"
	fundo.color = Color(0.03, 0.02, 0.06, 0.0)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fundo)
	var texto := Label.new()
	texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texto.add_theme_font_size_override("font_size", 26)
	texto.add_theme_color_override("font_color", Color("#f4e6c8"))
	texto.add_theme_color_override("font_outline_color", Color.BLACK)
	texto.add_theme_constant_override("outline_size", 6)
	var creditos: String = load("res://scripts/ui/titulo.gd").CREDITOS
	texto.text = "\n\n\n\n\n" + creditos.replace("[", "").replace("]", "") + "\n\n\n[F1]  Raio-X"
	fundo.add_child(texto)
	var tela := get_viewport().get_visible_rect().size
	# no alto dos créditos, a história contada em ícones
	var fim := FraseVisual.new()
	fim.raio = 34.0
	fim.icones = ["teseu", "ariadne", "ateniense", "ateniense", "ateniense", "seta", "navio", "|", "trofeu"]
	texto.add_child(fim)
	fim.position = Vector2((tela.x - fim.size.x) / 2.0, 0)
	texto.size = Vector2(tela.x, 0)
	texto.position = Vector2(0, tela.y)
	create_tween().tween_property(fundo, "color:a", 0.88, 0.8)
	await get_tree().process_frame
	var altura := texto.get_combined_minimum_size().y
	var y := tela.y
	while y > -altura:
		await get_tree().process_frame
		if _jogo and _jogo._pular:
			break
		var vel := 70.0 * (5.0 if Input.is_action_pressed("atacar") or Input.is_action_pressed("interagir") else 1.0)
		y -= vel * get_process_delta_time()
		texto.position.y = y
	var tw := create_tween()
	tw.tween_property(fundo, "modulate:a", 0.0, 0.6)
	tw.tween_callback(fundo.queue_free)



# --------------------------------------------------------------------------
# Linguagem de cinema: correção de cor por cena, vinheta, granulação e flash
# --------------------------------------------------------------------------
func _montar_cinema() -> void:
	_cinema = ColorRect.new()
	_cinema.name = "Cinema"
	_cinema.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cinema.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mat_cinema = ShaderMaterial.new()
	_mat_cinema.shader = load("res://scripts/visual/cinema.gdshader")
	_cinema.material = _mat_cinema
	_mat_cinema.set_shader_parameter("forca", 0.0)
	_mat_cinema.set_shader_parameter("tinta", Vector3(1.0, 0.94, 0.85))
	_mat_cinema.set_shader_parameter("saturacao", 1.0)
	_mat_cinema.set_shader_parameter("vinheta", 0.55)
	_cinema.visible = false
	add_child(_cinema)
	move_child(_cinema, _faixa_cima.get_index())   # embaixo das faixas e dos balões
	_flash = ColorRect.new()
	_flash.name = "Flash"
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(1, 1, 1, 0)
	add_child(_flash)
	move_child(_flash, _fade.get_index())


## Liga/desliga o filtro de cinema (suave).
func cinema(ligar: bool) -> void:
	if _mat_cinema == null:
		return
	# qualidade baixa (PC fraco): sem filtro de tela, só as faixas pretas
	if ligar and Config.qualidade != "alta":
		return
	if _tw_cinema:
		_tw_cinema.kill()
	if ligar:
		_cinema.visible = true
	_tw_cinema = create_tween()
	_tw_cinema.tween_method(func(v: float): _mat_cinema.set_shader_parameter("forca", v),
		float(_mat_cinema.get_shader_parameter("forca")), 1.0 if ligar else 0.0, 0.6)
	if not ligar:
		_tw_cinema.tween_callback(func(): _cinema.visible = false)


## Tom da cena: tinta (multiplica as cores) e saturação, com transição.
func cinema_tom(tinta: Color, saturacao := 1.0, vinheta := 0.55, dur := 0.5) -> void:
	if _mat_cinema == null:
		return
	var t0: Vector3 = _mat_cinema.get_shader_parameter("tinta")
	var s0 := float(_mat_cinema.get_shader_parameter("saturacao"))
	var v0 := float(_mat_cinema.get_shader_parameter("vinheta"))
	var t1 := Vector3(tinta.r, tinta.g, tinta.b)
	create_tween().tween_method(func(k: float):
		_mat_cinema.set_shader_parameter("tinta", t0.lerp(t1, k))
		_mat_cinema.set_shader_parameter("saturacao", lerpf(s0, saturacao, k))
		_mat_cinema.set_shader_parameter("vinheta", lerpf(v0, vinheta, k)), 0.0, 1.0, dur)


## Flash de tela (impactos fortes).
func flash(cor := Color.WHITE, dur := 0.35) -> void:
	if _flash == null:
		return
	_flash.color = Color(cor.r, cor.g, cor.b, 0.85)
	var tw := create_tween()
	tw.tween_property(_flash, "color:a", 0.0, dur).set_ease(Tween.EASE_OUT)



## Tela preta: dur = 0 é corte seco (instantâneo); senão, fade.
func preto(ligar: bool, dur := 0.0) -> void:
	if dur <= 0.0:
		_fade.color.a = 1.0 if ligar else 0.0
		return
	create_tween().tween_property(_fade, "color:a", 1.0 if ligar else 0.0, dur)
