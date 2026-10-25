extends RefCounted
## Funções de apoio para montar as peças cinzas do protótipo por código.
## Quando os modelos do Blender ficarem prontos, é aqui que as caixas
## vão sendo trocadas pelas cenas .glb importadas.


static func material(cor: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = cor
	mat.roughness = 0.85
	return mat


## Cria uma caixa. Se `solida` for true, ela vira um StaticBody3D com colisão.
static func caixa(pai: Node, tamanho: Vector3, posicao: Vector3, cor: Color, solida := true) -> Node3D:
	return caixa_com_material(pai, tamanho, posicao, material(cor), solida)


## Igual à `caixa`, mas reaproveitando um material (bom quando são centenas de peças).
static func caixa_com_material(pai: Node, tamanho: Vector3, posicao: Vector3, mat: Material, solida := true) -> Node3D:
	var malha := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = tamanho
	box.material = mat
	malha.mesh = box

	if not solida:
		malha.position = posicao
		pai.add_child(malha)
		return malha

	var corpo := StaticBody3D.new()
	corpo.position = posicao
	var forma := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = tamanho
	forma.shape = shape
	corpo.add_child(malha)
	corpo.add_child(forma)
	pai.add_child(corpo)
	return corpo


## Luz de tocha (amarelada) para dar clima às salas.
static func tocha(pai: Node, posicao: Vector3, alcance := 7.0) -> OmniLight3D:
	var luz := OmniLight3D.new()
	luz.position = posicao
	luz.light_color = Color(1.0, 0.72, 0.4)
	luz.light_energy = 1.4
	luz.omni_range = alcance
	pai.add_child(luz)
	return luz
