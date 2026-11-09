"""Gera todos os efeitos sonoros e músicas do jogo por SÍNTESE (sem samples).

Uso (na pasta do projeto):
    pip install numpy scipy soundfile
    python3 ferramentas/audio/gerar_sons.py

Saída:
    assets/audio/sfx/*.wav     efeitos curtos
    assets/audio/musica/*.ogg  trilhas em loop (o loop é ligado pelo jogo)

Tudo é feito com osciladores, ruído filtrado, envelopes e Karplus-Strong
(corda dedilhada, para a lira grega). Mudou algum som? Rode de novo.
"""
import os
import numpy as np
import soundfile as sf
from scipy import signal

TAXA = 44100
RAIZ = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "audio")
rng = np.random.default_rng(7)


# ----------------------------------------------------------------- básicos
def t(dur):
    return np.arange(int(dur * TAXA)) / TAXA


def ruido(dur):
    return rng.uniform(-1, 1, int(dur * TAXA))


def env(n, ataque=0.005, queda=0.2, curva=4.0):
    """Envelope ataque linear + queda exponencial."""
    x = np.arange(n) / TAXA
    a = np.clip(x / max(ataque, 1e-4), 0, 1)
    d = np.exp(-np.maximum(x - ataque, 0) * curva / max(queda, 1e-4))
    return a * d


def filtro(x, tipo, freq, ordem=2):
    w = np.clip(np.asarray(freq, dtype=float) / (TAXA / 2), 1e-4, 0.999)
    if w.ndim == 0:
        w = float(w)
    b, a = signal.butter(ordem, w, btype=tipo)
    return signal.lfilter(b, a, x)


def varredura(f0, f1, dur, forma="sin"):
    """Oscilador com frequência variando exponencialmente de f0 até f1."""
    n = int(dur * TAXA)
    f = f0 * (f1 / f0) ** (np.arange(n) / max(n - 1, 1))
    fase = 2 * np.pi * np.cumsum(f) / TAXA
    if forma == "sin":
        return np.sin(fase)
    if forma == "saw":
        return 2 * ((fase / (2 * np.pi)) % 1.0) - 1
    if forma == "tri":
        return 2 * np.abs(2 * ((fase / (2 * np.pi)) % 1.0) - 1) - 1
    return np.sign(np.sin(fase))


def mix(*partes):
    n = max(len(p) for p in partes)
    out = np.zeros(n)
    for p in partes:
        out[: len(p)] += p
    return out


def reverb(x, tamanho=1.2, umidade=0.25):
    n = int(tamanho * TAXA)
    ir = ruido(tamanho) * np.exp(-np.arange(n) / TAXA * 5.0 / tamanho)
    ir = filtro(ir, "low", 5000)
    ir /= np.sqrt(np.sum(ir ** 2))
    molhado = signal.fftconvolve(x, ir)
    seco = np.concatenate([x, np.zeros(len(molhado) - len(x))])
    return seco * (1 - umidade) + molhado * umidade * 0.6


def normalizar(x, pico=0.89):
    m = np.max(np.abs(x))
    return x if m < 1e-9 else x / m * pico


def salvar_sfx(nome, x, pico=0.89):
    x = normalizar(x, pico)
    fade = min(len(x), int(0.004 * TAXA))
    x[-fade:] *= np.linspace(1, 0, fade)
    caminho = os.path.join(RAIZ, "sfx", nome + ".wav")
    sf.write(caminho, x.astype(np.float32), TAXA, subtype="PCM_16")
    print("  sfx", nome, "%.2fs" % (len(x) / TAXA))


# ----------------------------------------------------------------- instrumentos
def nota_hz(n):
    """n = número MIDI."""
    return 440.0 * 2 ** ((n - 69) / 12)


def lira(freq, dur, brilho=0.5):
    """Corda dedilhada (Karplus-Strong)."""
    n = int(dur * TAXA)
    periodo = max(int(TAXA / freq), 2)
    buf = filtro(ruido(periodo / TAXA + 0.001)[:periodo], "low", 1500 + 5000 * brilho)
    out = np.zeros(n)
    ganho = 0.996
    for i in range(n):
        v = buf[i % periodo]
        out[i] = v
        buf[i % periodo] = ganho * 0.5 * (v + buf[(i + 1) % periodo])
    return out * env(n, 0.002, dur, 3.0)


def lira_rapida(freq, dur, brilho=0.5):
    # versão vetorizada (mais rápida) por blocos de período
    n = int(dur * TAXA)
    periodo = max(int(round(TAXA / freq)), 2)
    blocos = n // periodo + 2
    buf = filtro(rng.uniform(-1, 1, periodo), "low", 1500 + 5000 * brilho)
    saida = []
    for _ in range(blocos):
        saida.append(buf)
        buf = 0.996 * 0.5 * (buf + np.roll(buf, -1))
    out = np.concatenate(saida)[:n]
    return out * env(n, 0.002, dur, 2.5)


def flauta(freq, dur):
    x = t(dur)
    vib = 1 + 0.006 * np.sin(2 * np.pi * 5.2 * x) * np.clip(x / 0.3, 0, 1)
    fase = 2 * np.pi * np.cumsum(freq * vib) / TAXA
    tom = np.sin(fase) + 0.25 * np.sin(2 * fase) + 0.08 * np.sin(3 * fase)
    sopro = filtro(ruido(dur), "band", [freq * 0.9, freq * 2.5]) * 0.12
    e = np.clip(x / 0.06, 0, 1) * np.clip((dur - x) / 0.12, 0, 1)
    return (tom + sopro) * e


def pad(freqs, dur):
    x = t(dur)
    out = np.zeros(len(x))
    for f in freqs:
        for det in (-0.004, 0.0, 0.005):
            out += varredura(f * (1 + det), f * (1 + det), dur, "saw")
    out = filtro(out, "low", 900)
    e = np.clip(x / 0.8, 0, 1) * np.clip((dur - x) / 0.8, 0, 1)
    return out * e / (3 * len(freqs))


def baixo(freq, dur):
    x = t(dur)
    s = np.sin(2 * np.pi * freq * x) + 0.3 * varredura(freq, freq, dur, "tri")
    return s * env(len(x), 0.004, dur, 3.0)


def metal_grave(freq, dur):
    """Sopro grave áspero (tipo trompa) para o chefe."""
    x = t(dur)
    s = varredura(freq, freq, dur, "saw") + 0.5 * varredura(freq * 1.005, freq * 1.005, dur, "saw")
    corte = 300 + 1600 * np.clip(x / 0.12, 0, 1) * np.exp(-x * 1.5)
    out = np.zeros(len(x))
    # filtro variável aproximado por blocos
    bloco = 512
    zi = None
    b, a = signal.butter(2, 0.05)
    for i in range(0, len(x), bloco):
        b, a = signal.butter(2, min(corte[i] / (TAXA / 2), 0.99))
        if zi is None:
            zi = signal.lfilter_zi(b, a) * 0
        out[i:i + bloco], zi = signal.lfilter(b, a, s[i:i + bloco], zi=zi)
    return out * np.clip(x / 0.03, 0, 1) * np.clip((dur - x) / 0.08, 0, 1)


def bumbo(dur=0.45, f0=110, f1=42):
    s = varredura(f0, f1, dur) * env(int(dur * TAXA), 0.001, dur, 5.0)
    clique = filtro(ruido(0.01), "high", 2000) * 0.3
    return mix(s, clique)


def tambor(dur=0.3, freq=180):
    """Tambor de moldura / tom."""
    s = varredura(freq * 1.4, freq, dur) * env(int(dur * TAXA), 0.001, dur, 6.0)
    pele = filtro(ruido(dur), "band", [freq, freq * 4]) * env(int(dur * TAXA), 0.001, 0.08, 6) * 0.5
    return mix(s, pele)


def caixa(dur=0.2):
    r = filtro(ruido(dur), "band", [1200, 7000]) * env(int(dur * TAXA), 0.001, dur, 7.0)
    corpo = np.sin(2 * np.pi * 200 * t(dur)) * env(int(dur * TAXA), 0.001, 0.06, 6) * 0.6
    return mix(r, corpo)


def chocalho(dur=0.06):
    return filtro(ruido(dur), "high", 6000) * env(int(dur * TAXA), 0.001, dur, 8.0) * 0.5


def prato(dur=1.2):
    r = filtro(ruido(dur), "high", 5000)
    return r * env(int(dur * TAXA), 0.002, dur, 5.0) * 0.6


# ----------------------------------------------------------------- sequenciador
class Faixa:
    def __init__(self, bpm, compassos, tempos=4):
        self.bpm = bpm
        self.batida = 60.0 / bpm
        self.dur = compassos * tempos * self.batida
        self.n = int(self.dur * TAXA)
        self.trilhas = {}

    def por(self, trilha, inicio_batidas, som, vol=1.0):
        buf = self.trilhas.setdefault(trilha, np.zeros(self.n + TAXA * 6))
        i = int(inicio_batidas * self.batida * TAXA)
        fim = min(i + len(som), len(buf))
        buf[i:fim] += som[: fim - i] * vol

    def render(self, volumes, rev=1.6, umidade=0.28):
        total = np.zeros(self.n + TAXA * 6)
        for nome, buf in self.trilhas.items():
            total += buf * volumes.get(nome, 1.0)
        total = reverb(total, rev, umidade)
        # loop sem emenda: a cauda depois do fim volta para o começo
        corpo = total[: self.n].copy()
        cauda = total[self.n:]
        k = min(len(cauda), self.n)
        corpo[:k] += cauda[:k]
        return corpo


def salvar_musica(nome, x):
    x = normalizar(x, 0.8)
    # compressão leve (tanh) para dar corpo
    x = np.tanh(x * 1.3) / np.tanh(1.3)
    x = normalizar(x, 0.85)
    caminho = os.path.join(RAIZ, "musica", nome + ".ogg")
    sf.write(caminho, np.stack([x, x], axis=1).astype(np.float32), TAXA, format="OGG",
             subtype="VORBIS")
    print("  musica", nome, "%.1fs" % (len(x) / TAXA))


ESCALA_DORICA = [0, 2, 3, 5, 7, 9, 10]
ESCALA_FRIGIA = [0, 1, 3, 5, 7, 8, 10]
ESCALA_FRIGIA_DOM = [0, 1, 4, 5, 7, 8, 10]
ESCALA_EOLIA = [0, 2, 3, 5, 7, 8, 10]


def grau(raiz, escala, g):
    oit, idx = divmod(g, len(escala))
    return raiz + 12 * oit + escala[idx]


# ================================================================= MÚSICAS
def musica_exploracao():
    """Entrada / salas vencidas: lira tranquila em Ré dórico."""
    f = Faixa(88, 16)
    raiz = 50  # Ré
    acordes = [0, 0, 3, 3, 4, 4, 0, 6, 0, 0, 3, 3, 4, 2, 6, 0]
    padrao = [0, 4, 7, 9, 7, 4, 2, 4]
    for c, g in enumerate(acordes):
        b0 = c * 4
        f.por("baixo", b0, baixo(nota_hz(grau(raiz - 12, ESCALA_DORICA, g)), 3.8), 0.7)
        f.por("pad", b0, pad([nota_hz(grau(raiz, ESCALA_DORICA, g + k)) for k in (0, 2, 4)], f.batida * 4.4))
        for k, p in enumerate(padrao):
            f.por("lira", b0 + k * 0.5, lira_rapida(nota_hz(grau(raiz + 12, ESCALA_DORICA, g + p // 2 * 0 + [0, 2, 4, 6][k % 4])), 1.4, 0.4), 0.5)
        f.por("perc", b0, tambor(0.4, 110), 0.5)
        f.por("perc", b0 + 2.5, tambor(0.3, 160), 0.3)
    melodia = [(16, 9, 2), (18, 11, 1), (19, 9, 1), (20, 7, 4), (24, 9, 2), (26, 7, 1), (27, 5, 1),
               (28, 4, 4), (48, 9, 2), (50, 11, 1), (51, 12, 1), (52, 11, 3), (55, 9, 1), (56, 7, 4),
               (60, 4, 2), (62, 2, 2)]
    for b, g, d in melodia:
        f.por("flauta", b, flauta(nota_hz(grau(raiz + 12, ESCALA_DORICA, g)), d * f.batida * 0.95), 0.35)
    return f.render({"lira": 0.8, "pad": 0.55, "baixo": 0.6, "perc": 0.6, "flauta": 0.9})


def musica_enigma():
    """Salas de enigma (depois do combate): misteriosa, Lá eólio, lenta."""
    f = Faixa(72, 12)
    raiz = 57
    acordes = [0, 5, 3, 4, 0, 5, 6, 4, 0, 3, 5, 4]
    for c, g in enumerate(acordes):
        b0 = c * 4
        f.por("pad", b0, pad([nota_hz(grau(raiz - 12, ESCALA_EOLIA, g + k)) for k in (0, 2, 4)], f.batida * 4.5))
        for k in range(4):
            gg = g + [4, 2, 7, 4][k]
            f.por("lira", b0 + k + (0.5 if k % 2 else 0), lira_rapida(nota_hz(grau(raiz, ESCALA_EOLIA, gg)), 2.0, 0.25), 0.45)
        f.por("baixo", b0, baixo(nota_hz(grau(raiz - 24, ESCALA_EOLIA, g)), 4.0), 0.6)
        if c % 2 == 1:
            sino = np.sin(2 * np.pi * nota_hz(grau(raiz + 24, ESCALA_EOLIA, g + 4)) * t(2.5)) * env(int(2.5 * TAXA), 0.002, 2.5, 4)
            f.por("sino", b0 + 3, sino, 0.2)
    return f.render({"pad": 0.7, "lira": 0.8, "baixo": 0.5, "sino": 1.0}, 2.2, 0.35)


def musica_combate():
    """Salas de combate: tambores rápidos e lira em Mi frígio."""
    f = Faixa(138, 16)
    raiz = 52
    progr = [0, 0, 1, 0, 0, 0, 6, 1] * 2
    for c, g in enumerate(progr):
        b0 = c * 4
        for k in range(8):
            nota = grau(raiz - 12, ESCALA_FRIGIA, g + (0 if k % 4 != 3 else 4))
            f.por("baixo", b0 + k * 0.5, baixo(nota_hz(nota), 0.3), 0.8 if k % 2 == 0 else 0.55)
        for k in (0, 1.5, 2, 3.5):
            f.por("bumbo", b0 + k, bumbo(0.35, 120, 45), 0.9)
        for k in (1, 3):
            f.por("caixa", b0 + k, caixa(), 0.55)
        for k in range(8):
            f.por("chocalho", b0 + k * 0.5 + 0.25, chocalho(), 0.4)
        for k, gg in enumerate([0, 2, 4, 2, 7, 4, 2, 1]):
            if (c + k) % 3 == 0 or c >= 8:
                f.por("lira", b0 + k * 0.5, lira_rapida(nota_hz(grau(raiz + 12, ESCALA_FRIGIA, g + gg)), 0.6, 0.7), 0.45)
        if c % 4 == 3:
            for k in range(4):
                f.por("tom", b0 + 2 + k * 0.5, tambor(0.25, 220 - k * 30), 0.7)
        if c in (0, 8):
            f.por("prato", b0, prato(1.5), 0.5)
    return f.render({"baixo": 0.75, "bumbo": 0.9, "caixa": 0.6, "chocalho": 0.5, "lira": 0.8, "tom": 0.7, "prato": 0.5},
                    1.0, 0.18)


def musica_chefe():
    """Minotauro: Ré frígio dominante, metais graves e tambores pesados."""
    f = Faixa(152, 16)
    raiz = 38
    riff = [0, 0, 1, 0, 4, 0, 1, 0]
    progr = [0, 0, 0, 1, 0, 0, 5, 4] * 2
    for c, g in enumerate(progr):
        b0 = c * 4
        for k, r in enumerate(riff):
            f.por("baixo", b0 + k * 0.5, baixo(nota_hz(grau(raiz, ESCALA_FRIGIA_DOM, g + r)), 0.28), 0.9)
        for k in (0, 0.75, 1.5, 2, 2.75, 3.5):
            f.por("bumbo", b0 + k, bumbo(0.4, 100, 38), 1.0)
        for k in (1, 3):
            f.por("caixa", b0 + k, caixa(0.25), 0.7)
        for k in range(8):
            f.por("chocalho", b0 + k * 0.5, chocalho(0.05), 0.35)
        if c % 2 == 0:
            acorde = [grau(raiz + 12, ESCALA_FRIGIA_DOM, g + k) for k in (0, 2, 4)]
            for nn in acorde:
                f.por("metal", b0, metal_grave(nota_hz(nn), f.batida * 1.4), 0.35)
                f.por("metal", b0 + 2, metal_grave(nota_hz(nn), f.batida * 0.6), 0.3)
                f.por("metal", b0 + 2.75, metal_grave(nota_hz(nn + (1 if c % 4 == 2 else 0)), f.batida * 1.2), 0.3)
        if c >= 8:
            mel = [7, 8, 7, 5, 4, 5, 4, 1]
            for k, gg in enumerate(mel):
                f.por("lira", b0 + k * 0.5, lira_rapida(nota_hz(grau(raiz + 24, ESCALA_FRIGIA_DOM, gg)), 0.5, 0.8), 0.4)
        if c % 4 == 0:
            f.por("prato", b0, prato(1.8), 0.6)
    return f.render({"baixo": 0.8, "bumbo": 1.0, "caixa": 0.6, "chocalho": 0.4, "metal": 0.9, "lira": 0.6, "prato": 0.5},
                    1.4, 0.22)


def musica_titulo():
    """Tela de título: flauta sobre pad, Lá eólio, majestosa e calma."""
    f = Faixa(70, 12)
    raiz = 57
    acordes = [0, 5, 2, 6, 0, 5, 3, 4, 0, 5, 6, 0]
    for c, g in enumerate(acordes):
        b0 = c * 4
        f.por("pad", b0, pad([nota_hz(grau(raiz - 12, ESCALA_EOLIA, g + k)) for k in (0, 2, 4, 7)], f.batida * 4.6))
        f.por("baixo", b0, baixo(nota_hz(grau(raiz - 24, ESCALA_EOLIA, g)), 4.5), 0.5)
        for k in range(4):
            f.por("lira", b0 + k, lira_rapida(nota_hz(grau(raiz, ESCALA_EOLIA, g + [0, 4, 2, 4][k])), 2.0, 0.3), 0.35)
        f.por("perc", b0, tambor(0.6, 90), 0.5)
    melodia = [(4, 4, 2), (6, 5, 1), (7, 4, 1), (8, 2, 3), (11, 1, 1), (12, 0, 4), (16, 7, 2), (18, 6, 1),
               (19, 4, 1), (20, 5, 3), (23, 4, 1), (24, 2, 4), (32, 4, 2), (34, 6, 2), (36, 7, 3),
               (39, 6, 1), (40, 4, 2), (42, 2, 2), (44, 0, 4)]
    for b, g, d in melodia:
        f.por("flauta", b, flauta(nota_hz(grau(raiz + 12, ESCALA_EOLIA, g)), d * f.batida * 0.95), 0.4)
    return f.render({"pad": 0.65, "baixo": 0.5, "lira": 0.7, "perc": 0.5, "flauta": 1.0}, 2.4, 0.33)


# ================================================================= EFEITOS
def gerar_sfx():
    # espada: "swoosh" de ruído com filtro que sobe e desce
    d = 0.22
    r = ruido(d)
    x = t(d)
    corpo = filtro(r, "band", [700, 2500]) * np.sin(np.pi * np.clip(x / (d * 0.6), 0, 1)) ** 2
    chiado = filtro(r, "band", [2500, 7000]) * np.sin(np.pi * np.clip((x - d * 0.2) / (d * 0.7), 0, 1)) ** 2
    salvar_sfx("espada", corpo * 0.8 + chiado * 0.6)

    # acerto: baque + estalo
    salvar_sfx("acerto", mix(bumbo(0.18, 220, 70) * 1.2, filtro(ruido(0.05), "band", [1500, 6000]) * env(int(0.05 * TAXA), 0.001, 0.05, 6)))

    # dano no Teseu: baque grave + "ai" sintético (formante descendente)
    voz = varredura(520, 300, 0.22, "saw")
    voz = filtro(voz, "band", [500, 1500]) * env(len(voz), 0.01, 0.22, 3)
    salvar_sfx("dano", mix(bumbo(0.25, 160, 55), voz * 0.5))

    # passo: toque abafado em pedra (2 variações)
    for k, fq in enumerate((900, 1300)):
        p = filtro(ruido(0.07), "band", [fq * 0.4, fq]) * env(int(0.07 * TAXA), 0.001, 0.05, 6)
        salvar_sfx("passo%d" % (k + 1), mix(p, bumbo(0.06, 140, 80) * 0.4), 0.5)

    # escudo bloqueando: metal (parciais inarmônicos)
    d = 0.5
    x = t(d)
    sino = sum(np.sin(2 * np.pi * f0 * x) * a for f0, a in ((620, 1.0), (1530, 0.6), (2410, 0.45), (3870, 0.3)))
    salvar_sfx("bloqueio", mix(sino * env(len(x), 0.001, 0.4, 5), filtro(ruido(0.03), "high", 3000) * 0.8))

    # portal: brilho subindo
    d = 0.9
    x = t(d)
    s = sum(varredura(f0, f0 * 2.2, d) * 0.3 for f0 in (330, 495, 660))
    s += filtro(ruido(d), "band", [2000, 8000]) * 0.15
    salvar_sfx("portal", reverb(s * np.sin(np.pi * x / d), 0.8, 0.3))

    # grade: corrente/metal batendo (cai e trava)
    d = 0.7
    x = t(d)
    chacoalhar = sum(filtro(ruido(d), "band", [f0, f0 * 1.3]) for f0 in (1800, 3200)) * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 22 * x))) * np.exp(-x * 3)
    batida = mix(np.zeros(int(0.45 * TAXA)), bumbo(0.25, 90, 40) * 1.5 + 0.6 * sum(np.sin(2 * np.pi * f0 * t(0.25)) for f0 in (410, 1170)) * env(int(0.25 * TAXA), 0.001, 0.2, 5))
    salvar_sfx("grade", mix(chacoalhar * 0.4, batida))

    # rugido do Minotauro: dente de serra grave com vibrato + ruído rosnado
    d = 1.8
    x = t(d)
    f0 = 85 + 30 * np.sin(np.pi * x / d) + 6 * np.sin(2 * np.pi * 9 * x)
    fase = 2 * np.pi * np.cumsum(f0) / TAXA
    serra = 2 * ((fase / (2 * np.pi)) % 1.0) - 1
    rosnado = filtro(ruido(d), "band", [150, 900]) * (1 + np.sin(2 * np.pi * 30 * x)) * 0.6
    s = filtro(serra + rosnado, "low", 1400) + 0.5 * filtro(serra, "band", [500, 900])
    e = np.clip(x / 0.15, 0, 1) * np.clip((d - x) / 0.6, 0, 1)
    salvar_sfx("rugido", reverb(s * e, 1.2, 0.3))

    # casco do Minotauro (trote) e golpe do machado no chão
    c = mix(bumbo(0.12, 300, 120), filtro(ruido(0.04), "band", [800, 3000]) * env(int(0.04 * TAXA), 0.001, 0.03, 5) * 0.8)
    salvar_sfx("casco", c, 0.6)
    salvar_sfx("impacto", reverb(mix(bumbo(0.8, 90, 28) * 1.5, filtro(ruido(0.6), "low", 900) * env(int(0.6 * TAXA), 0.002, 0.5, 4)), 1.0, 0.25))
    salvar_sfx("parede", reverb(mix(bumbo(0.6, 70, 30) * 1.5, filtro(ruido(0.5), "band", [200, 2500]) * env(int(0.5 * TAXA), 0.001, 0.3, 5)), 1.0, 0.3))

    # minitaurinho: grunhido curto, e "puf" ao morrer
    d = 0.3
    x = t(d)
    g = filtro(varredura(260, 180, d, "saw"), "band", [300, 1200]) * env(len(x), 0.01, d, 3)
    salvar_sfx("grunhido", g)
    puf = filtro(ruido(0.5), "low", 1800) * env(int(0.5 * TAXA), 0.005, 0.5, 4)
    salvar_sfx("puf", mix(puf, varredura(600, 200, 0.25) * env(int(0.25 * TAXA), 0.001, 0.25, 4) * 0.4))

    # pedra: arremesso (assobio curto) e quebra
    salvar_sfx("arremesso", filtro(ruido(0.25), "band", [500, 1800]) * np.sin(np.pi * t(0.25) / 0.25) ** 2)
    quebra = sum(filtro(ruido(0.35), "band", [f0, f0 * 1.6]) * env(int(0.35 * TAXA), 0.001, 0.12 + 0.05 * k, 6) for k, f0 in enumerate((400, 900, 2200)))
    salvar_sfx("pedra", mix(bumbo(0.15, 180, 60), quebra))

    # braseiro acendendo (fwoosh) e erro
    d = 0.8
    x = t(d)
    fw = filtro(ruido(d), "low", 900) * np.clip(x / 0.05, 0, 1) * np.exp(-x * 3) + filtro(ruido(d), "band", [2000, 6000]) * 0.1 * np.exp(-x * 5)
    salvar_sfx("fogo", fw)
    erro = mix(varredura(300, 150, 0.25, "sqr") * env(int(0.25 * TAXA), 0.002, 0.25, 2),
               np.concatenate([np.zeros(int(0.22 * TAXA)), varredura(220, 110, 0.35, "sqr") * env(int(0.35 * TAXA), 0.002, 0.35, 2)]))
    salvar_sfx("erro", filtro(erro, "low", 2500) * 0.6)

    # acerto de passo do enigma (sino) e enigma resolvido (arpejo)
    def sino(fq, dd=1.2):
        xx = t(dd)
        return (np.sin(2 * np.pi * fq * xx) + 0.4 * np.sin(2 * np.pi * fq * 2.76 * xx) + 0.2 * np.sin(2 * np.pi * fq * 5.4 * xx)) * env(len(xx), 0.002, dd, 4)
    salvar_sfx("sino", reverb(sino(880), 0.8, 0.25))
    arp = np.zeros(int(2.2 * TAXA))
    for k, n in enumerate([69, 73, 76, 81, 85, 88]):
        s = sino(nota_hz(n), 1.4)
        i = int(k * 0.11 * TAXA)
        arp[i:i + len(s)] += s[: len(arp) - i]
    salvar_sfx("resolvido", reverb(arp, 1.4, 0.3))

    # estátua arrastando, alavanca, espelho girando, cela abrindo
    d = 0.3
    salvar_sfx("arrastar", filtro(ruido(d), "band", [120, 900]) * np.sin(np.pi * t(d) / d) * (1 + 0.5 * np.sin(2 * np.pi * 37 * t(d))))
    salvar_sfx("alavanca", mix(filtro(ruido(0.1), "band", [800, 2500]) * env(int(0.1 * TAXA), 0.001, 0.1, 5), np.concatenate([np.zeros(int(0.12 * TAXA)), bumbo(0.2, 260, 120)])))
    salvar_sfx("girar", mix(filtro(ruido(0.25), "band", [1500, 4000]) * np.sin(np.pi * t(0.25) / 0.25) * 0.4, np.concatenate([np.zeros(int(0.2 * TAXA)), filtro(ruido(0.03), "high", 3000)])))

    # cura e coração
    cura = np.zeros(int(0.9 * TAXA))
    for k, n in enumerate([72, 76, 79, 84]):
        s = np.sin(2 * np.pi * nota_hz(n) * t(0.5)) * env(int(0.5 * TAXA), 0.003, 0.5, 4)
        i = int(k * 0.08 * TAXA)
        cura[i:i + len(s)] += s
    salvar_sfx("cura", reverb(cura, 0.6, 0.2))

    # menu: mover e confirmar
    salvar_sfx("menu_mover", (np.sign(np.sin(2 * np.pi * 880 * t(0.05)))) * env(int(0.05 * TAXA), 0.001, 0.05, 4) * 0.5, 0.5)
    ok = mix(np.sign(np.sin(2 * np.pi * 660 * t(0.07))) * 0.5,
             np.concatenate([np.zeros(int(0.07 * TAXA)), np.sign(np.sin(2 * np.pi * 990 * t(0.12))) * env(int(0.12 * TAXA), 0.001, 0.12, 3) * 0.5]))
    salvar_sfx("menu_ok", filtro(ok, "low", 4000), 0.55)

    # texto da caixa de diálogo (bip curtinho)
    salvar_sfx("texto", np.sign(np.sin(2 * np.pi * 1200 * t(0.025))) * env(int(0.025 * TAXA), 0.001, 0.025, 3), 0.3)

    # novelo: whoosh suave + sino (respawn / Ariadne)
    salvar_sfx("novelo", reverb(mix(filtro(ruido(0.6), "band", [400, 1500]) * np.sin(np.pi * t(0.6) / 0.6) * 0.5, sino(660, 1.0) * 0.6), 1.0, 0.3))

    # jingles: game over (descendente) e vitória (fanfarra)
    go = np.zeros(int(3.5 * TAXA))
    for k, n in enumerate([64, 62, 60, 57, 52]):
        s = mix(flauta(nota_hz(n), 0.5 if k < 4 else 1.6), 0.5 * lira_rapida(nota_hz(n - 12), 1.5, 0.3))
        i = int(k * 0.42 * TAXA)
        go[i:i + len(s)] += s[: len(go) - i]
    salvar_sfx("game_over", reverb(go, 1.8, 0.3))
    vit = np.zeros(int(3.5 * TAXA))
    for k, (n, dd) in enumerate([(60, 0.18), (64, 0.18), (67, 0.18), (72, 0.5), (67, 0.18), (72, 1.6)]):
        s = mix(sum(metal_grave(nota_hz(n + o), dd + 0.05) for o in (0, 12)) * 0.6, lira_rapida(nota_hz(n), 1.2, 0.6) * 0.5)
        i = int([0, 0.2, 0.4, 0.6, 1.15, 1.35][k] * TAXA)
        vit[i:i + len(s)] += s[: len(vit) - i]
    vit[:len(prato(1.8))] += prato(1.8) * 0.3
    salvar_sfx("vitoria", reverb(vit, 1.6, 0.3))


if __name__ == "__main__":
    os.makedirs(os.path.join(RAIZ, "sfx"), exist_ok=True)
    os.makedirs(os.path.join(RAIZ, "musica"), exist_ok=True)
    print("Efeitos:")
    gerar_sfx()
    print("Músicas:")
    salvar_musica("titulo", musica_titulo())
    salvar_musica("exploracao", musica_exploracao())
    salvar_musica("enigma", musica_enigma())
    salvar_musica("combate", musica_combate())
    salvar_musica("chefe", musica_chefe())
