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
	await get_tree().process_frame
	_jogo = get_tree().get_first_node_in_group("jogo")
	if _jogo:
		_jogo.novelo_mudou.connect(func(n): _desenho.definir_novelo(n, _jogo.novelo_inicial))
		_jogo.prisioneiros_mudou.connect(_desenho.definir_atenienses)
		_jogo.puzzles_mudou.connect(_desenho.definir_enigmas)
		_jogo.mensagem.connect(mostrar_mensagem)
		_jogo.titulo_sala.connect(mostrar_banner)
		_jogo.transicao.connect(_ao_transicionar)
		_jogo.chefe_apareceu.connect(_ao_aparecer_chefe)
		_jogo.fim_de_jogo.connect(_ao_terminar)
		_jogo.cinematica.connect(_ao_cinematica)
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
	var altura := 70.0
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


func mostrar_banner(texto: String) -> void:
	_banner.text = "~ %s ~" % texto
	if _tween_banner:
		_tween_banner.kill()
	_banner.modulate.a = 0.0
	_tween_banner = create_tween()
	_tween_banner.tween_property(_banner, "modulate:a", 1.0, 0.3)
	_tween_banner.tween_interval(1.8)
	_tween_banner.tween_property(_banner, "modulate:a", 0.0, 0.6)


func _ao_transicionar(escurecer: bool) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0 if escurecer else 0.0, 0.3 if escurecer else 0.45)


func _ao_aparecer_chefe(chefe: Node) -> void:
	if chefe == null:
		return
	if not chefe.vida_mudou.is_connected(_desenho.definir_chefe):
		chefe.vida_mudou.connect(_desenho.definir_chefe)
	_desenho.definir_chefe(chefe.vida_maxima, chefe.vida_maxima)


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
			$GameOver/Caixa/Coluna/Detalhe.text = "Atenienses libertados: %d / %d   ·   Enigmas: %d / %d" % [
				j.prisioneiros_libertados, j.total_prisioneiros, j.puzzles_concluidos.size(), j.puzzles_para_abrir_arena]
		_abrir_tela(_game_over, $GameOver/Caixa/Coluna/TentarDeNovo)
		return
	await get_tree().create_timer(2.5).timeout
	if j:
		$Vitoria/Caixa/Coluna/Detalhe.text = "Atenienses libertados: %d / %d\nVoltas do novelo restantes: %d" % [
			j.prisioneiros_libertados, j.total_prisioneiros, j.novelo]
	_abrir_tela(_vitoria, $Vitoria/Caixa/Coluna/JogarDeNovo)


func _abrir_tela(tela: Control, foco: Button) -> void:
	tela.modulate.a = 0.0
	tela.visible = true
	create_tween().tween_property(tela, "modulate:a", 1.0, 0.8)
	foco.grab_focus()
