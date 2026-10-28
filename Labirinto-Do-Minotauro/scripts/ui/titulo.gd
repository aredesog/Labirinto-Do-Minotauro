extends Node3D
## Tela de título: maquete da arena com o Minotauro ao fundo, câmera girando
## devagar e o menu (Jogar, Como jogar, Opções, Créditos, Sair).
##
## Para mudar os nomes nos créditos, edite CREDITOS abaixo.

const CENA_JOGO := "res://cenas/fase_principal.tscn"
const CREDITOS := """[Labirinto do Minotauro]
Trabalho de Computação Gráfica · Ciência da Computação · UNIFAL-MG

Grupo: Guilherme Aredes e equipe

Modelos 3D: Blender (gerados por script Python)
Motor: Godot 4.7 (renderizador Compatibilidade)
Sons e músicas: sintetizados por código (numpy/scipy)
Inspiração visual: The Legend of Zelda: Link's Awakening

Baseado no mito grego de Teseu, Ariadne e o Minotauro."""
const COMO_JOGAR := """WASD / setas — andar
Espaço / J — espada
Shift / L (segurar) — escudo: bloqueia golpes e pedras que vêm da frente
E / K — usar (alavanca, braseiro, espelho)
Andar contra a estátua — empurrar
R — reiniciar a sala · Esc — pausa

Cada porta é um portal para uma sala sorteada.
Vença os minitaurinhos, resolva os 3 enigmas e liberte os 13 atenienses.
O novelo de Ariadne te traz de volta 3 vezes. Depois... acabou o fio.
Contra o Minotauro: faça ele bater nas colunas com a investida!"""

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
	Config.registrar_controles()
	Config.carregar()
	Config.aplicar_qualidade(self)
	Som.musica("titulo", 1.0)
	# braseiros acesos e o Teseu parado, olhando para o Minotauro
	for b in find_children("*", "", true, false):
		if b is Braseiro:
			b.acender()
	var teseu := get_node_or_null("Teseu")
	if teseu and teseu.has_method("definir_controle"):
		teseu.definir_controle(false)
	$UI/ComoJogar/Caixa/Coluna/Texto.text = COMO_JOGAR
	$UI/Creditos/Caixa/Coluna/Texto.text = CREDITOS
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
	b.text = "Qualidade gráfica: %s" % ("ALTA" if Config.qualidade == "alta" else "BAIXA (PC fraco)")


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
