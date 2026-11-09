class_name CameraDiorama
extends Camera3D
## Câmera de cima em 3/4 (visual de maquete), no estilo Binding of Isaac:
##  - dentro de uma sala pequena, trava no centro da sala (enquadra tudo);
##  - em corredores e na arena grande, segue o Teseu.
## Também marca as salas visitadas (para o minimapa).
##
## MODO CINEMA (cenas): plano(pos, mira, fov) põe a câmera em qualquer ângulo
## (close na altura dos olhos, câmera baixa olhando para cima, plano de cima...)
## e mover_plano() faz travellings suaves. focar()/soltar() voltam ao normal.

@export var alvo: Node3D
@export var altura: float = 12.0
@export var distancia: float = 9.5
@export var suavidade: float = 6.0
## Salas com metade do tamanho até este valor ficam com a câmera travada.
@export var travar_ate: float = 7.5

var area_atual: Node = null
var _tremor := 0.0
## Cena de cinema: a câmera mira num ponto com zoom (null = segue o jogo).
var _foco_fixo: Variant = null
var _zoom_fixo := 1.0
var _plano := false
## "Soco" de zoom: a câmera chega mais perto por um instante (golpe forte).
var _soco := 0.0
var _p_pos := Vector3.ZERO
var _p_mira := Vector3.ZERO
## Inclinação da câmera em volta do eixo de visão ("plano holandês", radianos).
var _p_rolo := 0.0
## Câmera na mão: balanço leve e orgânico (0 = tripé).
var mao := 1.0
var _t_mao := 0.0
var _tw_plano: Tween
var _base_padrao := Basis.IDENTITY
var _fov_padrao := 50.0


func _ready() -> void:
	if alvo == null:
		alvo = get_tree().get_first_node_in_group("jogador")
	if alvo:
		global_position = _posicao_desejada()
		look_at(_foco() + Vector3.UP * 0.5, Vector3.UP)
	_base_padrao = global_basis
	_fov_padrao = fov


func _foco() -> Vector3:
	area_atual = null
	for a in get_tree().get_nodes_in_group("area_sala"):
		if a.contem(alvo.global_position, 0.3):
			area_atual = a
			a.visitada = true
			break
	if area_atual and area_atual.meio_tamanho.x <= travar_ate and area_atual.meio_tamanho.y <= travar_ate:
		return area_atual.global_position
	return alvo.global_position


func _posicao_desejada() -> Vector3:
	var foco := _foco()
	var zoom: float = area_atual.zoom_camera if area_atual else 1.0
	if _foco_fixo != null:
		foco = _foco_fixo
		zoom = _zoom_fixo
	zoom *= 1.0 - _soco * 0.12
	return foco + Vector3(0, altura, distancia) * zoom


## Aproxima a câmera de um ponto (cenas de diálogo). zoom < 1 = mais perto.
func focar(ponto: Vector3, zoom := 0.6) -> void:
	_sair_do_plano()
	_foco_fixo = ponto
	_zoom_fixo = zoom


func soltar() -> void:
	_sair_do_plano()
	_foco_fixo = null


## Câmera de cinema: corta direto para "pos" mirando "mira".
func plano(pos: Vector3, mira: Vector3, lente := -1.0, rolo := 0.0) -> void:
	if _tw_plano:
		_tw_plano.kill()
	_plano = true
	_p_pos = pos
	_p_mira = mira
	_p_rolo = rolo
	if lente > 0.0:
		fov = lente
	_aplicar_plano(0.0)


## Travelling: desliza até "pos"/"mira" em "dur" segundos.
func mover_plano(pos: Vector3, mira: Vector3, dur: float, lente := -1.0) -> void:
	if not _plano:
		plano(pos, mira, lente)
		return
	if _tw_plano:
		_tw_plano.kill()
	_tw_plano = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tw_plano.tween_property(self, "_p_pos", pos, dur)
	_tw_plano.tween_property(self, "_p_mira", mira, dur)
	if lente > 0.0:
		_tw_plano.tween_property(self, "fov", lente, dur)


## Inclina a câmera aos poucos (tensão).
func rolar(rolo: float, dur: float) -> void:
	create_tween().tween_property(self, "_p_rolo", rolo, dur).set_trans(Tween.TRANS_SINE)


## Efeito VERTIGO (dolly zoom, "Um Corpo que Cai"): a câmera anda para a frente
## enquanto a lente abre, e o objeto em foco fica do mesmo tamanho enquanto o
## fundo "estica". Distância nova:  d2 = d1 · tan(fov1/2) / tan(fov2/2)
func vertigo(lente_final: float, dur: float) -> void:
	if not _plano:
		return
	var d1 := _p_pos.distance_to(_p_mira)
	var d2 := d1 * tan(deg_to_rad(fov) * 0.5) / tan(deg_to_rad(lente_final) * 0.5)
	var pos2 := _p_mira + (_p_pos - _p_mira).normalized() * d2
	mover_plano(pos2, _p_mira, dur, lente_final)


func _sair_do_plano() -> void:
	if not _plano:
		return
	_plano = false
	_p_rolo = 0.0
	if _tw_plano:
		_tw_plano.kill()
	global_basis = _base_padrao
	fov = _fov_padrao


func _aplicar_plano(delta: float) -> void:
	_t_mao += delta
	var balanco := Vector3(sin(_t_mao * 0.9) + sin(_t_mao * 2.3) * 0.3, sin(_t_mao * 1.3) * 0.7,
		cos(_t_mao * 0.7) + cos(_t_mao * 1.9) * 0.3) * 0.022 * mao
	global_position = _p_pos + balanco
	if _tremor > 0.0:
		global_position += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _tremor * 0.15
	if _p_pos.distance_to(_p_mira) > 0.01:
		look_at(_p_mira, Vector3.UP)
		if absf(_p_rolo) > 0.0001:
			rotate_object_local(Vector3(0, 0, 1), _p_rolo)


## Chacoalha a câmera (golpes e investidas do Minotauro).
func tremer(forca: float) -> void:
	_tremor = maxf(_tremor, forca)


func soco(forca := 1.0) -> void:
	_soco = maxf(_soco, forca)


func _process(delta: float) -> void:
	if _plano:
		_tremor = maxf(_tremor - delta * 1.5, 0.0)
		_aplicar_plano(delta)
		return
	if alvo == null:
		return
	_soco = maxf(_soco - delta * 2.5, 0.0)
	var k := 1.0 - exp(-(suavidade + _soco * 14.0) * delta)
	global_position = global_position.lerp(_posicao_desejada(), k)
	if _tremor > 0.0:
		_tremor = maxf(_tremor - delta * 1.5, 0.0)
		global_position += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _tremor * 0.3


## Pula direto para a posição (usado ao renascer/teleportar).
func encaixar() -> void:
	if _plano:
		_aplicar_plano(0.0)
		return
	if alvo:
		global_position = _posicao_desejada()
