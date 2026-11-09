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
	for p in get_nodes_in_group("projetil"):
		p.quebrar()
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
## Regra: a 10ª sala é sempre a arena; enigmas são forçados quando o
## número de enigmas pendentes alcança o de salas que sobram antes dela.
func checar_sorteio(a: Node, rotulo: String) -> void:
	var tipos := tipos_destino(a)
	var proxima: int = jogo.salas_visitadas + 1
	var vagas: int = jogo.sala_do_minotauro - proxima
	var pend: int = jogo.puzzles_pendentes(a).size()
	checar(tipos.size() == a.portas().size(), "%s: todos os %d portais acendem" % [rotulo, a.portas().size()])
	if proxima >= jogo.sala_do_minotauro:
		checar(tipos.all(func(t): return t == "labirinto"), "%s: saindo da 9ª sala todos levam ao labirinto do Minotauro %s" % [rotulo, str(tipos)])
	else:
		checar(not ("labirinto" in tipos), "%s: labirinto só na sala %d (próxima=%d) %s" % [rotulo, jogo.sala_do_minotauro, proxima, str(tipos)])
		if pend > 0:
			checar("puzzle" in tipos, "%s: há portal para um enigma pendente %s" % [rotulo, str(tipos)])
		if pend > 0 and pend >= vagas:
			checar(tipos.all(func(t): return t == "puzzle"), "%s: faltam %d enigmas e %d salas -> todos levam a enigma %s" % [rotulo, pend, vagas, str(tipos)])
	for p in portas_ativas(a):
		checar(p.destino != a, "%s: portal não leva para a mesma sala" % rotulo)
		if p.destino.tipo == "puzzle":
			checar(not p.destino.esta_concluida(), "%s: não sorteia enigma já resolvido" % rotulo)


func _rodar() -> void:
	await _tela_titulo()
	Config.mostrar_abertura = false
	fase = (load("res://cenas/fase_principal.tscn") as PackedScene).instantiate()
	root.add_child(fase)
	await esperar(1.0)
	jogo = get_first_node_in_group("jogo")
	teseu = get_first_node_in_group("jogador")
	cam = fase.get_node("Camera")
	var inicio := fase.find_child("Inicio", true, false)
	print("== Início ==")
	checar(get_nodes_in_group("area_sala").size() == 12, "12 áreas (início, 6 salas, 3 labirintos até os enigmas, labirinto, arena)")
	jogo.labirinto_antes_do_enigma = false   # ligado só no teste dele (antes da sala A)
	checar(fase.find_child("Corredores", true, false) == null, "não há mais corredores")
	checar_sorteio(inicio, "início")
	for id in ["A", "B", "C", "D", "E", "F"]:
		var n: int = sala(id).portas().size()
		checar(n == 3, "sala %s tem 3 portais (oeste, norte, leste): %d" % [id, n])
		var lados: Array = sala(id).portas().map(func(p): return String(p.name))
		lados.sort()
		checar(lados == ["PortaL", "PortaN", "PortaO"], "sala %s: portais em %s, entrada embaixo" % [id, str(lados)])
	checar(fase.get_node("HUD/Desenho").vida == 10, "HUD: 5 corações (10 meios)")
	checar(teseu._anim is AnimTeseu and teseu._anim.corpo != null, "Teseu: animação procedural no Visual/Corpo")
	checar(get_nodes_in_group("anfora_tutorial").size() == 3, "tutorial: 3 ânforas para quebrar na entrada")
	await esperar(0.3)
	await foto("22_tutorial_anforas")
	var anf: Node3D = get_nodes_in_group("anfora_tutorial")[0]
	anf.quebrar()
	await esperar(0.2)
	checar(not is_instance_valid(anf) or anf.is_queued_for_deletion(), "a ânfora quebra")
	var esc0: Vector3 = teseu._anim.corpo.scale
	teseu._atacar()
	await esperar(0.08)
	checar(teseu._anim.corpo.scale != esc0, "Teseu: golpe estica/achata o corpo (squash & stretch)")
	await esperar(0.4)
	checar(Som.faixa_atual() == "exploracao", "música de exploração na entrada")
	# simulação do sorteio no fim da partida (depois volta ao normal)
	jogo.salas_visitadas = 7
	jogo.sortear_destinos(inicio)
	checar(tipos_destino(inicio).all(func(t): return t == "puzzle"), "sala 8 com 3 enigmas faltando: todos os portais levam a enigma")
	jogo.salas_visitadas = 9
	jogo.sortear_destinos(inicio)
	checar(tipos_destino(inicio).all(func(t): return t == "labirinto"), "depois da 9ª sala: todos os portais levam ao labirinto")
	jogo.salas_visitadas = 0
	jogo.sortear_destinos(inicio)
	await esperar(1.0)
	await foto("01_inicio_portais")

	# ------------------------------------------------ atravessar um portal de verdade
	print("== Atravessar portal ==")
	var porta: Node3D = portas_ativas(inicio)[0]
	var destino: Node = porta.destino
	teseu.global_position = porta.global_position - porta.global_basis.z * 0.5 + Vector3.UP * 0.1
	await esperar(0.9)
	checar(destino.contem(teseu.global_position), "o portal levou o Teseu para '%s'" % destino.nome_sala)
	checar(teseu.global_position.z - destino.global_position.z > 3.0, "Teseu chega pela entrada de baixo")
	checar(jogo.salas_visitadas == 1 and fase.get_node("HUD/Desenho").sala_numero == 1, "HUD conta a sala 1 de 10")
	checar(destino.estado == 1, "ao chegar, o combate começa")
	checar(grades_fechadas(destino) == destino.portas().size(), "as portas da sala fecham")
	checar(portas_ativas(destino).is_empty(), "portais apagados durante o combate")
	checar(inimigos().size() > 0, "surgem minitaurinhos")
	var normais := inimigos().filter(func(n): return not (n is MinitaurinhoArremessador))
	checar(normais.size() > 0 and normais[0].vida == 3, "minitaurinho normal tem 3 de vida")
	checar(Som.faixa_atual() == "combate", "música de combate durante a luta")
	await esperar(0.4)
	await foto("02_chegada_" + destino.name)
	jogo.reiniciar_sala_atual()
	await esperar(0.3)
	await matar_inimigos()

	# ------------------------------------------------ A: estátuas
	print("== Labirinto até o enigma ==")
	var a := sala("A")
	if a.estado == 0:   # ainda não visitada
		jogo.labirinto_antes_do_enigma = true
		var n_antes: int = jogo.salas_visitadas
		await ir(a)
		var mini: Node = jogo.area_atual
		checar(mini is MiniLabirinto and mini.destino == a, "portal de enigma leva antes a um trecho de labirinto")
		checar(mini.contem(teseu.global_position), "Teseu chega dentro do labirinto")
		checar(jogo.salas_visitadas == n_antes + 1, "o labirinto conta como a sala")
		var passos: int = mini.caminho_solucao().size()
		checar(passos >= MiniLabirinto.CAMINHO_MIN and passos <= MiniLabirinto.CAMINHO_MAX, "caminho curto até a saída (%d células)" % passos)
		await esperar(0.6)
		await foto("28_labirinto_enigma")
		teseu.global_position = mini.saida_global()
		await esperar(1.0)
		checar(jogo.area_atual == a, "a saída dourada leva à sala do enigma")
		checar(jogo.salas_visitadas == n_antes + 1, "labirinto + enigma contam uma sala só")
		jogo.labirinto_antes_do_enigma = false
	print("== A: estátuas ==")
	if a.estado != 2:
		await ir(a)
		await matar_inimigos()
	checar(a.estado == 2, "A: puzzle ativo depois do combate")
	checar(a.get_node("Puzzle").demonstrado, "A: cena curta mostra o que fazer (sem texto)")
	checar(fase.get_node("HUD/Aviso").visible, "A: aviso em pictogramas aparece")
	await esperar(1.0)
	await foto("20_demo_estatuas")
	await esperar(3.0)
	checar(teseu._controle_ativo, "A: depois da cena o controle volta")
	checar(Som.faixa_atual() == "enigma", "música de enigma depois do combate")
	var pz_a := a.get_node("Puzzle")
	var est: Array[Node] = pz_a.filhos_no_grupo("estatua")
	var sx := Vector3(-1, 1, 1) if pz_a.espelhado else Vector3.ONE
	print("  (estátuas %s)" % ("espelhadas" if pz_a.espelhado else "normais"))
	for mv in [[0, Vector3.RIGHT], [0, Vector3.RIGHT], [1, Vector3.LEFT], [1, Vector3.LEFT],
			[2, Vector3.RIGHT], [2, Vector3.RIGHT], [2, Vector3.BACK]]:
		est[mv[0]].empurrar(mv[1] * sx)
		await esperar(0.35)
	await esperar(0.9)
	await foto("23_refens_livres")
	await esperar(0.9)
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
	var pz_c := c.get_node("Puzzle")
	for x in pz_c.filhos_no_grupo("braseiro"):
		br[x.simbolo] = x
	var ordem: Array = pz_c.ordem
	print("  (ordem sorteada: %s)" % str(ordem))
	var ord_s := ordem.duplicate()
	ord_s.sort()
	checar(br.size() == 4 and ord_s == ["lua", "onda", "raio", "sol"], "braseiros: 4 símbolos e a ordem é uma permutação deles")
	checar(ordem != ["sol", "lua", "onda", "raio"], "braseiros: ordem sorteada diferente da original")
	br[ordem[1]].interagir(teseu)
	await esperar(0.5)
	checar(inimigos().size() == 1, "errar a ordem chama reforço")
	await matar_inimigos()
	for simb in ordem.slice(0, 3):
		br[simb].interagir(teseu)
		await esperar(0.2)
	jogo.avisar(c.get_node("Puzzle").icones_dica(), 3.0)
	await esperar(1.0)
	await foto("05_C_braseiros")
	br[ordem[3]].interagir(teseu)
	await esperar(1.8)
	checar(c.esta_concluida() and jogo.prisioneiros_libertados == 8, "C resolvida, 8 libertados")
	checar_sorteio(c, "C")

	# ------------------------------------------------ E: espelhos
	print("== E: espelhos ==")
	var e := sala("E")
	await ir(e)
	await matar_inimigos()
	var cliques := []
	for nome in ["Espelho1", "Espelho2", "Espelho3"]:
		cliques.append(e.find_child(nome, true, false).cliques_ate_solucao())
	print("  (cliques sorteados: %s)" % str(cliques))
	checar(not (0 in cliques), "espelhos: nenhum começa na posição da solução")
	# bug: girar só o 1º espelho fazia o feixe "varrer" a sala e acertar o cristal
	var esp1 := e.find_child("Espelho1", true, false)
	for k in 8:
		esp1.interagir(teseu)
		for q in 20:
			await esperar(0.02)
			if e.esta_concluida():
				break
	checar(not e.esta_concluida(), "espelhos: girar só o 1º espelho não resolve (nem durante o giro)")
	for nome in ["Espelho1", "Espelho2", "Espelho3"]:
		var esp := e.find_child(nome, true, false)
		for k in esp.cliques_ate_solucao():
			esp.interagir(teseu)
			await esperar(0.35)
	await esperar(0.4)
	await foto("06_E_espelhos")
	# modo Raio-X (F1): vetores da reflexão nos espelhos, colisões, normais
	var rx := fase.get_parent().find_child("RaioX", true, false)
	if rx == null:
		rx = root.find_child("RaioX", true, false)
	checar(rx != null, "raio-x: nó criado pelo jogo")
	if rx:
		rx.alternar()
		await esperar(0.3)
		checar(rx._painel.text.contains("r = d") and rx._rotulos.size() >= 1, "raio-x: mostra d, n, r e o ângulo em cada espelho")
		await foto("06b_raio_x_espelhos")
		var antes: int = Toon.materiais_convertidos()
		Toon.definir(false)
		await esperar(0.2)
		checar(antes > 0 and Toon.materiais_convertidos() == 0, "F3: volta para a iluminação PBR")
		await foto("06c_pbr_sem_toon")
		Toon.definir(true)
		await esperar(0.2)
		checar(Toon.materiais_convertidos() > 0, "F3: cel shading de novo")
		rx.alternar()
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
	await _combate_novo(f)
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
	var fio := fase.find_child("FioAriadne", true, false)
	for k in 10:   # anda em zigue-zague para o fio aparecer no chão
		teseu.global_position += Vector3(0.35 if k % 4 < 2 else -0.2, 0, -0.3)
		await esperar(0.06)
	checar(fio != null and fio.pontos.size() >= 3, "o fio de Ariadne fica no chão por onde ele anda")
	await foto("21_fio_ariadne")
	teseu._invulneravel = 0.0
	teseu.levar_dano(1)
	await esperar(0.6)
	await foto("21b_fio_puxando")
	checar(jogo.novelo == antes - 1, "morrer gasta uma volta do novelo")
	checar(fio.puxando, "o fio puxa o Teseu de volta até a porta")
	await esperar(1.2)
	checar(teseu.global_position.distance_to(jogo.checkpoint) < 0.6 and teseu._controle_ativo,
		"depois do puxão ele renasce na porta")
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
	# a partida chega à 9ª sala: ao vencê-la, todos os portais levam ao Minotauro
	jogo.salas_visitadas = 9
	jogo.sortear_destinos(b2)
	checar_sorteio(b2, "9ª sala")
	var p_lab: Node3D = null
	for p in portas_ativas(b2):
		if p.destino.tipo == "labirinto":
			p_lab = p
	checar(p_lab != null, "sala vencida depois dos 3 enigmas tem portal para o labirinto")
	if p_lab:
		teseu.global_position = p_lab.global_position - p_lab.global_basis.z * 0.5 + Vector3.UP * 0.1
		await esperar(1.0)
		var lab := fase.find_child("Labirinto", true, false)
		var arena := fase.find_child("Arena", true, false)
		checar(lab != null and jogo.area_atual == lab and lab.contem(teseu.global_position), "portal leva à entrada do labirinto")
		checar(jogo.salas_visitadas == jogo.sala_do_minotauro, "o labirinto conta como a 10ª sala")
		var caminho: PackedVector3Array = lab.caminho_solucao()
		checar(caminho.size() >= 5, "o labirinto sempre tem caminho da entrada até a arena (%d passos)" % caminho.size())
		await esperar(0.6)
		await foto("26_labirinto")
		# segue o caminho certo, célula por célula (o fio vai ficando no chão)
		for k in caminho.size():
			teseu.global_position = caminho[k] + Vector3.UP * 0.1
			await esperar(0.05)
		checar(jogo.area_atual == lab, "ainda no labirinto antes do portão")
		await foto("27_labirinto_fio")
		teseu.global_position = arena.to_global(Vector3(0, 0.1, 6.0))
		await esperar(0.6)
		checar(jogo.area_atual == arena, "atravessar o portão do centro leva à arena")
		checar(jogo.salas_visitadas == jogo.sala_do_minotauro, "entrar na arena não conta sala a mais")
		await _luta_chefe(arena)
	await _abertura_e_game_over()
	print("== RESULTADO: %d falha(s) ==" % falhas)
	quit(falhas)



# ------------------------------------------------------------------ escudo, arremessador, partículas
func _combate_novo(f: Node) -> void:
	print("== Escudo e arremessador ==")
	var arr := inimigos().filter(func(n): return n is MinitaurinhoArremessador)
	checar(arr.size() >= 2, "Antecâmara tem minitaurinhos arremessadores (%d)" % arr.size())
	for i in inimigos():
		i.set_physics_process(false)  # congela para o teste ficar previsível
	teseu.global_position = f.global_position + Vector3(0, 0.1, 1.0)
	teseu.vida = 10
	teseu._direcao_olhar = Vector3.FORWARD  # olhando para -Z
	Input.action_press("defender")
	await esperar(0.15)
	checar(teseu.defendendo, "segurar Shift ergue o escudo")
	teseu._invulneravel = 0.0
	teseu.levar_dano(1, Vector3.BACK)        # golpe vindo da frente (-Z)
	checar(teseu.vida == 10, "escudo bloqueia golpe de frente (vida=%d)" % teseu.vida)
	teseu._invulneravel = 0.0
	teseu.levar_dano(3, Vector3.BACK)
	checar(teseu.vida == 9, "escudo reduz pela metade o golpe forte (vida=%d)" % teseu.vida)
	teseu._invulneravel = 0.0
	teseu.levar_dano(1, Vector3.FORWARD)     # golpe vindo de trás
	checar(teseu.vida == 8, "golpe pelas costas passa pelo escudo (vida=%d)" % teseu.vida)
	# pedra vindo da frente com o escudo: quebra sem dano
	teseu._invulneravel = 0.0
	var vida0: int = teseu.vida
	var pedra := PedraArremessada.new()
	f.add_child(pedra)
	pedra.global_position = teseu.global_position + Vector3(0, 1.1, -4.0)
	pedra.lancar(Vector3.BACK, 7.5)
	await esperar(0.8)
	checar(not is_instance_valid(pedra) and teseu.vida == vida0, "escudo bloqueia a pedra (vida=%d)" % teseu.vida)
	Input.action_release("defender")
	await esperar(0.1)
	checar(not teseu.defendendo, "soltar Shift abaixa o escudo")
	# pedra sem escudo: acerta
	teseu._invulneravel = 0.0
	var pedra2 := PedraArremessada.new()
	f.add_child(pedra2)
	pedra2.global_position = teseu.global_position + Vector3(0, 1.1, -4.0)
	pedra2.lancar(Vector3.BACK, 7.5)
	await esperar(0.8)
	checar(teseu.vida == vida0 - 2, "pedra sem escudo tira 1 coração (vida=%d)" % teseu.vida)
	checar(arr[0].vida == 2, "arremessador tem 2 de vida")
	# espada quebra a pedra
	var pedra3 := PedraArremessada.new()
	f.add_child(pedra3)
	pedra3.global_position = teseu.global_position + Vector3(0, 1.1, -1.2)
	pedra3.lancar(Vector3.BACK, 0.5)
	await esperar(0.05)
	teseu._cooldown_ataque = 0.0
	teseu._atacar()
	await esperar(0.05)
	checar(not is_instance_valid(pedra3) or pedra3.is_queued_for_deletion(), "a espada quebra a pedra")
	# o arremessador mira e arremessa de verdade
	var a0: Node3D = arr[0]
	a0.set_physics_process(true)
	a0.global_position = f.global_position + Vector3(0, 0.1, -3.5)
	teseu.global_position = f.global_position + Vector3(0, 0.1, 2.0)
	a0._cooldown = 0.0
	a0._espera = 0.0
	var viu_pedra := false
	for k in 25:
		await esperar(0.1)
		if not get_nodes_in_group("projetil").is_empty():
			viu_pedra = true
			break
	checar(viu_pedra, "o arremessador ergue a pedra e arremessa")
	await foto("14_arremessador")
	# partículas: faíscas, fumaça
	teseu._invulneravel = 99.0
	for i in get_nodes_in_group("inimigo"):
		i.levar_dano(99)
	await esperar(0.1)
	var particulas := root.find_children("*", "CPUParticles3D", true, false).size()
	checar(particulas > 0, "partículas na tela (%d emissores)" % particulas)
	teseu._invulneravel = 0.0
	teseu.vida = 10


# ------------------------------------------------------------------ tela de título
func _tela_titulo() -> void:
	print("== Tela de título ==")
	var t := (load("res://cenas/titulo.tscn") as PackedScene).instantiate()
	root.add_child(t)
	await esperar(1.5)
	var col := t.get_node("UI/Principal/Caixa/Coluna")
	checar(col.get_node("Jogar") is Button and col.get_node("Creditos") is Button and col.get_node("Sair") is Button,
		"título tem Jogar / Créditos / Sair")
	checar(Som.faixa_atual() == "titulo", "música do título tocando")
	await foto("00_titulo")
	t._abrir("creditos")
	await esperar(0.3)
	checar(t.get_node("UI/Creditos").visible and not t.get_node("UI/Principal").visible, "créditos abrem")
	await foto("00b_creditos")
	t._voltar()
	var q0 := Config.qualidade
	t._trocar_qualidade()
	checar(Config.qualidade != q0, "opção de qualidade troca (%s -> %s)" % [q0, Config.qualidade])
	checar(t.get_node("TiltShift").visible == (Config.qualidade == "alta"), "qualidade baixa desliga o tilt-shift")
	if Config.qualidade == "baixa":
		await foto("00c_titulo_qualidade_baixa")
	t._trocar_qualidade()
	t._voltar()
	t.queue_free()
	await esperar(0.3)


# ------------------------------------------------------------------ abertura e game over
func _abertura_e_game_over() -> void:
	print("== Abertura (Ariadne) e game over ==")
	fase.queue_free()
	await esperar(0.5)
	Config.mostrar_abertura = true
	fase = (load("res://cenas/fase_principal.tscn") as PackedScene).instantiate()
	root.add_child(fase)
	await esperar(2.5)
	jogo = get_first_node_in_group("jogo")
	teseu = get_first_node_in_group("jogador")
	checar(jogo.em_cinematica, "a partida começa com a cena da Ariadne")
	checar(fase.get_node("HUD/FaixaCima").visible, "faixas de cinema aparecem")
	checar(not teseu._controle_ativo, "Teseu fica parado durante a cena")
	var viu_balao := false
	for k in 100:
		if fase.get_node("HUD").get_children().any(func(n): return n is Balao or n is Pensamento):
			viu_balao = true
			break
		await esperar(0.1)
	checar(viu_balao, "abertura em pantomima: balões de pictogramas (celas, Minotauro, Ariadne)")
	checar(fase.get_node("HUD/Dialogo").modulate.a < 0.05, "nenhuma caixa de texto na abertura")
	await foto("17_abertura_refens")
	# fotografa o Minotauro rugindo e o pensamento da Ariadne (só com janela)
	if DisplayServer.get_name() != "headless":
		var m_ab := fase.find_child("Minotauro", true, false)
		var foi_mino := false
		for k in 400:
			await esperar(0.1)
			if not foi_mino and m_ab and m_ab.estado == 1:
				await esperar(0.9)
				await foto("18_abertura_minotauro")
				foi_mino = true
			if fase.get_node("HUD").get_children().any(func(n): return n is Pensamento):
				await esperar(2.5)
				await foto("19_abertura_pensamento")
				break
	await foto("15_abertura_ariadne")
	jogo._pular = true
	await esperar(1.0)
	checar(not jogo.em_cinematica and teseu._controle_ativo, "Esc pula a cena e devolve o controle")
	var mino := fase.find_child("Minotauro", true, false)
	checar(mino.estado == 0 and mino.global_position.distance_to(mino.get_parent().to_global(mino._posicao_inicial)) < 0.3,
		"depois da cena o Minotauro volta parado para o lugar")
	checar(teseu.get_node("Visual/Novelo").scale.x > 0.9, "o novelo está na cabeça do Teseu")
	Config.mostrar_abertura = false
	# game over: sem novelo e morre
	jogo.novelo = 0
	teseu._invulneravel = 0.0
	teseu.vida = 1
	teseu.levar_dano(1)
	await esperar(2.5)
	checar(fase.get_node("HUD/GameOver").visible, "novelo acabou -> tela de GAME OVER")
	checar(jogo.terminou and Som.faixa_atual() == "", "game over para a música e trava o jogo")
	await foto("16_game_over")


# ------------------------------------------------------------------ chefe
func _luta_chefe(arena: Node) -> void:
	print("== Minotauro ==")
	var chefe: Node3D = arena.find_child("Minotauro", true, false)
	var hud := fase.get_node("HUD/Desenho")
	checar(chefe != null, "o Minotauro está na arena")
	checar(chefe.estado == 1, "a luta começa com o rugido (intro)")
	checar(hud.chefe_ativo and hud.chefe_maximo == chefe.vida_maxima, "barra de vida do chefe aparece")
	checar(Som.faixa_atual() == "chefe", "música do chefe")
	var mat_tilt: ShaderMaterial = fase.find_child("Filtro", true, false).material
	checar(float(mat_tilt.get_shader_parameter("desfoque_max")) < 0.6, "tilt-shift mais leve na arena (%.2f)" % float(mat_tilt.get_shader_parameter("desfoque_max")))
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

	# investida que ACERTA: joga o Teseu para o lado e o Minotauro freia
	await esperar(2.6)
	teseu.vida = 99
	teseu._invulneravel = 0.0
	chefe.global_position = arena.global_position + Vector3(3.5, 0.05, 0)
	chefe.rotation.y = -PI / 2
	teseu.global_position = arena.global_position + Vector3(-1.0, 0.1, 0.25)
	var z0: float = teseu.global_position.z
	chefe._mudar(2)
	chefe._cooldown_investida = 0.0
	var freou := false
	var atordoou := false
	var vida_antes: int = teseu.vida
	for k in 50:
		await esperar(0.1)
		if chefe.estado == 10:
			freou = true
		if chefe.estado == 5:
			atordoou = true
		if freou and chefe.estado == 2:
			break
	checar(freou and not atordoou, "investida que acerta: ele freia e NÃO fica atordoado")
	checar(teseu.vida < vida_antes, "investida fere o Teseu")
	checar(absf(teseu.global_position.z - z0) > 1.2, "investida joga o Teseu para o lado (desvio %.1f m)" % absf(teseu.global_position.z - z0))

	# morreu na arena: o Minotauro recupera só 25%
	chefe.vida = 8
	teseu.vida = 1
	teseu._invulneravel = 0.0
	teseu.levar_dano(1)
	await esperar(0.5)
	checar(chefe.vida == 14, "Teseu morreu: Minotauro recupera só 25%% (8 -> %d de 24)" % chefe.vida)
	await esperar(3.2)

	# preso atrás da pilastra do canto: tem que sair sozinho
	teseu.vida = 99
	teseu._invulneravel = 99.0
	teseu.global_position = arena.global_position + Vector3(0, 0.1, 1.0)
	chefe.global_position = arena.global_position + Vector3(5.9, 0.05, -5.9)
	chefe._mudar(2)
	chefe._cooldown_investida = 99.0
	var p0: Vector3 = chefe.global_position
	var saiu := false
	for k in 50:
		await esperar(0.1)
		if chefe.global_position.distance_to(p0) > 2.5 or chefe.estado in [6, 7]:
			saiu = true
			break
	checar(saiu, "Minotauro não fica preso na pilastra do canto")
	teseu._invulneravel = 0.0
	teseu.vida = 99

	# fase 2
	chefe._mudar(2)
	chefe.vida = chefe.vida_maxima / 2 + 1
	chefe._invulneravel = 0.0
	teseu.global_position = chefe.global_position + chefe.global_basis.z * 2.0 + Vector3.UP * 0.1
	teseu._direcao_olhar = -chefe.global_basis.z
	teseu._cooldown_ataque = 0.0
	teseu._atacar()
	await esperar(0.3)
	checar(chefe.fase2, "com metade da vida entra na fase 2")
	checar(inimigos().size() == 2, "fase 2 chama 2 minitaurinhos")
	var meio_a: Vector2 = arena.get("meio_tamanho") if arena.get("meio_tamanho") != null else Vector2(6, 6)
	var dentro := true
	for cria in inimigos():
		var l: Vector3 = (cria as Node3D).global_position - (arena as Node3D).global_position
		if absf(l.x) > meio_a.x - 0.5 or absf(l.z) > meio_a.y - 0.5:
			dentro = false
	checar(dentro, "as crias nascem dentro da arena")
	var longe: Vector3 = chefe._ponto_dentro_da_arena((arena as Node3D).global_position + Vector3(40, 0, -40))
	var ll: Vector3 = longe - (arena as Node3D).global_position
	checar(absf(ll.x) < meio_a.x and absf(ll.z) < meio_a.y, "ponto de nascimento é preso dentro da arena")
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
	await foto("24_queda_foto")
	await esperar(2.5)
	await foto("24b_queda_camera_lenta")
	await esperar(2.5)
	await foto("25_queda_trofeu")
	checar(arena.esta_concluida(), "arena vencida")
	# final: o fio leva todos de volta à entrada, onde a Ariadne espera
	await esperar(3.5)
	var entrada: Node = null
	for ar_ in jogo._areas():
		if ar_.tipo == "inicio":
			entrada = ar_
	var atenienses := entrada.find_children("Ateniense*", "", false, false)
	checar(atenienses.size() == 13, "final: os 13 atenienses saem junto com o Teseu")
	var fio := entrada.find_child("FioFinal", false, false)
	checar(fio != null and fio.get_child_count() >= 5, "final: o fio vermelho fica no chão até a Ariadne")
	checar(jogo.area_atual == entrada, "final acontece na entrada do labirinto")
	await foto("13a_final_saida")
	jogo._pular = true
	await esperar(3.0)
	checar(fase.get_node("HUD/Vitoria").visible, "tela de vitória aparece (Esc pula o final)")
	await foto("13_vitoria")
	# créditos (rodando de novo só para a foto)
	jogo._pular = false
	var hud_c := fase.get_node("HUD")
	hud_c.rolar_creditos()
	await esperar(4.0)
	checar(hud_c.find_child("Creditos", false, false) != null, "créditos sobem na tela")
	await foto("13b_creditos")
	jogo._pular = true
	await esperar(1.5)
	jogo._pular = false
