class_name Config
extends RefCounted
## Opções do jogador (qualidade gráfica e volumes), salvas em user://config.cfg.
## Tudo estático: use Config.qualidade, Config.salvar() etc. de qualquer script.
##
## Qualidade:
##   "alta"  -> sombras suaves, luz das tochas, tilt-shift
##   "baixa" -> pensada para GPU integrada (ex.: Radeon 610M): sombra simples,
##              só a chama das tochas brilha (sem luz dinâmica), sem tilt-shift
##              e a cena 3D renderizada em 85% da resolução.

const ARQUIVO := "user://config.cfg"

static var qualidade: String = "alta"
static var volume_musica: float = 0.8
static var volume_efeitos: float = 1.0
## Mostra a cena da Ariadne no começo da partida (o teste automático desliga).
static var mostrar_abertura: bool = true
static var _carregado := false


## Teclas do jogo (registradas por código para não depender do project.godot).
const CONTROLES := {
	"mover_cima": [KEY_W, KEY_UP],
	"mover_baixo": [KEY_S, KEY_DOWN],
	"mover_esquerda": [KEY_A, KEY_LEFT],
	"mover_direita": [KEY_D, KEY_RIGHT],
	"atacar": [KEY_SPACE, KEY_J],
	"interagir": [KEY_E, KEY_K],
	"defender": [KEY_SHIFT, KEY_L],
	"reiniciar_sala": [KEY_R],
	"pausar": [KEY_ESCAPE, KEY_P],
}


static func registrar_controles() -> void:
	for acao in CONTROLES:
		if InputMap.has_action(acao):
			continue
		InputMap.add_action(acao)
		for tecla in CONTROLES[acao]:
			var ev := InputEventKey.new()
			ev.physical_keycode = tecla
			InputMap.action_add_event(acao, ev)


static func carregar() -> void:
	if _carregado:
		return
	_carregado = true
	var cfg := ConfigFile.new()
	if cfg.load(ARQUIVO) != OK:
		# primeira vez: em GPU integrada já começa na qualidade baixa
		qualidade = "baixa" if gpu_integrada() else "alta"
		return
	qualidade = cfg.get_value("video", "qualidade", qualidade)
	volume_musica = cfg.get_value("audio", "musica", volume_musica)
	volume_efeitos = cfg.get_value("audio", "efeitos", volume_efeitos)


## Palpite pelo nome da placa de vídeo (Radeon 610M, Intel UHD/Iris, Vega...).
static func gpu_integrada() -> bool:
	var nome := RenderingServer.get_video_adapter_name().to_lower()
	for pista in ["610m", "intel", "uhd", "iris", "vega", "radeon(tm) graphics", "llvmpipe", "mali", "adreno"]:
		if pista in nome:
			return true
	return false


static func salvar() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("video", "qualidade", qualidade)
	cfg.set_value("audio", "musica", volume_musica)
	cfg.set_value("audio", "efeitos", volume_efeitos)
	cfg.save(ARQUIVO)


static func aplicar_volumes() -> void:
	carregar()
	for par in [["Musica", volume_musica], ["Efeitos", volume_efeitos]]:
		var i := AudioServer.get_bus_index(par[0])
		if i >= 0:
			AudioServer.set_bus_volume_db(i, linear_to_db(maxf(par[1], 0.0001)))
			AudioServer.set_bus_mute(i, par[1] <= 0.01)


static func baixa() -> bool:
	carregar()
	return qualidade == "baixa"


## Aplica a qualidade numa cena de jogo (sol, tochas, tilt-shift, resolução).
static func aplicar_qualidade(cena: Node) -> void:
	carregar()
	var vp := cena.get_viewport()
	var low := qualidade == "baixa"
	if vp:
		vp.scaling_3d_scale = 0.85 if low else 1.0
		vp.msaa_3d = Viewport.MSAA_DISABLED if low else Viewport.MSAA_2X
	RenderingServer.directional_shadow_atlas_set_size(2048 if low else 4096, true)
	for n in cena.find_children("*", "DirectionalLight3D", true, false):
		var sol := n as DirectionalLight3D
		sol.shadow_blur = 0.6 if low else 2.0
		sol.directional_shadow_max_distance = 26.0 if low else 40.0
	# tochas: na qualidade baixa só a chama emissiva fica (sem OmniLight)
	for t in cena.get_tree().get_nodes_in_group("tocha"):
		var luz := t.find_child("Luz", true, false) as Light3D
		if luz:
			luz.visible = not low
	var tilt := cena.find_child("TiltShift", true, false) as CanvasLayer
	if tilt:
		tilt.visible = not low
