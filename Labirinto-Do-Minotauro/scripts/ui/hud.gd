extends CanvasLayer
## HUD no estilo Zelda: Link's Awakening.
##   - Desenho (hud_desenho.gd): corações, novelos, botões, enigmas, atenienses
##   - Dialogo: caixa de texto embaixo, com o texto sendo "digitado"
##   - Banner: nome da sala ao chegar
##   - Fade: tela preta do teletransporte
##   - Menu de pausa (Esc): continuar / reiniciar sala / reiniciar jogo

@onready var _desenho: Control = $Desenho
@onready var _dialogo: Control = $Dialogo
@onready var _texto: Label = $Dialogo/Texto
@onready var _banner: Label = $Banner
@onready var _fade: ColorRect = $Fade
@onready var _menu: Control = $Menu
@onready var _vitoria: Control = $Vitoria

var _tween_msg: Tween
var _tween_banner: Tween
var _jogo: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_menu.visible = false
	_vitoria.visible = false
	$Vitoria/Caixa/Coluna/JogarDeNovo.pressed.connect(func(): _jogo.reiniciar_jogo())
	_dialogo.modulate.a = 0.0
	_banner.modulate.a = 0.0
	_fade.color.a = 0.0
	$Menu/Caixa/Botoes/Continuar.pressed.connect(_fechar_menu)
	$Menu/Caixa/Botoes/ReiniciarSala.pressed.connect(func():
		_fechar_menu()
		_jogo.reiniciar_sala_atual())
	$Menu/Caixa/Botoes/ReiniciarJogo.pressed.connect(func(): _jogo.reiniciar_jogo())
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
		_desenho.definir_novelo(_jogo.novelo, _jogo.novelo_inicial)
		_desenho.definir_atenienses(_jogo.prisioneiros_libertados, _jogo.total_prisioneiros)
		_desenho.definir_enigmas(_jogo.puzzles_concluidos.size(), _jogo.puzzles_para_abrir_arena)
	var jogador := get_tree().get_first_node_in_group("jogador")
	if jogador:
		jogador.vida_mudou.connect(_desenho.definir_vida)
		_desenho.definir_vida(jogador.vida, jogador.vida_maxima)


func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed("pausar"):
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


## Caixa de diálogo com o texto aparecendo letra por letra.
func mostrar_mensagem(texto: String, duracao: float = 3.0) -> void:
	_texto.text = texto
	_texto.visible_ratio = 0.0
	if _tween_msg:
		_tween_msg.kill()
	_tween_msg = create_tween()
	_tween_msg.tween_property(_dialogo, "modulate:a", 1.0, 0.15)
	_tween_msg.tween_property(_texto, "visible_ratio", 1.0, clampf(texto.length() * 0.018, 0.2, 1.2))
	_tween_msg.tween_interval(duracao)
	_tween_msg.tween_property(_dialogo, "modulate:a", 0.0, 0.3)


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


func _ao_terminar(venceu: bool) -> void:
	if not venceu:
		return
	_desenho.chefe_ativo = false
	await get_tree().create_timer(2.5).timeout
	var j := get_tree().get_first_node_in_group("jogo")
	if j:
		$Vitoria/Caixa/Coluna/Detalhe.text = "Atenienses libertados: %d / %d\nVoltas do novelo restantes: %d" % [
			j.prisioneiros_libertados, j.total_prisioneiros, j.novelo]
	_vitoria.modulate.a = 0.0
	_vitoria.visible = true
	create_tween().tween_property(_vitoria, "modulate:a", 1.0, 0.8)
	$Vitoria/Caixa/Coluna/JogarDeNovo.grab_focus()
