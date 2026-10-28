# Labirinto do Minotauro: salas ligadas por portais

Feito para **Godot 4.7** no renderizador **Compatibilidade**.

## Como instalar

Extraia o zip, clique em **Importar** no Godot, escolha o `project.godot` e
aperte **F5**. A cena principal agora é a **tela de título**
(`cenas/titulo.tscn`); para pular direto para o jogo, abra
`cenas/fase_principal.tscn` e aperte **F6**.

## Controles

| Tecla | Ação |
|---|---|
| WASD / setas | andar |
| Espaço / J | espada |
| **Shift** / L (segurar) | escudo: bloqueia o que vem da frente |
| E / K | usar (alavanca, braseiro, espelho) |
| andar contra a estátua | empurrar (1 m por vez) |
| **R** | reiniciar a sala atual |
| **Esc** / P | menu: continuar, reiniciar sala, reiniciar jogo, menu inicial (na cena da Ariadne: pula a cena) |

## Como o labirinto funciona

Não tem mais corredores: cada sala fica isolada e **toda porta é um portal**.

1. Ao chegar numa sala, as portas fecham com grade e surgem os minitaurinhos.
2. Vencida a sala, os portais acendem, todos iguais. **O destino é surpresa:**
   o portal não mostra para onde leva.
3. Por baixo, o sorteio (`GerenciadorJogo.sortear_destinos`) garante que o
   jogo sempre pode ser terminado:
   - enquanto faltar enigma, **pelo menos um portal leva a um enigma pendente**
     (mas o jogador não sabe qual);
   - os outros portais levam a **salas de combate aleatórias** (30% de chance de
     ser outro enigma);
   - com os **3 enigmas** resolvidos, um portal passa a levar ao **Minotauro**;
   - um portal nunca leva para a própria sala nem para um enigma já resolvido.
   Para depurar, marque `revelar_destino` numa porta para ver a cor do destino.
4. **Salas de combate podem se repetir**, e voltam com +1 inimigo a cada
   visita (até 6). Vencer uma sala de combate cura **2 corações**.

| Sala | Tipo | Portas | Inimigos | Presos |
|---|---|---|---|---|
| Entrada do Labirinto | início | 2 | - | - |
| Sala das Estátuas | enigma | 3 | 3 | 4 |
| Sala dos Braseiros | enigma | 2 | 3 | 4 |
| Sala dos Espelhos | enigma | 3 | 4 | 5 |
| Salão dos Chifres | combate | 3 | 3+ | - |
| Cova dos Minitauros | combate | 2 | 4+ | - |
| Antecâmara | combate | 3 | 4+ | - |
| Arena do Minotauro | chefe | - | - | - |

Para testar com sempre o mesmo sorteio, coloque um número em `semente` no nó
`GerenciadorJogo` (0 = aleatório).

## HUD (estilo Zelda: Link's Awakening)

- **Corações** com meio coração (5 corações). Cada golpe de minitaurinho tira
  **meio coração**. Eles piscam quando a vida está baixa.
- **Novelos de Ariadne** logo abaixo: ficam cinza quando gastos. O novelo na
  cabeça do Teseu também encolhe.
- **Botões de item** redondos no canto superior direito: espada [Espaço] e
  usar [E].
- **Enigmas**: 3 losangos que ficam dourados, como os instrumentos do Zelda.
- **Atenienses libertados** no canto inferior direito, como as rúpias.
- **Caixa de diálogo** com o texto sendo digitado e o **nome da sala** ao chegar.

Tudo é desenhado por código em `scripts/ui/hud_desenho.gd`, sem imagens. Os
corações saem da curva paramétrica do coração.

## Puzzles (mudam a cada partida)

- **Estátuas:** empurre as 3 estátuas até as placas douradas. A alavanca
  devolve tudo ao lugar. Em metade das partidas o enigma aparece **espelhado**.
- **Braseiros:** cada símbolo tem uma cor. Acenda na ordem do mosaico; errar
  chama um reforço. A **ordem do mosaico** e **qual braseiro tem qual símbolo**
  são sorteadas (`sortear` no nó Puzzle; desligue para usar a ordem fixa).
- **Espelhos:** gire os 3 espelhos até a luz chegar ao cristal (raycast +
  reflexão `r = d − 2(d·n)n`). Cada espelho **começa num ângulo sorteado**
  (nunca já na solução). O ângulo certo fica em `angulo_solucao` de cada espelho.

## Combate

- **Escudo (Shift):** Teseu anda mais devagar e não ataca, mas bloqueia golpes
  e pedras **de frente**. Minitaurinho e pedra: sem dano. Minotauro: metade.
- **Minitaurinho arremessador** (pelo cinza, faixa vermelha): fica longe, ergue a
  pedra acima da cabeça (aviso) e arremessa. A espada quebra a pedra no ar.
  Quantos aparecem por sala: tabela `ARREMESSADORES` em `gerar_cenas.gd`
  (Salão dos Chifres 1, Cova 1, Espelhos 1, Antecâmara 2; +1 a cada 2 revisitas).
- **Partículas** (`scripts/visual/efeitos.gd`): faíscas, poeira, fumaça, estilhaços.

## Som e música

`Som.tocar("nome")` e `Som.musica("faixa")` funcionam de qualquer script, sem
Autoload. Efeitos em `assets/audio/sfx/`, músicas em `assets/audio/musica/`:

| Música | Quando toca |
|---|---|
| `titulo` | tela de título e depois da vitória |
| `exploracao` | entrada e salas vencidas |
| `combate` | enquanto há minitaurinhos na sala |
| `enigma` | enigma liberado depois do combate |
| `chefe` | arena do Minotauro |

Para trocar um som por outro, basta substituir o arquivo mantendo o nome.
Para gerar tudo de novo: `python3 ferramentas/audio/gerar_sons.py`.

## Telas

- **Título:** Jogar, Como jogar, Opções (qualidade ALTA/BAIXA e volumes, salvos em
  `user://config.cfg`), Créditos (edite o texto em `scripts/ui/titulo.gd`) e Sair.
- **Abertura:** a Ariadne fala com o Teseu e o novelo voa até a cabeça dele.
  Espaço/E avança as falas, Esc pula. Só aparece ao vir do título.
- **Game over:** quando o novelo acaba. Tentar de novo ou voltar ao título.

## Desempenho (GPU integrada, ex.: Radeon 610M)

A qualidade **BAIXA** (Opções) desliga a luz dinâmica das tochas, o tilt-shift
e o MSAA, usa sombra mais simples e renderiza o 3D em 85% da resolução. Na
primeira vez que o jogo abre numa GPU integrada, ele já começa em BAIXA.
O tilt-shift foi otimizado (9 amostras em vez de 25) e é mais leve na arena.

## Pontos de Computação Gráfica para a apresentação

- Reflexão vetorial com raycast: `scripts/puzzles/espelhos/fonte_luz.gd`
- Shader do portal (redemoinho em coordenadas polares): `scripts/visual/portal.gdshader`
- Tilt-shift (pós-processamento de tela): `scripts/visual/tilt_shift.gdshader`
- Coração por curva paramétrica no HUD: `scripts/ui/hud_desenho.gd`
- Modelagem procedural no Blender (Python): `ferramentas/blender/modelos.py`
- Animação procedural do Minotauro (pivôs + estados): `scripts/inimigos/minotauro.gd`

## A luta contra o Minotauro

Ao atravessar o portal do Minotauro (depois dos 3 enigmas), a luta começa.
Barra de vida no topo e 24 de vida. Padrões, cada um com aviso visual:

- **Perseguição:** ele trota atrás do Teseu.
- **Golpe de machado:** se o Teseu chega perto, ele **ergue o machado** (aviso)
  e bate no chão, soltando uma onda de choque na frente. Tira 1 coração.
- **Investida:** ele **empina e aparece uma faixa vermelha no chão** (aviso),
  depois dispara em linha reta. Tira 1,5 coração.
  Se bater numa **parede ou coluna**, fica **atordoado** (estrelas na cabeça):
  é a hora de atacar, porque a espada tira o **dobro**.
- **Fase 2** (metade da vida): ele ruge, fica mais rápido e chama 2 minitaurinhos.
- Morreu na arena: a luta recomeça e gasta uma volta do novelo.
- Venceu: tela de **vitória** com o resumo e o botão "Jogar de novo".

A animação é **procedural**: o modelo tem pivôs (pernas, tronco, cabeça, braços,
cauda) que giram por código conforme o estado (`scripts/inimigos/minotauro.gd`),
sem precisar de esqueleto.

## O que é provisório

- **Teseu e minitaurinho:** o Teseu já usa a **espada xiphos** e o **escudo
  hoplon** modelados (`assets/modelos/armas/`), mas o corpo ainda é o do NPC.
  Para trocar pelo modelo final, troque o nó `Visual` (mantenha
  `Visual/Novelo` e `Visual/Espada`).

## Para modificar

- **Salas, portas, inimigos:** tabela `SALAS_MAPA` em `ferramentas/godot/gerar_cenas.gd`.
  Para regenerar (**sobrescreve `cenas/`**, e precisa ser sem `--headless`):
  `godot --path . --script res://ferramentas/godot/gerar_cenas.gd`
- **Modelos:** `blender --background --python ferramentas/blender/modelos.py`
- **Teste automático** (mais de 110 verificações, incluindo título, escudo,
  arremessador, abertura, game over e a luta do chefe):
  `godot --path . --script res://ferramentas/godot/teste_automatico.gd`
