# Labirinto do Minotauro

Trabalho final de Computação Gráfica (UNIFAL-MG), grupo **Herdeiros de Luca**.
Teseu entra no labirinto de Creta, derrota os minitaurinhos de cada sala e enfrenta o Minotauro.

Engine: **Godot 4.7.2 (versão padrão, sem .NET)** com **GDScript**. Renderizador: Compatibilidade.

## Como rodar

1. Abra o Godot 4.7.2 → **Importar** → selecione o `project.godot` desta pasta.
2. Aperte **F5** (ou o botão ▶ no canto superior direito).

| Tecla | Ação |
|---|---|
| WASD / setas | andar |
| Espaço / J | atacar |
| R | recomeçar |

## Estado atual: protótipo cinza (THDL-69)

Tudo é feito de cápsulas e caixas, montadas por código. A ideia é programar a jogabilidade agora
e trocar as peças pelos modelos do Blender depois.

O labirinto é **gerado por algoritmo**, no estilo do labirinto do Minotauro do Twilight Forest:

- Grade de 17×17 células de 4 m (~68×68 m), com corredores estreitos, becos sem saída e alguns ciclos.
- **Entrada** no sul; **sala do Minotauro** (grade dourada) no norte, trancada até todas as salas de combate serem liberadas.
- **4 salas de combate:** ao entrar, as grades fecham até todos os minitaurinhos caírem. A sala liberada vira ponto de retorno.
- **2 fontes** (azuis): recuperam a vida e marcam o ponto de retorno.
- **Minitaurinhos errantes** andam pelos corredores e, quando sentem o Teseu por perto, seguem o caminho do labirinto até ele.
- **Fio de Ariadne:** Teseu deixa um fio vermelho no chão por onde passa, para não se perder. Os 3 novelos são os respawns.
- Os inimigos "preparam" o golpe (ficam mais claros) antes de bater: dá para desviar. O Minotauro faz investidas.

Para mudar o labirinto, edite as constantes no topo de `scripts/main.gd`:
`SEMENTE` (0 = labirinto diferente a cada partida), `LARGURA`, `ALTURA`, `N_SALAS_COMBATE`, `N_FONTES`,
`CHANCE_CICLO` e `N_ERRANTES`. Com a mesma semente, todo o grupo vê o mesmo mapa.

## Estrutura

```
scenes/main.tscn      cena principal (só um nó com o main.gd)
scripts/main.gd       monta o labirinto a partir do gerador e cuida das regras do jogo
scripts/gerador_labirinto.gd  gera o mapa (salas, corredores, portas, ciclos) e o caminho A*
scripts/sala.gd       lógica das salas: grades, gatilho, inimigos, fonte
scripts/fio.gd        o fio de Ariadne desenhado no chão
scripts/jogador.gd    Teseu: movimento, ataque, vida
scripts/inimigo.gd    minitaurinho (de sala ou errante) e Minotauro
scripts/hud.gd        vida, novelos, salas e mensagens
scripts/construtor.gd funções para criar caixas, materiais e tochas
assets/modelos/       .glb exportados do Blender
assets/texturas/      texturas
```

## Combinados entre modelagem e programação

1. Escala: 1 unidade do Blender = 1 m no Godot.
2. Peças de cenário na grade do labirinto: célula de 4×4 m, paredes de 0,6 m de espessura e 2,6 m de altura.
3. Origem dos personagens **nos pés**; peças de cenário com origem **num canto**.
4. Todos os personagens olhando para a câmera da vista frontal do Blender (Numpad 1, eixo **-Y**). No Godot, se o modelo chegar de costas, gira-se o nó do modelo 180°, nunca o modelo no Blender.
5. Nomes das animações: `idle`, `andar`, `atacar`, `dano`, `morte`.
6. Exportar em glTF binário (`.glb`), com modificadores aplicados, para `assets/modelos/`.

## Próximos passos

- Testar o fluxo Blender → Godot com um boneco simples (THDL-68).
- Trocar as cápsulas pelos modelos do Teseu, minitaurinho e Minotauro.
- Trocar as caixas pelo kit modular do labirinto.
- Visual de diorama: câmera, iluminação e shader *tilt-shift*.
