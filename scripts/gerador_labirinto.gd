extends RefCounted
## Gera o labirinto numa grade de células (estilo Twilight Forest):
## 1. reserva retângulos para as salas (entrada, combate, fontes e chefe);
## 2. cava o labirinto nas células restantes por backtracking recursivo,
##    o que cria corredores longos e becos sem saída;
## 3. abre as portas das salas;
## 4. derruba algumas paredes a mais para criar ciclos (caminhos alternativos).
##
## Também guarda um grafo A* das células de corredor, usado pelos
## minitaurinhos errantes para perseguir o Teseu.

const N := Vector2i(0, -1)
const S := Vector2i(0, 1)
const L := Vector2i(1, 0)
const O := Vector2i(-1, 0)
const DIRECOES: Array[Vector2i] = [N, S, L, O]

var largura := 0
var altura := 0
var celula := 4.0          # tamanho de cada célula em metros
var rng := RandomNumberGenerator.new()

var parede_l: Array = []   # parede_l[y][x]: parede entre (x, y) e (x + 1, y)
var parede_s: Array = []   # parede_s[y][x]: parede entre (x, y) e (x, y + 1)
var sala_de: Array = []    # sala_de[y][x]: índice da sala ou -1 (corredor)

## Cada sala: {tipo, rect: Rect2i, portas: [{celula: Vector2i, dir: Vector2i}]}
var salas: Array = []

var _astar := AStar2D.new()


func gerar(p_largura: int, p_altura: int, p_celula: float, semente: int,
		n_combate: int, n_fontes: int, chance_ciclo: float) -> void:
	largura = p_largura
	altura = p_altura
	celula = p_celula
	if semente == 0:
		rng.randomize()
	else:
		rng.seed = semente

	parede_l.clear()
	parede_s.clear()
	sala_de.clear()
	salas.clear()
	for y in altura:
		var linha_l := []
		var linha_s := []
		var linha_sala := []
		for x in largura:
			linha_l.append(true)
			linha_s.append(true)
			linha_sala.append(-1)
		parede_l.append(linha_l)
		parede_s.append(linha_s)
		sala_de.append(linha_sala)

	# 1. Salas. Entrada embaixo no meio, chefe no fundo (norte).
	_reservar("entrada", Rect2i(largura / 2 - 1, altura - 3, 2, 2))
	_reservar("chefe", Rect2i(largura / 2 - 2, 1, 4, 4))
	_espalhar_salas("combate", n_combate, [Vector2i(3, 3), Vector2i(3, 2), Vector2i(2, 3)])
	_espalhar_salas("fonte", n_fontes, [Vector2i(2, 2)])

	for i in salas.size():
		var rect: Rect2i = salas[i].rect
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				sala_de[y][x] = i
				if x + 1 < rect.end.x:
					_abrir(Vector2i(x, y), L)
				if y + 1 < rect.end.y:
					_abrir(Vector2i(x, y), S)

	# 2. Labirinto nos corredores.
	_cavar_labirinto()

	# 3. Portas.
	for sala in salas:
		var n_portas := 1 if sala.tipo == "chefe" else 2
		_abrir_portas(sala, n_portas)

	# 4. Ciclos.
	for y in altura:
		for x in largura:
			var c := Vector2i(x, y)
			if not eh_corredor(c):
				continue
			for d in [L, S]:
				var v: Vector2i = c + d
				if dentro(v) and eh_corredor(v) and not aberto(c, d) and rng.randf() < chance_ciclo:
					_abrir(c, d)

	_montar_navegacao()


# --- consultas -------------------------------------------------------------

func dentro(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < largura and c.y < altura


func eh_corredor(c: Vector2i) -> bool:
	return dentro(c) and sala_de[c.y][c.x] == -1


func aberto(c: Vector2i, d: Vector2i) -> bool:
	var v := c + d
	if not dentro(c) or not dentro(v):
		return false
	match d:
		L:
			return not parede_l[c.y][c.x]
		O:
			return not parede_l[v.y][v.x]
		S:
			return not parede_s[c.y][c.x]
		_:
			return not parede_s[v.y][v.x]


## Centro da célula no mundo (y = 0, no chão).
func centro(c: Vector2i) -> Vector3:
	return Vector3((c.x - largura / 2.0 + 0.5) * celula, 0.0, (c.y - altura / 2.0 + 0.5) * celula)


func celula_de(posicao: Vector3) -> Vector2i:
	return Vector2i(floori(posicao.x / celula + largura / 2.0), floori(posicao.z / celula + altura / 2.0))


func centro_sala(sala: Dictionary) -> Vector3:
	var rect: Rect2i = sala.rect
	var a := centro(rect.position)
	var b := centro(rect.end - Vector2i.ONE)
	return (a + b) / 2.0


func tamanho_sala(sala: Dictionary) -> Vector2:
	var rect: Rect2i = sala.rect
	return Vector2(rect.size.x * celula, rect.size.y * celula)


## Caminho entre duas células de corredor (lista de células, incluindo as pontas).
## Vazio se alguma delas não for corredor.
func caminho(de: Vector2i, para: Vector2i) -> Array[Vector2i]:
	var resultado: Array[Vector2i] = []
	if not eh_corredor(de) or not eh_corredor(para):
		return resultado
	for id in _astar.get_id_path(_id(de), _id(para)):
		resultado.append(Vector2i(id % largura, id / largura))
	return resultado


func vizinhos_abertos(c: Vector2i, so_corredor := true) -> Array[Vector2i]:
	var resultado: Array[Vector2i] = []
	for d in DIRECOES:
		var v := c + d
		if aberto(c, d) and (not so_corredor or eh_corredor(v)):
			resultado.append(v)
	return resultado


## Células alcançáveis a partir de `origem` (para os testes).
func alcancaveis(origem: Vector2i) -> Dictionary:
	var vistos := {origem: true}
	var fila: Array[Vector2i] = [origem]
	while not fila.is_empty():
		var c: Vector2i = fila.pop_front()
		for v in vizinhos_abertos(c, false):
			if not vistos.has(v):
				vistos[v] = true
				fila.append(v)
	return vistos


# --- geração ---------------------------------------------------------------

func _id(c: Vector2i) -> int:
	return c.y * largura + c.x


func _abrir(c: Vector2i, d: Vector2i) -> void:
	var v := c + d
	match d:
		L:
			parede_l[c.y][c.x] = false
		O:
			parede_l[v.y][v.x] = false
		S:
			parede_s[c.y][c.x] = false
		_:
			parede_s[v.y][v.x] = false


func _reservar(tipo: String, rect: Rect2i) -> void:
	salas.append({"tipo": tipo, "rect": rect, "portas": []})


func _cabe(rect: Rect2i) -> bool:
	# Uma célula de folga da borda e entre salas, para sempre haver corredor em volta.
	if rect.position.x < 1 or rect.position.y < 1:
		return false
	if rect.end.x > largura - 1 or rect.end.y > altura - 1:
		return false
	for sala in salas:
		if rect.grow(1).intersects(sala.rect):
			return false
	return true


func _espalhar_salas(tipo: String, quantidade: int, tamanhos: Array) -> void:
	var colocadas := 0
	var tentativas := 0
	while colocadas < quantidade and tentativas < 500:
		tentativas += 1
		var tam: Vector2i = tamanhos[rng.randi_range(0, tamanhos.size() - 1)]
		var pos := Vector2i(rng.randi_range(1, largura - 1 - tam.x), rng.randi_range(1, altura - 1 - tam.y))
		var rect := Rect2i(pos, tam)
		if _cabe(rect):
			_reservar(tipo, rect)
			colocadas += 1
	if colocadas < quantidade:
		push_warning("Só couberam %d de %d salas de %s" % [colocadas, quantidade, tipo])


func _cavar_labirinto() -> void:
	var visitado := {}
	var pendentes: Array[Vector2i] = []
	for y in altura:
		for x in largura:
			if sala_de[y][x] == -1:
				pendentes.append(Vector2i(x, y))

	var primeira := true
	for inicio in pendentes:
		if visitado.has(inicio):
			continue
		# Se sobrou um pedaço isolado, liga ele ao que já foi cavado.
		if not primeira:
			for d in DIRECOES:
				if visitado.has(inicio + d):
					_abrir(inicio, d)
					break
		primeira = false
		visitado[inicio] = true
		var pilha: Array[Vector2i] = [inicio]
		while not pilha.is_empty():
			var atual: Vector2i = pilha.back()
			var opcoes: Array[Vector2i] = []
			for d in DIRECOES:
				var v := atual + d
				if eh_corredor(v) and not visitado.has(v):
					opcoes.append(d)
			if opcoes.is_empty():
				pilha.pop_back()
				continue
			var d: Vector2i = opcoes[rng.randi_range(0, opcoes.size() - 1)]
			_abrir(atual, d)
			visitado[atual + d] = true
			pilha.append(atual + d)


func _abrir_portas(sala: Dictionary, quantidade: int) -> void:
	var rect: Rect2i = sala.rect
	var candidatas: Array = []
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var c := Vector2i(x, y)
			for d in DIRECOES:
				if eh_corredor(c + d):
					candidatas.append({"celula": c, "dir": d})
	# Embaralha e tenta usar lados diferentes da sala.
	for i in range(candidatas.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = candidatas[i]
		candidatas[i] = candidatas[j]
		candidatas[j] = tmp
	var lados_usados := {}
	for passo in 2:
		for porta in candidatas:
			if sala.portas.size() >= quantidade:
				return
			if porta in sala.portas:
				continue
			if passo == 0 and lados_usados.has(porta.dir):
				continue
			lados_usados[porta.dir] = true
			sala.portas.append(porta)
			_abrir(porta.celula, porta.dir)


func _montar_navegacao() -> void:
	_astar.clear()
	for y in altura:
		for x in largura:
			var c := Vector2i(x, y)
			if eh_corredor(c):
				_astar.add_point(_id(c), Vector2(x, y))
	for y in altura:
		for x in largura:
			var c := Vector2i(x, y)
			if not eh_corredor(c):
				continue
			for d in [L, S]:
				if aberto(c, d) and eh_corredor(c + d):
					_astar.connect_points(_id(c), _id(c + d))
