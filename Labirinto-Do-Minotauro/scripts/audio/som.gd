class_name Som
extends Node
## Toca os efeitos sonoros e as músicas. Funciona de qualquer script, sem
## Autoload e sem precisar de nó na cena:
##     Som.tocar("espada")
##     Som.musica("combate")
##
## Os sons são gerados por síntese em ferramentas/audio/gerar_sons.py.
## Efeitos e música vão para os barramentos "Efeitos" e "Musica" (criados
## aqui se não existirem), assim o volume pode ser ajustado no menu.

const PASTA_SFX := "res://assets/audio/sfx/"
const PASTA_MUSICA := "res://assets/audio/musica/"
const VOZES := 14
## Ajuste fino de volume (dB) de cada efeito.
const VOLUMES := {
	"erro": -9.0, "menu_ok": -8.0, "menu_mover": -10.0, "texto": -16.0,
	"passo1": -13.0, "passo2": -13.0, "casco": -4.0, "grade": 0.0,
	"espada": -4.0, "acerto": -2.0, "dano": -2.0, "bloqueio": -3.0,
	"portal": -6.0, "fogo": -4.0, "sino": -6.0, "resolvido": -3.0,
	"rugido": 0.0, "impacto": 0.0, "parede": 0.0, "grunhido": -9.0,
	"puf": -6.0, "pedra": -5.0, "arremesso": -8.0, "arrastar": -6.0,
	"alavanca": -4.0, "girar": -6.0, "cura": -6.0, "novelo": -4.0,
	"game_over": -3.0, "vitoria": -3.0,
}
const VOLUME_MUSICA := -8.0

static var _inst: Som

var _cache := {}
var _vozes: Array[AudioStreamPlayer] = []
var _proxima := 0
var _ultimo_toque := {}
var _musicas: Array[AudioStreamPlayer] = []
var _musica_ativa := 0
var _faixa := ""
var _pendentes: Array = []
var _tweens: Array[Tween] = [null, null]


# ----------------------------------------------------------------- API estática
static func tocar(nome: String, volume_db := 0.0, variacao_tom := 0.06, tom := 1.0) -> void:
	var s := _obter()
	if s:
		s._tocar(nome, volume_db, variacao_tom, tom)


## Troca a música com fade cruzado. Nome vazio = silêncio.
static func musica(nome: String, fade := 1.2) -> void:
	var s := _obter()
	if s:
		s._trocar_musica(nome, fade)


static func faixa_atual() -> String:
	var s := _obter()
	return s._faixa if s else ""


static func _obter() -> Som:
	if is_instance_valid(_inst):
		return _inst
	var arvore := Engine.get_main_loop() as SceneTree
	if arvore == null or arvore.root == null:
		return null
	_inst = Som.new()
	_inst.name = "Som"
	arvore.root.add_child.call_deferred(_inst)
	return _inst


# ----------------------------------------------------------------- instância
func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_criar_barramentos()
	for i in VOZES:
		var p := AudioStreamPlayer.new()
		p.bus = "Efeitos"
		add_child(p)
		_vozes.append(p)
	for i in 2:
		var m := AudioStreamPlayer.new()
		m.bus = "Musica"
		m.volume_db = -80.0
		add_child(m)
		_musicas.append(m)


func _ready() -> void:
	# pedidos feitos antes do nó entrar na árvore
	for p in _pendentes:
		if p[0] == "sfx":
			_tocar(p[1], p[2], p[3], p[4])
		else:
			_trocar_musica(p[1], p[2])
	_pendentes.clear()


static func _criar_barramentos() -> void:
	for nome in ["Musica", "Efeitos"]:
		if AudioServer.get_bus_index(nome) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, nome)
			AudioServer.set_bus_send(i, "Master")
	Config.aplicar_volumes()


func _carregar(caminho: String) -> AudioStream:
	if _cache.has(caminho):
		return _cache[caminho]
	var st: AudioStream = null
	if ResourceLoader.exists(caminho):
		st = load(caminho) as AudioStream
	_cache[caminho] = st
	return st


func _tocar(nome: String, volume_db: float, variacao_tom: float, tom := 1.0) -> void:
	if not is_inside_tree():
		_pendentes.append(["sfx", nome, volume_db, variacao_tom, tom])
		return
	# o mesmo som disparado várias vezes no mesmo instante vira um só
	var agora := Time.get_ticks_msec()
	if agora - int(_ultimo_toque.get(nome, -1000)) < 45:
		return
	_ultimo_toque[nome] = agora
	var st := _carregar(PASTA_SFX + nome + ".wav")
	if st == null:
		return
	var voz: AudioStreamPlayer = null
	for k in VOZES:
		var v := _vozes[(_proxima + k) % VOZES]
		if not v.playing:
			voz = v
			break
	if voz == null:
		voz = _vozes[_proxima]
	_proxima = (_proxima + 1) % VOZES
	voz.stream = st
	voz.volume_db = float(VOLUMES.get(nome, 0.0)) + volume_db
	voz.pitch_scale = tom * (1.0 + randf_range(-variacao_tom, variacao_tom))
	voz.play()


func _trocar_musica(nome: String, fade: float) -> void:
	if not is_inside_tree():
		_pendentes.append(["musica", nome, fade])
		return
	if nome == _faixa:
		return
	_faixa = nome
	var velha := _musicas[_musica_ativa]
	if velha.playing:
		_novo_tween(_musica_ativa).tween_property(velha, "volume_db", -60.0, fade)
		_tweens[_musica_ativa].tween_callback(velha.stop)
	if nome == "":
		return
	var st := _carregar(PASTA_MUSICA + nome + ".ogg")
	if st == null:
		return
	if "loop" in st:
		st.set("loop", true)
	_musica_ativa = 1 - _musica_ativa
	var nova := _musicas[_musica_ativa]
	nova.stream = st
	nova.volume_db = -40.0
	nova.play()
	_novo_tween(_musica_ativa).tween_property(nova, "volume_db", VOLUME_MUSICA, fade * 0.8)


## Cada player de música tem no máximo um tween (um fade novo cancela o antigo,
## senão o "stop" de um fade velho podia cortar a música nova).
func _novo_tween(i: int) -> Tween:
	if _tweens[i]:
		_tweens[i].kill()
	_tweens[i] = create_tween()
	return _tweens[i]
