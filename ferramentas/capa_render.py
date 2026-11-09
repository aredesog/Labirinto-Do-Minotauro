"""Renderizador por software de .glb (toon + contorno) para a capa do README."""
import io
import json
import struct

import numpy as np
from PIL import Image, ImageFilter


def _q(q):
    x, y, z, w = q
    return np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                     [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                     [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])


def _matriz(no):
    if 'matrix' in no:
        return np.array(no['matrix']).reshape(4, 4).T
    m = np.eye(4)
    s = np.array(no.get('scale', [1, 1, 1]))
    r = _q(no.get('rotation', [0, 0, 0, 1]))
    m[:3, :3] = r * s
    m[:3, 3] = no.get('translation', [0, 0, 0])
    return m


def _slerp(q0, q1, t):
    q0 = np.array(q0); q1 = np.array(q1)
    d = np.dot(q0, q1)
    if d < 0:
        q1 = -q1; d = -d
    if d > 0.9995:
        r = q0 + t * (q1 - q0)
        return r / np.linalg.norm(r)
    th = np.arccos(d)
    return (np.sin((1 - t) * th) * q0 + np.sin(t * th) * q1) / np.sin(th)


def carregar(caminho, anim=None, tempo=0.0):
    d = open(caminho, 'rb').read()
    jl = struct.unpack_from('<I', d, 12)[0]
    g = json.loads(d[20:20 + jl])
    B = d[20 + jl + 8:]
    tipos = {5126: np.float32, 5125: np.uint32, 5123: np.uint16, 5121: np.uint8}
    ncomp = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}

    def acc(i):
        a = g['accessors'][i]
        v = g['bufferViews'][a['bufferView']]
        n = ncomp[a['type']]
        dt = tipos[a['componentType']]
        off = v.get('byteOffset', 0) + a.get('byteOffset', 0)
        stride = v.get('byteStride', 0)
        tam = np.dtype(dt).itemsize * n
        if stride and stride != tam:
            raw = np.frombuffer(B, np.uint8, stride * (a['count'] - 1) + tam, off)
            out = np.stack([np.frombuffer(raw[k * stride:k * stride + tam].tobytes(), dt) for k in range(a['count'])])
        else:
            out = np.frombuffer(B, dt, a['count'] * n, off).reshape(-1, n) if n > 1 else np.frombuffer(B, dt, a['count'], off)
        return out

    # --- pose: TRS de cada nó, com a animação (se pedida) aplicada em "tempo"
    trs = {}
    for i, no in enumerate(g['nodes']):
        trs[i] = [list(no.get('translation', [0, 0, 0])), list(no.get('rotation', [0, 0, 0, 1])),
                  list(no.get('scale', [1, 1, 1]))]
    if anim is not None:
        an = [x for x in g.get('animations', []) if x.get('name') == anim]
        if an:
            an = an[0]
            for ch in an['channels']:
                smp = an['samplers'][ch['sampler']]
                tt = acc(smp['input']).reshape(-1)
                vv = acc(smp['output'])
                t = min(max(tempo, tt[0]), tt[-1])
                k = int(np.searchsorted(tt, t, side='right') - 1)
                k = max(0, min(k, len(tt) - 1))
                k2 = min(k + 1, len(tt) - 1)
                f = 0.0 if k2 == k else (t - tt[k]) / (tt[k2] - tt[k])
                caminho_ = ch['target']['path']
                no = ch['target']['node']
                if caminho_ == 'rotation':
                    trs[no][1] = list(_slerp(vv[k], vv[k2], f))
                elif caminho_ == 'translation':
                    trs[no][0] = list(vv[k] * (1 - f) + vv[k2] * f)
                elif caminho_ == 'scale':
                    trs[no][2] = list(vv[k] * (1 - f) + vv[k2] * f)
    globais = {}

    def local(i):
        m = np.eye(4)
        no = g['nodes'][i]
        if 'matrix' in no and anim is None:
            return _matriz(no)
        t_, r_, s_ = trs[i]
        m[:3, :3] = _q(r_) * np.array(s_)
        m[:3, 3] = t_
        return m

    def calc(i, pai):
        globais[i] = pai @ local(i)
        for c in g['nodes'][i].get('children', []):
            calc(c, globais[i])
    for ni in g['scenes'][g.get('scene', 0)]['nodes']:
        calc(ni, np.eye(4))

    imgs = []
    for im in g.get('images', []):
        v = g['bufferViews'][im['bufferView']]
        imgs.append(np.asarray(Image.open(io.BytesIO(B[v.get('byteOffset', 0):v.get('byteOffset', 0) + v['byteLength']])).convert('RGB')).astype(np.float32) / 255)

    def tex_mat(mi):
        if mi is None:
            return None, np.array([0.8, 0.8, 0.8])
        m = g['materials'][mi]
        pbr = m.get('pbrMetallicRoughness', {})
        cor = np.array(pbr.get('baseColorFactor', [1, 1, 1, 1])[:3])
        t = pbr.get('baseColorTexture')
        if t is not None:
            return imgs[g['textures'][t['index']]['source']], cor
        return None, cor

    partes = []

    def visitar(ni, pai):
        no = g['nodes'][ni]
        M = globais.get(ni, pai @ _matriz(no))
        if 'mesh' in no:
            pele = None
            if 'skin' in no:
                sk = g['skins'][no['skin']]
                ibm = acc(sk['inverseBindMatrices']).reshape(-1, 4, 4).transpose(0, 2, 1)
                pele = np.stack([globais[j] @ ibm[k] for k, j in enumerate(sk['joints'])])
            for pr in g['meshes'][no['mesh']]['primitives']:
                P = acc(pr['attributes']['POSITION']).astype(np.float64)
                if pele is not None and 'JOINTS_0' in pr['attributes']:
                    J = acc(pr['attributes']['JOINTS_0']).astype(np.int64)
                    W = acc(pr['attributes']['WEIGHTS_0']).astype(np.float64)
                    if W.max() > 1.5:
                        W = W / 255.0
                    W = W / np.maximum(W.sum(1, keepdims=True), 1e-9)
                    Ph = np.c_[P, np.ones(len(P))]
                    out = np.zeros((len(P), 3))
                    for c in range(4):
                        Mj = pele[J[:, c]]                      # (n,4,4)
                        out += W[:, c:c + 1] * np.einsum('nij,nj->ni', Mj, Ph)[:, :3]
                    P = out
                else:
                    Mu = M
                    P = (Mu[:3, :3] @ P.T).T + Mu[:3, 3]
                T = acc(pr['attributes']['TEXCOORD_0']).astype(np.float64) if 'TEXCOORD_0' in pr['attributes'] else np.zeros((len(P), 2))
                F = acc(pr['indices']).astype(np.int64).reshape(-1, 3)
                tex, cor = tex_mat(pr.get('material'))
                partes.append((P, T, F, tex, cor))
        for c in no.get('children', []):
            visitar(c, M)

    for ni in g['scenes'][g.get('scene', 0)]['nodes']:
        visitar(ni, np.eye(4))
    return partes


def render(partes, larg, alt, yaw=0.0, pitch=0.0, escala=None, centro=None, luz=(0.5, 0.75, 0.6), bandas=True,
           cor_luz=(1.0, 1.0, 1.0), cor_sombra=(0.55, 0.5, 0.65), contorno=3):
    """Ortográfico. Devolve imagem RGBA (fundo transparente) com contorno."""
    cy, sy = np.cos(yaw), np.sin(yaw)
    cp, sp = np.cos(pitch), np.sin(pitch)
    Ry = np.array([[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]])
    Rx = np.array([[1, 0, 0], [0, cp, -sp], [0, sp, cp]])
    R = Rx @ Ry
    todos = np.concatenate([p[0] for p in partes]) @ R.T
    mn, mx = todos.min(0), todos.max(0)
    if escala is None:
        escala = 0.92 * min(larg / (mx[0] - mn[0]), alt / (mx[1] - mn[1]))
    if centro is None:
        centro = (mn + mx) / 2
    img = np.zeros((alt, larg, 3))
    a = np.zeros((alt, larg))
    zb = np.full((alt, larg), -1e9)
    L = np.array(luz) / np.linalg.norm(luz)
    for P0, T, F, tex, cor in partes:
        P = P0 @ R.T
        sx = (P[:, 0] - centro[0]) * escala + larg / 2
        syy = alt / 2 - (P[:, 1] - centro[1]) * escala
        z = P[:, 2]
        # normal por face (visual facetado leve, bom para toon)
        e1 = P[F[:, 1]] - P[F[:, 0]]
        e2 = P[F[:, 2]] - P[F[:, 0]]
        fn = np.cross(e1, e2)
        fn /= np.maximum(np.linalg.norm(fn, axis=1, keepdims=True), 1e-12)
        # normais suaves por vértice
        vn = np.zeros_like(P)
        for c in range(3):
            np.add.at(vn, F[:, c], np.cross(e1, e2))
        vn /= np.maximum(np.linalg.norm(vn, axis=1, keepdims=True), 1e-12)
        for k, tri in enumerate(F):
            xs, ys = sx[tri], syy[tri]
            x0, x1 = int(max(xs.min(), 0)), int(min(xs.max() + 1, larg))
            y0, y1 = int(max(ys.min(), 0)), int(min(ys.max() + 1, alt))
            if x1 <= x0 or y1 <= y0:
                continue
            gx, gy = np.meshgrid(np.arange(x0, x1) + 0.5, np.arange(y0, y1) + 0.5)
            (ax, bx, cx), (ay, by, cyy) = xs, ys
            den = (by - cyy) * (ax - cx) + (cx - bx) * (ay - cyy)
            if abs(den) < 1e-9:
                continue
            w0 = ((by - cyy) * (gx - cx) + (cx - bx) * (gy - cyy)) / den
            w1 = ((cyy - ay) * (gx - cx) + (ax - cx) * (gy - cyy)) / den
            w2 = 1 - w0 - w1
            m = (w0 >= 0) & (w1 >= 0) & (w2 >= 0)
            if not m.any():
                continue
            zz = w0 * z[tri[0]] + w1 * z[tri[1]] + w2 * z[tri[2]]
            sub = zb[y0:y1, x0:x1]
            m &= zz > sub
            if not m.any():
                continue
            if tex is not None:
                u = w0 * T[tri[0], 0] + w1 * T[tri[1], 0] + w2 * T[tri[2], 0]
                v = w0 * T[tri[0], 1] + w1 * T[tri[1], 1] + w2 * T[tri[2], 1]
                u = np.mod(u, 1.0)
                v = np.mod(v, 1.0)
                base = tex[(v * (tex.shape[0] - 1)).astype(int), (u * (tex.shape[1] - 1)).astype(int)] * cor
            else:
                base = np.broadcast_to(cor, gx.shape + (3,))
            nn = w0[..., None] * vn[tri[0]] + w1[..., None] * vn[tri[1]] + w2[..., None] * vn[tri[2]]
            nn /= np.maximum(np.linalg.norm(nn, axis=-1, keepdims=True), 1e-9)
            d = np.clip(nn @ L, 0, 1)
            if bandas:   # cel shading: 3 faixas
                d = np.where(d > 0.55, 1.0, np.where(d > 0.18, 0.72, 0.45))
            sh = np.array(cor_sombra) + (np.array(cor_luz) - np.array(cor_sombra)) * d[..., None]
            # brilho de borda (rim light) fraquinho
            rim = (1 - np.clip(nn[..., 2], 0, 1)) ** 3 * 0.25
            col = base * sh + rim[..., None]
            sub[m] = zz[m]
            img[y0:y1, x0:x1][m] = col[m]
            a[y0:y1, x0:x1][m] = 1.0
    rgba = np.dstack([np.clip(img, 0, 1), a])
    im = Image.fromarray((rgba * 255).astype(np.uint8), 'RGBA')
    if contorno > 0:
        alfa = im.getchannel('A').filter(ImageFilter.MaxFilter(contorno * 2 + 1))
        borda = Image.new('RGBA', im.size, (42, 18, 16, 0))
        borda.putalpha(alfa)
        borda.alpha_composite(im)
        im = borda
    return im, escala, centro
