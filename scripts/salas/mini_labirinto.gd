class_name MiniLabirinto
extends AreaSala
## Um trecho de labirinto no caminho de cada ENIGMA: o portal que sorteou
## uma sala de enigma traz o Teseu primeiro para cá (só na primeira vez).
## Entrada e saída ficam em bordas sorteadas (nunca a mesma borda), então o
## portal dourado que leva ao enigma muda de lugar a cada labirinto.
##
## Pequeno de propósito (7x7 células): mesmo algoritmo do labirinto grande
## (backtracking recursivo + "trança" nos becos sem saída), e se o caminho
## certo ficar fora de CAMINHO_MIN..CAMINHO_MAX células, sorteia de novo.
## Simulado em Python com 2000 sementes: mediana de 13 células (~40 m).
##
## Sem texto, a saída é indicada por uma COLUNA DE LUZ DOURADA (visível de
## todo corredor), pela seta do HUD com os ícones do enigma que espera do
## outro lado, e o fio de Ariadne marca por onde o Teseu já passou.

const N := 7
const CEL := 3.2
const CAMINHO_MIN := 10
const CAMINHO_MAX := 20
const MOD := "res://assets/modelos/cenario/"
const COR := Color("#ffc94a")

## A sala de enigma para onde a saída leva.
var destino: Node
var paredes_h: Array = []   ## [linha 0..N][coluna]: parede na borda norte da célula
var paredes_v: Array = []   ## [linha][coluna 0..N]: parede na borda oeste da célula
## Bordas: 0 norte, 1 leste, 2 sul, 3 oeste.
var cel_entrada := Vector2i(3, N - 1)
var cel_saida := Vector2i(3, 0)
var lado_entrada := 2
var lado_saida := 0

var _coluna_luz: MeshInstance3D
var _gatilho: Area3D


func _init() -> void:
	tipo = "corredor"
	nome_sala = "Labirinto"
	meio_tamanho = Vector2(N * CEL / 2.0, N * CEL / 2.0)
	zoom_camera = 1.0
	tilt_shift = 0.8


func montar(rng: RandomNumberGenerator, destino_: Node) -> void:
	destino = destino_
	for tentativa in 30:
		_gerar(rng)
		var n := _caminho_celulas().size()
		if n >= CAMINHO_MIN and n <= CAMINHO_MAX:
			break
	_construir()


# --------------------------------------------------------------------------
# Geração
# --------------------------------------------------------------------------
func _gerar(rng: RandomNumberGenerator) -> void:
	paredes_h.clear()
	paredes_v.clear()
	for r in N + 1:
		var linha := []
		linha.resize(N)
		linha.fill(true)
		paredes_h.append(linha)
	for r in N:
		var linha := []
		linha.resize(N + 1)
		linha.fill(true)
		paredes_v.append(linha)
	var visitada := []
	for r in N:
		var linha := []
		linha.resize(N)
		linha.fill(false)
		visitada.append(linha)
	lado_entrada = rng.randi_range(0, 3)
	lado_saida = (lado_entrada + rng.randi_range(1, 3)) % 4   # outra borda
	cel_entrada = _celula_da_borda(lado_entrada, rng.randi_range(1, N - 2))
	cel_saida = _celula_da_borda(lado_saida, rng.randi_range(1, N - 2))
	var pilha: Array[Vector2i] = [cel_entrada]
	visitada[cel_entrada.y][cel_entrada.x] = true
	while not pilha.is_empty():
		var atual: Vector2i = pilha[pilha.size() - 1]
		var vizinhos: Array[Vector2i] = []
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var v := atual + d
			if v.x >= 0 and v.x < N and v.y >= 0 and v.y < N and not visitada[v.y][v.x]:
				vizinhos.append(v)
		if vizinhos.is_empty():
			pilha.pop_back()
			continue
		var prox: Vector2i = vizinhos[rng.randi_range(0, vizinhos.size() - 1)]
		_abrir(atual, prox)
		visitada[prox.y][prox.x] = true
		pilha.append(prox)
	# trança: becos sem saída ganham uma passagem extra
	for r in N:
		for c in N:
			var a := Vector2i(c, r)
			var abertos := 0
			var fechados: Array[Vector2i] = []
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var b := a + d
				if b.x < 0 or b.x >= N or b.y < 0 or b.y >= N:
					continue
				if passa(a, b):
					abertos += 1
				else:
					fechados.append(b)
			if abertos == 1 and not fechados.is_empty():
				_abrir(a, fechados[rng.randi_range(0, fechados.size() - 1)])
	# abre a saída na borda sorteada
	match lado_saida:
		0:
			paredes_h[0][cel_saida.x] = false
		2:
			paredes_h[N][cel_saida.x] = false
		1:
			paredes_v[cel_saida.y][N] = false
		_:
			paredes_v[cel_saida.y][0] = false


func _celula_da_borda(lado: int, k: int) -> Vector2i:
	match lado:
		0:
			return Vector2i(k, 0)
		1:
			return Vector2i(N - 1, k)
		2:
			return Vector2i(k, N - 1)
	return Vector2i(0, k)


## Direção "para fora" de uma borda.
static func _para_fora(lado: int) -> Vector3:
	match lado:
		0:
			return Vector3.FORWARD
		1:
			return Vector3.RIGHT
		2:
			return Vector3.BACK
	return Vector3.LEFT


## Meio da abertura da saída (local).
func _borda_saida() -> Vector3:
	return centro_celula(cel_saida.x, cel_saida.y) + _para_fora(lado_saida) * (CEL / 2.0)


func _abrir(a: Vector2i, b: Vector2i) -> void:
	if b.y == a.y + 1:
		paredes_h[b.y][a.x] = false
	elif b.y == a.y - 1:
		paredes_h[a.y][a.x] = false
	elif b.x == a.x + 1:
		paredes_v[a.y][b.x] = false
	else:
		paredes_v[a.y][a.x] = false


func passa(a: Vector2i, b: Vector2i) -> bool:
	if b.x < 0 or b.x >= N or b.y < 0 or b.y >= N:
		return false
	if b.y == a.y + 1:
		return not paredes_h[b.y][a.x]
	if b.y == a.y - 1:
		return not paredes_h[a.y][a.x]
	if b.x == a.x + 1:
		return not paredes_v[a.y][b.x]
	return not paredes_v[a.y][a.x]


func centro_celula(c: int, r: int) -> Vector3:
	return Vector3((c - (N - 1) / 2.0) * CEL, 0.0, (r - (N - 1) / 2.0) * CEL)


## Caminho certo (busca em largura), em coordenadas globais, até a saída.
func caminho_solucao() -> PackedVector3Array:
	var lista := PackedVector3Array()
	for cel in _caminho_celulas():
		lista.append(to_global(centro_celula(cel.x, cel.y)))
	return lista


func _caminho_celulas() -> Array[Vector2i]:
	var ini := cel_entrada
	var fim := cel_saida
	var pai := {ini: ini}
	var fila: Array[Vector2i] = [ini]
	while not fila.is_empty():
		var a: Vector2i = fila.pop_front()
		if a == fim:
			break
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var b := a + d
			if not pai.has(b) and passa(a, b):
				pai[b] = a
				fila.append(b)
	var lista: Array[Vector2i] = []
	if not pai.has(fim):
		return lista
	var n := fim
	while true:
		lista.append(n)
		if n == ini:
			break
		n = pai[n]
	lista.reverse()
	return lista


# --------------------------------------------------------------------------
# Construção (as mesmas peças do labirinto grande, em MultiMesh)
# --------------------------------------------------------------------------
func _construir() -> void:
	var meio := N * CEL / 2.0
	var t_paredes: Array[Transform3D] = []
	var t_pilar: Array[Transform3D] = []
	var corpo := StaticBody3D.new()
	corpo.name = "Colisao"
	corpo.collision_layer = 1
	corpo.collision_mask = 0
	add_child(corpo)
	var vertices := {}
	for r in N + 1:
		for c in N:
			if not paredes_h[r][c]:
				continue
			var z := (r - N / 2.0) * CEL
			var x0 := (c - N / 2.0) * CEL
			var borda := r == 0 or r == N
			_parede(t_paredes, corpo, Vector3(x0 + CEL / 2.0, 0, z), 0.0, 1.0 if borda else 0.55)
			vertices[Vector2i(c, r)] = true
			vertices[Vector2i(c + 1, r)] = true
	for r in N:
		for c in N + 1:
			if not paredes_v[r][c]:
				continue
			var x := (c - N / 2.0) * CEL
			var z0 := (r - N / 2.0) * CEL
			var borda := c == 0 or c == N
			_parede(t_paredes, corpo, Vector3(x, 0, z0 + CEL / 2.0), PI / 2.0, 1.0 if borda else 0.75)
			vertices[Vector2i(c, r)] = true
			vertices[Vector2i(c, r + 1)] = true
	for v: Vector2i in vertices:
		t_pilar.append(Transform3D(Basis.from_scale(Vector3(1.0, 0.72, 1.0)),
			Vector3((v.x - N / 2.0) * CEL, 0, (v.y - N / 2.0) * CEL)))
	_multimesh("Paredes", _partes(MOD + "parede.glb"), t_paredes)
	_multimesh("Pilares", _partes(MOD + "pilar.glb"), t_pilar)
	var t_piso: Array[Transform3D] = []
	var lim := int(ceil(meio))
	for i in range(-lim, lim):
		for j in range(-lim, lim):
			t_piso.append(Transform3D(Basis.IDENTITY, Vector3(i + 0.5, 0, j + 0.5)))
	_multimesh("Piso", _partes(MOD + "piso.glb"), t_piso)
	_caixa(corpo, Vector3(meio * 2.0 + 4.0, 0.5, meio * 2.0 + 4.0), Vector3(0, -0.25, 0))
	# a saída: portal dourado na abertura da borda norte
	var fora := _para_fora(lado_saida)
	var borda := _borda_saida()
	var giro := Basis(Vector3.UP, atan2(fora.x, fora.z))   # +Z local -> para fora
	var portal := MeshInstance3D.new()
	portal.name = "PortalSaida"
	var q := QuadMesh.new()
	q.size = Vector2(CEL - 0.5, 2.6)
	portal.mesh = q
	var sm := ShaderMaterial.new()
	sm.shader = load("res://scripts/visual/portal.gdshader")
	sm.set_shader_parameter("cor", COR)
	portal.material_override = sm
	portal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	portal.transform = Transform3D(giro, borda + fora * 0.05 + Vector3.UP * 1.3)
	add_child(portal)
	var luz := OmniLight3D.new()
	luz.light_color = COR
	luz.light_energy = 1.6
	luz.omni_range = 5.0
	luz.position = borda - fora * 0.6 + Vector3.UP * 1.6
	add_child(luz)
	# atrás do portal não tem para onde ir
	var bloq := CollisionShape3D.new()
	var bb := BoxShape3D.new()
	bb.size = Vector3(CEL + 0.8, 3.0, 0.4)
	bloq.shape = bb
	bloq.transform = Transform3D(giro, borda + fora * 1.0 + Vector3.UP * 1.5)
	corpo.add_child(bloq)
	# coluna de luz dourada sobre a saída
	_coluna_luz = MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = 1.0
	cil.bottom_radius = 1.5
	cil.height = 30.0
	_coluna_luz.mesh = cil
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(COR.r, COR.g, COR.b, 0.2)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_coluna_luz.material_override = m
	_coluna_luz.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_coluna_luz.position = borda + fora * 0.4 + Vector3.UP * 15.0
	_coluna_luz.visible = false
	add_child(_coluna_luz)
	_gatilho = Area3D.new()
	_gatilho.collision_layer = 0
	_gatilho.collision_mask = 2
	add_child(_gatilho)
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(CEL - 0.4, 2.0, 0.9)
	forma.shape = caixa
	forma.transform = Transform3D(giro, borda + fora * 0.35 + Vector3.UP * 1.0)
	_gatilho.add_child(forma)
	_gatilho.body_entered.connect(_ao_sair)


func _parede(lista: Array[Transform3D], corpo: StaticBody3D, centro: Vector3, giro: float, altura := 1.0) -> void:
	var b := Basis(Vector3.UP, giro)
	var dir := b * Vector3.RIGHT
	for k in 3:
		var p := centro + dir * ((k - 1) * CEL / 3.0)
		lista.append(Transform3D(b * Basis.from_scale(Vector3(CEL / 3.0, altura, 1.0)), p))
	var tam := Vector3(CEL + 0.3, 3.0, 0.5) if giro == 0.0 else Vector3(0.5, 3.0, CEL + 0.3)
	_caixa(corpo, tam, centro + Vector3.UP * 1.5)


func _caixa(corpo: StaticBody3D, tam: Vector3, pos: Vector3) -> void:
	var f := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = tam
	f.shape = bx
	f.position = pos
	corpo.add_child(f)


func _partes(caminho: String) -> Array:
	var cena := load(caminho) as PackedScene
	if cena == null:
		return []
	var raiz := cena.instantiate() as Node3D
	var lista := []
	for n in raiz.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var xf := Transform3D.IDENTITY
		var no: Node = mi
		while no != raiz and no is Node3D:
			xf = (no as Node3D).transform * xf
			no = no.get_parent()
		lista.append([mi.mesh, xf])
	raiz.free()
	return lista


func _multimesh(nome: String, partes: Array, transformacoes: Array[Transform3D]) -> void:
	for i in partes.size():
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = partes[i][0]
		mm.instance_count = transformacoes.size()
		var local: Transform3D = partes[i][1]
		for k in transformacoes.size():
			mm.set_instance_transform(k, transformacoes[k] * local)
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "%s%d" % [nome, i]
		mmi.multimesh = mm
		add_child(mmi)


# --------------------------------------------------------------------------
# Jogo
# --------------------------------------------------------------------------
func ponto_de_chegada() -> Vector3:
	# perto da borda por onde ele "entrou"
	return to_global(centro_celula(cel_entrada.x, cel_entrada.y) + _para_fora(lado_entrada) * (CEL * 0.2) + Vector3.UP * 0.1)


## Ponto da saída (no portal dourado), em coordenadas globais.
func saida_global() -> Vector3:
	return to_global(_borda_saida() + _para_fora(lado_saida) * 0.35 + Vector3.UP * 0.1)


func ao_chegar() -> void:
	visitada = true
	var jogo := get_tree().get_first_node_in_group("jogo")
	if jogo:
		jogo.set("sala_atual", null)   # nada para "reiniciar" aqui
	Som.musica("exploracao", 1.0)


func esta_concluida() -> bool:
	return true


func _process(_delta: float) -> void:
	var jogo := get_tree().get_first_node_in_group("jogo")
	var aqui: bool = jogo != null and jogo.get("area_atual") == self
	if _coluna_luz:
		_coluna_luz.visible = aqui
		if aqui:
			var mat := _coluna_luz.material_override as StandardMaterial3D
			mat.albedo_color.a = 0.16 + sin(Time.get_ticks_msec() * 0.003) * 0.06


func _ao_sair(corpo: Node3D) -> void:
	if not corpo.is_in_group("jogador"):
		return
	var jogo := get_tree().get_first_node_in_group("jogo")
	if jogo and jogo.get("area_atual") == self and not bool(jogo.get("teleportando")) \
			and jogo.has_method("sair_do_labirinto"):
		jogo.sair_do_labirinto(self)
