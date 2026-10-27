extends SceneTree
## Gera todas as cenas (.tscn) do jogo a partir dos modelos .glb.
##
## Uso (na pasta do projeto, com os .glb já importados pelo editor).
## NÃO use --headless: o piso usa MultiMesh e precisa do renderizador ativo
## para salvar as posições:
##   godot --path . --script res://ferramentas/godot/gerar_cenas.gd
##
## Edite as funções sala_*() para mudar o layout e rode de novo.
## ATENÇÃO: sobrescreve os arquivos em res://cenas/.

const MOD := "res://assets/modelos/"
const OBJ := "res://cenas/objetos/"
const SALAS := "res://cenas/salas/"

const CAMADA_CENARIO := 1
const CAMADA_JOGADOR := 2
const CAMADA_INIMIGO := 4

var _malhas_cache := {}


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://cenas/objetos")
	DirAccess.make_dir_recursive_absolute("res://cenas/salas")
	gerar_objetos()
	for antigo in ["sala_1_estatuas", "sala_2_braseiros", "sala_3_espelhos"]:
		DirAccess.remove_absolute(SALAS + antigo + ".tscn")
	salvar(sala_estatuas(), SALAS + "sala_A_estatuas.tscn")
	salvar(sala_combate("B"), SALAS + "sala_B_combate.tscn")
	salvar(sala_braseiros(), SALAS + "sala_C_braseiros.tscn")
	salvar(sala_combate("D"), SALAS + "sala_D_combate.tscn")
	salvar(sala_espelhos(), SALAS + "sala_E_espelhos.tscn")
	salvar(sala_combate("F"), SALAS + "sala_F_combate.tscn")
	salvar(fase_principal(), "res://cenas/fase_principal.tscn")
	print("CENAS GERADAS")
	quit()


# ==========================================================================
# Utilidades
# ==========================================================================
func salvar(raiz: Node, caminho: String) -> void:
	var cena := PackedScene.new()
	var erro := cena.pack(raiz)
	assert(erro == OK, "falha ao empacotar " + caminho)
	erro = ResourceSaver.save(cena, caminho)
	assert(erro == OK, "falha ao salvar " + caminho)
	print("  salvo ", caminho)
	raiz.free()


func add(pai: Node, filho: Node, dono: Node, nome := "") -> Node:
	if nome != "":
		filho.name = nome
	pai.add_child(filho, true)
	filho.owner = dono
	return filho


func inst(caminho: String) -> Node:
	return (load(caminho) as PackedScene).instantiate()


func modelo(pai: Node, dono: Node, caminho: String, pos := Vector3.ZERO, rot_y := 0.0,
		escala := Vector3.ONE, nome := "Modelo") -> Node3D:
	var n := inst(caminho) as Node3D
	n.position = pos
	n.rotation.y = deg_to_rad(rot_y)
	n.scale = escala
	return add(pai, n, dono, nome) as Node3D


func n3d(pai: Node, dono: Node, nome: String, pos := Vector3.ZERO) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	return add(pai, n, dono, nome) as Node3D


func marcador(pai: Node, dono: Node, nome: String, pos: Vector3, grupo := "") -> Marker3D:
	var m := Marker3D.new()
	m.position = pos
	if grupo != "":
		m.add_to_group(grupo, true)
	return add(pai, m, dono, nome) as Marker3D


func caixa(corpo: Node, dono: Node, tamanho: Vector3, pos: Vector3, nome := "Forma") -> CollisionShape3D:
	var f := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = tamanho
	f.shape = s
	f.position = pos
	return add(corpo, f, dono, nome) as CollisionShape3D


func cilindro(corpo: Node, dono: Node, raio: float, altura: float, pos: Vector3, nome := "Forma") -> CollisionShape3D:
	var f := CollisionShape3D.new()
	var s := CylinderShape3D.new()
	s.radius = raio
	s.height = altura
	f.shape = s
	f.position = pos
	return add(corpo, f, dono, nome) as CollisionShape3D


func corpo_estatico(pai: Node, dono: Node, nome := "Corpo") -> StaticBody3D:
	var c := StaticBody3D.new()
	c.collision_layer = CAMADA_CENARIO
	c.collision_mask = 0
	return add(pai, c, dono, nome) as StaticBody3D


func luz(pai: Node, dono: Node, nome: String, pos: Vector3, cor: Color, energia: float,
		alcance: float, visivel := true) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = cor
	l.light_energy = energia
	l.omni_range = alcance
	l.shadow_enabled = false
	l.visible = visivel
	return add(pai, l, dono, nome) as OmniLight3D


func mat(cor: Color, emissao := 0.0, rugosidade := 0.4) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = cor
	m.roughness = rugosidade
	if emissao > 0.0:
		m.emission_enabled = true
		m.emission = cor
		m.emission_energy_multiplier = emissao
	return m


func malha(pai: Node, dono: Node, nome: String, mesh: Mesh, material: Material, pos := Vector3.ZERO,
		rot := Vector3.ZERO, escala := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mesh.material = material
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees = rot
	mi.scale = escala
	return add(pai, mi, dono, nome) as MeshInstance3D


## Pega a malha de um .glb que tem uma única peça (para usar em MultiMesh).
func malha_do_glb(caminho: String) -> Mesh:
	if _malhas_cache.has(caminho):
		return _malhas_cache[caminho]
	var raiz := inst(caminho)
	var mi := raiz.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var m := mi.mesh
	raiz.free()
	_malhas_cache[caminho] = m
	return m


## Coloca várias cópias de uma peça do kit, agrupadas sob um nó (fácil de
## mexer no editor: cada peça é uma instância do .glb).
func muitas(pai: Node, dono: Node, nome: String, caminho_glb: String, transformacoes: Array) -> void:
	if transformacoes.is_empty():
		return
	var grupo := n3d(pai, dono, nome)
	var cena := load(caminho_glb) as PackedScene
	var base_nome := caminho_glb.get_file().get_basename().capitalize().replace(" ", "")
	for t in transformacoes:
		var n := cena.instantiate() as Node3D
		n.transform = t
		add(grupo, n, dono, base_nome)


func xf(pos: Vector3, rot_y := 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, deg_to_rad(rot_y)), pos)


# ==========================================================================
# Objetos (cenas reutilizáveis)
# ==========================================================================
func gerar_objetos() -> void:
	# --- prisioneiro ---
	var p := Node3D.new()
	p.name = "Prisioneiro"
	p.set_script(load("res://scripts/salas/prisioneiro.gd"))
	modelo(p, p, MOD + "personagens/prisioneiro.glb")
	salvar(p, OBJ + "prisioneiro.tscn")

	# --- Teseu provisório ---
	var t := CharacterBody3D.new()
	t.name = "Teseu"
	t.set_script(load("res://scripts/jogador/teseu_prototipo.gd"))
	t.collision_layer = CAMADA_JOGADOR
	t.collision_mask = CAMADA_CENARIO | CAMADA_INIMIGO
	var cap := CollisionShape3D.new()
	var cs := CapsuleShape3D.new()
	cs.radius = 0.3
	cs.height = 1.2
	cap.shape = cs
	cap.position = Vector3(0, 0.6, 0)
	add(t, cap, t, "Forma")
	var vis := n3d(t, t, "Visual")
	modelo(vis, t, MOD + "personagens/prisioneiro.glb", Vector3.ZERO, 0, Vector3.ONE * 1.15, "Corpo")
	var faixa := TorusMesh.new()
	faixa.inner_radius = 0.3
	faixa.outer_radius = 0.36
	malha(vis, t, "Faixa", faixa, mat(Color("#b8342c")), Vector3(0, 1.08, 0.02), Vector3(-12, 0, 0),
		Vector3(1.0, 0.6, 1.0))
	var capa := BoxMesh.new()
	capa.size = Vector3(0.42, 0.5, 0.05)
	malha(vis, t, "Capa", capa, mat(Color("#b8342c")), Vector3(0, 0.4, -0.2), Vector3(10, 0, 0))
	# escudo hoplon no braço esquerdo (+X) e espada xiphos na mão direita (-X)
	modelo(vis, t, MOD + "armas/escudo_hoplon.glb", Vector3(0.36, 0.45, 0.06), 65,
		Vector3.ONE * 0.95, "Escudo")
	# o pivô fica no centro do corpo e a espada a 0,3 m dele (o "braço"):
	# assim o golpe gira em volta do Teseu sem atravessar o corpo
	var piv_espada := n3d(vis, t, "Espada", Vector3(0, 0.42, 0.0))
	var esp := modelo(piv_espada, t, MOD + "armas/espada_xiphos.glb", Vector3(0, 0, 0.3), 0,
		Vector3.ONE * 1.15, "Xiphos")
	esp.rotation_degrees = Vector3(90, 0, 0)  # lâmina para a frente (+Z)
	# novelo de Ariadne preso na cabeça (encolhe a cada volta gasta)
	var nov := n3d(vis, t, "Novelo", Vector3(0, 1.38, -0.08))
	var bola := SphereMesh.new()
	bola.radius = 0.15
	bola.height = 0.3
	malha(nov, t, "Bola", bola, mat(Color("#c0302a"), 0.0, 0.8))
	for k in 3:
		var fio := TorusMesh.new()
		fio.inner_radius = 0.14
		fio.outer_radius = 0.165
		malha(nov, t, "Fio%d" % k, fio, mat(Color("#8e1f1a"), 0.0, 0.8), Vector3.ZERO,
			Vector3(60 * k, 30 * k, 90))
	salvar(t, OBJ + "teseu_prototipo.tscn")

	# --- Minitaurinho provisório ---
	var m := CharacterBody3D.new()
	m.name = "Minitaurinho"
	m.set_script(load("res://scripts/inimigos/minitaurinho_prototipo.gd"))
	m.collision_layer = CAMADA_INIMIGO
	m.collision_mask = CAMADA_CENARIO | CAMADA_JOGADOR | CAMADA_INIMIGO
	var cap2 := CollisionShape3D.new()
	var cs2 := CapsuleShape3D.new()
	cs2.radius = 0.32
	cs2.height = 1.1
	cap2.shape = cs2
	cap2.position = Vector3(0, 0.55, 0)
	add(m, cap2, m, "Forma")
	var vm := n3d(m, m, "Visual")
	var marrom := mat(Color("#a0704a"))
	var corpo := SphereMesh.new()
	corpo.radius = 0.3
	corpo.height = 0.55
	malha(vm, m, "Corpo", corpo, marrom, Vector3(0, 0.35, 0))
	var tanga := CylinderMesh.new()
	tanga.top_radius = 0.28
	tanga.bottom_radius = 0.24
	tanga.height = 0.14
	malha(vm, m, "Tanga", tanga, mat(Color("#3f6fa8")), Vector3(0, 0.2, 0))
	var cabeca := SphereMesh.new()
	cabeca.radius = 0.32
	cabeca.height = 0.6
	malha(vm, m, "Cabeca", cabeca, marrom, Vector3(0, 0.85, 0))
	var focinho := SphereMesh.new()
	focinho.radius = 0.18
	focinho.height = 0.24
	malha(vm, m, "Focinho", focinho, mat(Color("#d9b08c")), Vector3(0, 0.76, 0.24))
	for lado in [-1.0, 1.0]:
		var chifre := CylinderMesh.new()
		chifre.top_radius = 0.0
		chifre.bottom_radius = 0.06
		chifre.height = 0.3
		malha(vm, m, "Chifre" + ("E" if lado < 0 else "D"), chifre, mat(Color("#f2e8cc")),
			Vector3(lado * 0.3, 1.08, 0.0), Vector3(0, 0, -lado * 50))
		var olho := SphereMesh.new()
		olho.radius = 0.05
		olho.height = 0.1
		malha(vm, m, "Olho" + ("E" if lado < 0 else "D"), olho, mat(Color("#1a1a1a"), 0.0, 0.2),
			Vector3(lado * 0.12, 0.92, 0.27))
	salvar(m, OBJ + "minitaurinho_prototipo.tscn")

	# --- Minotauro (chefe) ---
	var mi := CharacterBody3D.new()
	mi.name = "Minotauro"
	mi.set_script(load("res://scripts/inimigos/minotauro.gd"))
	mi.collision_layer = CAMADA_INIMIGO
	mi.collision_mask = CAMADA_CENARIO | CAMADA_JOGADOR
	mi.set("cena_minitaurinho", load(OBJ + "minitaurinho_prototipo.tscn"))
	caixa(mi, mi, Vector3(1.25, 3.0, 2.5), Vector3(0, 1.5, -0.25))
	var vmi := n3d(mi, mi, "Visual")
	modelo(vmi, mi, MOD + "personagens/minotauro.glb", Vector3.ZERO, 0, Vector3.ONE * 1.25)
	var faixa_mira := QuadMesh.new()
	faixa_mira.size = Vector2(1.6, 4.0)
	var mat_mira := StandardMaterial3D.new()
	mat_mira.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_mira.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_mira.albedo_color = Color(1.0, 0.15, 0.1, 0.45)
	var mira := MeshInstance3D.new()
	mira.mesh = faixa_mira
	mira.material_override = mat_mira
	mira.rotation_degrees = Vector3(-90, 0, 0)
	mira.position = Vector3(0, 0.06, 3.2)
	mira.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add(mi, mira, mi, "Mira")
	salvar(mi, OBJ + "minotauro.tscn")

	# --- grade da porta ---
	var g := Node3D.new()
	g.name = "GradePorta"
	g.set_script(load("res://scripts/salas/grade_porta.gd"))
	modelo(g, g, MOD + "cenario/grade_porta.glb")
	var cg := corpo_estatico(g, g)
	caixa(cg, g, Vector3(2.2, 2.5, 0.7), Vector3(0, 1.25, 0), "Bloqueio")
	salvar(g, OBJ + "grade_porta.tscn")

	# --- cela ---
	var c := Node3D.new()
	c.name = "Cela"
	c.set_script(load("res://scripts/salas/cela.gd"))
	c.set("cena_prisioneiro", load(OBJ + "prisioneiro.tscn"))
	modelo(c, c, MOD + "puzzles/cela.glb")
	var cc := corpo_estatico(c, c)
	for lado in [-1.0, 1.0]:
		caixa(cc, c, Vector3(0.25, 1.8, 1.5), Vector3(lado * 1.375, 0.9, -0.75), "Lado")
	caixa(cc, c, Vector3(3.0, 1.8, 0.25), Vector3(0, 0.9, -1.375), "Fundo")
	caixa(cc, c, Vector3(2.5, 1.8, 0.12), Vector3(0, 0.9, 0), "BloqueioGrade")
	salvar(c, OBJ + "cela.tscn")

	# --- estátua empurrável ---
	var e := StaticBody3D.new()
	e.name = "EstatuaTouro"
	e.set_script(load("res://scripts/puzzles/estatuas/estatua_empurravel.gd"))
	e.collision_layer = CAMADA_CENARIO
	e.collision_mask = 0
	caixa(e, e, Vector3(0.88, 1.3, 0.88), Vector3(0, 0.65, 0))
	modelo(e, e, MOD + "puzzles/estatua_touro.glb")
	salvar(e, OBJ + "estatua_touro.tscn")

	# --- placa de pressão ---
	var pp := Node3D.new()
	pp.name = "PlacaPressao"
	pp.set_script(load("res://scripts/puzzles/estatuas/placa_pressao.gd"))
	modelo(pp, pp, MOD + "puzzles/placa_pressao.glb")
	luz(pp, pp, "Brilho", Vector3(0, 0.4, 0), Color("#ffd76a"), 0.8, 1.4, false)
	salvar(pp, OBJ + "placa_pressao.tscn")

	# --- alavanca ---
	var a := Node3D.new()
	a.name = "Alavanca"
	a.set_script(load("res://scripts/puzzles/alavanca.gd"))
	modelo(a, a, MOD + "puzzles/alavanca.glb")
	caixa(corpo_estatico(a, a), a, Vector3(0.5, 0.4, 0.4), Vector3(0, 0.2, 0))
	salvar(a, OBJ + "alavanca.tscn")

	# --- braseiro com estela e símbolo ---
	var b := Node3D.new()
	b.name = "Braseiro"
	b.set_script(load("res://scripts/puzzles/braseiros/braseiro.gd"))
	modelo(b, b, MOD + "puzzles/braseiro.glb")
	modelo(b, b, MOD + "cenario/pilar.glb", Vector3(0, 0, -0.6), 0, Vector3(0.75, 0.68, 0.75), "Estela")
	n3d(b, b, "SuporteSimbolo", Vector3(0, -0.02, -0.36)).scale = Vector3.ONE * 0.75
	var chao := n3d(b, b, "SuporteChao", Vector3(0, 0.03, 0.95))
	chao.rotation_degrees = Vector3(-90, 0, 0)
	chao.scale = Vector3.ONE * 1.25
	var cb := corpo_estatico(b, b)
	cilindro(cb, b, 0.45, 0.9, Vector3(0, 0.45, 0))
	caixa(cb, b, Vector3(0.45, 1.1, 0.45), Vector3(0, 0.55, -0.6), "FormaEstela")
	var fogo := n3d(b, b, "Fogo", Vector3(0, 0.82, 0))
	var chama := CylinderMesh.new()
	chama.top_radius = 0.0
	chama.bottom_radius = 0.28
	chama.height = 0.7
	malha(fogo, b, "ChamaFora", chama, mat(Color("#e8742a"), 1.2), Vector3(0, 0.35, 0))
	var chama2 := CylinderMesh.new()
	chama2.top_radius = 0.0
	chama2.bottom_radius = 0.16
	chama2.height = 0.45
	malha(fogo, b, "ChamaDentro", chama2, mat(Color("#ffc94a"), 1.6), Vector3(0, 0.24, 0))
	luz(b, b, "Luz", Vector3(0, 1.4, 0), Color("#ff9a3c"), 1.2, 3.5, false)
	salvar(b, OBJ + "braseiro.tscn")

	# --- espelho ---
	var es := StaticBody3D.new()
	es.name = "Espelho"
	es.set_script(load("res://scripts/puzzles/espelhos/espelho.gd"))
	es.collision_layer = CAMADA_CENARIO
	es.collision_mask = 0
	modelo(es, es, MOD + "puzzles/espelho.glb")
	caixa(es, es, Vector3(0.9, 1.0, 0.1), Vector3(0, 1.06, 0), "FormaEspelho")
	cilindro(es, es, 0.42, 0.2, Vector3(0, 0.1, 0), "FormaBase")
	salvar(es, OBJ + "espelho.tscn")

	# --- cristal ---
	var cr := StaticBody3D.new()
	cr.name = "Cristal"
	cr.set_script(load("res://scripts/puzzles/espelhos/cristal.gd"))
	cr.collision_layer = CAMADA_CENARIO
	cr.collision_mask = 0
	modelo(cr, cr, MOD + "puzzles/cristal.glb")
	caixa(cr, cr, Vector3(0.5, 1.7, 0.5), Vector3(0, 0.85, 0))
	luz(cr, cr, "Luz", Vector3(0, 1.3, 0), Color("#7fd6ff"), 1.0, 3.0, false)
	salvar(cr, OBJ + "cristal.tscn")

	# --- fonte de luz (presa na parede, emite para +Z) ---
	var fl := Node3D.new()
	fl.name = "FonteLuz"
	fl.set_script(load("res://scripts/puzzles/espelhos/fonte_luz.gd"))
	modelo(fl, fl, MOD + "puzzles/fonte_luz.glb", Vector3(0, 0.44, 0))
	marcador(fl, fl, "Emissor", Vector3(0, 1.06, 0.12))
	salvar(fl, OBJ + "fonte_luz.tscn")

	# --- tocha ---
	var to := Node3D.new()
	to.name = "Tocha"
	to.set_script(load("res://scripts/visual/tocha.gd"))
	modelo(to, to, MOD + "cenario/tocha.glb")
	luz(to, to, "Luz", Vector3(0, 1.55, 0.25), Color("#ffa04a"), 0.7, 3.5)
	salvar(to, OBJ + "tocha.tscn")

	# --- portão do Minotauro ---
	var pm := Node3D.new()
	pm.name = "PortaoMinotauro"
	pm.set_script(load("res://scripts/salas/portao_minotauro.gd"))
	modelo(pm, pm, MOD + "cenario/portao_minotauro.glb")
	var cpm := corpo_estatico(pm, pm)
	caixa(cpm, pm, Vector3(3.0, 2.8, 0.3), Vector3(0, 1.4, 0), "Bloqueio")
	for lado in [-1.0, 1.0]:
		caixa(cpm, pm, Vector3(0.5, 3.0, 0.5), Vector3(lado * 1.75, 1.5, 0), "Coluna")
	salvar(pm, OBJ + "portao_minotauro.tscn")

	# --- props com colisão ---
	for nome in ["coluna_grega", "anfora"]:
		var pr := StaticBody3D.new()
		pr.name = nome.capitalize().replace(" ", "")
		pr.collision_layer = CAMADA_CENARIO
		pr.collision_mask = 0
		modelo(pr, pr, MOD + "props/%s.glb" % nome)
		if nome == "coluna_grega":
			cilindro(pr, pr, 0.33, 2.2, Vector3(0, 1.1, 0))
		else:
			cilindro(pr, pr, 0.3, 0.95, Vector3(0, 0.47, 0))
		salvar(pr, OBJ + nome + ".tscn")


# ==========================================================================
# SALAS LIGADAS POR PORTAIS (sem corredores)
#
# Cada sala fica isolada no mundo. Toda porta é um portal: quando a sala é
# vencida, o GerenciadorJogo sorteia para onde cada portal leva (sempre há
# um portal para um enigma pendente; com os 3 enigmas feitos, um leva ao
# Minotauro). As salas de combate podem ser sorteadas várias vezes.
# ==========================================================================
const ESPACO_SALAS := 40.0

## id: [nome do arquivo, título, tipo, portas, metade do tamanho, inimigos, presos]
const SALAS_MAPA := {
	"inicio": ["", "Entrada do Labirinto", "inicio", ["L", "N"], 3, 0, 0],
	"A": ["sala_A_estatuas", "Sala das Estátuas", "puzzle", ["O", "N", "L"], 5, 3, 4],
	"B": ["sala_B_combate", "Salão dos Chifres", "combate", ["S", "N", "L"], 5, 3, 0],
	"C": ["sala_C_braseiros", "Sala dos Braseiros", "puzzle", ["O", "L"], 5, 3, 4],
	"D": ["sala_D_combate", "Cova dos Minitauros", "combate", ["O", "S"], 5, 4, 0],
	"E": ["sala_E_espelhos", "Sala dos Espelhos", "puzzle", ["O", "N", "L"], 5, 4, 5],
	"F": ["sala_F_combate", "Antecâmara", "combate", ["N", "S", "L"], 5, 4, 0],
	"arena": ["", "Arena do Minotauro", "chefe", ["O"], 7, 0, 0],
}
const ORDEM_MUNDO := ["inicio", "A", "B", "C", "D", "E", "F", "arena"]


func centro_sala(id: String) -> Vector3:
	return Vector3(ORDEM_MUNDO.find(id) * ESPACO_SALAS, 0, 0)


## Peça de parede na borda de uma célula/sala. lado: N, S, L (leste), O (oeste).
## A parede sul é baixa para não tapar a câmera.
func parede_em(grupo: Node3D, col: StaticBody3D, dono: Node, pos_borda: Vector3, lado: String) -> void:
	var rot: float = {"N": 0.0, "S": 180.0, "O": 90.0, "L": -90.0}[lado]
	var fora: Vector3 = {"N": Vector3(0, 0, -1), "S": Vector3(0, 0, 1),
		"O": Vector3(-1, 0, 0), "L": Vector3(1, 0, 0)}[lado]
	var arquivo := "parede_baixa.glb" if lado == "S" else "parede.glb"
	var n := (load(MOD + "cenario/" + arquivo) as PackedScene).instantiate() as Node3D
	n.position = pos_borda + fora * 0.15
	n.rotation.y = deg_to_rad(rot)
	add(grupo, n, dono, "Parede")
	# colisão grossa (0,6 m) e alta, toda do lado de fora: nada atravessa
	var tam := Vector3(1.6, 3.0, 0.6) if lado in ["N", "S"] else Vector3(0.6, 3.0, 1.6)
	caixa(col, dono, tam, pos_borda + fora * 0.3 + Vector3.UP * 1.5, "Muro")


## Piso de uma área retangular com uma só MultiMesh (1 chamada de desenho).
func piso_area(pai: Node3D, dono: Node, celulas: Array) -> void:
	var t := []
	for c in celulas:
		t.append(xf(Vector3(c.x + 0.5, 0, c.y + 0.5)))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = malha_do_glb(MOD + "cenario/piso.glb")
	mm.instance_count = t.size()
	for i in t.size():
		mm.set_instance_transform(i, t[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add(pai, mmi, dono, "Piso")


## Estrutura de um cômodo quadrado (metade do lado = h) com portas de 2 m
## (4 m na arena) nos lados pedidos. Cria grades, marcadores e colisão.
func comodo(raiz: Node3D, h: int, portas: Array, largura_porta := 2, com_grades := true, dono: Node = null,
		portais := true) -> void:
	if dono == null:
		dono = raiz
	var est := n3d(raiz, dono, "Estrutura")
	var celulas := []
	for i in range(-h, h):
		for j in range(-h, h):
			celulas.append(Vector2i(i, j))
	piso_area(est, dono, celulas)
	var paredes := n3d(est, dono, "Paredes")
	var col := corpo_estatico(est, dono, "Colisao")
	var meia_porta := largura_porta / 2.0
	for k in range(-h, h):
		var m := k + 0.5
		var na_porta := absf(m) < meia_porta
		if not (na_porta and "N" in portas):
			parede_em(paredes, col, dono, Vector3(m, 0, -h), "N")
		if not (na_porta and "S" in portas):
			parede_em(paredes, col, dono, Vector3(m, 0, h), "S")
		if not (na_porta and "O" in portas):
			parede_em(paredes, col, dono, Vector3(-h, 0, m), "O")
		if not (na_porta and "L" in portas):
			parede_em(paredes, col, dono, Vector3(h, 0, m), "L")
	for sx in [-1.0, 1.0]:
		modelo(est, dono, MOD + "cenario/pilar.glb", Vector3(sx * (h + 0.15), 0, -h - 0.15), 0,
			Vector3.ONE, "PilarCanto")
	if "N" in portas and largura_porta == 2:
		modelo(est, dono, MOD + "cenario/arco_porta.glb", Vector3(0, 0, -h - 0.15), 0, Vector3.ONE, "Arco")
	if not portais:
		return
	for lado in portas:
		porta_portal(raiz, dono, h, lado, com_grades)


## Porta-portal. Orientação local: -Z = para fora da sala, +Z = para dentro.
func porta_portal(raiz: Node3D, dono: Node, h: int, lado: String, com_grade: bool) -> void:
	var dir: Vector3 = {"N": Vector3(0, 0, -1), "S": Vector3(0, 0, 1),
		"O": Vector3(-1, 0, 0), "L": Vector3(1, 0, 0)}[lado]
	var porta := Node3D.new()
	porta.set_script(load("res://scripts/salas/porta_teleporte.gd"))
	porta.position = dir * (h + 0.15)
	porta.rotation.y = deg_to_rad({"N": 0.0, "S": 180.0, "O": 90.0, "L": -90.0}[lado])
	add(raiz, porta, dono, "Porta" + lado)
	if com_grade:
		var g := inst(OBJ + "grade_porta.tscn") as Node3D
		add(porta, g, dono, "Grade")
		g.add_to_group("grade_sala", true)
	marcador(porta, dono, "Entrada", Vector3(0, 0.1, 1.7))
	# redemoinho do portal
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.3)
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	var sm := ShaderMaterial.new()
	sm.shader = load("res://scripts/visual/portal.gdshader")
	mi.material_override = sm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(0, 1.15, -0.45)
	add(porta, mi, dono, "Portal")
	# ícone do tipo de destino + nome, flutuando sobre a porta
	var icone := n3d(porta, dono, "Icone", Vector3(0, 2.35, 0.9))
	var losango := BoxMesh.new()
	losango.size = Vector3(0.32, 0.32, 0.32)
	malha(icone, dono, "Losango", losango, mat(Color.WHITE), Vector3.ZERO, Vector3(45, 0, 45))
	var rot := Label3D.new()
	rot.font_size = 44
	rot.outline_size = 12
	rot.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	rot.position = Vector3(0, 2.85, 0.9)
	add(porta, rot, dono, "Rotulo")
	# área que teleporta + "fundo" que impede sair andando para o vazio
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = CAMADA_JOGADOR
	add(porta, area, dono, "Passagem")
	caixa(area, dono, Vector3(1.9, 2.0, 0.7), Vector3(0, 1.0, -0.6))
	var fundo := corpo_estatico(porta, dono, "Fundo")
	caixa(fundo, dono, Vector3(2.6, 3.0, 0.4), Vector3(0, 1.5, -1.25))


func tocha_parede(pai: Node3D, dono: Node, pos: Vector3, parede: String) -> void:
	var rot: float = {"N": 0.0, "O": 90.0, "L": -90.0}[parede]
	var t := inst(OBJ + "tocha.tscn") as Node3D
	t.position = pos
	t.rotation.y = deg_to_rad(rot)
	add(pai, t, dono, "Tocha")


func objeto(pai: Node3D, dono: Node, cena: String, pos: Vector3, rot_y := 0.0, nome := "") -> Node3D:
	var o := inst(OBJ + cena) as Node3D
	o.position = pos
	o.rotation.y = deg_to_rad(rot_y)
	return add(pai, o, dono, nome) as Node3D


func titulo_chao(pai: Node3D, dono: Node, texto: String, pos: Vector3, tamanho := 56) -> void:
	var l := Label3D.new()
	l.text = texto
	l.font_size = tamanho
	l.outline_size = 14
	l.modulate = Color("#fff3d6")
	l.position = pos
	l.rotation_degrees = Vector3(-90, 0, 0)
	add(pai, l, dono, "Titulo")


## Sala genérica (puzzle ou combate) a partir da tabela SALAS_MAPA.
func sala_base(id: String) -> Node3D:
	var d: Array = SALAS_MAPA[id]
	var s := Node3D.new()
	s.name = "Sala" + id
	s.set_script(load("res://scripts/salas/sala.gd"))
	s.set("nome_sala", d[1])
	s.set("tipo", d[2])
	s.set("meio_tamanho", Vector2(d[4], d[4]))
	s.set("quantidade_inimigos", d[5])
	s.set("cena_inimigo", load(OBJ + "minitaurinho_prototipo.tscn"))
	comodo(s, d[4], d[3])
	if d[6] > 0:
		var cela_x := 3.48 if id == "E" else -3.48
		var cela := objeto(s, s, "cela.tscn", Vector3(cela_x, 0, -3.5), 0, "Cela")
		cela.set("quantidade_prisioneiros", d[6])
	return s


func spawns(s: Node3D, posicoes: Array) -> void:
	for p in posicoes:
		marcador(s, s, "Spawn", p, "spawn_inimigo")


# ---------------------------------------------------------------- A: estátuas
func sala_estatuas() -> Node3D:
	var s := sala_base("A")
	s.set("dica_puzzle", "Empurre as estátuas de touro até as placas douradas.\n(A alavanca devolve as estátuas ao lugar.)")
	var pz := Node3D.new()
	pz.set_script(load("res://scripts/puzzles/estatuas/puzzle_estatuas.gd"))
	add(s, pz, s, "Puzzle")
	# solução: E1 -> leste x2 | E2 -> oeste x2 | E3 -> leste x2, depois sul x1
	for par in [[Vector3(0.5, 0, -1.5), Vector3(2.5, 0, -1.5)],
			[Vector3(-0.5, 0, 1.5), Vector3(-2.5, 0, 1.5)],
			[Vector3(1.5, 0, 2.5), Vector3(3.5, 0, 3.5)]]:
		objeto(pz, s, "placa_pressao.tscn", par[1], 0, "Placa")
		objeto(pz, s, "estatua_touro.tscn", par[0], 0, "Estatua")
	objeto(pz, s, "alavanca.tscn", Vector3(-4.3, 0, 4.3), 0, "AlavancaReset")
	objeto(s, s, "coluna_grega.tscn", Vector3(4.3, 0, -4.3), 0, "Coluna")
	objeto(s, s, "anfora.tscn", Vector3(4.45, 0, -2.8), 0, "Anfora")
	modelo(s, s, MOD + "props/ossos.glb", Vector3(-3.8, 0, -2.0), 30, Vector3.ONE, "Ossos")
	tocha_parede(s, s, Vector3(3.0, 0, -4.98), "N")
	tocha_parede(s, s, Vector3(-4.98, 0, 3.0), "O")
	tocha_parede(s, s, Vector3(4.98, 0, -3.0), "L")
	spawns(s, [Vector3(-3.5, 0, 3.0), Vector3(3.5, 0, -3.0), Vector3(-1.5, 0, -0.5), Vector3(1.5, 0, 0.5)])
	return s


# ---------------------------------------------------------------- C: braseiros
func sala_braseiros() -> Node3D:
	var s := sala_base("C")
	s.set("dica_puzzle", "O mosaico na parede mostra a ordem das cores.\nAcenda os braseiros (E) nessa ordem.")
	var pz := Node3D.new()
	pz.set_script(load("res://scripts/puzzles/braseiros/puzzle_braseiros.gd"))
	pz.set("ordem", ["sol", "lua", "onda", "raio"])
	add(s, pz, s, "Puzzle")
	n3d(pz, s, "Mosaico", Vector3(3.3, 0, -4.97))
	var posicoes := {"lua": Vector3(-2.0, 0, -1.6), "onda": Vector3(2.0, 0, -1.6),
		"raio": Vector3(-2.0, 0, 2.0), "sol": Vector3(2.0, 0, 2.0)}
	for simbolo in posicoes:
		var b := objeto(pz, s, "braseiro.tscn", posicoes[simbolo], 0, "Braseiro" + simbolo.capitalize())
		b.set("simbolo", simbolo)
	objeto(s, s, "anfora.tscn", Vector3(4.45, 0, 4.3), 0, "Anfora")
	objeto(s, s, "anfora.tscn", Vector3(-4.45, 0, 4.3), 0, "Anfora")
	tocha_parede(s, s, Vector3(0.6, 0, -4.98), "N")
	tocha_parede(s, s, Vector3(-4.98, 0, 3.0), "O")
	tocha_parede(s, s, Vector3(4.98, 0, 3.0), "L")
	spawns(s, [Vector3(0, 0, 0.2), Vector3(0, 0, 3.6), Vector3(-3.5, 0, 3.6), Vector3(3.5, 0, 3.6)])
	return s


# ---------------------------------------------------------------- E: espelhos
func sala_espelhos() -> Node3D:
	var s := sala_base("E")
	s.set("dica_puzzle", "Gire os espelhos (E) para levar a luz até o cristal.")
	var pz := Node3D.new()
	pz.set_script(load("res://scripts/puzzles/espelhos/puzzle_espelhos.gd"))
	add(s, pz, s, "Puzzle")
	objeto(pz, s, "fonte_luz.tscn", Vector3(-4.95, 0, -2.5), 90, "FonteLuz")
	# solução: E1 = -45°, E2 = 135°, E3 = -135° (cada clique gira +45°)
	objeto(pz, s, "espelho.tscn", Vector3(-1.5, 0, -2.5), -135, "Espelho1")
	objeto(pz, s, "espelho.tscn", Vector3(-1.5, 0, 2.5), 90, "Espelho2")
	objeto(pz, s, "espelho.tscn", Vector3(2.5, 0, 2.5), 90, "Espelho3")
	objeto(pz, s, "cristal.tscn", Vector3(2.5, 0, -1.5), 0, "Cristal")
	objeto(s, s, "coluna_grega.tscn", Vector3(-4.3, 0, 4.3), 0, "Coluna")
	objeto(s, s, "coluna_grega.tscn", Vector3(4.3, 0, 4.3), 0, "Coluna")
	modelo(s, s, MOD + "props/ossos.glb", Vector3(0.5, 0, 4.0), -20, Vector3.ONE, "Ossos")
	tocha_parede(s, s, Vector3(-3.0, 0, -4.98), "N")
	spawns(s, [Vector3(-3.5, 0, 2.0), Vector3(3.5, 0, 2.0), Vector3(0.5, 0, 1.5), Vector3(-3.0, 0, -4.0)])
	return s


# ---------------------------------------------------------------- salas de combate
func sala_combate(id: String) -> Node3D:
	var s := sala_base(id)
	match id:
		"B":
			for p in [Vector3(-2.5, 0, -2.0), Vector3(2.5, 0, 2.5)]:
				objeto(s, s, "coluna_grega.tscn", p, 0, "Coluna")
			objeto(s, s, "anfora.tscn", Vector3(-4.4, 0, 4.3), 0, "Anfora")
			tocha_parede(s, s, Vector3(-3.0, 0, -4.98), "N")
			tocha_parede(s, s, Vector3(-4.98, 0, 0.0), "O")
			spawns(s, [Vector3(-3.5, 0, 0.5), Vector3(3.0, 0, -3.5), Vector3(0.0, 0, -2.5), Vector3(3.5, 0, 3.5)])
		"D":
			for p in [Vector3(-4.4, 0, -4.3), Vector3(4.4, 0, -4.3), Vector3(4.4, 0, 4.3), Vector3(-4.4, 0, 4.3)]:
				objeto(s, s, "anfora.tscn", p, 0, "Anfora")
			objeto(s, s, "coluna_grega.tscn", Vector3(0, 0, -1.0), 0, "Coluna")
			modelo(s, s, MOD + "props/ossos.glb", Vector3(2.5, 0, 2.0), 50, Vector3.ONE, "Ossos")
			tocha_parede(s, s, Vector3(0.0, 0, -4.98), "N")
			tocha_parede(s, s, Vector3(4.98, 0, 0.0), "L")
			spawns(s, [Vector3(3.5, 0, -3.0), Vector3(3.5, 0, 3.0), Vector3(-2.5, 0, -3.0), Vector3(0.0, 0, 2.5)])
		"F":
			for p in [Vector3(-2.5, 0, -2.5), Vector3(2.5, 0, -2.5), Vector3(-2.5, 0, 2.5), Vector3(2.5, 0, 2.5)]:
				objeto(s, s, "coluna_grega.tscn", p, 0, "Coluna")
			modelo(s, s, MOD + "props/ossos.glb", Vector3(-3.5, 0, 0.0), 10, Vector3.ONE, "Ossos")
			tocha_parede(s, s, Vector3(-3.0, 0, -4.98), "N")
			tocha_parede(s, s, Vector3(3.0, 0, -4.98), "N")
			spawns(s, [Vector3(-4.0, 0, -4.0), Vector3(4.0, 0, -4.0), Vector3(-4.0, 0, 4.0), Vector3(4.0, 0, 4.0), Vector3(0.0, 0, 0.0)])
	return s


# ==========================================================================
# Fase completa
# ==========================================================================
func area_simples(pai: Node3D, dono: Node, id: String, script := "res://scripts/salas/area_sala.gd") -> Node3D:
	var d: Array = SALAS_MAPA[id]
	var a := Node3D.new()
	a.set_script(load(script))
	a.set("nome_sala", d[1])
	a.set("tipo", d[2])
	a.set("meio_tamanho", Vector2(d[4], d[4]))
	a.position = centro_sala(id)
	add(pai, a, dono, id.capitalize())
	return a


func fase_principal() -> Node3D:
	var f := Node3D.new()
	f.name = "FasePrincipal"

	var jogo := Node.new()
	jogo.set_script(load("res://scripts/jogo/gerenciador_jogo.gd"))
	add(f, jogo, f, "GerenciadorJogo")

	var amb := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#2a2433")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#c9bde0")
	env.ambient_light_energy = 0.06
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	amb.environment = env
	add(f, amb, f, "Ambiente")
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-58, 28, 0)
	sol.light_color = Color("#fff1dc")
	sol.light_energy = 0.85
	sol.shadow_enabled = true
	sol.shadow_blur = 2.0
	sol.directional_shadow_max_distance = 40.0
	add(f, sol, f, "Sol")

	# chão infinito: nada cai no vazio
	var chao := StaticBody3D.new()
	chao.collision_layer = CAMADA_CENARIO
	chao.collision_mask = 0
	add(f, chao, f, "ChaoInfinito")
	var fc := CollisionShape3D.new()
	fc.shape = WorldBoundaryShape3D.new()
	add(chao, fc, f, "Forma")

	var mapa := n3d(f, f, "Mapa")
	# início: Ariadne entrega o novelo; 2 portais sorteados
	var ini := area_simples(mapa, f, "inicio")
	comodo(ini, 3, SALAS_MAPA["inicio"][3], 2, false, f)
	var ariadne := inst(OBJ + "prisioneiro.tscn") as Node3D
	ariadne.position = Vector3(-1.4, 0, -1.2)
	ariadne.rotation.y = deg_to_rad(30)
	add(ini, ariadne, f, "Ariadne")
	var nome_ar := Label3D.new()
	nome_ar.text = "Ariadne"
	nome_ar.font_size = 40
	nome_ar.outline_size = 10
	nome_ar.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	nome_ar.position = Vector3(-1.4, 1.6, -1.2)
	add(ini, nome_ar, f, "NomeAriadne")
	titulo_chao(ini, f, "Entrada do Labirinto", Vector3(0, 0.05, 2.0), 48)
	tocha_parede(ini, f, Vector3(-2.0, 0, -2.98), "N")

	# salas (cada uma é uma cena separada em cenas/salas/)
	for id in ["A", "B", "C", "D", "E", "F"]:
		var sala := inst(SALAS + SALAS_MAPA[id][0] + ".tscn") as Node3D
		sala.position = centro_sala(id)
		add(mapa, sala, f)

	# arena do Minotauro (14 × 14): chega-se só pelo portal roxo
	var arena := area_simples(mapa, f, "arena", "res://scripts/salas/arena_minotauro.gd")
	arena.set("zoom_camera", 1.22)
	comodo(arena, 7, ["O"], 4, false, f, false)
	var portao := inst(OBJ + "portao_minotauro.tscn") as Node3D
	portao.position = Vector3(-7.15, 0, 0)
	portao.rotation.y = deg_to_rad(90)
	add(arena, portao, f, "PortaoMinotauro")
	marcador(arena, f, "Chegada", Vector3(-5.2, 0.1, 0))
	for pos in [Vector3(-4.5, 0, -4.5), Vector3(4.5, 0, -4.5), Vector3(-4.5, 0, 4.5), Vector3(4.5, 0, 4.5)]:
		objeto(arena, f, "coluna_grega.tscn", pos, 0, "Coluna")
	tocha_parede(arena, f, Vector3(-3, 0, -6.98), "N")
	tocha_parede(arena, f, Vector3(3, 0, -6.98), "N")
	var chefe := inst(OBJ + "minotauro.tscn") as Node3D
	chefe.position = Vector3(3.5, 0.05, 0)
	chefe.rotation.y = deg_to_rad(-90)
	add(arena, chefe, f, "Minotauro")

	# jogador e câmera
	var teseu := inst(OBJ + "teseu_prototipo.tscn") as Node3D
	teseu.position = centro_sala("inicio") + Vector3(0.5, 0.1, 0.8)
	add(f, teseu, f, "Teseu")
	var cam := Camera3D.new()
	cam.set_script(load("res://scripts/visual/camera_diorama.gd"))
	cam.fov = 40.0
	cam.position = teseu.position + Vector3(0, 12.0, 9.5)
	add(f, cam, f, "Camera")

	# tilt-shift (camada 1) e HUD (camada 2)
	var ts := CanvasLayer.new()
	ts.layer = 1
	add(f, ts, f, "TiltShift")
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var smt := ShaderMaterial.new()
	smt.shader = load("res://scripts/visual/tilt_shift.gdshader")
	rect.material = smt
	add(ts, rect, f, "Filtro")
	hud(f)
	return f


func rotulo(texto: String, tamanho: int) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", tamanho)
	l.add_theme_color_override("font_color", Color("#fff3d6"))
	l.add_theme_color_override("font_outline_color", Color("#2a1d14"))
	l.add_theme_constant_override("outline_size", 8)
	return l


## HUD no estilo Zelda: Link's Awakening.
func hud(f: Node) -> void:
	var hud := CanvasLayer.new()
	hud.layer = 2
	hud.set_script(load("res://scripts/ui/hud.gd"))
	add(f, hud, f, "HUD")

	var desenho := Control.new()
	desenho.set_script(load("res://scripts/ui/hud_desenho.gd"))
	desenho.set_anchors_preset(Control.PRESET_FULL_RECT)
	desenho.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add(hud, desenho, f, "Desenho")

	# caixa de diálogo (embaixo, centralizada)
	var dialogo := PanelContainer.new()
	dialogo.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	dialogo.offset_left = -380
	dialogo.offset_right = 380
	dialogo.offset_top = -172
	dialogo.offset_bottom = -50
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.06, 0.09, 0.18, 0.93)
	estilo.border_color = Color("#e8d8a8")
	estilo.set_border_width_all(3)
	estilo.set_corner_radius_all(12)
	estilo.content_margin_left = 22
	estilo.content_margin_right = 22
	estilo.content_margin_top = 14
	estilo.content_margin_bottom = 14
	dialogo.add_theme_stylebox_override("panel", estilo)
	dialogo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add(hud, dialogo, f, "Dialogo")
	var texto := Label.new()
	texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	texto.add_theme_font_size_override("font_size", 23)
	texto.add_theme_color_override("font_color", Color.WHITE)
	texto.add_theme_constant_override("line_spacing", 4)
	add(dialogo, texto, f, "Texto")

	# nome da sala ao chegar
	var banner := rotulo("", 34)
	banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	banner.offset_top = 26
	banner.offset_bottom = 80
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_constant_override("outline_size", 10)
	add(hud, banner, f, "Banner")

	var ajuda := rotulo("WASD andar · Espaço espada · E usar · R reiniciar sala · Esc menu", 15)
	ajuda.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	ajuda.offset_left = 20
	ajuda.offset_top = -34
	ajuda.offset_bottom = -12
	ajuda.modulate.a = 0.75
	add(hud, ajuda, f, "Ajuda")

	var menu := Control.new()
	menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu.visible = false
	add(hud, menu, f, "Menu")
	var fundo := ColorRect.new()
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.color = Color(0.05, 0.04, 0.1, 0.75)
	add(menu, fundo, f, "Fundo")
	var caixa_c := CenterContainer.new()
	caixa_c.set_anchors_preset(Control.PRESET_FULL_RECT)
	add(menu, caixa_c, f, "Caixa")
	var botoes := VBoxContainer.new()
	botoes.add_theme_constant_override("separation", 12)
	add(caixa_c, botoes, f, "Botoes")
	var titulo := rotulo("Pausado", 40)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add(botoes, titulo, f, "Titulo")
	var estilo_b := StyleBoxFlat.new()
	estilo_b.bg_color = Color(0.06, 0.09, 0.18, 0.95)
	estilo_b.border_color = Color("#e8d8a8")
	estilo_b.set_border_width_all(2)
	estilo_b.set_corner_radius_all(10)
	var estilo_foco := estilo_b.duplicate() as StyleBoxFlat
	estilo_foco.border_color = Color("#ffc94a")
	estilo_foco.set_border_width_all(4)
	for par in [["Continuar", "Continuar"], ["ReiniciarSala", "Reiniciar sala (R)"],
			["ReiniciarJogo", "Reiniciar jogo"]]:
		var b := Button.new()
		b.text = par[1]
		b.custom_minimum_size = Vector2(320, 52)
		b.add_theme_font_size_override("font_size", 22)
		b.add_theme_stylebox_override("normal", estilo_b)
		b.add_theme_stylebox_override("hover", estilo_foco)
		b.add_theme_stylebox_override("focus", estilo_foco)
		b.add_theme_stylebox_override("pressed", estilo_foco)
		add(botoes, b, f, par[0])

	# tela de vitória
	var vit := Control.new()
	vit.set_anchors_preset(Control.PRESET_FULL_RECT)
	vit.visible = false
	add(hud, vit, f, "Vitoria")
	var fundo_v := ColorRect.new()
	fundo_v.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo_v.color = Color(0.05, 0.04, 0.1, 0.8)
	add(vit, fundo_v, f, "Fundo")
	var caixa_v := CenterContainer.new()
	caixa_v.set_anchors_preset(Control.PRESET_FULL_RECT)
	add(vit, caixa_v, f, "Caixa")
	var col_v := VBoxContainer.new()
	col_v.add_theme_constant_override("separation", 16)
	add(caixa_v, col_v, f, "Coluna")
	var t1 := rotulo("VITÓRIA!", 64)
	t1.add_theme_color_override("font_color", Color("#ffc94a"))
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add(col_v, t1, f, "Titulo")
	var t2 := rotulo("O Minotauro foi derrotado.\nAtenas está livre do tributo!", 28)
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add(col_v, t2, f, "Texto")
	var t3 := rotulo("", 20)
	t3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add(col_v, t3, f, "Detalhe")
	var bj := Button.new()
	bj.text = "Jogar de novo"
	bj.custom_minimum_size = Vector2(320, 56)
	bj.add_theme_font_size_override("font_size", 24)
	bj.add_theme_stylebox_override("normal", estilo_b)
	bj.add_theme_stylebox_override("hover", estilo_foco)
	bj.add_theme_stylebox_override("focus", estilo_foco)
	add(col_v, bj, f, "JogarDeNovo")

	var fade := ColorRect.new()
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0, 0, 0, 0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add(hud, fade, f, "Fade")
