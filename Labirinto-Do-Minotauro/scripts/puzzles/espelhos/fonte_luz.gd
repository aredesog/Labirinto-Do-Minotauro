class_name FonteLuz
extends Node3D
## Emite um feixe de luz para +Z local e o faz ricochetear nos espelhos
## usando raycast. O feixe é redesenhado a cada quadro com segmentos de malha.
##
## Algoritmo:
##   origem, direção = emissor
##   repita até max_reflexoes:
##       lança um raio  -> ponto de impacto
##       desenha o segmento origem -> impacto
##       se bateu num espelho: direção = reflexão (r = d - 2(d·n)n)
##       se bateu no cristal:  avisa o cristal e para
##       senão: para (parede, coluna...)

signal atingiu_cristal(cristal: Node)

@export var max_reflexoes: int = 8
@export var alcance: float = 40.0
@export var espessura: float = 0.11
@export var cor: Color = Color(1.0, 0.85, 0.4)
@export var ligada: bool = true

var _segmentos: Array[MeshInstance3D] = []
var _material: StandardMaterial3D
var _emissor: Node3D
var _brilho_impacto: OmniLight3D


func _ready() -> void:
	add_to_group("fonte_luz")
	_emissor = find_child("Emissor", true, false) as Node3D
	if _emissor == null:
		_emissor = self
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.albedo_color = cor
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.albedo_color.a = 0.85
	_material.emission_enabled = true
	_material.emission = cor
	_material.emission_energy_multiplier = 3.0
	_brilho_impacto = OmniLight3D.new()
	_brilho_impacto.light_color = cor
	_brilho_impacto.light_energy = 1.5
	_brilho_impacto.omni_range = 1.5
	add_child(_brilho_impacto)


func _physics_process(_delta: float) -> void:
	if not ligada:
		_mostrar_segmentos(0)
		_brilho_impacto.visible = false
		return
	var espaco := get_world_3d().direct_space_state
	var origem := _emissor.global_position
	var direcao := _emissor.global_basis.z.normalized()
	var excluir: Array[RID] = []
	var usados := 0

	for i in max_reflexoes + 1:
		var fim := origem + direcao * alcance
		var consulta := PhysicsRayQueryParameters3D.create(origem, fim, 1, excluir)
		var hit := espaco.intersect_ray(consulta)
		if hit.is_empty():
			_desenhar(usados, origem, fim)
			usados += 1
			_brilho_impacto.visible = false
			break
		var ponto: Vector3 = hit.position
		_desenhar(usados, origem, ponto)
		usados += 1
		_brilho_impacto.visible = true
		_brilho_impacto.global_position = ponto - direcao * 0.2
		var alvo: Object = hit.collider
		if alvo is Node and (alvo as Node).is_in_group("espelho"):
			var nova: Vector3 = alvo.refletir(direcao)
			if nova == Vector3.ZERO:
				break
			origem = ponto
			direcao = nova
			excluir = [hit.rid]
			continue
		if alvo is Node and (alvo as Node).is_in_group("cristal"):
			atingiu_cristal.emit(alvo)
		break

	_mostrar_segmentos(usados)


func _desenhar(indice: int, de: Vector3, ate: Vector3) -> void:
	while _segmentos.size() <= indice:
		var mi := MeshInstance3D.new()
		var caixa := BoxMesh.new()
		caixa.size = Vector3(espessura, espessura, 1.0)
		mi.mesh = caixa
		mi.material_override = _material
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.top_level = true
		add_child(mi)
		_segmentos.append(mi)
	var seg := _segmentos[indice]
	var comprimento := de.distance_to(ate)
	if comprimento < 0.001:
		seg.visible = false
		return
	seg.visible = true
	var meio := (de + ate) * 0.5
	seg.global_transform = Transform3D(Basis.looking_at((ate - de).normalized(), Vector3.UP), meio)
	seg.scale = Vector3(1, 1, comprimento)


func _mostrar_segmentos(quantos: int) -> void:
	for i in _segmentos.size():
		_segmentos[i].visible = i < quantos
