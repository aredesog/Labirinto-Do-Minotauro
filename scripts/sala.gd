extends Node3D
## Lógica de uma sala do labirinto (a geometria é feita pelo main.gd).
## Tipos:
##   "entrada"  - ponto de partida, sem combate
##   "combate"  - as grades fecham até todos os minitaurinhos caírem
##   "fonte"    - recupera a vida e vira checkpoint
##   "chefe"    - a sala do Minotauro, trancada até as salas de combate serem liberadas

signal ativada(sala)
signal liberada(sala)
signal fonte_visitada(sala)

const Construtor := preload("res://scripts/construtor.gd")

const COR_GRADE := Color(0.22, 0.2, 0.18)
const COR_GRADE_TRANCADA := Color(0.8, 0.62, 0.15)

var nome_sala := ""
var tipo := "combate"
var tamanho := Vector2(8, 8)

var ativa := false
var limpa := false
var trancada := false

var inimigos: Array = []
var _grades: Array[StaticBody3D] = []


## Chame antes de adicionar a sala na árvore. `posicao` é o centro da sala.
func configurar(p_nome: String, p_tipo: String, p_tamanho: Vector2) -> void:
	nome_sala = p_nome
	tipo = p_tipo
	tamanho = p_tamanho
	limpa = tipo != "combate" and tipo != "chefe"


func _ready() -> void:
	_criar_gatilho()
	var alcance := maxf(tamanho.x, tamanho.y) * 0.9
	if tipo == "fonte":
		_criar_fonte()
	else:
		Construtor.tocha(self, Vector3(0, 2.2, 0), alcance)


func eh_combate() -> bool:
	return tipo == "combate" or tipo == "chefe"


## Grade numa porta (posição local, relativa ao centro da sala).
func adicionar_grade(posicao_local: Vector3, tamanho_grade: Vector3) -> void:
	var cor := COR_GRADE_TRANCADA if trancada else COR_GRADE
	var grade := Construtor.caixa(self, tamanho_grade, posicao_local, cor) as StaticBody3D
	_grades.append(grade)
	_definir_grade(grade, trancada)


func adicionar_inimigo(inimigo: Node3D) -> void:
	inimigos.append(inimigo)
	add_child(inimigo)
	inimigo.morreu.connect(_on_inimigo_morreu)


func trancar() -> void:
	trancada = true
	_pintar_grades(COR_GRADE_TRANCADA)
	_definir_grades(true)


func destrancar() -> void:
	trancada = false
	_pintar_grades(COR_GRADE)
	_definir_grades(false)


## Volta a sala ao estado inicial quando o jogador morre.
func resetar() -> void:
	if not ativa or limpa:
		return
	ativa = false
	_definir_grades(trancada)
	for inimigo in inimigos:
		inimigo.resetar()


# --- interno -------------------------------------------------------------

func _criar_gatilho() -> void:
	# Área menor que a sala: o jogador já está todo dentro quando as grades fecham.
	var area := Area3D.new()
	var forma := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(maxf(tamanho.x - 2.5, 1.0), 2.0, maxf(tamanho.y - 2.5, 1.0))
	forma.shape = shape
	forma.position.y = 1.0
	area.add_child(forma)
	add_child(area)
	area.body_entered.connect(_on_corpo_entrou)


func _criar_fonte() -> void:
	Construtor.caixa(self, Vector3(2.4, 0.6, 2.4), Vector3(0, 0.3, 0), Color(0.6, 0.6, 0.62))
	Construtor.caixa(self, Vector3(2.0, 0.05, 2.0), Vector3(0, 0.62, 0), Color(0.3, 0.65, 0.95), false)
	Construtor.caixa(self, Vector3(0.4, 1.4, 0.4), Vector3(0, 1.3, 0), Color(0.65, 0.65, 0.67))
	var luz := Construtor.tocha(self, Vector3(0, 2.0, 0), 7.0)
	luz.light_color = Color(0.45, 0.75, 1.0)


func _definir_grades(fechadas: bool) -> void:
	for grade in _grades:
		_definir_grade(grade, fechadas)


func _definir_grade(grade: StaticBody3D, fechada: bool) -> void:
	grade.visible = fechada
	grade.get_child(1).set_deferred("disabled", not fechada)


func _pintar_grades(cor: Color) -> void:
	for grade in _grades:
		var malha := grade.get_child(0) as MeshInstance3D
		(malha.mesh as BoxMesh).material = Construtor.material(cor)


func _on_corpo_entrou(corpo: Node3D) -> void:
	if not corpo.is_in_group("jogador") or not corpo.vivo:
		return
	if tipo == "fonte":
		fonte_visitada.emit(self)
		return
	if not eh_combate() or limpa or ativa:
		return
	ativa = true
	_definir_grades(true)
	for inimigo in inimigos:
		inimigo.acordar()
	ativada.emit(self)


func _on_inimigo_morreu(_inimigo: Node3D) -> void:
	for inimigo in inimigos:
		if inimigo.vivo:
			return
	ativa = false
	limpa = true
	_definir_grades(false)
	liberada.emit(self)
