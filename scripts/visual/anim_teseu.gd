class_name AnimTeseu
extends RefCounted
## Animação procedural do Teseu — funciona com QUALQUER modelo.
##
## O modelo do Tripo3D é uma malha única (sem braços e pernas separados),
## então a animação principal mexe o CORPO INTEIRO, no estilo "boneco de
## brinquedo" (Animal Crossing / Link's Awakening):
##   andar   -> quica a cada passo, ginga de um lado para o outro, inclina
##              para a frente e estica/achata (squash & stretch)
##   parado  -> respira (estica e encolhe de leve)
##   escudo  -> agacha um pouco, firme
##   golpe   -> antecipação (encolhe e torce), estocada (estica e avança)
##   dano    -> é jogado para trás e treme
##   morte   -> cai de costas, com um quique
##   gestos  -> "sim", "nao", "vitoria", "chamar", "susto" (cenas de pantomima)
##
## Se o modelo TIVER pivôs (Cabeca, BracoE, BracoD, PernaE, PernaD), eles
## também balançam, como no AnimBoneco. Sem pivôs, só o corpo anima.
##
## O nó animado é "Visual/Corpo" (o "Visual" gira para onde o Teseu olha e
## pisca no dano — por isso o corpo é um filho dele).
##
## Volume: no squash & stretch a escala em X/Z é 1/sqrt(escala Y), para o
## boneco não "inchar" nem "murchar" (volume ≈ constante).

const ANGULO_ESCUDO := -1.45
const DURACAO_GOLPE := 0.28
const DURACAO_DANO := 0.35

var corpo: Node3D
var cabeca: Node3D
var braco_e: Node3D
var braco_d: Node3D
var perna_e: Node3D
var perna_d: Node3D
var travar_braco_e := false
var travar_braco_d := false
## Lido a cada frame (o teseu_prototipo.gd atualiza).
var defendendo := false
var morto := false

var _pos0 := Vector3.ZERO
var _rot0 := Vector3.ZERO
var _esc0 := Vector3.ONE
var _cabeca_y := 0.0

var _t := 0.0
var _golpe := 0.0
var _dano := 0.0
var _t_morte := 0.0
var _gesto := ""
var _t_gesto := 0.0
var _dur_gesto := 1.0
## Valores suavizados do andar (para não "estalar" ao parar/andar).
var _andar := 0.0


func _init(visual: Node3D) -> void:
	usar_corpo(visual.get_node_or_null("Corpo") as Node3D, visual)


## Chamado de novo quando o modelo é trocado (teseu_novo.glb).
func usar_corpo(novo: Node3D, visual: Node3D = null) -> void:
	corpo = novo
	var raiz: Node = novo if novo else visual
	if raiz == null:
		return
	if corpo:
		_pos0 = corpo.position
		_rot0 = corpo.rotation
		_esc0 = corpo.scale
	cabeca = raiz.find_child("Cabeca", true, false) as Node3D
	braco_e = raiz.find_child("BracoE", true, false) as Node3D
	braco_d = raiz.find_child("BracoD", true, false) as Node3D
	perna_e = raiz.find_child("PernaE", true, false) as Node3D
	perna_d = raiz.find_child("PernaD", true, false) as Node3D
	if cabeca:
		_cabeca_y = cabeca.position.y


func tem_pivos() -> bool:
	return braco_e != null or perna_e != null


# --------------------------------------------------------------------------
# Disparos (chamados pelo teseu_prototipo.gd e pelas cenas)
# --------------------------------------------------------------------------
func golpe() -> void:
	_golpe = DURACAO_GOLPE


func reagir_dano(dur := DURACAO_DANO) -> void:
	_dano = dur


func morrer() -> void:
	morto = true
	_t_morte = 0.0


func renascer() -> void:
	morto = false
	_dano = 0.0
	_golpe = 0.0
	_gesto = ""
	if corpo:
		corpo.position = _pos0
		corpo.rotation = _rot0
		corpo.scale = _esc0


## Gesto de pantomima: "sim", "nao", "vitoria", "chamar", "susto".
func gesto(nome: String, dur := 1.0) -> void:
	_gesto = nome
	_t_gesto = 0.0
	_dur_gesto = maxf(dur, 0.2)


func fazendo_gesto() -> bool:
	return _gesto != ""


## Braço para a frente (ângulo em radianos, negativo = frente).
func posar_braco(braco: Node3D, angulo_x: float, delta: float, vel := 18.0) -> void:
	if braco:
		braco.rotation.x = lerpf(braco.rotation.x, angulo_x, 1.0 - exp(-vel * delta))


# --------------------------------------------------------------------------
# Atualização (todo frame)
# --------------------------------------------------------------------------
## andando: 0 (parado) a 1 (velocidade máxima).
func atualizar(delta: float, andando: float, _ciclo := 11.0) -> void:
	_golpe = maxf(_golpe - delta, 0.0)
	_dano = maxf(_dano - delta, 0.0)
	if morto:
		_animar_morte(delta)
		return
	var k := 1.0 - exp(-12.0 * delta)
	_andar = lerpf(_andar, andando, k)
	_t += delta * (lerpf(7.0, 12.0, _andar) if _andar > 0.05 else 2.4)
	var s := sin(_t)

	# --- corpo inteiro: valores-alvo somados por camadas ---------------
	var pos := Vector3.ZERO
	var rot := Vector3.ZERO
	var estica := 0.0     # >0 estica para cima, <0 achata

	if _andar > 0.05:
		pos.y += absf(s) * 0.07 * _andar            # quique (2 por ciclo)
		rot.z += s * 0.10 * _andar                  # ginga lateral
		rot.x += 0.12 * _andar                      # inclina para a frente
		estica += cos(2.0 * _t) * 0.06 * _andar     # achata ao pisar
	else:
		estica += sin(_t) * 0.018                   # respiração
		rot.z += sin(_t * 0.5) * 0.015

	if defendendo:
		estica -= 0.07                              # agacha atrás do escudo
		rot.x -= 0.06

	if _golpe > 0.0:
		var p := 1.0 - _golpe / DURACAO_GOLPE       # 0 -> 1
		if p < 0.3:                                 # antecipação
			var a := p / 0.3
			estica -= 0.10 * a
			rot.y += 0.40 * a
		elif p < 0.65:                              # estocada
			var b := (p - 0.3) / 0.35
			estica += lerpf(-0.10, 0.10, b)
			rot.y += lerpf(0.40, -0.50, b)
			rot.x += 0.20 * b
			pos.z += 0.14 * b
		else:                                       # volta
			var c := (p - 0.65) / 0.35
			estica += 0.10 * (1.0 - c)
			rot.y -= 0.50 * (1.0 - c)
			rot.x += 0.20 * (1.0 - c)
			pos.z += 0.14 * (1.0 - c)

	if _dano > 0.0:
		var f := _dano / DURACAO_DANO               # 1 -> 0
		rot.x -= 0.30 * f
		rot.z += sin(_t_total() * 45.0) * 0.14 * f
		pos.z -= 0.10 * f
		estica -= 0.08 * f

	if _gesto != "":
		_t_gesto += delta
		var g := clampf(_t_gesto / _dur_gesto, 0.0, 1.0)
		var r := _camada_gesto(g)
		pos += r[0]
		rot += r[1]
		estica += r[2]
		if g >= 1.0:
			_gesto = ""

	_aplicar_corpo(pos, rot, estica, 1.0 - exp(-22.0 * delta))
	_animar_membros(delta, s)


## Cada gesto devolve [deslocamento, rotação, estica] em função de g (0 -> 1).
func _camada_gesto(g: float) -> Array:
	var pos := Vector3.ZERO
	var rot := Vector3.ZERO
	var estica := 0.0
	var env := sin(g * PI)                          # sobe e desce suave
	match _gesto:
		"sim":          # dois pulinhos acenando com a cabeça
			pos.y = absf(sin(g * TAU * 2.0)) * 0.12
			rot.x = sin(g * TAU * 2.0) * 0.22
			estica = sin(g * TAU * 4.0) * 0.05
		"nao":          # balança o corpo de um lado para o outro
			rot.y = sin(g * TAU * 3.0) * 0.40 * env
			rot.z = sin(g * TAU * 3.0) * 0.06 * env
		"vitoria":      # pulo com giro completo e esticada no alto
			var salto := sin(g * PI)
			pos.y = salto * 0.45
			rot.y = _suave(g) * TAU
			estica = 0.15 * salto - 0.12 * (1.0 - salto) * (1.0 if g > 0.85 or g < 0.1 else 0.0)
		"chamar":       # inclina e balança (venha cá!)
			rot.x = 0.25 * env
			rot.z = sin(g * TAU * 2.5) * 0.12 * env
			pos.y = absf(sin(g * TAU * 2.5)) * 0.05
		"susto":        # pula para trás encolhido
			pos.y = sin(g * PI) * 0.25
			pos.z = -0.25 * env
			rot.x = -0.35 * env
			estica = -0.12 * env
	return [pos, rot, estica]


func _aplicar_corpo(pos: Vector3, rot: Vector3, estica: float, k: float) -> void:
	if corpo == null:
		return
	var sy := 1.0 + estica
	var sxz := 1.0 / sqrt(maxf(sy, 0.3))
	# deslocamento no espaço do Visual (a frente do Teseu é +Z)
	corpo.position = corpo.position.lerp(_pos0 + pos, k)
	corpo.rotation = Vector3(
		lerp_angle(corpo.rotation.x, _rot0.x + rot.x, k),
		lerp_angle(corpo.rotation.y, _rot0.y + rot.y, k),
		lerp_angle(corpo.rotation.z, _rot0.z + rot.z, k))
	corpo.scale = corpo.scale.lerp(_esc0 * Vector3(sxz, sy, sxz), k)


func _animar_membros(delta: float, s: float) -> void:
	if not tem_pivos():
		return
	var amp := 0.52 * _andar
	var k := 1.0 - exp(-14.0 * delta)
	if perna_e:
		perna_e.rotation.x = lerpf(perna_e.rotation.x, s * amp, k)
	if perna_d:
		perna_d.rotation.x = lerpf(perna_d.rotation.x, -s * amp, k)
	if braco_e and not travar_braco_e:
		braco_e.rotation.x = lerpf(braco_e.rotation.x, -s * amp * 0.8, k)
	if braco_d and not travar_braco_d:
		var alvo := s * amp * 0.8
		if _gesto == "vitoria" or _gesto == "chamar":
			alvo = -2.6 + sin(_t_gesto * 18.0) * 0.25   # braço para o alto
		braco_d.rotation.x = lerpf(braco_d.rotation.x, alvo, k)
	if cabeca:
		cabeca.position.y = _cabeca_y + (absf(s) * 0.025 * _andar if _andar > 0.05 else sin(_t) * 0.006)


func _animar_morte(delta: float) -> void:
	_t_morte += delta
	var p := minf(_t_morte / 0.9, 1.0)
	if corpo:
		corpo.rotation.x = _rot0.x - 1.45 * _quique(p)
		corpo.rotation.z = _rot0.z + 0.25 * _suave(p)
		corpo.position = _pos0 + Vector3(0, 0.05 * sin(p * PI), -0.25 * _suave(p))
		corpo.scale = corpo.scale.lerp(_esc0, 1.0 - exp(-10.0 * delta))
	if braco_e:
		braco_e.rotation.z = lerpf(braco_e.rotation.z, -0.6, 0.1)
	if braco_d:
		braco_d.rotation.z = lerpf(braco_d.rotation.z, 0.6, 0.1)


func _t_total() -> float:
	return Time.get_ticks_msec() * 0.001


static func _suave(t: float) -> float:
	return 1.0 - pow(1.0 - t, 3.0)


## Ease-out com quique (o corpo bate no chão e repica uma vez).
static func _quique(t: float) -> float:
	if t < 0.7:
		return _suave(t / 0.7)
	var u := (t - 0.7) / 0.3
	return 1.0 - sin(u * PI) * 0.12
