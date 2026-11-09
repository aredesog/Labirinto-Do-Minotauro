class_name Toon
extends RefCounted
## Troca os materiais padrão (StandardMaterial3D, iluminação PBR) pelo shader
## de cel shading (toon.gdshader) e põe o contorno (toon_contorno.gdshader)
## nos personagens e objetos pequenos.
##
## Funciona em tempo de execução: Toon.instalar(arvore) converte o que já
## está na cena e tudo o que nascer depois (inimigos, prisioneiros...).
## F3 no modo Raio-X liga/desliga para comparar Toon x PBR.

const SHADER := preload("res://scripts/visual/toon.gdshader")
const SHADER_CONTORNO := preload("res://scripts/visual/toon_contorno.gdshader")
## Objetos maiores que isto (paredes, piso) não ganham contorno.
const TAMANHO_MAX_CONTORNO := 3.2

static var ligado := true
static var _cache := {}          # StandardMaterial3D -> ShaderMaterial
static var _contorno: ShaderMaterial
static var _convertidos: Array = []  # [MeshInstance3D/MultiMesh, superfície, original]
static var _arvore: SceneTree


static func instalar(arvore: SceneTree) -> void:
	_arvore = arvore
	# (não zera a lista: o que já foi convertido pelo node_added continua nela)
	_convertidos = _convertidos.filter(func(item): return is_instance_valid(item[0]))
	if not arvore.node_added.is_connected(_ao_adicionar):
		arvore.node_added.connect(_ao_adicionar)
	_converter_tudo(arvore.root)


static func _ao_adicionar(no: Node) -> void:
	if not ligado:
		return
	if no is MeshInstance3D or no is MultiMeshInstance3D:
		# adiado: deixa o dono terminar de configurar (ex.: definir_cor dos prisioneiros)
		_converter.call_deferred(no)


static func _converter_tudo(raiz: Node) -> void:
	if not ligado:
		return
	for n in raiz.find_children("*", "MeshInstance3D", true, false):
		_converter(n)
	for n in raiz.find_children("*", "MultiMeshInstance3D", true, false):
		_converter(n)


static func _material_contorno() -> ShaderMaterial:
	if _contorno == null:
		_contorno = ShaderMaterial.new()
		_contorno.shader = SHADER_CONTORNO
	return _contorno


## Só converte materiais "comuns": sem transparência, sem brilho próprio
## (fogo, cristal, portal) e com sombreamento normal.
static func _convertivel(m: Material) -> bool:
	var s := m as StandardMaterial3D
	if s == null:
		return false
	if s.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		return false
	if s.shading_mode != BaseMaterial3D.SHADING_MODE_PER_PIXEL:
		return false
	if s.emission_enabled:
		return false
	return true


static func material_toon(s: StandardMaterial3D, contorno: bool) -> ShaderMaterial:
	var chave := [s, contorno]
	if _cache.has(chave):
		return _cache[chave]
	var t := ShaderMaterial.new()
	t.shader = SHADER
	t.set_shader_parameter("cor", s.albedo_color)
	if s.albedo_texture:
		t.set_shader_parameter("textura", s.albedo_texture)
		t.set_shader_parameter("usar_textura", true)
	# metal (escudo, espada, fivela) ganha brilho seco
	t.set_shader_parameter("tamanho_brilho", 0.12 if s.metallic > 0.3 else 0.0)
	if contorno and not Config.baixa():
		t.next_pass = _material_contorno()
	_cache[chave] = t
	return t


static func _converter(no) -> void:
	if not is_instance_valid(no) or not ligado:
		return
	if no.has_meta("toon"):
		return
	no.set_meta("toon", true)
	if no is MultiMeshInstance3D:
		var mm := no as MultiMeshInstance3D
		var orig: Material = mm.material_override
		if orig == null and mm.multimesh and mm.multimesh.mesh and mm.multimesh.mesh.get_surface_count() > 0:
			orig = mm.multimesh.mesh.surface_get_material(0)
		if orig and _convertivel(orig):
			_convertidos.append([mm, -1, mm.material_override])
			mm.material_override = material_toon(orig, false)
		return
	var mi := no as MeshInstance3D
	if mi.mesh == null:
		return
	if mi.material_override:
		if _convertivel(mi.material_override):
			_convertidos.append([mi, -1, mi.material_override])
			mi.material_override = material_toon(mi.material_override, _quer_contorno(mi))
		return
	var contorno := _quer_contorno(mi)
	for i in mi.mesh.get_surface_count():
		var atual := mi.get_surface_override_material(i)
		var orig: Material = atual if atual else mi.mesh.surface_get_material(i)
		if orig and _convertivel(orig):
			_convertidos.append([mi, i, atual])
			mi.set_surface_override_material(i, material_toon(orig, contorno))


static func _quer_contorno(mi: MeshInstance3D) -> bool:
	# contorno só em quem precisa se destacar do cenário (personagens e
	# objetos dos enigmas): cada contorno é mais um draw call por malha
	var n: Node = mi.get_parent()
	while n:
		if n is CharacterBody3D or n is Prisioneiro:
			return true
		if n.is_in_group("empurravel") or n.is_in_group("espelho") or n.is_in_group("interagivel") \
				or n.name == "Ariadne":
			return true
		if n.is_in_group("area_sala"):
			return false
		n = n.get_parent()
	return false


## Liga/desliga o cel shading em tempo real (comparação Toon x PBR).
static func definir(ativo: bool) -> void:
	if ativo == ligado:
		return
	ligado = ativo
	if not ativo:
		for item in _convertidos:
			if not is_instance_valid(item[0]):
				continue
			var no: Node = item[0]
			no.remove_meta("toon")
			if item[1] < 0:
				no.material_override = item[2]
			else:
				no.set_surface_override_material(item[1], item[2])
		_convertidos.clear()
	elif _arvore:
		_converter_tudo(_arvore.root)


static func materiais_convertidos() -> int:
	return _convertidos.size()
