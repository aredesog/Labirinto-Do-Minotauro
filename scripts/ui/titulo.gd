extends Node3D
## Tela de título: maquete da arena com o Minotauro ao fundo, câmera girando
## devagar e o menu (Jogar, Como jogar, Opções, Créditos, Sair).
##
## Para mudar os nomes nos créditos, edite CREDITOS abaixo.
##
## SEM TEXTO: os botões são ícones (jogar ▶, ajuda ?, engrenagem, créditos,
## sair) e o "Como jogar" é um diagrama de pictogramas (DIAGRAMA abaixo).
## O texto antigo (COMO_JOGAR) fica só como dica ao passar o mouse.

const CENA_JOGO := "res://cenas/fase_principal.tscn"
const CREDITOS := """[Labirinto do Minotauro]
Trabalho de Computação Gráfica · Ciência da Computação · UNIFAL-MG

Grupo "Herdeiros de Luca":
Guilherme Aredes
Melissa Alves
Mel Dias
Diego Vinna
Francisco Toro
Pedro Ferreira

Personagens (Minotauro, minitaurinho, Ariadne): modelados pelo grupo
Rig e animações: Blender · cenário e objetos gerados por script Python
Motor: Godot 4.7 (renderizador Compatibilidade)
Sons e músicas: sintetizados por código (numpy/scipy)
Inspiração visual: The Legend of Zelda: Link's Awakening

Baseado no mito grego de Teseu, Ariadne e o Minotauro."""
const COMO_JOGAR := """WASD / setas — andar
Espaço / J — espada
Shift / L (segurar) — escudo: bloqueia golpes e pedras que vêm da frente
E / K — usar (alavanca, braseiro, espelho)
Andar contra a estátua — empurrar
Esc — pausa (lá dá para reiniciar a sala)
F1 — Raio-X de CG (colisões, normais, reflexões) · F2 tilt-shift · F3 toon/PBR

Cada porta é um portal para uma sala sorteada.
Vença os minitaurinhos, resolva os 3 enigmas e liberte os 13 atenienses.
O novelo de Ariadne te traz de volta 3 vezes. Depois... acabou o fio.
Contra o Minotauro: faça ele bater nas colunas com a investida!"""

## "Como jogar" em pictogramas: cada linha é uma frase visual.
const DIAGRAMA := [
	["setas", "teseu", "|", "|", "tecla_espaco", "espada", "minitauro"],
	["tecla_shift", "escudo", "|", "|", "tecla:E", "usar", "chama", "espelho"],
	["teseu", "seta", "estatua", "seta", "placa"],
	["portal", "seta", "diamante", "diamante", "diamante", "seta", "minotauro"],
	["minotauro", "seta", "coluna", "estrelas", "|", "espada"],
	["novelo", "novelo", "novelo", "seta", "reiniciar", "teseu"],
	["tecla:Esc", "pausa", "reiniciar", "|", "tecla:F1", "olho"],
]

@export var velocidade_camera: float = 0.12
@export var raio_camera: float = 11.5
@export var altura_camera: float = 7.5

var _tempo := 0.0
var _saindo := false

@onready var _camera: Camera3D = $Camera
@onready var _ui: CanvasLayer = $UI
@onready var _principal: Control = $UI/Principal
@onready var _paineis := {
	"como": $UI/ComoJogar, "opcoes": $UI/Opcoes, "creditos": $UI/Creditos,
}
@onready var _fade: ColorRect = $UI/Fade


func _ready() -> void:
	Engine.time_scale = 1.0   # nunca começar o menu em câmera lenta
	Config.registrar_controles()
	Config.carregar()
	Config.aplicar_qualidade(self)
	Toon.instalar(get_tree())
	Som.musica("titulo", 1.0)
	# braseiros acesos e o Teseu parado, olhando para o Minotauro
	for b in find_children("*", "", true, false):
		if b is Braseiro:
			b.acender()
	var teseu := get_node_or_null("Teseu")
	if teseu and teseu.has_method("definir_controle"):
		teseu.definir_controle(false)
	$UI/Creditos/Caixa/Coluna/Texto.text = CREDITOS
	_montar_pictogramas()
	var b_principal := $UI/Principal/Caixa/Coluna
	b_principal.get_node("Jogar").pressed.connect(_jogar)
	b_principal.get_node("ComoJogar").pressed.connect(_abrir.bind("como"))
	b_principal.get_node("Opcoes").pressed.connect(_abrir.bind("opcoes"))
	b_principal.get_node("Creditos").pressed.connect(_abrir.bind("creditos"))
	b_principal.get_node("Sair").pressed.connect(func(): get_tree().quit())
	for nome in _paineis:
		_paineis[nome].get_node("Caixa/Coluna/Voltar").pressed.connect(_voltar)
	var op := $UI/Opcoes/Caixa/Coluna
	op.get_node("Qualidade").pressed.connect(_trocar_qualidade)
	op.get_node("Musica/Barra").value = Config.volume_musica * 100.0
	op.get_node("Efeitos/Barra").value = Config.volume_efeitos * 100.0
	op.get_node("Musica/Barra").value_changed.connect(func(v):
		Config.volume_musica = v / 100.0
		Config.aplicar_volumes())
	op.get_node("Efeitos/Barra").value_changed.connect(func(v):
		Config.volume_efeitos = v / 100.0
		Config.aplicar_volumes()
		Som.tocar("espada"))
	_atualizar_qualidade()
	for b in find_children("*", "Button", true, false):
		(b as Button).focus_entered.connect(func(): Som.tocar("menu_mover", 0.0, 0.0))
		(b as Button).pressed.connect(func(): Som.tocar("menu_ok", 0.0, 0.0))
	_voltar()
	# entrada: título desce e a tela clareia
	_fade.color.a = 1.0
	create_tween().tween_property(_fade, "color:a", 0.0, 1.2)
	var logo := $UI/Principal/Logo as Control
	logo.modulate.a = 0.0
	create_tween().tween_property(logo, "modulate:a", 1.0, 1.5).set_delay(0.4)


func _process(delta: float) -> void:
	# a câmera balança num arco na frente da arena (o Minotauro sempre à vista)
	_tempo += delta
	var angulo := sin(_tempo * velocidade_camera) * 0.65
	var centro := Vector3(0, 1.2, -0.5)
	_camera.global_position = centro + Vector3(sin(angulo) * raio_camera, altura_camera, cos(angulo) * raio_camera)
	# mira um pouco à esquerda do centro: a arena fica do lado direito da tela,
	# livre do menu
	_camera.look_at(centro - _camera.global_basis.x * 2.6, Vector3.UP)
	var logo := $UI/Principal/Logo as Control
	logo.position.y = 50.0 + sin(Time.get_ticks_msec() * 0.0015) * 5.0


func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed("pausar") or evento.is_action_pressed("ui_cancel"):
		if not _principal.visible:
			_voltar()
			get_viewport().set_input_as_handled()


func _abrir(nome: String) -> void:
	_principal.visible = false
	for n in _paineis:
		_paineis[n].visible = n == nome
	_paineis[nome].get_node("Caixa/Coluna/Voltar").grab_focus()
	if nome == "opcoes":
		$UI/Opcoes/Caixa/Coluna/Qualidade.grab_focus()


func _voltar() -> void:
	Config.salvar()
	for n in _paineis:
		_paineis[n].visible = false
	_principal.visible = true
	$UI/Principal/Caixa/Coluna/Jogar.grab_focus()


func _trocar_qualidade() -> void:
	Config.qualidade = "baixa" if Config.qualidade == "alta" else "alta"
	Config.aplicar_qualidade(self)
	_atualizar_qualidade()


func _atualizar_qualidade() -> void:
	var b := $UI/Opcoes/Caixa/Coluna/Qualidade as Button
	b.text = ""
	b.tooltip_text = "Qualidade gráfica: %s" % ("ALTA" if Config.qualidade == "alta" else "BAIXA (PC fraco)")
	FraseVisual.em_botao(b, ["qualidade_alta" if Config.qualidade == "alta" else "qualidade_baixa"], 20.0)


## Troca os textos dos menus por ícones.
func _montar_pictogramas() -> void:
	var col := $UI/Principal/Caixa/Coluna
	FraseVisual.em_botao(col.get_node("Jogar"), ["jogar"], 22.0)
	FraseVisual.em_botao(col.get_node("ComoJogar"), ["ajuda"], 19.0)
	FraseVisual.em_botao(col.get_node("Opcoes"), ["engrenagem"], 19.0)
	FraseVisual.em_botao(col.get_node("Creditos"), ["creditos"], 19.0)
	FraseVisual.em_botao(col.get_node("Sair"), ["sair"], 19.0)
	for nome in _paineis:
		FraseVisual.em_botao(_paineis[nome].get_node("Caixa/Coluna/Voltar"), ["voltar"], 19.0)
	FraseVisual.em_rotulo($UI/Principal/Logo/Linha3, ["teseu", "novelo", "seta", "minotauro"], 16.0)
	FraseVisual.em_rotulo($UI/ComoJogar/Caixa/Coluna/Titulo, ["ajuda"], 28.0)
	FraseVisual.em_rotulo($UI/Creditos/Caixa/Coluna/Titulo, ["creditos"], 28.0)
	FraseVisual.em_rotulo($UI/Opcoes/Caixa/Coluna/Titulo, ["engrenagem"], 28.0)
	FraseVisual.em_rotulo($UI/Opcoes/Caixa/Coluna/Musica/Rotulo, ["musica"], 16.0)
	FraseVisual.em_rotulo($UI/Opcoes/Caixa/Coluna/Efeitos/Rotulo, ["som"], 16.0)
	$UI/Opcoes/Caixa/Coluna/Dica.visible = false
	# "Como jogar": o texto vira um diagrama de frases visuais
	var texto := $UI/ComoJogar/Caixa/Coluna/Texto as Label
	texto.text = ""
	texto.tooltip_text = COMO_JOGAR
	texto.visible = false
	var diagrama := VBoxContainer.new()
	diagrama.name = "Diagrama"
	diagrama.add_theme_constant_override("separation", 6)
	texto.get_parent().add_child(diagrama)
	texto.get_parent().move_child(diagrama, texto.get_index())
	for linha in DIAGRAMA:
		var f := FraseVisual.new()
		f.raio = 19.0
		f.icones = linha
		diagrama.add_child(f)


func _jogar() -> void:
	if _saindo:
		return
	_saindo = true
	Config.salvar()
	Config.mostrar_abertura = true
	Som.tocar("portal")
	Som.musica("", 0.8)
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.8)
	await tw.finished
	get_tree().change_scene_to_file(CENA_JOGO)
