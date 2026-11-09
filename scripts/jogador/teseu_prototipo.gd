class_name Teseu
extends CharacterBody3D
## Teseu (jogador).
##
## MODELO NOVO (Tripo3D): exporte do Blender como
##   assets/modelos/personagens/teseu_novo.glb
## (File > Export > glTF 2.0, formato "glTF Binary"). Se esse arquivo existir,
## ele entra no lugar do boneco antigo sozinho: o script mede a malha, ajusta
## a altura (altura_modelo_novo), põe os pés no chão e centraliza. Se ele
## aparecer de costas, mude giro_modelo_novo para 180.
## A animação é procedural (AnimTeseu): não precisa de esqueleto.
##
## Controles: WASD/setas = andar | Espaço/J = atacar | E/K = interagir
##            Shift/L (segurar) = escudo
## Empurrar estátua: ande contra ela por um instante.
##
## ESCUDO: segurando Shift o Teseu anda devagar e não ataca, mas golpes e
## pedras que vêm DA FRENTE são bloqueados (minitaurinho e pedra: sem dano;
## golpes do Minotauro: metade do dano).
##
## O novelo de Ariadne fica na cabeça (nó "Visual/Novelo") e encolhe a cada
## volta gasta.

signal vida_mudou(atual: int, maximo: int)

@export var velocidade: float = 4.5
## Vida em MEIOS corações (10 = 5 corações, como no Zelda). Cada golpe
## de minitaurinho tira meio coração.
@export var vida_maxima: int = 10
@export var dano_ataque: int = 1
@export var alcance_interacao: float = 1.4
@export var tempo_para_empurrar: float = 0.25
## Força do empurrão ao levar dano (aplicada pela física: não atravessa paredes).
@export var forca_empurrao: float = 7.0
## Se cair abaixo desta altura, volta ao checkpoint sem perder vida.
@export var altura_minima: float = -3.0
## Fração da velocidade com o escudo erguido.
@export var velocidade_escudo: float = 0.45
## Quão "de frente" o golpe precisa vir para o escudo pegar (cosseno do ângulo).
@export var angulo_bloqueio: float = 0.35
## Altura (m) do modelo novo depois de ajustado.
@export var altura_modelo_novo: float = 1.25
## Giro (graus) do modelo novo, caso ele venha olhando para trás.
@export var giro_modelo_novo: float = 0.0
## O modelo do Tripo já tem espada na mão? Então esconda a espada extra.
@export var esconder_espada_extra: bool = true

const MODELO_NOVO := "res://assets/modelos/personagens/teseu_novo.glb"

var vida: int
var _direcao_olhar := Vector3.BACK
var _tempo_empurrando := 0.0
var _cooldown_ataque := 0.0
var _invulneravel := 0.0
var _controle_ativo := true
var _empurrao := Vector3.ZERO
var _rastro: MeshInstance3D
var defendendo := false
## Contadores usados pelas dicas do tutorial (HUD): quantos golpes acertou
## e quantas vezes bloqueou com o escudo.
var acertos_total := 0
var bloqueios_total := 0
var _passo := 0.0
var _pe := 0
## Posição do escudo no braço e na frente do corpo (bloqueando).
const ESCUDO_BRACO := [Vector3(0.36, 0.45, 0.06), 65.0]
const ESCUDO_FRENTE := [Vector3(0.05, 0.5, 0.42), 0.0]
## Posição da espada em descanso (ponta para frente e para baixo).
const ESPADA_DESCANSO := Vector3(0.45, -1.05, 0.0)

@onready var _visual: Node3D = get_node_or_null("Visual")
@onready var _espada: Node3D = get_node_or_null("Visual/Espada")
@onready var _novelo: Node3D = get_node_or_null("Visual/Novelo")
@onready var _escudo: Node3D = get_node_or_null("Visual/Escudo")
var _anim: AnimTeseu
## Lugar do escudo no braço (muda de lado no modelo novo: lá a espada fica
## na mão esquerda, então o escudo vai para o braço direito).
var _escudo_braco: Array = ESCUDO_BRACO
## Cenas de cinema: direção em que o Teseu anda sozinho (controle desligado).
var direcao_cinematica := Vector3.ZERO
var _golpe := 0.0


func _ready() -> void:
	add_to_group("jogador")
	vida = vida_maxima
	vida_mudou.emit(vida, vida_maxima)
	_criar_rastro()
	if _visual:
		_trocar_modelo_se_houver()
		_anim = AnimTeseu.new(_visual)
	if _espada:
		_espada.rotation = ESPADA_DESCANSO
	await get_tree().process_frame
	var jogo := get_tree().get_first_node_in_group("jogo")
	if jogo:
		jogo.novelo_mudou.connect(_atualizar_novelo)
		_atualizar_novelo(jogo.novelo, true)


func _physics_process(delta: float) -> void:
	_cooldown_ataque = max(_cooldown_ataque - delta, 0.0)
	_invulneravel = max(_invulneravel - delta, 0.0)
	if _visual:
		_visual.visible = _invulneravel <= 0.0 or int(_invulneravel * 12.0) % 2 == 0

	if global_position.y < altura_minima:
		_resgatar_do_vazio()
		return

	var entrada := Vector2.ZERO
	if _controle_ativo:
		entrada = Input.get_vector("mover_esquerda", "mover_direita", "mover_cima", "mover_baixo")
	elif direcao_cinematica != Vector3.ZERO:
		entrada = Vector2(direcao_cinematica.x, direcao_cinematica.z)
	_definir_defesa(_controle_ativo and Input.is_action_pressed("defender"))
	# A câmera olha para -Z, então "cima" na tela é -Z no mundo.
	var direcao := Vector3(entrada.x, 0.0, entrada.y)
	if direcao.length() > 0.1:
		direcao = direcao.normalized()
		_direcao_olhar = direcao
		if _visual:
			var alvo := atan2(direcao.x, direcao.z)
			_visual.rotation.y = lerp_angle(_visual.rotation.y, alvo, 15.0 * delta)

	# o empurrão entra na velocidade e é resolvido pelo move_and_slide,
	# então a parede segura o Teseu (antes ele era teleportado e atravessava)
	_empurrao = _empurrao.move_toward(Vector3.ZERO, 30.0 * delta)
	var vel := velocidade * (velocidade_escudo if defendendo else 1.0)
	velocity.x = direcao.x * vel + _empurrao.x
	velocity.z = direcao.z * vel + _empurrao.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - 20.0 * delta
	move_and_slide()
	_verificar_empurrao(direcao, delta)
	_passos(direcao, delta)
	_animar(delta)

	if not _controle_ativo:
		return
	if Input.is_action_just_pressed("atacar") and _cooldown_ataque <= 0.0 and not defendendo:
		_atacar()
	if Input.is_action_just_pressed("interagir"):
		_interagir()


# --------------------------------------------------------------------------
func _verificar_empurrao(direcao: Vector3, delta: float) -> void:
	var empurravel: Node = null
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var obj := col.get_collider()
		if obj and obj.is_in_group("empurravel") and direcao.dot(-col.get_normal()) > 0.7:
			empurravel = obj
			break
	if empurravel == null:
		_tempo_empurrando = 0.0
		return
	_tempo_empurrando += delta
	if _tempo_empurrando >= tempo_para_empurrar:
		_tempo_empurrando = 0.0
		# Empurra só nas 4 direções da grade.
		var eixo := Vector3(signf(direcao.x), 0, 0) if absf(direcao.x) > absf(direcao.z) \
			else Vector3(0, 0, signf(direcao.z))
		empurravel.empurrar(eixo)


func _atacar() -> void:
	_cooldown_ataque = 0.32
	_golpe = 0.28
	Som.tocar("espada")
	if _anim:
		_anim.golpe()
	# golpe em arco (da direita para a esquerda), com rastro de corte
	if _espada:
		var tw := create_tween()
		_espada.rotation = Vector3(0.0, -1.7, 0.0)
		tw.tween_property(_espada, "rotation:y", 1.5, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.05)
		tw.tween_property(_espada, "rotation", ESPADA_DESCANSO, 0.12)
	if _rastro:
		_rastro.visible = true
		var mat := _rastro.material_override as StandardMaterial3D
		mat.albedo_color.a = 0.55
		var tr := create_tween()
		tr.tween_property(mat, "albedo_color:a", 0.0, 0.22).set_delay(0.06)
		tr.tween_callback(func(): _rastro.visible = false)
	# acerta tudo num arco de ~200° à frente
	var acertou := 0
	var derrubou := false
	for inimigo in get_tree().get_nodes_in_group("inimigo"):
		var alvo := inimigo as Node3D
		if alvo == null or not alvo.has_method("levar_dano"):
			continue
		var d := alvo.global_position - global_position
		d.y = 0
		var extra = alvo.get("raio_acerto")
		var raio := 1.55 + (float(extra) if extra != null else 0.0)
		if d.length() < raio and (d.length() < 0.5 or _direcao_olhar.dot(d.normalized()) > -0.2):
			alvo.levar_dano(dano_ataque, d.normalized() if d.length() > 0.01 else _direcao_olhar)
			Efeitos.faisca(alvo.global_position.lerp(global_position, 0.35) + Vector3.UP * 0.8)
			acertou += 1
			var v = alvo.get("vida")
			if v != null and int(v) <= 0:
				derrubou = true
	# a espada também quebra as pedras arremessadas
	for pedra in get_tree().get_nodes_in_group("projetil"):
		var dp: Vector3 = pedra.global_position - global_position
		dp.y = 0
		if dp.length() < 1.6 and (dp.length() < 0.5 or _direcao_olhar.dot(dp.normalized()) > -0.2):
			pedra.quebrar()
	# ânforas do tutorial (e outros objetos que quebram)
	for obj in get_tree().get_nodes_in_group("quebravel"):
		var o := obj as Node3D
		var dq := o.global_position - global_position
		dq.y = 0
		if dq.length() < 1.5 and (dq.length() < 0.5 or _direcao_olhar.dot(dq.normalized()) > -0.2):
			o.quebrar()
			acertou += 1
	# PESO NO GOLPE: congela um instante, treme a câmera e, se derrubou,
	# a câmera dá um "soco" de zoom
	if acertou > 0:
		acertos_total += acertou
		Efeitos.congelar(get_tree(), 0.09 if derrubou else 0.06)
		var cam := get_viewport().get_camera_3d()
		if cam and cam.has_method("tremer"):
			cam.tremer(0.18 if derrubou else 0.1)
			if derrubou:
				cam.soco(1.0)


## Malha em meia-lua do rastro do golpe (criada uma vez, por código).
func _criar_rastro() -> void:
	if _visual == null:
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 24
	var ini := -1.7
	var fim := 1.5
	for i in n:
		var a0 := lerpf(ini, fim, float(i) / n)
		var a1 := lerpf(ini, fim, float(i + 1) / n)
		var f0 := float(i) / n
		var f1 := float(i + 1) / n
		var p0i := Vector3(sin(a0), 0, cos(a0)) * 0.55
		var p0e := Vector3(sin(a0), 0, cos(a0)) * 1.15
		var p1i := Vector3(sin(a1), 0, cos(a1)) * 0.55
		var p1e := Vector3(sin(a1), 0, cos(a1)) * 1.15
		for par in [[p0i, f0], [p0e, f0], [p1e, f1], [p0i, f0], [p1e, f1], [p1i, f1]]:
			st.set_color(Color(1, 1, 1, par[1] * par[1]))
			st.add_vertex(par[0])
	_rastro = MeshInstance3D.new()
	_rastro.name = "Rastro"
	_rastro.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(0.82, 0.92, 1.0, 0.0)
	_rastro.material_override = mat
	_rastro.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rastro.position = Vector3(0, 0.45, 0)
	_rastro.visible = false
	_visual.add_child(_rastro)


func _interagir() -> void:
	var melhor: Node3D = null
	var menor := alcance_interacao
	for n in get_tree().get_nodes_in_group("interagivel"):
		var obj := n as Node3D
		if obj == null:
			continue
		var d := obj.global_position.distance_to(global_position)
		if d < menor:
			menor = d
			melhor = obj
	if melhor and melhor.has_method("interagir"):
		melhor.interagir(self)


# --------------------------------------------------------------------------
## bloqueio_total: se o escudo pegar, o dano vai a zero (pedras).
func levar_dano(quantidade: int, direcao: Vector3 = Vector3.ZERO, bloqueio_total := false) -> void:
	if _invulneravel > 0.0 or vida <= 0:
		return
	if bloqueia(direcao):
		# escudo: o golpe vem da frente. Empurra um pouco e reduz o dano.
		var d0 := Vector3(direcao.x, 0, direcao.z).normalized()
		_empurrao = d0 * forca_empurrao * 0.6
		Som.tocar("bloqueio")
		bloqueios_total += 1
		if _escudo:
			Efeitos.faisca(_escudo.global_position + Vector3.UP * 0.1, Color(1.0, 0.95, 0.7))
			var tw := create_tween()
			tw.tween_property(_escudo, "position", ESCUDO_FRENTE[0] - Vector3(0, 0, 0.12), 0.05)
			tw.tween_property(_escudo, "position", ESCUDO_FRENTE[0], 0.12)
		quantidade = 0 if bloqueio_total else quantidade / 2
		if quantidade <= 0:
			_invulneravel = 0.25
			return
	vida = max(vida - quantidade, 0)
	_invulneravel = 1.0
	vida_mudou.emit(vida, vida_maxima)
	Som.tocar("dano")
	if _anim:
		_anim.reagir_dano()
	if direcao != Vector3.ZERO:
		var d := Vector3(direcao.x, 0, direcao.z).normalized()
		_empurrao = d * forca_empurrao
	if vida == 0:
		_controle_ativo = false
		if _anim:
			_anim.morrer()
		var jogo := get_tree().get_first_node_in_group("jogo")
		if jogo:
			jogo.jogador_morreu()


## Pernas e braços do modelo (pivôs do Blender): anda, ergue o escudo, golpeia.
func _animar(delta: float) -> void:
	if _anim == null:
		return
	_golpe = maxf(_golpe - delta, 0.0)
	var h := Vector2(velocity.x, velocity.z).length()
	_anim.defendendo = defendendo
	_anim.travar_braco_e = defendendo
	_anim.travar_braco_d = _golpe > 0.0
	if defendendo:
		_anim.posar_braco(_anim.braco_e, -1.45, delta)
	if _golpe > 0.0:
		# braço da espada: sobe e desce acompanhando o arco do golpe
		_anim.posar_braco(_anim.braco_d, -1.9 if _golpe > 0.14 else -0.6, delta, 30.0)
	_anim.atualizar(delta, clampf(h / velocidade, 0.0, 1.0))


## O escudo pega o golpe? (direcao = para onde o golpe empurra o Teseu)
func bloqueia(direcao: Vector3) -> bool:
	if not defendendo or direcao == Vector3.ZERO:
		return false
	var vindo_de := -Vector3(direcao.x, 0, direcao.z).normalized()
	return _direcao_olhar.dot(vindo_de) > angulo_bloqueio


func _definir_defesa(ligar: bool) -> void:
	if ligar == defendendo:
		return
	defendendo = ligar
	if _escudo == null:
		return
	var alvo: Array = ESCUDO_FRENTE if ligar else _escudo_braco
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_escudo, "position", alvo[0], 0.08)
	tw.tween_property(_escudo, "rotation:y", deg_to_rad(alvo[1]), 0.08)
	if _espada and ligar:
		tw.tween_property(_espada, "rotation", Vector3(0.3, -1.9, 0.0), 0.08)
	elif _espada:
		tw.tween_property(_espada, "rotation", ESPADA_DESCANSO, 0.1)


func _passos(direcao: Vector3, delta: float) -> void:
	if direcao.length() < 0.1 or not is_on_floor():
		_passo = 0.05
		return
	_passo -= delta
	if _passo <= 0.0:
		_passo = 0.42 if defendendo else 0.3
		_pe = 1 - _pe
		Som.tocar("passo%d" % (_pe + 1), 0.0, 0.1)


func curar(quantidade: int) -> void:
	if quantidade > 0 and vida < vida_maxima:
		Som.tocar("cura")
	vida = mini(vida + quantidade, vida_maxima)
	vida_mudou.emit(vida, vida_maxima)


func renascer(posicao: Vector3) -> void:
	global_position = posicao
	velocity = Vector3.ZERO
	_empurrao = Vector3.ZERO
	vida = vida_maxima
	_invulneravel = 1.5
	_controle_ativo = true
	if _anim:
		_anim.renascer()
	vida_mudou.emit(vida, vida_maxima)
	Som.tocar("novelo")
	Efeitos.poeira(posicao, 12, 0.5)


## Rede de segurança: se algo empurrar o Teseu para fora do mapa,
## ele volta ao último checkpoint sem gastar o novelo.
## Joga o Teseu longe (investida do Minotauro). A física segura nas paredes.
func arremessar(impulso: Vector3) -> void:
	_empurrao = Vector3(impulso.x, 0, impulso.z)


## Liga/desliga o controle (cenas, telas de fim).
func definir_controle(ativo: bool) -> void:
	_controle_ativo = ativo
	if not ativo:
		_definir_defesa(false)


func _resgatar_do_vazio() -> void:
	var jogo := get_tree().get_first_node_in_group("jogo")
	global_position = jogo.checkpoint if jogo else Vector3(0, 1, 0)
	velocity = Vector3.ZERO
	_empurrao = Vector3.ZERO
	_invulneravel = 1.0


## O novelo na cabeça encolhe conforme as voltas acabam.
func _atualizar_novelo(restante: int, instantaneo := false) -> void:
	if _novelo == null:
		return
	var jogo := get_tree().get_first_node_in_group("jogo")
	var total: int = jogo.novelo_inicial if jogo else 3
	var alvo := Vector3.ONE * (0.35 + 0.65 * float(restante) / float(max(total, 1)))
	if restante <= 0:
		alvo = Vector3.ONE * 0.01
	if instantaneo:
		_novelo.scale = alvo
		return
	var tw := create_tween()
	tw.tween_property(_novelo, "scale", alvo * 1.3, 0.12)
	tw.tween_property(_novelo, "scale", alvo, 0.25).set_trans(Tween.TRANS_BACK)


## Gesto de pantomima nas cenas: "sim", "nao", "vitoria", "chamar", "susto".
func gesto(nome: String, dur := 1.0) -> void:
	if _anim:
		_anim.gesto(nome, dur)


## Troca o boneco antigo pelo teseu_novo.glb (se ele existir no projeto).
## Cria  Visual/Corpo (pivô nos pés, é ele que a AnimTeseu anima)
##         └── Modelo (o .glb, escalado e centralizado)
func _trocar_modelo_se_houver() -> void:
	if not ResourceLoader.exists(MODELO_NOVO):
		return
	var cena := load(MODELO_NOVO) as PackedScene
	if cena == null:
		return
	var antigo := _visual.get_node_or_null("Corpo")
	# a cena já usa o modelo novo (é o normal agora): só os ajustes
	if antigo and antigo.scene_file_path == MODELO_NOVO:
		_ajustes_modelo_novo()
		return
	if antigo:
		_visual.remove_child(antigo)
		antigo.queue_free()
	var corpo := Node3D.new()
	corpo.name = "Corpo"
	_visual.add_child(corpo)
	var modelo := cena.instantiate() as Node3D
	modelo.name = "Modelo"
	corpo.add_child(modelo)
	# caixa que envolve todas as malhas, no espaço do Corpo
	var caixa := AABB()
	var primeira := true
	var inv := corpo.global_transform.affine_inverse()
	for mi in modelo.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var c := (inv * m.global_transform) * m.get_aabb()
		caixa = c if primeira else caixa.merge(c)
		primeira = false
	if primeira or caixa.size.y < 0.001:
		return
	var esc := altura_modelo_novo / caixa.size.y
	var base := Basis.from_euler(Vector3(0, deg_to_rad(giro_modelo_novo), 0)).scaled(Vector3.ONE * esc)
	var pe := Vector3(caixa.get_center().x, caixa.position.y, caixa.get_center().z)
	modelo.transform = Transform3D(base, -(base * pe))
	_ajustes_modelo_novo()


## Novelo no alto da cabeça, espada extra escondida (o modelo já tem espada)
## e escudo no braço direito.
func _ajustes_modelo_novo() -> void:
	if _novelo:
		_novelo.position.y = altura_modelo_novo + 0.04
	if _espada and esconder_espada_extra:
		_espada.visible = false
	if _escudo:
		_escudo_braco = [Vector3(-0.34, 0.45, 0.06), -65.0]
		_escudo.position = _escudo_braco[0]
		_escudo.rotation.y = deg_to_rad(_escudo_braco[1])
