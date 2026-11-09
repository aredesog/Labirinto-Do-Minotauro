class_name Labirinto
extends AreaSala
## O LABIRINTO de Dédalo, construído em volta da arena: o Minotauro mora no
## centro, como no mito. É a última etapa antes do chefe: o portal da 10ª sala
## traz o Teseu para a entrada (borda NORTE, do outro lado do portão, então ele
## precisa contornar a arena); ele atravessa os corredores até o portão sul da
## arena, que abre — e fecha atrás dele quando ele entra.
##
## Tamanho certo para quem nunca jogou: depois do backtracking, os becos sem
## saída ganham um atalho (labirinto "trançado") e, se o caminho certo ficar
## fora de CAMINHO_MIN..CAMINHO_MAX células, sorteia de novo. Testado em
## Python com 400 sementes: caminho de 13 a 36 células (média ~26, ~80 m).
##
## Sorteado a cada partida (usa a semente do jogo), com o algoritmo de
## "backtracking recursivo" (busca em profundidade com pilha): ele gera um
## labirinto PERFEITO — existe exatamente um caminho entre quaisquer duas
## células, então a saída sempre existe e não há ciclos.
##
## Sem texto, o jogador se orienta por:
##   - uma COLUNA DE LUZ VERMELHA sobre a arena, visível de todo corredor;
##   - o RUGIDO do Minotauro, mais alto quanto mais perto do centro;
##   - o FIO DE ARIADNE no chão, mostrando por onde ele já passou.
##
## Desenho: paredes, pilares e piso são as peças do próprio jogo, numa
## MultiMesh cada (poucas chamadas de desenho); a colisão é uma caixa por parede.

const N := 13            ## células por lado
const CEL := 3.2         ## tamanho da célula (m)
const MIOLO_INI := 4     ## o miolo 5x5 (células 4..8) é a arena (16 m)
const MIOLO_FIM := 8
const COL_PORTAO := 6    ## coluna do portão (sul do miolo)
const CAMINHO_MIN := 12
const CAMINHO_MAX := 36
const MOD := "res://assets/modelos/cenario/"

var paredes_h: Array = []   ## [linha 0..N][coluna]: parede na borda norte da célula
var paredes_v: Array = []   ## [linha][coluna 0..N]: parede na borda oeste da célula
var col_entrada := 7
var arena: Node3D

var _coluna_luz: MeshInstance3D
var _t_rugido := 2.0
var _gatilho: Area3D


func _init() -> void:
	tipo = "labirinto"
	nome_sala = "Labirinto"
	meio_tamanho = Vector2(N * CEL / 2.0, N * CEL / 2.0)
	zoom_camera = 1.0
	tilt_shift = 0.8


## Gera e constrói. rng: o sorteio da partida.
func montar(rng: RandomNumberGenerator, arena_: Node3D) -> void:
	arena = arena_
	for tentativa in 25:
		_gerar(rng)
		var n := _tamanho_caminho()
		if n >= CAMINHO_MIN and n <= CAMINHO_MAX:
			break
	_construir()


# --------------------------------------------------------------------------
# Geração (backtracking recursivo)
# --------------------------------------------------------------------------
func no_miolo(c: int, r: int) -> bool:
	return c >= MIOLO_INI and c <= MIOLO_FIM and r >= MIOLO_INI and r <= MIOLO_FIM


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
		for c in N:
			linha.append(no_miolo(c, r))   # o miolo (arena) fica de fora
		visitada.append(linha)
	col_entrada = rng.randi_range(1, N - 2)
	var pilha: Array[Vector2i] = [Vector2i(col_entrada, 0)]
	visitada[0][col_entrada] = true
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
	# trança: cada beco sem saída ganha uma passagem extra (atalhos, menos
	# voltas para quem se perde)
	for r in N:
		for c in N:
			if no_miolo(c, r):
				continue
			var a := Vector2i(c, r)
			var abertos := 0
			var fechados: Array[Vector2i] = []
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var b := a + d
				if b.x < 0 or b.x >= N or b.y < 0 or b.y >= N or no_miolo(b.x, b.y):
					continue
				if passa(a, b):
					abertos += 1
				else:
					fechados.append(b)
			if abertos == 1 and not fechados.is_empty():
				_abrir(a, fechados[rng.randi_range(0, fechados.size() - 1)])
	# entrada (borda norte) e passagem para o portão da arena (sul do miolo)
	paredes_h[0][col_entrada] = false
	paredes_h[MIOLO_FIM + 1][COL_PORTAO] = false


func _abrir(a: Vector2i, b: Vector2i) -> void:
	if b.y == a.y + 1:
		paredes_h[b.y][a.x] = false
	elif b.y == a.y - 1:
		paredes_h[a.y][a.x] = false
	elif b.x == a.x + 1:
		paredes_v[a.y][b.x] = false
	else:
		paredes_v[a.y][a.x] = false


## Pode andar da célula a para a vizinha b?
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


## Caminho certo (busca em largura) da entrada até o portão da arena, em
## coordenadas globais — usado pelo teste e pelas cenas.
func caminho_solucao() -> PackedVector3Array:
	var celulas := _caminho_celulas()
	var lista := PackedVector3Array()
	for cel in celulas:
		lista.append(to_global(centro_celula(cel.x, cel.y)))
	if not celulas.is_empty():
		lista.append(to_global(Vector3(0, 0, 7.6)))   # diante do portão
	return lista


func _tamanho_caminho() -> int:
	return _caminho_celulas().size()


func _caminho_celulas() -> Array[Vector2i]:
	var ini := Vector2i(col_entrada, 0)
	var fim := Vector2i(COL_PORTAO, MIOLO_FIM + 1)
	var pai := {ini: ini}
	var fila: Array[Vector2i] = [ini]
	while not fila.is_empty():
		var a: Vector2i = fila.pop_front()
		if a == fim:
			break
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var b := a + d
			if not pai.has(b) and not no_miolo(b.x, b.y) and passa(a, b):
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
# Construção
# --------------------------------------------------------------------------
func _construir() -> void:
	var meio := N * CEL / 2.0
	# a parede do kit tem 1,5 m. Bordas externas: inteira. Por dentro, mais
	# baixa: 1,1 m nas "verticais" da tela e 0,8 m nas "horizontais" (a
	# câmera olha do sul, então essas não escondem o Teseu).
	var t_paredes: Array[Transform3D] = []
	var t_pilar: Array[Transform3D] = []
	var corpo := StaticBody3D.new()
	corpo.name = "Colisao"
	corpo.collision_layer = 1
	corpo.collision_mask = 0
	add_child(corpo)
	var vertices := {}
	# paredes horizontais (bordas norte/sul das células)
	for r in N + 1:
		for c in N:
			if not paredes_h[r][c]:
				continue
			var dentro_a := r - 1 >= 0 and no_miolo(c, r - 1)
			var dentro_b := r < N and no_miolo(c, r)
			if dentro_a and dentro_b:
				continue   # dentro da arena
			var z := (r - N / 2.0) * CEL
			var x0 := (c - N / 2.0) * CEL
			var borda := r == 0 or r == N
			_parede(t_paredes, corpo, Vector3(x0 + CEL / 2.0, 0, z), 0.0, 1.0 if borda else 0.55)
			vertices[Vector2i(c, r)] = true
			vertices[Vector2i(c + 1, r)] = true
	# paredes verticais (bordas oeste/leste)
	for r in N:
		for c in N + 1:
			if not paredes_v[r][c]:
				continue
			var dentro_a := c - 1 >= 0 and no_miolo(c - 1, r)
			var dentro_b := c < N and no_miolo(c, r)
			if dentro_a and dentro_b:
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
	# vestíbulo: entre a parede do miolo e a da arena, só se passa pelo portão
	for lado in [-1.0, 1.0]:
		_caixa(corpo, Vector3(5.6, 3.0, 1.0), Vector3(lado * 5.0, 1.5, 7.65))
	# piso (peças de 1 m, sem o chão da arena) + colisão
	var t_piso: Array[Transform3D] = []
	var lim := int(ceil(meio))
	for i in range(-lim, lim):
		for j in range(-lim, lim):
			if absf(i + 0.5) < 7.0 and absf(j + 0.5) < 7.0:
				continue
			t_piso.append(Transform3D(Basis.IDENTITY, Vector3(i + 0.5, 0, j + 0.5)))
	_multimesh("Piso", _partes(MOD + "piso.glb"), t_piso)
	_caixa(corpo, Vector3(meio * 2.0 + 1.0, 0.5, meio * 2.0 + 1.0), Vector3(0, -0.25, 0))
	# coluna de luz vermelha sobre a arena (o "norte" do jogador)
	_coluna_luz = MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = 1.6
	cil.bottom_radius = 2.6
	cil.height = 34.0
	_coluna_luz.mesh = cil
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(1.0, 0.15, 0.08, 0.22)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_coluna_luz.material_override = m
	_coluna_luz.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_coluna_luz.position = Vector3(0, 17.0, 0)
	_coluna_luz.visible = false
	add_child(_coluna_luz)
	# gatilho logo depois do portão: o Teseu entrou na arena
	_gatilho = Area3D.new()
	_gatilho.collision_layer = 0
	_gatilho.collision_mask = 2
	add_child(_gatilho)
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(4.0, 2.0, 1.2)
	forma.shape = caixa
	forma.position = Vector3(0, 1.0, 5.9)
	_gatilho.add_child(forma)
	_gatilho.body_entered.connect(_ao_entrar_na_arena)


func _parede(lista: Array[Transform3D], corpo: StaticBody3D, centro: Vector3, giro: float, altura := 1.0) -> void:
	# 3 peças de 1 m esticadas para cobrir a borda de 3,2 m (escala LOCAL)
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


## Malhas de um .glb com a transformação de cada uma (uma peça pode ter várias).
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
	return to_global(centro_celula(col_entrada, 0) + Vector3(0, 0.1, -CEL * 0.2))


func ao_chegar() -> void:
	visitada = true
	var jogo := get_tree().get_first_node_in_group("jogo")
	if jogo:
		jogo.set("sala_atual", null)   # nada para "reiniciar" aqui
	_t_rugido = 1.5
	get_tree().call_group("porta_minotauro", "abrir")
	Som.musica("enigma", 1.0)


func esta_concluida() -> bool:
	return false


## Liga a coluna de luz (as cenas também usam, no sobrevoo).
func mostrar_coluna(sim: bool) -> void:
	if _coluna_luz:
		_coluna_luz.visible = sim


func _process(delta: float) -> void:
	var jogo := get_tree().get_first_node_in_group("jogo")
	var aqui: bool = jogo != null and jogo.get("area_atual") == self
	if _coluna_luz and not bool(jogo.get("em_cinematica") if jogo else false):
		_coluna_luz.visible = aqui
	if _coluna_luz and _coluna_luz.visible:
		var mat := _coluna_luz.material_override as StandardMaterial3D
		mat.albedo_color.a = 0.18 + sin(Time.get_ticks_msec() * 0.003) * 0.06
	if not aqui:
		return
	# o rugido guia: quanto mais perto do centro, mais alto
	_t_rugido -= delta
	if _t_rugido <= 0.0:
		_t_rugido = 6.0
		var teseu := get_tree().get_first_node_in_group("jogador") as Node3D
		if teseu:
			var d := Vector2(teseu.global_position.x - global_position.x, teseu.global_position.z - global_position.z).length()
			Som.tocar("rugido", lerpf(-6.0, -26.0, clampf((d - 8.0) / 22.0, 0.0, 1.0)), 0.0, 0.8)


func _ao_entrar_na_arena(corpo: Node3D) -> void:
	if not corpo.is_in_group("jogador"):
		return
	var jogo := get_tree().get_first_node_in_group("jogo")
	if jogo and jogo.get("area_atual") == self and jogo.has_method("entrar_na_arena"):
		jogo.entrar_na_arena(arena)
