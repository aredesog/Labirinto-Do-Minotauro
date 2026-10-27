extends SceneTree
## Teste automático: joga o labirinto sozinho e confere cada regra.
##   godot --path . --script res://ferramentas/godot/teste_automatico.gd
## Com janela (sem --headless) também salva screenshots em user://capturas/.

var fase: Node
var jogo: Node
var teseu: Node3D
var cam: Node3D
var falhas := 0
var capturas := ProjectSettings.globalize_path("user://capturas/")


func _initialize() -> void:
	_rodar()


func checar(cond: bool, texto: String) -> void:
	print(("  [OK]   " if cond else "  [FALHOU] ") + texto)
	if not cond:
		falhas += 1


func esperar(seg: float) -> void:
	await create_timer(seg).timeout


func foto(nome: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await process_frame
	await process_frame
	DirAccess.make_dir_recursive_absolute(capturas)
	root.get_viewport().get_texture().get_image().save_png(capturas + nome + ".png")
	print("  foto: ", nome)


## Só os minitaurinhos (o Minotauro fica parado na arena até a luta).
func inimigos() -> Array:
	return get_nodes_in_group("inimigo").filter(func(n): return not n.is_in_group("chefe"))


func matar_inimigos() -> void:
	for i in get_nodes_in_group("inimigo"):
		i.levar_dano(99)
	await esperar(0.6)


func sala(id: String) -> Node:
	return fase.find_child("Sala" + id, true, false)


func ir(destino: Node) -> void:
	jogo.teleportar(destino)
	await esperar(0.7)


func grades_fechadas(s: Node) -> int:
	var n := 0
	for g in s.find_children("*", "", true, false):
		if g.is_in_group("grade_sala") and g.fechada:
			n += 1
	return n


func portas_ativas(a: Node) -> Array:
	return a.portas().filter(func(p): return p.ativa)


func tipos_destino(a: Node) -> Array:
	return portas_ativas(a).map(func(p): return p.destino.tipo)


## Confere a regra do sorteio depois de vencer uma sala.
func checar_sorteio(a: Node, rotulo: String) -> void:
	var tipos := tipos_destino(a)
	checar(tipos.size() == a.portas().size(), "%s: todos os %d portais acendem" % [rotulo, a.portas().size()])
	if jogo.puzzles_pendentes().size() > 0:
		checar("puzzle" in tipos, "%s: há portal para um enigma pendente %s" % [rotulo, str(tipos)])
	else:
		checar("chefe" in tipos, "%s: com 3 enigmas há portal para o Minotauro %s" % [rotulo, str(tipos)])
	for p in portas_ativas(a):
		checar(p.destino != a, "%s: portal não leva para a mesma sala" % rotulo)
		if p.destino.tipo == "puzzle":
			checar(not p.destino.esta_concluida(), "%s: não sorteia enigma já resolvido" % rotulo)


func _rodar() -> void:
	fase = (load("res://cenas/fase_principal.tscn") as PackedScene).instantiate()
	root.add_child(fase)
	await esperar(1.0)
	jogo = get_first_node_in_group("jogo")
	teseu = get_first_node_in_group("jogador")
	cam = fase.get_node("Camera")
	var inicio := fase.find_child("Inicio", true, false)
	print("== Início ==")
	checar(get_nodes_in_group("area_sala").size() == 8, "8 cômodos (início, 6 salas, arena)")
	checar(fase.find_child("Corredores", true, false) == null, "não há mais corredores")
	checar_sorteio(inicio, "início")
	for id in ["A", "B", "C", "D", "E", "F"]:
		var n: int = sala(id).portas().size()
		checar(n == 2 or n == 3, "sala %s tem %d portas-portal" % [id, n])
	checar(fase.get_node("HUD/Desenho").vida == 10, "HUD: 5 corações (10 meios)")
	await esperar(1.0)
	await foto("01_inicio_portais")

	# ------------------------------------------------ atravessar um portal de verdade
	print("== Atravessar portal ==")
	var porta: Node3D = portas_ativas(inicio)[0]
	var destino: Node = porta.destino
	teseu.global_position = porta.global_position - porta.global_basis.z * 0.5 + Vector3.UP * 0.1
	await esperar(0.9)
	checar(destino.contem(teseu.global_position), "o portal levou o Teseu para '%s'" % destino.nome_sala)
	checar(destino.estado == 1, "ao chegar, o combate começa")
	checar(grades_fechadas(destino) == destino.portas().size(), "as portas da sala fecham")
	checar(portas_ativas(destino).is_empty(), "portais apagados durante o combate")
	checar(inimigos().size() > 0, "surgem minitaurinhos")
	checar(inimigos()[0].vida == 2, "minitaurinho tem 2 de vida (65%)")
	await esperar(0.4)
	await foto("02_chegada_" + destino.name)
	jogo.reiniciar_sala_atual()
	await esperar(0.3)
	await matar_inimigos()

	# ------------------------------------------------ A: estátuas
	print("== A: estátuas ==")
	var a := sala("A")
	if a.estado != 2:
		await ir(a)
		await matar_inimigos()
	checar(a.estado == 2, "A: puzzle ativo depois do combate")
	var est: Array[Node] = a.get_node("Puzzle").filhos_no_grupo("estatua")
	for mv in [[0, Vector3.RIGHT], [0, Vector3.RIGHT], [1, Vector3.LEFT], [1, Vector3.LEFT],
			[2, Vector3.RIGHT], [2, Vector3.RIGHT], [2, Vector3.BACK]]:
		est[mv[0]].empurrar(mv[1])
		await esperar(0.35)
	await esperar(1.8)
	checar(a.esta_concluida() and jogo.prisioneiros_libertados == 4, "A resolvida, 4 libertados")
	checar(grades_fechadas(a) == 0, "A: grades abrem")
	checar_sorteio(a, "A")
	await foto("03_A_portais")

	# ------------------------------------------------ B: combate e revisita
	print("== B: combate ==")
	var b := sala("B")
	teseu.vida = 4
	var visitas_antes: int = b.visitas
	await ir(b)
	var n1 := inimigos().size()
	checar(n1 == 3 + visitas_antes, "B: %d minitaurinhos (3 + visitas anteriores=%d)" % [n1, visitas_antes])
	await foto("04_B_combate")
	await matar_inimigos()
	await esperar(0.3)
	checar(b.esta_concluida(), "B: vencida")
	checar(teseu.vida == 8, "vencer combate cura 2 corações (vida=%d meios)" % teseu.vida)
	checar(jogo.puzzles_concluidos.size() == 1, "combate não conta como enigma")
	checar_sorteio(b, "B")
	await ir(sala("D"))
	await matar_inimigos()
	await ir(b)
	checar(inimigos().size() == n1 + 1, "B revisitada: volta com +1 inimigo (%d)" % (n1 + 1))
	await matar_inimigos()

	# ------------------------------------------------ D: reiniciar sala
	print("== D: reiniciar ==")
	var d := sala("D")
	await ir(d)
	var nov: int = jogo.novelo
	var cp: Vector3 = jogo.checkpoint
	checar(inimigos().size() == mini(4 + d.visitas - 1, 6), "D revisitada: %d inimigos" % inimigos().size())
	var n_d := inimigos().size()
	teseu.global_position = d.global_position + Vector3(2, 0.1, 2)
	jogo.reiniciar_sala_atual()
	await esperar(0.4)
	checar(teseu.global_position.distance_to(cp) < 0.6, "reiniciar volta para a porta de chegada")
	checar(inimigos().size() == n_d, "reiniciar recomeça o combate")
	checar(jogo.novelo == nov, "reiniciar não gasta o novelo")
	await matar_inimigos()

	# ------------------------------------------------ C: braseiros
	print("== C: braseiros ==")
	var c := sala("C")
	await ir(c)
	await matar_inimigos()
	var br := {}
	for x in c.get_node("Puzzle").filhos_no_grupo("braseiro"):
		br[x.simbolo] = x
	br["lua"].interagir(teseu)
	await esperar(0.5)
	checar(inimigos().size() == 1, "errar a ordem chama reforço")
	await matar_inimigos()
	for simb in ["sol", "lua", "onda"]:
		br[simb].interagir(teseu)
		await esperar(0.2)
	jogo.mensagem.emit("Acenda os braseiros na ordem do mosaico.", 3.0)
	await esperar(1.0)
	await foto("05_C_braseiros")
	br["raio"].interagir(teseu)
	await esperar(1.8)
	checar(c.esta_concluida() and jogo.prisioneiros_libertados == 8, "C resolvida, 8 libertados")
	checar_sorteio(c, "C")

	# ------------------------------------------------ E: espelhos
	print("== E: espelhos ==")
	var e := sala("E")
	await ir(e)
	await matar_inimigos()
	for nome in {"Espelho1": 2, "Espelho2": 1, "Espelho3": 3}:
		var esp := e.find_child(nome, true, false)
		for k in {"Espelho1": 2, "Espelho2": 1, "Espelho3": 3}[nome]:
			esp.interagir(teseu)
			await esperar(0.35)
	await esperar(0.4)
	await foto("06_E_espelhos")
	await esperar(2.0)
	checar(e.esta_concluida() and jogo.prisioneiros_libertados == 13, "E resolvida, 13 libertados")
	checar(jogo.puzzles_concluidos.size() == 3, "3 enigmas")
	checar_sorteio(e, "E")
	await esperar(1.0)
	await foto("07_E_portal_minotauro")

	# ------------------------------------------------ F: colisão e void
	print("== F: colisão ==")
	var f := sala("F")
	await ir(f)
	teseu.vida = 99
	teseu.global_position = f.global_position + Vector3(3.0, 0.1, -4.4)
	for k in 6:
		teseu._invulneravel = 0.0
		teseu.levar_dano(0, Vector3(0, 0, -1))
		await esperar(0.25)
	checar(teseu.global_position.z > f.global_position.z - 5.0, "empurrão não atravessa a parede")
	teseu.global_position = f.global_position + Vector3(0, 0.1, -4.4)
	for k in 6:
		teseu._invulneravel = 0.0
		teseu.levar_dano(0, Vector3(0, 0, -1))
		await esperar(0.25)
	checar(f.contem(teseu.global_position) and f.estado == 1, "empurrão não atravessa a grade nem teleporta")
	await matar_inimigos()
	await esperar(0.3)
	var nov2: int = jogo.novelo
	teseu.global_position = Vector3(500, -10, 500)
	await esperar(0.2)
	checar(teseu.global_position.distance_to(jogo.checkpoint) < 0.6 and jogo.novelo == nov2,
		"cair no vazio -> volta ao checkpoint sem gastar novelo")

	# ------------------------------------------------ morte
	print("== Morte ==")
	var b2 := sala("B")
	await ir(b2)
	teseu.vida = 1
	var antes: int = jogo.novelo
	var escala: float = teseu.get_node("Visual/Novelo").scale.x
	teseu._invulneravel = 0.0
	teseu.levar_dano(1)
	await esperar(0.6)
	checar(jogo.novelo == antes - 1, "morrer gasta uma volta do novelo")
	checar(teseu.get_node("Visual/Novelo").scale.x < escala, "o novelo na cabeça encolhe")
	checar(fase.get_node("HUD/Desenho").novelo == antes - 1, "HUD mostra o novelo gasto")
	checar(b2.estado == 1 and inimigos().size() > 0, "a sala recomeça após a morte")
	teseu.vida = 3
	fase.get_node("HUD/Desenho").definir_vida(3, 10)
	await esperar(0.4)
	await foto("08_hud_vida_baixa")
	await matar_inimigos()

	# ------------------------------------------------ Minotauro
	print("== Arena ==")
	var p_chefe: Node3D = null
	for p in portas_ativas(b2):
		if p.destino.tipo == "chefe":
			p_chefe = p
	checar(p_chefe != null, "sala vencida depois dos 3 enigmas tem portal para o Minotauro")
	if p_chefe:
		teseu.global_position = p_chefe.global_position - p_chefe.global_basis.z * 0.5 + Vector3.UP * 0.1
		await esperar(1.0)
		var arena := fase.find_child("Arena", true, false)
		checar(arena.contem(teseu.global_position), "portal leva à arena")
		await _luta_chefe(arena)
	print("== RESULTADO: %d falha(s) ==" % falhas)
	quit(falhas)



# ------------------------------------------------------------------ chefe
func _luta_chefe(arena: Node) -> void:
	print("== Minotauro ==")
	var chefe: Node3D = arena.find_child("Minotauro", true, false)
	var hud := fase.get_node("HUD/Desenho")
	checar(chefe != null, "o Minotauro está na arena")
	checar(chefe.estado == 1, "a luta começa com o rugido (intro)")
	checar(hud.chefe_ativo and hud.chefe_maximo == chefe.vida_maxima, "barra de vida do chefe aparece")
	await esperar(0.8)
	await foto("09_arena_intro")
	await esperar(1.4)
	checar(chefe.estado != 1, "depois do rugido ele parte para o ataque")

	# golpe de machado: Teseu perto, na frente dele
	teseu.vida = 10
	teseu._invulneravel = 0.0
	chefe._cooldown_investida = 99.0
	teseu.global_position = chefe.global_position + chefe.global_basis.z * 2.6 + Vector3.UP * 0.1
	var viu_golpe := false
	var fotografou := false
	for k in 30:
		await esperar(0.1)
		if chefe.estado == 6 and not fotografou and k > 3:
			fotografou = true
			await foto("10_golpe_erguido")
		if chefe.estado == 7:
			viu_golpe = true
	checar(viu_golpe, "Teseu perto -> ele ergue o machado e bate no chão")
	checar(teseu.vida < 10, "o golpe de machado fere o Teseu (vida=%d)" % teseu.vida)

	# investida: Teseu longe -> mira, dispara e bate na parede
	teseu.vida = 99
	teseu.global_position = arena.global_position + Vector3(-5.0, 0.1, 0)
	chefe.global_position = arena.global_position + Vector3(3.5, 0.05, 0)
	chefe._mudar(2)
	chefe._cooldown_investida = 0.0
	var viu_mira := false
	var atordoado := false
	for k in 50:
		await esperar(0.1)
		if chefe.estado == 3 and not viu_mira:
			viu_mira = true
			await foto("11_investida_mira")
		if chefe.estado == 4:
			teseu.global_position = arena.global_position + Vector3(-3.0, 0.1, 5.0)  # sai da frente
		if chefe.estado == 5:
			atordoado = true
			break
	checar(viu_mira, "antes da investida aparece a faixa vermelha (aviso)")
	checar(atordoado, "a investida bate na parede e deixa ele atordoado")
	await foto("12_atordoado")
	var v0: int = chefe.vida
	teseu.global_position = chefe.global_position + chefe.global_basis.z * 2.0 + Vector3.UP * 0.1
	teseu._direcao_olhar = -chefe.global_basis.z
	teseu._cooldown_ataque = 0.0
	teseu._atacar()
	await esperar(0.1)
	checar(v0 - chefe.vida == 2, "atordoado, a espada tira o dobro (%d -> %d)" % [v0, chefe.vida])

	# fase 2
	chefe.vida = chefe.vida_maxima / 2 + 1
	chefe._invulneravel = 0.0
	teseu._cooldown_ataque = 0.0
	teseu._atacar()
	await esperar(0.3)
	checar(chefe.fase2, "com metade da vida entra na fase 2")
	checar(inimigos().size() == 2, "fase 2 chama 2 minitaurinhos")
	await esperar(2.0)

	# derrota
	chefe.vida = 1
	chefe._invulneravel = 0.0
	teseu.global_position = chefe.global_position + chefe.global_basis.z * 2.0 + Vector3.UP * 0.1
	teseu._direcao_olhar = -chefe.global_basis.z
	teseu._cooldown_ataque = 0.0
	teseu._atacar()
	await esperar(0.2)
	checar(chefe.esta_morto(), "o Minotauro cai")
	checar(inimigos().is_empty(), "as crias somem junto")
	await esperar(5.0)
	checar(arena.esta_concluida(), "arena vencida")
	checar(fase.get_node("HUD/Vitoria").visible, "tela de vitória aparece")
	await foto("13_vitoria")
