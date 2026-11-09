"""Gera docs/capturas/capa.png (1280x640) com os modelos do jogo renderizados por software
(toon + contorno, esqueleto posado pelas animações do grupo). Uso: python3 ferramentas/gerar_capa.py
Precisa de: numpy pillow. A fonte do título é TeX Gyre Bonum (troque FONTE se não tiver)."""
import random
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

sys.path.insert(0, __import__('os').path.dirname(__import__('os').path.abspath(__file__)))
from capa_render import carregar, render  # noqa: E402

P = __import__('os').path.join(__import__('os').path.dirname(__import__('os').path.abspath(__file__)), '..', 'assets', 'modelos', 'personagens') + '/'
W, H = 2560, 1280
FONTE = '/usr/share/texmf/fonts/opentype/public/tex-gyre/texgyrebonum-bold.otf'
random.seed(7)


def gradiente_vertical(w, h, topo, base):
    t = np.linspace(0, 1, h)[:, None, None]
    a = np.array(topo, float)[None, None, :]
    b = np.array(base, float)[None, None, :]
    return Image.fromarray(np.repeat((a + (b - a) * t), w, axis=1).astype(np.uint8), 'RGB')


def brilho_radial(w, h, cx, cy, raio, cor, forca=1.0):
    yy, xx = np.mgrid[0:h, 0:w]
    d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / raio
    a = np.clip(1 - d, 0, 1) ** 2 * forca
    im = np.zeros((h, w, 4))
    im[..., :3] = cor
    im[..., 3] = a * 255
    return Image.fromarray(im.astype(np.uint8), 'RGBA')


def coef_perspectiva(dst, src):
    """Coeficientes do Image.PERSPECTIVE que levam os 4 cantos dst -> src."""
    m = []
    for (x, y), (u, v) in zip(dst, src):
        m.append([x, y, 1, 0, 0, 0, -u * x, -u * y])
        m.append([0, 0, 0, x, y, 1, -v * x, -v * y])
    b = np.array(src).reshape(8)
    return np.linalg.solve(np.array(m, float), b).tolist()


# ---------------------------------------------------------------- labirinto
def labirinto(cols, lins, cel):
    vis = [[False] * cols for _ in range(lins)]
    paredes_h = [[True] * cols for _ in range(lins + 1)]
    paredes_v = [[True] * (cols + 1) for _ in range(lins)]
    pilha = [(lins // 2, cols // 2)]
    vis[lins // 2][cols // 2] = True
    while pilha:
        r, c = pilha[-1]
        viz = [(r + dr, c + dc, dr, dc) for dr, dc in ((1, 0), (-1, 0), (0, 1), (0, -1))
               if 0 <= r + dr < lins and 0 <= c + dc < cols and not vis[r + dr][c + dc]]
        if not viz:
            pilha.pop()
            continue
        nr, nc, dr, dc = random.choice(viz)
        if dr == 1:
            paredes_h[r + 1][c] = False
        elif dr == -1:
            paredes_h[r][c] = False
        elif dc == 1:
            paredes_v[r][c + 1] = False
        else:
            paredes_v[r][c] = False
        vis[nr][nc] = True
        pilha.append((nr, nc))
    tw, th = cols * cel, lins * cel
    img = Image.new('RGB', (tw, th), (203, 182, 142))
    d = ImageDraw.Draw(img)
    # ladrilhos
    for r in range(lins):
        for c in range(cols):
            x, y = c * cel, r * cel
            tom = random.randint(-8, 8)
            d.rectangle([x + 3, y + 3, x + cel - 3, y + cel - 3], fill=(203 + tom, 182 + tom, 142 + tom))
    esp = cel // 5
    frente = (110, 96, 140)
    topo = (184, 172, 201)

    def parede(x0, y0, x1, y1):
        d.rectangle([x0, y0 + esp // 2, x1, y1 + esp], fill=frente)   # face da frente (volume)
        d.rectangle([x0, y0, x1, y1], fill=topo)
    for r in range(lins + 1):
        for c in range(cols):
            if paredes_h[r][c]:
                parede(c * cel - esp // 2, r * cel - esp // 2, (c + 1) * cel + esp // 2, r * cel + esp // 2)
    for r in range(lins):
        for c in range(cols + 1):
            if paredes_v[r][c]:
                parede(c * cel - esp // 2, r * cel - esp // 2, c * cel + esp // 2, (r + 1) * cel + esp // 2)
    return img, paredes_h, paredes_v


def caminho_fio(paredes_h, paredes_v, cols, lins, ini, fim):
    """BFS pelo labirinto: o caminho do fio de Ariadne."""
    from collections import deque
    pai = {ini: None}
    q = deque([ini])
    while q:
        r, c = q.popleft()
        if (r, c) == fim:
            break
        for dr, dc in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nr, nc = r + dr, c + dc
            if not (0 <= nr < lins and 0 <= nc < cols) or (nr, nc) in pai:
                continue
            if dr == 1 and paredes_h[r + 1][c]:
                continue
            if dr == -1 and paredes_h[r][c]:
                continue
            if dc == 1 and paredes_v[r][c + 1]:
                continue
            if dc == -1 and paredes_v[r][c]:
                continue
            pai[(nr, nc)] = (r, c)
            q.append((nr, nc))
    cam = []
    n = fim
    while n is not None:
        cam.append(n)
        n = pai.get(n)
    return cam[::-1]


COLS, LINS, CEL = 17, 9, 160
lab, ph, pv = labirinto(COLS, LINS, CEL)
fio = caminho_fio(ph, pv, COLS, LINS, (LINS - 1, 1), (LINS - 2, 7))
dl = ImageDraw.Draw(lab)
pts = [(c * CEL + CEL / 2 + random.uniform(-6, 6), r * CEL + CEL / 2 + random.uniform(-6, 6)) for r, c in fio]

# chão em perspectiva (maquete vista de cima, 3/4)
fundo = gradiente_vertical(W, H, (22, 14, 40), (58, 30, 52))
tw, th = lab.size
dst = [(-450, 470), (W + 450, 470), (W + 250, H + 30), (-250, H + 30)]
src = [(0, 0), (tw, 0), (tw, th), (0, th)]
chao = lab.transform((W, H), Image.PERSPECTIVE, coef_perspectiva(dst, src), Image.BICUBIC)
masc = Image.new('L', (W, H), 0)
ImageDraw.Draw(masc).polygon(dst, fill=255)
# escurece o fundo do labirinto (névoa ao longe)
nevoa = np.clip((np.arange(H) - 470) / 560.0, 0, 1)[:, None]
masc_np = np.array(masc).astype(float) * (0.25 + 0.6 * nevoa)
fundo.paste(chao, (0, 0), Image.fromarray(masc_np.astype(np.uint8)))
fundo = fundo.convert('RGBA')
# o FIO DE ARIADNE: sai dos pés do Teseu e entra no labirinto rumo ao Minotauro
def bezier(p0, p1, p2, p3, n=200):
    t = np.linspace(0, 1, n)[:, None]
    return ((1 - t) ** 3 * p0 + 3 * (1 - t) ** 2 * t * p1 + 3 * (1 - t) * t ** 2 * p2 + t ** 3 * p3)


curva = np.concatenate([
    bezier(np.array([-40, 1240.0]), np.array([300, 1300.0]), np.array([600, 1180.0]), np.array([960, 1235.0])),
    bezier(np.array([960, 1235.0]), np.array([1250, 1290.0]), np.array([1150, 1060.0]), np.array([1420, 1040.0])),
    bezier(np.array([1420, 1040.0]), np.array([1650, 1020.0]), np.array([1560, 900.0]), np.array([1760, 880.0])),
])
glow = Image.new('L', (W, H), 0)
gd = ImageDraw.Draw(glow)
linha = Image.new('RGBA', (W, H), (0, 0, 0, 0))
ld = ImageDraw.Draw(linha)
for k in range(len(curva) - 1):
    y = curva[k][1]
    larg = 5 + 15 * np.clip((y - 860) / 400.0, 0, 1)    # mais fino ao longe
    a, b = tuple(curva[k]), tuple(curva[k + 1])
    gd.line([a, b], fill=255, width=int(larg * 5))
    ld.line([a, b], fill=(110, 14, 12, 255), width=int(larg + 6))
for k in range(len(curva) - 1):
    y = curva[k][1]
    larg = 5 + 15 * np.clip((y - 860) / 400.0, 0, 1)
    ld.line([tuple(curva[k]), tuple(curva[k + 1])], fill=(240, 62, 46, 255), width=int(larg))
camada = Image.new('RGBA', (W, H), (255, 70, 50, 0))
camada.putalpha(glow.filter(ImageFilter.GaussianBlur(24)).point(lambda v: int(v * 0.85)))
fundo.alpha_composite(camada)
fundo.alpha_composite(linha)

# tochas (brilhos laranjas espalhados)
for x, y, r in [(260, 640, 170), (2300, 610, 170), (900, 560, 120), (1700, 560, 120)]:
    fundo.alpha_composite(brilho_radial(W, H, x, y, r * 2.2, (255, 150, 60), 0.55))

# brilho vermelho atrás do Minotauro
fundo.alpha_composite(brilho_radial(W, H, 1930, 420, 950, (255, 40, 30), 0.9))
# luz dourada atrás do Teseu
fundo.alpha_composite(brilho_radial(W, H, 1000, 760, 650, (255, 200, 110), 0.5))


def sombra_chao(img, cx, base_y, larg):
    s = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(s).ellipse([cx - larg / 2, base_y - larg * 0.12, cx + larg / 2, base_y + larg * 0.12], fill=(20, 8, 20, 150))
    img.alpha_composite(s.filter(ImageFilter.GaussianBlur(18)))


def colar(img, perso, x, y, brilho=None):
    if brilho:
        g = Image.new('RGBA', perso.size, brilho + (0,))
        g.putalpha(perso.getchannel('A').filter(ImageFilter.GaussianBlur(30)).point(lambda v: int(v * 0.8)))
        img.alpha_composite(g, (x, y))
    img.alpha_composite(perso, (x, y))


# ---------------------------------------------------------------- personagens
print('renderizando personagens...')
mino, _, _ = render(carregar(P + 'minotauro_grupo.glb', 'erguer', 0.55), 1250, 1420, yaw=-0.55, pitch=0.08,
                    cor_luz=(1.08, 0.92, 0.88), cor_sombra=(0.42, 0.26, 0.36), luz=(-0.4, 0.8, 0.7), contorno=5)
cria1, _, _ = render(carregar(P + 'minitaurinho_grupo.glb', 'atacar', 0.15), 380, 440, yaw=-0.8, pitch=0.1,
                     cor_sombra=(0.45, 0.3, 0.4), contorno=4)
cria2, _, _ = render(carregar(P + 'minitaurinho_grupo.glb', 'andar', 0.3), 360, 420, yaw=-0.2, pitch=0.1,
                     cor_sombra=(0.45, 0.3, 0.4), contorno=4)
ariadne, _, _ = render(carregar(P + 'ariadne_grupo.glb', 'parado', 0.0), 420, 560, yaw=0.55, pitch=0.1,
                       cor_luz=(1.06, 1.0, 0.95), cor_sombra=(0.5, 0.42, 0.6), contorno=4)
teseu, _, _ = render(carregar(P + 'teseu_novo.glb'), 860, 1000, yaw=0.38, pitch=0.1,
                     cor_luz=(1.08, 1.02, 0.94), cor_sombra=(0.5, 0.42, 0.6), luz=(0.6, 0.75, 0.6), contorno=5)

sombra_chao(fundo, 1930, 1180, 700)
colar(fundo, mino, 1300, -170, brilho=(255, 50, 30))
sombra_chao(fundo, 1560, 1235, 230)
colar(fundo, cria1, 1370, 830)
sombra_chao(fundo, 2380, 1240, 220)
colar(fundo, cria2, 2200, 850)
sombra_chao(fundo, 520, 1190, 260)
colar(fundo, ariadne, 300, 650, brilho=(255, 180, 210))
sombra_chao(fundo, 1000, 1262, 470)
colar(fundo, teseu, 570, 275, brilho=(255, 210, 120))

# vinheta
yy, xx = np.mgrid[0:H, 0:W]
d = np.sqrt(((xx - W / 2) / (W / 2)) ** 2 + ((yy - H / 2) / (H / 2)) ** 2)
vin = np.zeros((H, W, 4), np.uint8)
vin[..., 3] = (np.clip((d - 0.75) / 0.6, 0, 1) ** 1.5 * 200).astype(np.uint8)
fundo.alpha_composite(Image.fromarray(vin, 'RGBA'))


# ---------------------------------------------------------------- título
def texto_ouro(img, xy, txt, tam, espaco=0):
    f = ImageFont.truetype(FONTE, tam)
    # mede com espaçamento entre letras
    larguras = [f.getlength(ch) for ch in txt]
    total = sum(larguras) + espaco * (len(txt) - 1)
    x0, y0 = xy
    camada = Image.new('RGBA', img.size, (0, 0, 0, 0))
    dd = ImageDraw.Draw(camada)
    x = x0
    for ch, lw in zip(txt, larguras):
        dd.text((x, y0), ch, font=f, fill=(255, 255, 255, 255), stroke_width=int(tam * 0.09), stroke_fill=(255, 255, 255, 255))
        x += lw + espaco
    alfa_borda = camada.getchannel('A')
    # sombra
    sombra = Image.new('RGBA', img.size, (10, 4, 12, 0))
    sombra.putalpha(alfa_borda.filter(ImageFilter.GaussianBlur(10)).point(lambda v: int(v * 0.8)))
    img.alpha_composite(sombra, (8, 14))
    # contorno marrom escuro
    contorno = Image.new('RGBA', img.size, (42, 18, 16, 0))
    contorno.putalpha(alfa_borda)
    img.alpha_composite(contorno)
    # letras em degradê dourado
    letras = Image.new('RGBA', img.size, (0, 0, 0, 0))
    dl2 = ImageDraw.Draw(letras)
    x = x0
    for ch, lw in zip(txt, larguras):
        dl2.text((x, y0), ch, font=f, fill=(255, 255, 255, 255))
        x += lw + espaco
    a = letras.getchannel('A')
    bb = a.getbbox()
    grad = np.zeros((H, W, 4), np.uint8)
    if bb:
        t = np.clip((np.arange(H) - bb[1]) / max(bb[3] - bb[1], 1), 0, 1)[:, None]
        topo = np.array([255, 241, 184])
        meio = np.array([255, 196, 74])
        base = np.array([196, 120, 30])
        cor = np.where(t < 0.55, topo + (meio - topo) * (t / 0.55)[..., None] if False else 0, 0)
        c1 = topo[None, None, :] + (meio - topo)[None, None, :] * np.clip(t / 0.55, 0, 1)[..., None]
        c2 = meio[None, None, :] + (base - meio)[None, None, :] * np.clip((t - 0.55) / 0.45, 0, 1)[..., None]
        col = np.where((t < 0.55)[..., None], c1, c2)
        grad[..., :3] = np.repeat(col, W, axis=1).astype(np.uint8)
    grad[..., 3] = np.array(a)
    img.alpha_composite(Image.fromarray(grad, 'RGBA'))
    # brilho no topo das letras
    return total


def centralizado(txt, tam, espaco):
    f = ImageFont.truetype(FONTE, tam)
    return sum(f.getlength(ch) for ch in txt) + espaco * (len(txt) - 1)


x_tit = 140
texto_ouro(fundo, (x_tit, 80), 'LABIRINTO', 210, 14)
texto_ouro(fundo, (x_tit + 8, 300), 'DO MINOTAURO', 132, 10)

# os 3 enigmas (diamantes do HUD) e a linha decorativa grega
dd = ImageDraw.Draw(fundo)
for i in range(3):
    cx, cy, r = x_tit + 50 + i * 90, 520, 30
    poly = [(cx, cy - r), (cx + r * 0.72, cy), (cx, cy + r), (cx - r * 0.72, cy)]
    dd.polygon([(px + 4, py + 6) for px, py in poly], fill=(10, 4, 12))
    dd.polygon(poly, fill=(255, 201, 74), outline=(42, 18, 16), width=6)
    dd.polygon([(cx, cy - r), (cx + 12, cy - 6), (cx - 12, cy - 6)], fill=(255, 245, 210))
# meandro grego (greca) embaixo do título
y0, passo = 455, 36
x = x_tit + 300
while x < x_tit + 1150:
    pts_g = [(x, y0 + 30), (x, y0), (x + passo, y0), (x + passo, y0 + 20), (x + passo * 0.5, y0 + 20),
             (x + passo * 0.5, y0 + 10)]
    dd.line(pts_g, fill=(255, 201, 74), width=6)
    dd.line([(x, y0 + 30), (x + passo * 1.3, y0 + 30)], fill=(255, 201, 74), width=6)
    x += passo * 1.3

capa = fundo.convert('RGB').resize((W // 2, H // 2), Image.LANCZOS)
capa.save(__import__('os').path.join(__import__('os').path.dirname(__import__('os').path.abspath(__file__)), '..', 'docs', 'capturas', 'capa.png'), optimize=True)
print('ok')
