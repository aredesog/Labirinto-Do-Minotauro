class_name FioAriadne
extends MeshInstance3D
## O FIO DE ARIADNE de verdade: uma fita vermelha que sai do novelo na cabeça
## do Teseu e se desenrola no chão por onde ele anda, desde a porta onde ele
## chegou (o checkpoint). Quando ele cai, o fio o PUXA DE VOLTA pelo mesmo
## caminho até a porta — é a "vida" do jogo contada pelo próprio mito.
##
## Computação Gráfica: a malha é refeita a cada quadro (ImmediateMesh) como
## uma fita (triangle strip): para cada ponto do caminho, a tangente
##   t = p[i+1] - p[i-1]
## dá a direção, e o vetor lateral  l = normalize(-t.z, 0, t.x) * largura/2
## abre a fita para os dois lados (p + l, p - l).

const PASSO := 0.2            ## distância mínima entre pontos gravados (m)
const MAX_PONTOS := 800
const LARGURA := 0.075
const ALTURA_CHAO := 0.035

var pontos := PackedVector3Array()
var alvo: Node3D
var puxando := false

var _imesh: ImmediateMesh
var _mat: StandardMaterial3D
var _t := 0.0


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	_imesh = ImmediateMesh.new()
	mesh = _imesh
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color("#c0302a")
	_mat.emission_enabled = true          # brilha de leve (e o toon não converte)
	_mat.emission = Color("#ff3a2a")
	_mat.emission_energy_multiplier = 0.45
	_mat.roughness = 0.6
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Recomeça o fio num ponto (chegada por um portal, renascer).
func comecar(pos: Vector3) -> void:
	pontos.clear()
	pontos.append(_chao(pos))


func _chao(p: Vector3) -> Vector3:
	return Vector3(p.x, p.y + ALTURA_CHAO, p.z)


func _process(delta: float) -> void:
	_t += delta
	if alvo == null or not is_instance_valid(alvo):
		alvo = get_tree().get_first_node_in_group("jogador") as Node3D
		if alvo == null:
			return
	if pontos.is_empty():
		comecar(alvo.global_position)
	if not puxando:
		var p := _chao(alvo.global_position)
		var ultimo := pontos[pontos.size() - 1]
		var d := p.distance_to(ultimo)
		if d > 4.0:
			comecar(p)             # pulo grande (resgate do vazio): fio novo
		elif d > PASSO:
			pontos.append(p)
			if pontos.size() > MAX_PONTOS:
				pontos.remove_at(1)  # mantém o começo (a porta)
	_desenhar()


func _desenhar() -> void:
	_imesh.clear_surfaces()
	if alvo == null or pontos.is_empty():
		return
	# caminho no chão + um trecho subindo do chão até o novelo na cabeça
	var caminho := pontos.duplicate()
	var pe := _chao(alvo.global_position)
	if caminho[caminho.size() - 1].distance_to(pe) > 0.02:
		caminho.append(pe)
	var novelo := alvo.get_node_or_null("Visual/Novelo") as Node3D
	var cabeca := novelo.global_position if novelo and novelo.scale.x > 0.05 else Vector3.ZERO
	if caminho.size() < 2 and cabeca == Vector3.ZERO:
		return
	_imesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, _mat)
	var lateral := Vector3.RIGHT * LARGURA * 0.5
	var n := caminho.size()
	for i in n:
		var a := caminho[maxi(i - 1, 0)]
		var b := caminho[mini(i + 1, n - 1)]
		var t := b - a
		t.y = 0.0
		if t.length() > 0.001:
			lateral = Vector3(-t.z, 0.0, t.x).normalized() * LARGURA * 0.5
		var p := caminho[i]
		_imesh.surface_set_normal(Vector3.UP)
		_imesh.surface_add_vertex(p + lateral)
		_imesh.surface_add_vertex(p - lateral)
	if cabeca != Vector3.ZERO:
		# do pé até a cabeça, balançando de leve
		var base := caminho[n - 1]
		for k in range(1, 6):
			var f := k / 5.0
			var q := base.lerp(cabeca, f)
			q += Vector3(sin(_t * 3.0 + f * 4.0), 0, cos(_t * 2.5 + f * 3.0)) * 0.04 * sin(f * PI)
			_imesh.surface_add_vertex(q + lateral * (1.0 - f * 0.4))
			_imesh.surface_add_vertex(q - lateral * (1.0 - f * 0.4))
	_imesh.surface_end()


## Puxa o Teseu de volta pelo caminho do fio até o começo (a porta).
## Durante o puxão, o fio vai sendo enrolado.
func puxar(teseu: Node3D, dur := 0.85) -> void:
	if pontos.is_empty():
		return
	puxando = true
	# caminho de volta: posição atual -> ... -> começo
	var volta := PackedVector3Array()
	volta.append(_chao(teseu.global_position))
	for i in range(pontos.size() - 1, -1, -1):
		volta.append(pontos[i])
	var acum := PackedFloat32Array([0.0])
	for i in range(1, volta.size()):
		acum.append(acum[i - 1] + volta[i].distance_to(volta[i - 1]))
	var total := acum[acum.size() - 1]
	if total < 0.05:
		puxando = false
		return
	var y0 := teseu.global_position.y
	Som.tocar("novelo")
	var tw := create_tween()
	tw.tween_method(func(k: float):
		if not is_instance_valid(teseu):
			return
		var dist := total * k
		var seg := 1
		while seg < volta.size() - 1 and acum[seg] < dist:
			seg += 1
		var ini := acum[seg - 1]
		var tam := maxf(acum[seg] - ini, 0.0001)
		var pos := volta[seg - 1].lerp(volta[seg], clampf((dist - ini) / tam, 0.0, 1.0))
		teseu.global_position = Vector3(pos.x, y0 + sin(k * PI) * 0.35, pos.z)
		if "velocity" in teseu:
			teseu.velocity = Vector3.ZERO
		# o que ainda não foi enrolado: do começo até o ponto atual
		var resto := PackedVector3Array()
		for i in range(volta.size() - 1, seg - 1, -1):
			resto.append(volta[i])
		pontos = resto, 0.0, 1.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	puxando = false
