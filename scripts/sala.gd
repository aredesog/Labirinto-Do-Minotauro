extends Node3D
## Uma sala do labirinto: chão, paredes com vãos de porta, grades e inimigos.
## Ao entrar numa sala com combate, as grades fecham até todos os
## inimigos serem derrotados.

signal ativada(sala)
signal liberada(sala)

const Construtor := preload("res://scripts/construtor.gd")

const ALTURA_PAREDE := 2.0
const ESPESSURA := 0.5
const LARGURA_PORTA := 2.0

const COR_CHAO_A := Color(0.78, 0.72, 0.6)
const COR_CHAO_B := Color(0.72, 0.66, 0.55)
const COR_PAREDE := Color(0.55, 0.53, 0.5)
const COR_GRADE := Color(0.25, 0.22, 0.2)
const COR_GRADE_TRANCADA := Color(0.75, 0.6, 0.15)

var nome_sala := ""
var tamanho := Vector2(8, 8)
var portas: Array[String] = []
var tem_combate := true
var eh_chefe := false

var ativa := false
var limpa := false
var trancada := false

var inimigos: Array = []
var _grades: Array[StaticBody3D] = []


## Chame antes de adicionar a sala na árvore.
func configurar(p_nome: String, p_tamanho: Vector2, p_portas: Array[String], p_tem_combate := true) -> void:
	nome_sala = p_nome
	tamanho = p_tamanho
	portas = p_portas
	tem_combate = p_tem_combate
	limpa = not p_tem_combate


func _ready() -> void:
	_criar_chao()
	for lado in ["N", "S", "L", "O"]:
		_criar_parede(lado, lado in portas)
	for lado in portas:
		_criar_grade(lado)
	_criar_gatilho()
	Construtor.tocha(self, Vector3(0, 1.8, 0), maxf(tamanho.x, tamanho.y))
	_definir_grades(trancada)


func adicionar_inimigo(inimigo: Node3D) -> void:
	inimigos.append(inimigo)
	add_child(inimigo)
	inimigo.morreu.connect(_on_inimigo_morreu)


func trancar() -> void:
	trancada = true
	_pintar_grades(COR_GRADE_TRANCADA)
	if is_inside_tree():
		_definir_grades(true)


func destrancar() -> void:
	trancada = false
	_pintar_grades(COR_GRADE)
	_definir_grades(false)


## Volta a sala ao estado inicial quando o jogador morre lá dentro.
func resetar() -> void:
	if not ativa or limpa:
		return
	ativa = false
	_definir_grades(trancada)
	for inimigo in inimigos:
		inimigo.resetar()


# --- construção ----------------------------------------------------------

func _criar_chao() -> void:
	# Base sólida (cobre também a espessura das paredes, para não haver
	# buraco no vão da porta).
	var base := Vector3(tamanho.x + 2 * ESPESSURA, 0.2, tamanho.y + 2 * ESPESSURA)
	Construtor.caixa(self, base, Vector3(0, -0.1, 0), COR_CHAO_B)
	# Ladrilhos de 2 m em xadrez, só visuais, para dar noção de movimento.
	var nx := int(tamanho.x / 2.0)
	var nz := int(tamanho.y / 2.0)
	for i in nx:
		for j in nz:
			if (i + j) % 2 == 0:
				var pos := Vector3(-tamanho.x / 2.0 + 1.0 + i * 2.0, 0.005, -tamanho.y / 2.0 + 1.0 + j * 2.0)
				Construtor.caixa(self, Vector3(2, 0.01, 2), pos, COR_CHAO_A, false)


func _criar_parede(lado: String, com_porta: bool) -> void:
	var horizontal := lado == "N" or lado == "S"
	# N/S cobrem os cantos; L/O ficam só no comprimento interno.
	var comprimento := tamanho.x + 2 * ESPESSURA if horizontal else tamanho.y
	var fixo := _coordenada_parede(lado)
	var trechos: Array = []
	if com_porta:
		var metade_vao := LARGURA_PORTA / 2.0
		var trecho := (comprimento / 2.0) - metade_vao
		trechos.append([-(metade_vao + trecho / 2.0), trecho])
		trechos.append([metade_vao + trecho / 2.0, trecho])
	else:
		trechos.append([0.0, comprimento])

	for t in trechos:
		var centro: float = t[0]
		var tam: float = t[1]
		if horizontal:
			Construtor.caixa(self, Vector3(tam, ALTURA_PAREDE, ESPESSURA),
				Vector3(centro, ALTURA_PAREDE / 2.0, fixo), COR_PAREDE)
		else:
			Construtor.caixa(self, Vector3(ESPESSURA, ALTURA_PAREDE, tam),
				Vector3(fixo, ALTURA_PAREDE / 2.0, centro), COR_PAREDE)


func _criar_grade(lado: String) -> void:
	var horizontal := lado == "N" or lado == "S"
	var fixo := _coordenada_parede(lado)
	var tam := Vector3(LARGURA_PORTA, ALTURA_PAREDE, 0.2) if horizontal else Vector3(0.2, ALTURA_PAREDE, LARGURA_PORTA)
	var pos := Vector3(0, ALTURA_PAREDE / 2.0, fixo) if horizontal else Vector3(fixo, ALTURA_PAREDE / 2.0, 0)
	var grade := Construtor.caixa(self, tam, pos, COR_GRADE) as StaticBody3D
	_grades.append(grade)


func _criar_gatilho() -> void:
	# Área um pouco menor que a sala: o jogador já está todo dentro
	# quando as grades fecham.
	var area := Area3D.new()
	var forma := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(maxf(tamanho.x - 2.0, 1.0), 2.0, maxf(tamanho.y - 2.0, 1.0))
	forma.shape = shape
	forma.position.y = 1.0
	area.add_child(forma)
	add_child(area)
	area.body_entered.connect(_on_corpo_entrou)


func _coordenada_parede(lado: String) -> float:
	match lado:
		"N":
			return -(tamanho.y / 2.0 + ESPESSURA / 2.0)
		"S":
			return tamanho.y / 2.0 + ESPESSURA / 2.0
		"L":
			return tamanho.x / 2.0 + ESPESSURA / 2.0
		_:
			return -(tamanho.x / 2.0 + ESPESSURA / 2.0)


# --- estado --------------------------------------------------------------

func _definir_grades(fechadas: bool) -> void:
	for grade in _grades:
		grade.visible = fechadas
		grade.get_child(1).set_deferred("disabled", not fechadas)


func _pintar_grades(cor: Color) -> void:
	for grade in _grades:
		var malha := grade.get_child(0) as MeshInstance3D
		(malha.mesh as BoxMesh).material = Construtor.material(cor)


func _on_corpo_entrou(corpo: Node3D) -> void:
	if not corpo.is_in_group("jogador") or not corpo.vivo:
		return
	if not tem_combate or limpa or ativa:
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
