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

Tudo é feito de cápsulas e caixas, montadas por código em `scripts/main.gd`.
A ideia é programar a jogabilidade agora e trocar as peças pelos modelos do Blender depois.

- Teseu (cápsula azul) com câmera de cima em 3/4.
- 5 salas ligadas por corredores: Entrada → Pilares → Leste/Oeste, e a sala do Minotauro ao norte.
- Ao entrar numa sala, as **grades fecham** até todos os minitaurinhos caírem.
- Minitaurinhos "preparam" o golpe (ficam mais claros) antes de bater: dá para desviar.
- **Novelo de Ariadne:** 3 respawns. Ao morrer, Teseu volta para a última sala liberada.
- A porta do Minotauro (grade dourada) só abre depois das três salas liberadas.
- O Minotauro é maior, tem mais vida e faz investidas.

## Estrutura

```
scenes/main.tscn      cena principal (só um nó com o main.gd)
scripts/main.gd       monta o labirinto e cuida das regras do jogo
scripts/sala.gd       sala: chão, paredes, grades, gatilho e inimigos
scripts/jogador.gd    Teseu: movimento, ataque, vida
scripts/inimigo.gd    minitaurinho e Minotauro (IA simples)
scripts/hud.gd        vida, novelos, salas e mensagens
scripts/construtor.gd funções para criar caixas, materiais e tochas
assets/modelos/       .glb exportados do Blender
assets/texturas/      texturas
```

## Combinados entre modelagem e programação

1. Escala: 1 unidade do Blender = 1 m no Godot.
2. Peças de cenário em múltiplos de 1 m (corredor de 2 m, sala padrão 8×8, sala do Minotauro 14×14).
3. Origem dos personagens **nos pés**; peças de cenário com origem **num canto**.
4. Todos os personagens olhando para a câmera da vista frontal do Blender (Numpad 1, eixo **-Y**). No Godot, se o modelo chegar de costas, gira-se o nó do modelo 180°, nunca o modelo no Blender.
5. Nomes das animações: `idle`, `andar`, `atacar`, `dano`, `morte`.
6. Exportar em glTF binário (`.glb`), com modificadores aplicados, para `assets/modelos/`.

## Próximos passos

- Testar o fluxo Blender → Godot com um boneco simples (THDL-68).
- Trocar as cápsulas pelos modelos do Teseu, minitaurinho e Minotauro.
- Trocar as caixas pelo kit modular do labirinto.
- Visual de diorama: câmera, iluminação e shader *tilt-shift*.
