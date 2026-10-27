"""
Gera todos os modelos do cenário, props e puzzles do Labirinto do Minotauro.

Uso (com Blender instalado):
    blender --background --python ferramentas/blender/modelos.py
ou, com o módulo bpy no Python:
    python3 ferramentas/blender/modelos.py

Saída:
    assets/modelos/<categoria>/<nome>.glb   -> importado pelo Godot
    assets/modelos/fontes/<nome>.blend      -> para editar no Blender

Para mudar uma medida, edite a função do modelo e rode o script de novo.
Nomes de objetos usados pelos scripts do Godot estão marcados com  # <- Godot
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from construtor import (Peca, exportar, limpar_cena, material, raiz, vazio)  # noqa: E402

RAIZ_PROJETO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
PASTA_MODELOS = os.path.join(RAIZ_PROJETO, "assets", "modelos")
PASTA_FONTES = os.path.join(PASTA_MODELOS, "fontes")


def M(nome, **kw):
    return material(nome, **kw)


# ==========================================================================
# KIT DO CENÁRIO
# ==========================================================================
def piso():
    """Ladrilho de 1×1 m; topo em z = 0 (o piso fica rente ao chão)."""
    r = raiz("Piso")
    p = Peca("Ladrilho")
    p.caixa(M("pedra_junta"), (1.0, 1.0, 0.12), (0, 0, -0.06))
    p.caixa(M("pedra_piso"), (0.92, 0.92, 0.06), (0, 0, -0.01))
    p.caixa(M("pedra_clara"), (0.66, 0.12, 0.012), (0, 0.3, 0.02))
    p.criar(bevel=0.015, pai=r)


def parede():
    """Parede de 1 m de largura, 1,5 m de altura, 0,3 m de espessura, em tijolos."""
    r = raiz("Parede")
    p = Peca("Tijolos")
    alt_fiada, esp = 0.34, 0.3
    for fiada in range(4):
        z = fiada * alt_fiada + alt_fiada / 2
        desloc = 0.25 if fiada % 2 else 0.0
        x = -0.5 - desloc
        while x < 0.5:
            x0, x1 = max(x, -0.5), min(x + 0.5, 0.5)
            if x1 - x0 > 0.05:
                p.caixa(M("parede"), (x1 - x0 - 0.03, esp - 0.02, alt_fiada - 0.03),
                        ((x0 + x1) / 2, 0, z))
            x += 0.5
    p.caixa(M("parede_escura"), (0.98, esp - 0.08, 4 * alt_fiada - 0.02),
            (0, 0, 2 * alt_fiada))
    p.caixa(M("parede_borda"), (1.0, esp + 0.04, 0.14), (0, 0, 4 * alt_fiada + 0.07))
    p.criar(bevel=0.02, pai=r)


def parede_baixa():
    """Faixa baixa para o lado da parede virado para a câmera (não tapa a visão)."""
    r = raiz("ParedeBaixa")
    p = Peca("Faixa")
    p.caixa(M("parede"), (0.97, 0.28, 0.26), (0, 0, 0.13))
    p.caixa(M("parede_borda"), (1.0, 0.34, 0.1), (0, 0, 0.31))
    p.criar(bevel=0.02, pai=r)


def pilar():
    r = raiz("Pilar")
    p = Peca("Pilar")
    p.caixa(M("parede_borda"), (0.56, 0.56, 0.16), (0, 0, 0.08))
    p.caixa(M("parede"), (0.46, 0.46, 1.32), (0, 0, 0.82))
    p.caixa(M("parede_borda"), (0.58, 0.58, 0.16), (0, 0, 1.56))
    p.criar(bevel=0.025, pai=r)


def arco_porta():
    """Moldura para uma passagem de 2 m. Largura total 3 m."""
    r = raiz("ArcoPorta")
    p = Peca("Arco")
    for lado in (-1, 1):
        x = lado * 1.25
        p.caixa(M("parede"), (0.5, 0.36, 1.5), (x, 0, 0.75))
        p.caixa(M("parede_borda"), (0.56, 0.42, 0.12), (x, 0, 0.06))
    # arco semicircular feito de aduelas (cunhas exatas, sem sobreposição)
    n, r_in, r_out, folga = 9, 1.0, 1.5, 0.012
    for i in range(n):
        a0 = math.pi * i / n + folga
        a1 = math.pi * (i + 1) / n - folga
        contorno = []
        for a, raio in ((a0, r_in), (a1, r_in), (a1, r_out), (a0, r_out)):
            contorno.append((math.cos(a) * raio, 1.5 + math.sin(a) * raio * 0.62))
        # prisma no plano XY girado para ficar no plano XZ (frente em -Y)
        p.prisma(M("parede" if i % 2 else "parede_escura"), contorno, 0.36,
                 pos=(0, 0.18, 0), rot=(90, 0, 0))
    p.caixa(M("ouro"), (0.26, 0.4, 0.26), (0, 0, 1.5 + 1.25 * 0.62))
    p.criar(bevel=0.025, pai=r)


def grade_porta():
    """Grade que desce/sobe para trancar a sala. O nó 'Grade' é o que se move."""
    r = raiz("GradePorta")
    g = Peca("Grade")  # <- Godot (anima a posição Y)
    for i in range(7):
        x = -0.9 + i * 0.3
        g.cilindro(M("ferro", rugosidade=0.45, metal=0.6), 0.045, 1.5, (x, 0, 0), lados=10)
        g.cilindro(M("ferro", rugosidade=0.45, metal=0.6), 0.06, 0.12, (x, 0, -0.06),
                   raio_topo=0.0, lados=10, rot=(180, 0, 0))
    for z in (0.4, 1.1):
        g.caixa(M("ferro", rugosidade=0.45, metal=0.6), (2.0, 0.08, 0.1), (0, 0, z))
    g.criar(bevel=0.01, pai=r)


def tocha():
    """Tocha de parede. Encostar o lado +Y (traseiro) na parede."""
    r = raiz("Tocha")
    p = Peca("Suporte")
    p.caixa(M("ferro", metal=0.5), (0.12, 0.05, 0.3), (0, 0.12, 1.0))
    p.cilindro(M("ferro", metal=0.5), 0.025, 0.25, (0, 0.12, 1.0), rot=(60, 0, 0), lados=8)
    p.cilindro(M("madeira"), 0.035, 0.4, (0, -0.02, 0.95), lados=10)
    p.torno(M("bronze", metal=0.6), [(0.04, 0), (0.1, 0.08), (0.11, 0.12), (0.09, 0.12)],
            pos=(0, -0.02, 1.32), lados=16)
    p.criar(bevel=0.008, pai=r)
    f = Peca("Chama")  # <- Godot (pisca / acende)
    f.esfera(M("chama", emissao=1.5), 0.09, (0, -0.02, 1.52), escala=(1, 1, 1.6), segs=12, aneis=8)
    f.esfera(M("ouro", emissao=2.0), 0.05, (0, -0.02, 1.5), escala=(1, 1, 1.4), segs=10, aneis=6)
    f.criar(bevel=0, pai=r)
    vazio("PontoLuz", (0, -0.1, 1.55), pai=r)  # <- Godot (OmniLight)


def portao_minotauro():
    """Porta dupla da arena (3 m × 2,6 m). As folhas giram nas dobradiças."""
    r = raiz("PortaoMinotauro")
    m = Peca("Moldura")
    for lado in (-1, 1):
        m.caixa(M("parede"), (0.5, 0.5, 2.9), (lado * 1.75, 0, 1.45))
    m.caixa(M("parede_borda"), (4.0, 0.6, 0.5), (0, 0, 3.0))
    # emblema: cabeça de touro em bronze com chifres curtos e curvados para cima
    m.esfera(M("bronze", metal=0.6), 0.3, (0, -0.25, 3.0), escala=(1.1, 0.6, 1.0))
    m.esfera(M("bronze_escuro", metal=0.6), 0.16, (0, -0.4, 2.88), escala=(1.1, 0.6, 0.8))
    for s in (-1, 1):
        m.tubo(M("marmore"), [(s * 0.24, -0.3, 3.12), (s * 0.4, -0.32, 3.18),
                              (s * 0.46, -0.33, 3.32), (s * 0.4, -0.33, 3.44)],
               0.07, raio_final=0.02)
        m.esfera(M("ouro", metal=0.5), 0.04, (s * 0.1, -0.42, 3.06), segs=10, aneis=6)
    m.criar(bevel=0.03, pai=r)
    for nome, lado in (("FolhaEsq", -1), ("FolhaDir", 1)):  # <- Godot (giram em Z local)
        piv = vazio(nome, (lado * 1.5, 0, 0), pai=r)
        f = Peca(nome + "Malha")
        cx = -lado * 0.75
        f.caixa(M("madeira"), (1.48, 0.16, 2.7), (cx, 0, 1.35))
        for z in (0.5, 1.35, 2.2):
            f.caixa(M("ferro", metal=0.6), (1.5, 0.2, 0.12), (cx, 0, z))
        f.cilindro(M("bronze", metal=0.7), 0.1, 0.06, (cx + lado * 0.55, -0.1, 1.2),
                   rot=(90, 0, 0), lados=16)
        f.criar(bevel=0.02, pai=piv)


# ==========================================================================
# PROPS
# ==========================================================================
def coluna_grega():
    r = raiz("ColunaGrega")
    p = Peca("Coluna")
    p.caixa(M("marmore_sombra"), (0.7, 0.7, 0.14), (0, 0, 0.07))
    p.torno(M("marmore"), [(0.3, 0.14), (0.3, 0.2), (0.25, 0.24)], lados=24)
    p.torno(M("marmore"), [(0.24, 0.24), (0.2, 1.9)], lados=20, fechar_base=False)
    p.torno(M("marmore"), [(0.2, 1.9), (0.3, 2.02), (0.3, 2.06)], lados=24)
    p.caixa(M("marmore_sombra"), (0.72, 0.72, 0.14), (0, 0, 2.13))
    p.criar(bevel=0.015, pai=r)


def anfora():
    r = raiz("Anfora")
    p = Peca("Anfora")
    perfil = [(0.0, 0.0), (0.13, 0.0), (0.16, 0.05), (0.27, 0.25), (0.3, 0.42),
              (0.26, 0.6), (0.14, 0.72), (0.1, 0.8), (0.11, 0.9), (0.15, 0.94)]
    p.torno(M("terracota"), perfil, lados=28, fechar_base=False)
    p.torno(M("preto_vaso"), [(0.296, 0.38), (0.302, 0.42), (0.296, 0.46)], lados=28,
            fechar_base=False, fechar_topo=False)
    p.torno(M("preto_vaso"), [(0.275, 0.26), (0.282, 0.28), (0.277, 0.3)], lados=28,
            fechar_base=False, fechar_topo=False)
    for lado in (-1, 1):
        p.tubo(M("terracota"),
               [(lado * 0.1, 0, 0.86), (lado * 0.24, 0, 0.86), (lado * 0.27, 0, 0.75),
                (lado * 0.2, 0, 0.64)], 0.025, lados=8)
    p.criar(bevel=0, pai=r)


def braseiro(simbolo=None):
    """Braseiro de bronze. Os nós 'Brasas' e 'Fogo' são ligados/desligados pelo puzzle."""
    nome = "Braseiro" if simbolo is None else "Braseiro"
    r = raiz(nome)
    p = Peca("Tripe")
    for i in range(3):
        a = 2 * math.pi * i / 3
        x, y = math.cos(a) * 0.32, math.sin(a) * 0.32
        p.tubo(M("bronze_escuro", metal=0.6),
               [(x, y, 0.0), (x * 0.8, y * 0.8, 0.35), (x * 0.45, y * 0.45, 0.62)], 0.035,
               lados=8)
    p.torno(M("bronze", metal=0.6),
            [(0.08, 0.6), (0.3, 0.68), (0.42, 0.8), (0.44, 0.84), (0.4, 0.84)], lados=24)
    p.criar(bevel=0.01, pai=r)
    b = Peca("Brasas")  # <- Godot (fica vermelho quando aceso)
    for i, (x, y) in enumerate([(0, 0), (0.12, 0.05), (-0.1, 0.09), (0.03, -0.13),
                                (-0.12, -0.08), (0.14, -0.1)]):
        b.esfera(M("preto_vaso"), 0.08, (x, y, 0.8), escala=(1, 1, 0.6), segs=8, aneis=6)
    b.criar(bevel=0, pai=r)


def ossos():
    r = raiz("Ossos")
    p = Peca("Ossos")
    for (x, y, ang, comp) in [(0, 0, 20, 0.5), (0.1, 0.12, -50, 0.4), (-0.15, 0.05, 80, 0.35)]:
        a = math.radians(ang)
        dx, dy = math.cos(a) * comp / 2, math.sin(a) * comp / 2
        p.tubo(M("osso"), [(x - dx, y - dy, 0.05), (x + dx, y + dy, 0.05)], 0.03, lados=8)
        for s in (-1, 1):
            for k in (-1, 1):
                ox, oy = -math.sin(a) * 0.03 * k, math.cos(a) * 0.03 * k
                p.esfera(M("osso"), 0.04, (x + s * dx + ox, y + s * dy + oy, 0.05),
                         segs=8, aneis=6)
    for (x, y, s) in [(0.3, -0.15, 0.12), (-0.3, -0.2, 0.09), (0.25, 0.25, 0.07)]:
        p.esfera(M("estatua"), s, (x, y, s * 0.5), escala=(1.2, 1, 0.7), segs=8, aneis=6)
    p.criar(bevel=0, pai=r)


# ==========================================================================
# OBJETOS DOS PUZZLES
# ==========================================================================
def placa_pressao():
    r = raiz("PlacaPressao")
    b = Peca("Base")
    b.caixa(M("pedra_junta"), (0.96, 0.96, 0.06), (0, 0, 0.0))
    b.criar(bevel=0.01, pai=r)
    p = Peca("Placa")  # <- Godot (afunda quando pressionada)
    p.caixa(M("parede_borda"), (0.8, 0.8, 0.08), (0, 0, 0.04))
    # símbolo do labirinto (espiral quadrada) em ouro
    w = 0.025
    for (x, y, sx, sy) in [(0, 0.26, 0.55, w), (0.26, 0, w, 0.55), (0, -0.26, 0.55, w),
                           (-0.26, 0.05, w, 0.45), (0.06, 0.15, 0.4, w), (0.15, -0.02, w, 0.33),
                           (-0.02, -0.15, 0.37, w), (-0.15, 0.03, w, 0.2)]:
        p.caixa(M("ouro", metal=0.4), (sx, sy, 0.02), (x, y, 0.085))
    p.criar(bevel=0.01, pai=r)


def estatua_touro():
    """Estátua de touro em um pedestal de 0,9 m (cabe em uma célula da grade)."""
    r = raiz("EstatuaTouro")
    p = Peca("Estatua")
    pedra, escura = M("estatua", rugosidade=0.6), M("estatua_escura", rugosidade=0.6)
    p.caixa(escura, (0.9, 0.9, 0.22), (0, 0, 0.11))
    p.caixa(pedra, (0.8, 0.8, 0.08), (0, 0, 0.26))
    # corpo
    p.esfera(pedra, 0.3, (0, 0.08, 0.58), escala=(0.9, 1.25, 0.75))
    for x in (-0.15, 0.15):
        for y in (-0.15, 0.3):
            p.cilindro(pedra, 0.07, 0.3, (x, y, 0.28), lados=10)
    # cabeça grande (proporção de brinquedo)
    p.esfera(pedra, 0.25, (0, -0.3, 0.82), escala=(1.1, 1, 0.95))
    p.esfera(M("estatua_escura", rugosidade=0.6), 0.17, (0, -0.48, 0.74), escala=(1.1, 0.8, 0.75))
    for s in (-1, 1):
        p.tubo(M("marmore"), [(s * 0.16, -0.3, 0.98), (s * 0.34, -0.32, 1.02),
                              (s * 0.42, -0.36, 1.16), (s * 0.4, -0.4, 1.26)],
               0.06, raio_final=0.015, lados=10)
        p.esfera(pedra, 0.07, (s * 0.27, -0.24, 0.9), escala=(1.6, 0.6, 0.6), segs=10, aneis=6)
        p.esfera(M("preto_vaso"), 0.035, (s * 0.1, -0.52, 0.86), segs=10, aneis=6)
    p.tubo(pedra, [(0, 0.48, 0.62), (0, 0.6, 0.5), (0, 0.62, 0.38)], 0.025, lados=8)
    p.criar(bevel=0.01, pai=r)


def alavanca():
    r = raiz("Alavanca")
    b = Peca("Base")
    b.caixa(M("parede_escura"), (0.5, 0.4, 0.3), (0, 0, 0.15))
    b.caixa(M("parede_borda"), (0.56, 0.46, 0.08), (0, 0, 0.32))
    b.criar(bevel=0.02, pai=r)
    piv = vazio("Haste", (0, 0, 0.36), pai=r)  # <- Godot (gira em X)
    h = Peca("HasteMalha")
    h.cilindro(M("madeira"), 0.04, 0.6, (0, 0, 0), lados=10)
    h.esfera(M("faixa"), 0.08, (0, 0, 0.62))
    h.criar(bevel=0, pai=piv)
    piv.rotation_euler = (math.radians(-30), 0, 0)


def espelho():
    """Espelho giratório. O nó 'Giratorio' gira em Y no Godot; a face espelhada olha para +Z."""
    r = raiz("Espelho")
    b = Peca("Base")
    b.torno(M("parede_escura"), [(0.42, 0), (0.42, 0.12), (0.36, 0.16), (0.2, 0.18)], lados=24)
    for i in range(8):
        a = 2 * math.pi * i / 8
        b.caixa(M("ouro", metal=0.5), (0.04, 0.12, 0.02),
                (math.cos(a) * 0.3, math.sin(a) * 0.3, 0.17), rot=(0, 0, math.degrees(a)))
    b.criar(bevel=0.01, pai=r)
    piv = vazio("Giratorio", (0, 0, 0.18), pai=r)  # <- Godot
    g = Peca("Moldura")
    g.cilindro(M("bronze_escuro", metal=0.6), 0.06, 0.35, (0, 0, 0), lados=12)
    g.caixa(M("bronze", metal=0.6), (0.9, 0.1, 0.08), (0, 0, 0.4))
    g.caixa(M("bronze", metal=0.6), (0.9, 0.1, 0.08), (0, 0, 1.36))
    for s in (-1, 1):
        g.caixa(M("bronze", metal=0.6), (0.08, 0.1, 1.04), (s * 0.45, 0, 0.88))
    g.caixa(M("espelho", cor="#cfe6ff", rugosidade=0.08, metal=0.35, emissao=0.25), (0.82, 0.03, 0.88), (0, -0.03, 0.88))
    # reflexo "pintado" (o renderizador Compatibilidade não reflete a cena)
    for k, (x, z) in enumerate([(-0.2, 1.1), (-0.05, 0.95)]):
        g.caixa(M("brilho_espelho", cor="#ffffff", rugosidade=0.1, emissao=0.6), (0.06, 0.01, 0.5), (x, -0.05, z), rot=(0, 30, 0))
    g.caixa(M("bronze_escuro", metal=0.6), (0.82, 0.04, 0.88), (0, 0.03, 0.88))
    g.esfera(M("ouro", metal=0.5), 0.07, (0, 0, 1.45), segs=12, aneis=8)
    g.criar(bevel=0.01, pai=piv)


def cristal():
    r = raiz("Cristal")
    b = Peca("Pedestal")
    b.torno(M("marmore_sombra"), [(0.32, 0), (0.32, 0.1), (0.22, 0.16), (0.18, 0.7),
                                  (0.28, 0.78), (0.28, 0.84)], lados=8)
    b.criar(bevel=0.01, suave=False, pai=r)
    c = Peca("Gema")  # <- Godot (brilha quando atingida pela luz)
    c.torno(M("cristal", rugosidade=0.1, emissao=0.3),
            [(0.0, 0.0), (0.16, 0.22), (0.16, 0.5), (0.0, 0.8)], lados=6,
            pos=(0, 0, 0.86), fechar_base=False, fechar_topo=False)
    c.criar(bevel=0, suave=False, pai=r)


def fonte_luz():
    """Fresta no teto/parede de onde sai o feixe (o feixe em si é desenhado no Godot)."""
    r = raiz("FonteLuz")
    p = Peca("Moldura")
    p.caixa(M("parede_escura"), (0.7, 0.4, 0.7), (0, 0.2, 0.35))
    p.esfera(M("ouro", emissao=2.0), 0.16, (0, -0.02, 0.62), escala=(1, 0.4, 1), segs=16, aneis=8)
    for i in range(8):
        a = 2 * math.pi * i / 8
        p.caixa(M("ouro", metal=0.5), (0.04, 0.04, 0.12),
                (math.cos(a) * 0.24, -0.02, 0.62 + math.sin(a) * 0.24),
                rot=(0, -math.degrees(a) + 90, 0))
    p.criar(bevel=0.015, pai=r)


CORES_SIMBOLO = {"sol": "#f2c230", "lua": "#6fa8ff", "onda": "#3cc9b0", "raio": "#b06cff"}


def placa_simbolo(simbolo):
    """Placa de parede com um símbolo (sol, lua, onda, raio). Fica 1 m acima do chão."""
    r = raiz("Simbolo" + simbolo.capitalize())
    p = Peca("Placa")
    p.caixa(M("parede_borda"), (0.6, 0.08, 0.6), (0, 0, 1.3))
    p.caixa(M("preto_vaso"), (0.5, 0.06, 0.5), (0, -0.02, 1.3))
    # cada símbolo tem sua cor (a mesma da chama do braseiro no Godot)
    ouro = M("simbolo_" + simbolo, cor=CORES_SIMBOLO[simbolo], rugosidade=0.3, emissao=0.6)
    z, y = 1.3, -0.06
    if simbolo == "sol":
        p.cilindro(ouro, 0.09, 0.04, (0, y + 0.02, z), rot=(90, 0, 0), lados=20)
        for i in range(8):
            a = 2 * math.pi * i / 8
            p.caixa(ouro, (0.035, 0.04, 0.08),
                    (math.cos(a) * 0.16, y, z + math.sin(a) * 0.16),
                    rot=(0, -math.degrees(a) + 90, 0))
    elif simbolo == "lua":
        pts = []
        for i in range(17):
            a = math.radians(40 + 280 * i / 16)
            pts.append((math.cos(a) * 0.15, math.sin(a) * 0.15))
        for i in range(16, -1, -1):
            a = math.radians(40 + 280 * i / 16)
            pts.append((math.cos(a) * 0.09 + 0.05, math.sin(a) * 0.1))
        p.prisma(ouro, pts, 0.04, pos=(0, y + 0.02, z), rot=(90, 0, 0))
    elif simbolo == "onda":
        for k, dz in enumerate((-0.08, 0.0, 0.08)):
            pts = [(-0.18 + 0.36 * i / 16, y, z + dz + math.sin(i / 16 * 2 * math.pi) * 0.035)
                   for i in range(17)]
            p.tubo(ouro, pts, 0.018, lados=6)
    elif simbolo == "raio":
        contorno = [(-0.03, 0.18), (0.1, 0.18), (0.02, 0.04), (0.1, 0.04),
                    (-0.06, -0.2), (-0.01, -0.03), (-0.09, -0.03)]
        p.prisma(ouro, contorno, 0.04, pos=(0, y + 0.02, z), rot=(90, 0, 0))
    p.criar(bevel=0.008, pai=r)


def cela():
    """Cela de 3 m × 1,5 m para os prisioneiros. A frente ('Grade') desce para dentro do chão."""
    r = raiz("Cela")
    p = Peca("Estrutura")
    p.caixa(M("pedra_junta"), (3.0, 1.5, 0.08), (0, 0.75, 0.04))
    for s in (-1, 1):
        p.caixa(M("parede"), (0.25, 1.5, 1.8), (s * 1.375, 0.75, 0.9))
    p.caixa(M("parede"), (3.0, 0.25, 1.8), (0, 1.375, 0.9))
    # só a borda no topo das paredes: a cela é aberta em cima para a câmera ver os presos
    for s in (-1, 1):
        p.caixa(M("parede_borda"), (0.33, 1.24, 0.12), (s * 1.375, 0.58, 1.86))
    p.caixa(M("parede_borda"), (3.08, 0.33, 0.12), (0, 1.375, 1.86))
    p.criar(bevel=0.02, pai=r)
    g = Peca("Grade")  # <- Godot
    ferro = M("ferro", rugosidade=0.45, metal=0.6)
    for i in range(10):
        g.cilindro(ferro, 0.035, 1.75, (-1.125 + i * 0.25, 0, 0.05), lados=8)
    for z in (0.5, 1.3):
        g.caixa(ferro, (2.55, 0.07, 0.08), (0, 0, z))
    g.caixa(M("bronze", metal=0.6), (0.18, 0.1, 0.22), (0, -0.05, 0.9))
    g.criar(bevel=0.008, pai=r)


def prisioneiro():
    """Jovem ateniense preso (NPC simples, sem rig). Material 'Tunica' recebe outra cor no Godot."""
    r = raiz("Prisioneiro")
    c = Peca("Corpo")  # <- Godot (troca a cor da túnica)
    pele = M("pele")
    tunica = M("tunica")
    c.torno(tunica, [(0.0, 0.12), (0.2, 0.12), (0.17, 0.3), (0.14, 0.5), (0.0, 0.52)], lados=20)
    for s in (-1, 1):
        c.cilindro(pele, 0.055, 0.14, (s * 0.08, 0, 0.0), lados=10)
        c.esfera(M("couro"), 0.065, (s * 0.08, -0.03, 0.03), escala=(1, 1.4, 0.6), segs=10, aneis=6)
        c.tubo(pele, [(s * 0.15, 0, 0.46), (s * 0.24, -0.02, 0.36), (s * 0.24, -0.06, 0.26)],
               0.045, lados=8)
    c.esfera(pele, 0.29, (0, 0, 0.8), escala=(1, 0.95, 0.92))
    c.esfera(M("cabelo"), 0.3, (0, 0.04, 0.86), escala=(1.02, 0.95, 0.85))
    for s in (-1, 1):
        c.esfera(M("preto_vaso"), 0.035, (s * 0.1, -0.27, 0.8), escala=(0.8, 0.5, 1.2),
                 segs=10, aneis=6)
        c.esfera(M("faixa", cor="#e88a7a"), 0.03, (s * 0.17, -0.24, 0.72),
                 escala=(1.4, 0.4, 0.8), segs=8, aneis=6)
    c.criar(bevel=0, pai=r)



# ==========================================================================
# ARMAS DO TESEU
# ==========================================================================
def espada_xiphos():
    """Xiphos grega: lâmina em folha. Cabo na origem, lâmina para +Z (vira +Y no Godot)."""
    r = raiz("Espada")
    p = Peca("Espada")
    aco = M("aco", cor="#dfe6f0", rugosidade=0.18, metal=0.85)
    # lâmina em forma de folha (mais larga perto da ponta, como a xiphos)
    perfil = [(0.0, 0.0), (0.032, 0.02), (0.03, 0.18), (0.045, 0.36), (0.038, 0.48), (0.0, 0.62)]
    contorno = [(x, z) for x, z in perfil] + [(-x, z) for x, z in reversed(perfil[1:-1])]
    p.prisma(aco, contorno, 0.016, pos=(0, 0.008, 0.08), rot=(90, 0, 0))
    p.caixa(M("aco_escuro", cor="#9aa6b8", rugosidade=0.25, metal=0.85), (0.012, 0.022, 0.5), (0, 0, 0.36))
    p.caixa(M("bronze", metal=0.7), (0.17, 0.05, 0.04), (0, 0, 0.07))
    p.cilindro(M("couro"), 0.022, 0.13, (0, 0, -0.07), lados=10)
    p.esfera(M("bronze", metal=0.7), 0.035, (0, 0, -0.085), segs=12, aneis=8)
    p.criar(bevel=0.004, pai=r)


def escudo_hoplon():
    """Escudo redondo de bronze com sol. Frente para -Y (vira +Z no Godot)."""
    r = raiz("Escudo")
    p = Peca("Escudo")
    p.torno(M("bronze", metal=0.7, rugosidade=0.3),
            [(0.0, 0.0), (0.24, 0.0), (0.27, 0.02), (0.27, 0.05), (0.2, 0.08), (0.0, 0.1)],
            rot=(90, 0, 0), lados=32)
    p.torno(M("bronze_escuro", metal=0.7), [(0.255, 0.035), (0.265, 0.05), (0.255, 0.065)],
            rot=(90, 0, 0), lados=32, fechar_base=False, fechar_topo=False)
    ouro = M("ouro", metal=0.6)
    p.cilindro(ouro, 0.06, 0.03, (0, -0.085, 0), rot=(90, 0, 0), lados=16)
    for i in range(8):
        a = 2 * math.pi * i / 8
        p.caixa(ouro, (0.025, 0.02, 0.06), (math.cos(a) * 0.12, -0.08, math.sin(a) * 0.12),
                rot=(0, -math.degrees(a) + 90, 0))
    p.criar(bevel=0.005, pai=r)


# ==========================================================================
# MINOTAURO (corpo de cavalo + tronco e cabeça de touro), articulado
# Pivôs (Empty) animados no Godot: PernaDE, PernaDD, PernaTE, PernaTD,
# Cauda, Tronco, Cabeca, BracoEsq, BracoDir (segura o Machado).
# Frente para -Y (vira +Z no Godot). Altura total ~2,5 m.
# ==========================================================================
def minotauro():
    r = raiz("Minotauro")
    pelo = M("pelo_touro", cor="#8a5a3c", rugosidade=0.6)
    pelo_cavalo = M("pelo_cavalo", cor="#9b6a45", rugosidade=0.6)
    claro = M("pelo_claro", cor="#c99a74", rugosidade=0.6)
    escuro = M("pelo_escuro", cor="#5a3a26", rugosidade=0.6)
    casco = M("casco", cor="#2e211b", rugosidade=0.5)
    chifre = M("marmore", cor="#f2e8cc", rugosidade=0.4)

    # corpo de cavalo
    c = Peca("CorpoCavalo")
    c.esfera(pelo_cavalo, 1.0, (0, 0.25, 0.98), escala=(0.46, 0.88, 0.42))
    c.esfera(claro, 1.0, (0, 0.25, 0.8), escala=(0.32, 0.62, 0.25))
    c.esfera(pelo_cavalo, 1.0, (0, -0.35, 1.1), escala=(0.4, 0.38, 0.4))
    c.criar(bevel=0, pai=r)

    # pernas (pivô no quadril, z = 0.8)
    for nome, x, y in [("PernaDE", 0.24, -0.38), ("PernaDD", -0.24, -0.38),
                       ("PernaTE", 0.24, 0.82), ("PernaTD", -0.24, 0.82)]:
        piv = vazio(nome, (x, y, 0.8), pai=r)
        pe = Peca(nome + "Malha")
        pe.esfera(pelo_cavalo, 0.17, (0, 0, -0.05), escala=(1, 1.2, 1.3), segs=14, aneis=10)
        pe.cilindro(pelo_cavalo, 0.1, 0.55, (0, 0, -0.62), raio_topo=0.12, lados=14)
        pe.cilindro(casco, 0.13, 0.12, (0, 0, -0.8), raio_topo=0.11, lados=14)
        pe.criar(bevel=0.01, pai=piv)

    # cauda
    piv = vazio("Cauda", (0, 1.08, 1.12), pai=r)
    ca = Peca("CaudaMalha")
    ca.tubo(escuro, [(0, 0, 0), (0, 0.18, -0.1), (0, 0.28, -0.35), (0, 0.24, -0.62)], 0.07, raio_final=0.03)
    ca.esfera(escuro, 0.09, (0, 0.24, -0.66), escala=(1, 1, 1.6), segs=10, aneis=8)
    ca.criar(bevel=0, pai=piv)

    # tronco de touro (pivô na cintura, sobre a frente do cavalo)
    tronco = vazio("Tronco", (0, -0.45, 1.25), pai=r)
    t = Peca("TroncoMalha")
    t.esfera(pelo, 1.0, (0, 0, 0.38), escala=(0.42, 0.33, 0.48))
    t.esfera(claro, 1.0, (0, -0.12, 0.42), escala=(0.27, 0.22, 0.32))
    t.caixa(M("faixa", cor="#b8342c"), (0.5, 0.42, 0.14), (0, 0, 0.0))
    t.toro(M("couro"), 0.4, 0.06, (0, 0, 0.06))
    t.caixa(M("ouro", metal=0.6), (0.14, 0.06, 0.13), (0, -0.4, 0.06))
    t.criar(bevel=0.01, pai=tronco)

    # cabeça de touro (grande, estilo brinquedo)
    cab = vazio("Cabeca", (0, -0.05, 0.86), pai=tronco)
    h = Peca("CabecaMalha")
    h.esfera(pelo, 0.44, (0, 0, 0.2), escala=(1, 0.92, 0.9))
    h.esfera(claro, 0.25, (0, -0.33, 0.05), escala=(1.15, 0.85, 0.78))
    h.esfera(escuro, 0.18, (0, 0.05, 0.6), escala=(1.2, 0.8, 0.5), segs=12, aneis=8)
    for s_ in (-1, 1):
        h.esfera(M("narina", cor="#4a2e1e"), 0.045, (s_ * 0.08, -0.53, 0.06), escala=(1, 0.6, 1.2),
                 segs=10, aneis=6)
        h.tubo(chifre, [(s_ * 0.3, 0.0, 0.42), (s_ * 0.6, -0.02, 0.48), (s_ * 0.76, -0.06, 0.68),
                        (s_ * 0.72, -0.1, 0.86)], 0.085, raio_final=0.02, lados=12)
        h.esfera(pelo, 0.11, (s_ * 0.48, 0.02, 0.28), escala=(1.7, 0.6, 0.7), segs=12, aneis=8)
        h.esfera(M("preto_vaso"), 0.065, (s_ * 0.17, -0.36, 0.3), escala=(0.8, 0.6, 1.1), segs=12, aneis=8)
        h.esfera(M("brilho", cor="#ffffff", rugosidade=0.2), 0.02, (s_ * 0.15, -0.41, 0.34), segs=8, aneis=6)
        h.tubo(escuro, [(s_ * 0.3, -0.35, 0.46), (s_ * 0.08, -0.4, 0.39)], 0.035, lados=8)
    h.toro(M("ouro", metal=0.7), 0.075, 0.018, (0, -0.56, -0.07), rot=(90, 0, 0))
    h.criar(bevel=0, pai=cab)

    # braços (pivô no ombro) — o direito (-X) segura o machado
    for nome, s_ in (("BracoEsq", 1), ("BracoDir", -1)):
        piv = vazio(nome, (s_ * 0.44, 0.0, 0.68), pai=tronco)
        b = Peca(nome + "Malha")
        b.esfera(pelo, 0.17, (0, 0, 0), segs=14, aneis=10)
        b.tubo(pelo, [(0, 0, 0), (s_ * 0.12, -0.03, -0.32)], 0.13, raio_final=0.11, lados=12)
        b.tubo(pelo, [(s_ * 0.12, -0.03, -0.32), (s_ * 0.14, -0.22, -0.52)], 0.11, raio_final=0.1, lados=12)
        b.esfera(escuro, 0.13, (s_ * 0.14, -0.26, -0.56), segs=12, aneis=8)
        b.toro(M("ouro", metal=0.6), 0.115, 0.025, (s_ * 0.13, -0.17, -0.45), rot=(60, 0, 0))
        b.criar(bevel=0, pai=piv)
        if nome == "BracoDir":
            mac = vazio("Machado", (s_ * 0.14, -0.26, -0.56), pai=piv)
            m = Peca("MachadoMalha")
            m.cilindro(M("madeira"), 0.04, 1.55, (0, 0, -0.35), lados=10)
            for lado in (-1, 1):
                lamina = [(0.0, -0.05), (0.32, -0.28), (0.4, 0.0), (0.32, 0.28), (0.0, 0.05)]
                lamina = [(lado * x, z) for x, z in lamina]
                m.prisma(M("aco", cor="#d3d6db", rugosidade=0.2, metal=0.8), lamina, 0.05,
                         pos=(0, 0.025, 1.0), rot=(90, 0, 0))
            m.caixa(M("bronze", metal=0.6), (0.12, 0.09, 0.2), (0, 0, 1.0))
            m.criar(bevel=0.006, pai=mac)


# ==========================================================================
TODOS = {
    "cenario": [("piso", piso), ("parede", parede), ("parede_baixa", parede_baixa),
                ("pilar", pilar), ("arco_porta", arco_porta), ("grade_porta", grade_porta),
                ("tocha", tocha), ("portao_minotauro", portao_minotauro)],
    "props": [("coluna_grega", coluna_grega), ("anfora", anfora), ("ossos", ossos)],
    "puzzles": [("placa_pressao", placa_pressao), ("estatua_touro", estatua_touro),
                ("alavanca", alavanca), ("braseiro", braseiro), ("espelho", espelho),
                ("cristal", cristal), ("fonte_luz", fonte_luz),
                ("simbolo_sol", lambda: placa_simbolo("sol")),
                ("simbolo_lua", lambda: placa_simbolo("lua")),
                ("simbolo_onda", lambda: placa_simbolo("onda")),
                ("simbolo_raio", lambda: placa_simbolo("raio")),
                ("cela", cela)],
    "personagens": [("prisioneiro", prisioneiro), ("minotauro", minotauro)],
    "armas": [("espada_xiphos", espada_xiphos), ("escudo_hoplon", escudo_hoplon)],
}


def main(filtro=None):
    for categoria, itens in TODOS.items():
        for nome, funcao in itens:
            if filtro and nome not in filtro:
                continue
            limpar_cena()
            funcao()
            exportar(nome, os.path.join(PASTA_MODELOS, categoria), PASTA_FONTES)
            print("OK", categoria, nome)


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    main(set(argv) if argv else None)
