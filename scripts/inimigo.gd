extends CharacterBody3D
## Minitaurinho (ou o Minotauro, com `eh_chefe = true`).
##
## Dois jeitos de existir:
##   - de sala: fica parado até a sala ser ativada e então persegue o Teseu;
##   - errante (`errante = true`): anda pelos corredores e, quando sente o
##     Teseu por perto, segue o caminho do labirinto até ele.
##
## Antes de golpear ele "prepara" o ataque (fica mais claro), o que dá
## tempo de o jogador desviar.

signal morreu(inimigo: Node3D)

const Construtor := preload("res://scripts/construtor.gd")

const TEMPO_PREPARO := 0.45
const RECARGA_GOLPE := 1.1
const FARO := 7               # até quantas células de caminho o errante sente o Teseu
const INTERVALO_ROTA := 0.4

var vida_max := 2
var velocidade := 2.6
var escala := 1.0
var cor := Color(0.55, 0.32, 0.18)
var eh_chefe := false
var errante := false
var mapa: RefCounted          # gerador_labirinto.gd, usado pelos errantes

var vida := 2
var vivo := true
var acordado := false
var raio := 0.45

var _posicao_inicial := Vector3.ZERO
var _recarga := 0.0
var _preparo := -1.0
var _empurrao := Vector3.ZERO
var _piscar := 0.0
# Investida do chefe
var _tempo_ate_investida := 3.0
var _investida := 0.0
var _direcao_investida := Vector3.ZERO
# Rota do errante
var _tempo_rota := 0.0
var _destino := Vector3.INF
var _celula_anterior := Vector2i(-1, -1)
var _perseguindo := false
var _direto := false

var _gravidade: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _pivo: Node3D
var _forma: CollisionShape3D
var _material: StandardMaterial3D


## Chame antes de adicionar na árvore.
func configurar(p_vida: int, p_velocidade: float, p_escala: float, p_cor: Color, p_chefe := false) -> void:
	vida_max = p_vida
	velocidade = p_velocidade
	escala = p_escala
	cor = p_cor
	eh_chefe = p_chefe


## Transforma em errante. Chame antes de adicionar na árvore.
func tornar_errante(p_mapa: RefCounted) -> void:
	errante = true
	mapa = p_mapa
	acordado = true


func _ready() -> void:
	add_to_group("inimigos")
	_posicao_inicial = position
	vida = vida_max
	raio = 0.45 * escala

	_forma = CollisionShape3D.new()
	var capsula := CapsuleShape3D.new()
	capsula.radius = raio
	capsula.height = 1.6 * escala
	_forma.shape = capsula
	_forma.position.y = 0.8 * escala
	add_child(_forma)

	_pivo = Node3D.new()
	add_child(_pivo)

	var corpo := MeshInstance3D.new()
	var malha := CapsuleMesh.new()
	malha.radius = raio
	malha.height = 1.6 * escala
	_material = Construtor.material(cor)
	malha.material = _material
	corpo.mesh = malha
	corpo.position.y = 0.8 * escala
	_pivo.add_child(corpo)

	# Chifres, para ler como "touro" de cima.
	var cor_chifre := Color(0.95, 0.9, 0.8)
	for lado in [-1.0, 1.0]:
		Construtor.caixa(_pivo, Vector3(0.12, 0.12, 0.35) * escala,
			Vector3(lado * 0.3, 1.5, -0.15) * escala, cor_chifre, false)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravidade * delta

	var horizontal := Vector3.ZERO
	var jogador := get_tree().get_first_node_in_group("jogador")
	var jogador_ok: bool = jogador != null and jogador.vivo

	if vivo and acordado:
		var para := Vector3.ZERO
		var distancia := INF
		if jogador_ok:
			para = jogador.global_position - global_position
			para.y = 0.0
			distancia = para.length()

		if errante:
			_atualizar_rota(delta, jogador if jogador_ok else null)
		else:
			_perseguindo = jogador_ok
			_direto = jogador_ok

		var alcance := raio + 0.4 + 0.5
		if _investida > 0.0:
			_investida -= delta
			horizontal = _direcao_investida * velocidade * 3.0
			if distancia <= alcance:
				jogador.levar_dano(1)
		elif _preparo >= 0.0:
			# Parado, preparando o golpe.
			_preparo -= delta
			if _preparo < 0.0:
				if distancia <= alcance + 0.3:
					jogador.levar_dano(1)
				_recarga = RECARGA_GOLPE
				_material.albedo_color = cor
		elif _perseguindo and _direto:
			if distancia > 0.01:
				_olhar(para)
			if distancia > alcance - 0.2:
				horizontal = para / distancia * velocidade
			if distancia <= alcance and _recarga <= 0.0:
				_preparo = TEMPO_PREPARO
				_material.albedo_color = cor.lightened(0.5)
			if eh_chefe:
				_tempo_ate_investida -= delta
				if _tempo_ate_investida <= 0.0 and distancia > 3.0:
					_investida = 0.6
					_direcao_investida = para / distancia
					_tempo_ate_investida = randf_range(3.0, 5.0)
		elif errante and _destino != Vector3.INF:
			var ate: Vector3 = _destino - global_position
			ate.y = 0.0
			if ate.length() > 0.05:
				_olhar(ate)
				var vel := velocidade if _perseguindo else velocidade * 0.5
				horizontal = ate.normalized() * vel

	horizontal += _empurrao
	_empurrao = _empurrao.move_toward(Vector3.ZERO, 25.0 * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	move_and_slide()

	_recarga -= delta
	if _piscar > 0.0:
		_piscar -= delta
		if _piscar <= 0.0 and _preparo < 0.0:
			_material.albedo_color = cor


func acordar() -> void:
	acordado = true


func levar_dano(quantidade: int, direcao: Vector3) -> void:
	if not vivo:
		return
	vida -= quantidade
	var forca := 3.0 if eh_chefe else 7.0
	_empurrao = direcao * forca
	_preparo = -1.0  # golpe interrompido
	_material.albedo_color = Color.WHITE
	_piscar = 0.1
	if vida <= 0:
		_morrer()


func resetar() -> void:
	vivo = true
	acordado = errante
	vida = vida_max
	position = _posicao_inicial
	velocity = Vector3.ZERO
	_empurrao = Vector3.ZERO
	_preparo = -1.0
	_recarga = 0.0
	_investida = 0.0
	_tempo_ate_investida = 3.0
	_destino = Vector3.INF
	_perseguindo = false
	_material.albedo_color = cor
	visible = true
	_forma.set_deferred("disabled", false)


# --- interno -------------------------------------------------------------

func _olhar(direcao: Vector3) -> void:
	_pivo.rotation.y = atan2(-direcao.x, -direcao.z)


func _atualizar_rota(delta: float, jogador: Node3D) -> void:
	_tempo_rota -= delta
	var chegou := _destino == Vector3.INF or Vector2(_destino.x - global_position.x, _destino.z - global_position.z).length() < 0.4
	if _tempo_rota > 0.0 and not chegou:
		return
	_tempo_rota = INTERVALO_ROTA

	var minha: Vector2i = mapa.celula_de(global_position)
	_perseguindo = false
	_direto = false

	if jogador:
		var alvo: Vector2i = mapa.celula_de(jogador.global_position)
		var rota: Array[Vector2i] = mapa.caminho(minha, alvo)
		if not rota.is_empty() and rota.size() <= FARO:
			_perseguindo = true
			if rota.size() <= 2:
				_direto = true
			else:
				_destino = mapa.centro(rota[1])
			return

	# Passeando: vai para uma célula vizinha, evitando voltar.
	if chegou:
		var opcoes: Array[Vector2i] = mapa.vizinhos_abertos(minha)
		if opcoes.size() > 1:
			opcoes.erase(_celula_anterior)
		if not opcoes.is_empty():
			_celula_anterior = minha
			_destino = mapa.centro(opcoes[randi_range(0, opcoes.size() - 1)])


func _morrer() -> void:
	vivo = false
	visible = false
	_forma.set_deferred("disabled", true)
	morreu.emit(self)
