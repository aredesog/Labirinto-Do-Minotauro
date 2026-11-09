"""Converte o teseu.blend (1,9 mi triângulos) num .glb leve para o jogo.
  1. lê posições / cantos / UV direto do .blend (Blender 5.x)
  2. separa os vértices por UV (costuras viram vértices duplicados)
  3. simplifica com meshoptimizer (mantém as costuras de UV)
  4. normais suaves (somadas por posição, sem quebrar nas costuras)
  5. grava GLB (Y para cima) com a textura base reduzida
Uso (o .blend do Blender 5 vem comprimido com zstd: pip install zstandard meshoptimizer numpy pillow):
  python3 ferramentas/blender/blend_para_glb.py teseu.blend assets/modelos/personagens/teseu_novo.glb 12000
"""
import io
import json
import struct
import sys

import numpy as np
import meshoptimizer
from PIL import Image

sys.path.insert(0, __import__('os').path.dirname(__import__('os').path.abspath(__file__)))
from blend_ler import Blend  # noqa: E402

entrada, saida = sys.argv[1], sys.argv[2]
alvo_tris = int(sys.argv[3]) if len(sys.argv) > 3 else 30000
bf = Blend(entrada)
me = [b for b in bf.blocos if b['code'] == b'ME'][0]
o = me['off']
st = bf.ler(o, 'Mesh', 'attribute_storage')
arr = bf.bloco(bf.ler(st, 'AttributeStorage', 'dna_attributes'))['off']
n = bf.ler(st, 'AttributeStorage', 'dna_attributes_num')
attrs = {}
for i in range(n):
    a = arr + i * 24
    nome = bf.dados(bf.ler(a, 'Attribute', 'name')).split(b'\0')[0].decode()
    aa = bf.bloco(bf.ler(a, 'Attribute', 'data'))['off']
    attrs[nome] = bf.dados(bf.ler(aa, 'AttributeArray', 'data'))

pos = np.frombuffer(attrs['position'], np.float32).reshape(-1, 3).astype(np.float64)
cv = np.frombuffer(attrs['.corner_vert'], np.int32)
uv = np.frombuffer(attrs['UVMap'], np.float32).reshape(-1, 2)
offs = np.frombuffer(bf.dados(bf.ler(o, 'Mesh', 'poly_offset_indices')), np.int32)
assert np.all(np.diff(offs[:bf.ler(o, 'Mesh', 'totpoly') + 1]) == 3), 'malha não é só triângulos'
print('original:', len(pos), 'vértices,', len(cv) // 3, 'triângulos')

# --- vértices únicos por (posição, UV)
uvq = np.round(uv * 65536).astype(np.int64)
chave = cv.astype(np.int64) * (1 << 40) + uvq[:, 0] * (1 << 20) + uvq[:, 1]
_, primeiro, inv = np.unique(chave, return_index=True, return_inverse=True)
v_pos = pos[cv[primeiro]].astype(np.float32)
v_uv = uv[primeiro].astype(np.float32)
idx = inv.astype(np.uint32)
print('com costuras de UV:', len(v_pos), 'vértices')

# --- simplificação
dest = np.zeros_like(idx)
erro = np.zeros(1, dtype=np.float32)
k = meshoptimizer.simplify(dest, idx, v_pos, target_index_count=alvo_tris * 3, target_error=0.02,
                           options=0, result_error=erro)
idx2 = dest[:k]
print('simplificado:', k // 3, 'triângulos, erro relativo', float(erro[0]))

usados, idx3 = np.unique(idx2, return_inverse=True)
p = v_pos[usados]
t = v_uv[usados]
f = idx3.reshape(-1, 3).astype(np.uint32)

# Blender (Z para cima, frente -Y)  ->  glTF (Y para cima, frente +Z)
p = np.stack([p[:, 0], p[:, 2], -p[:, 1]], axis=1).astype(np.float32)
# altura 1 m, pés no chão, centralizado (o Godot reajusta de qualquer jeito)
mn, mx = p.min(0), p.max(0)
p = (p - np.array([(mn[0] + mx[0]) / 2, mn[1], (mn[2] + mx[2]) / 2])) / (mx[1] - mn[1])
p = p.astype(np.float32)

# normais suaves somadas por POSIÇÃO (não racham nas costuras de UV)
e1 = p[f[:, 1]] - p[f[:, 0]]
e2 = p[f[:, 2]] - p[f[:, 0]]
fn = np.cross(e1, e2)
q = np.round(p * 1e5).astype(np.int64)
_, grupo = np.unique(q, axis=0, return_inverse=True)
grupo = grupo.reshape(-1)
acum = np.zeros((grupo.max() + 1, 3))
for c in range(3):
    np.add.at(acum, grupo[f[:, c]], fn)
nrm = acum[grupo]
nrm /= np.maximum(np.linalg.norm(nrm, axis=1, keepdims=True), 1e-12)
nrm = nrm.astype(np.float32)
# UV: Blender (origem embaixo)  ->  glTF (origem em cima)
t = np.stack([t[:, 0], 1.0 - t[:, 1]], axis=1).astype(np.float32)

# --- textura base (embutida no .blend)
jpg = None
for b in bf.blocos:
    if b['code'] == b'IM':
        nome = bf.ler(b['off'], 'ID', 'name', 0)
        caminho = bf.ler(b['off'], 'Image', 'filepath') if 'filepath' in bf.layout('Image') else ''
        if 'basecolor' not in (str(nome) + str(caminho)).lower():
            continue
        pf = bf.ler(b['off'], 'Image', 'packedfile')
        if not pf:
            lista = bf.ler(b['off'], 'Image', 'packedfiles')
            primeiro_ipf = struct.unpack_from('<Q', bf.d, lista)[0]
            pf = bf.ler(bf.bloco(primeiro_ipf)['off'], 'ImagePackedFile', 'packedfile')
        pb = bf.bloco(pf)['off']
        jpg = bf.dados(bf.ler(pb, 'PackedFile', 'data'))[:bf.ler(pb, 'PackedFile', 'size')]
        break
assert jpg, 'textura base não encontrada'
img = Image.open(io.BytesIO(jpg)).convert('RGB')
print('textura:', img.size)
img = img.resize((1024, 1024), Image.LANCZOS)
buf = io.BytesIO()
img.save(buf, 'JPEG', quality=88)
jpg = buf.getvalue()

# --- GLB
partes = []


def adicionar(bytes_):
    deslocamento = sum(len(x) for x in partes)
    partes.append(bytes_)
    while sum(len(x) for x in partes) % 4:
        partes.append(b'\0')
    return deslocamento, len(bytes_)


views, acessores = [], []


def acessor(arrv, tipo, comp, alvo=None, minmax=False):
    off, ln = adicionar(arrv.tobytes())
    v = {"buffer": 0, "byteOffset": off, "byteLength": ln}
    if alvo:
        v["target"] = alvo
    views.append(v)
    a = {"bufferView": len(views) - 1, "componentType": comp, "count": int(len(arrv)), "type": tipo}
    if minmax:
        a["min"] = arrv.min(0).tolist()
        a["max"] = arrv.max(0).tolist()
    acessores.append(a)
    return len(acessores) - 1


a_pos = acessor(p, "VEC3", 5126, 34962, True)
a_nrm = acessor(nrm, "VEC3", 5126, 34962)
a_uv = acessor(t, "VEC2", 5126, 34962)
a_idx = acessor(f.reshape(-1), "SCALAR", 5125, 34963)
off, ln = adicionar(jpg)
views.append({"buffer": 0, "byteOffset": off, "byteLength": ln})
bin_ = b''.join(partes)
gltf = {
    "asset": {"version": "2.0", "generator": "Labirinto do Minotauro - converter.py"},
    "scene": 0, "scenes": [{"nodes": [0]}],
    "nodes": [{"name": "Teseu", "mesh": 0}],
    "meshes": [{"name": "Teseu", "primitives": [{"attributes": {"POSITION": a_pos, "NORMAL": a_nrm, "TEXCOORD_0": a_uv},
                                                 "indices": a_idx, "material": 0}]}],
    "materials": [{"name": "Teseu", "pbrMetallicRoughness": {"baseColorTexture": {"index": 0},
                                                             "metallicFactor": 0.0, "roughnessFactor": 0.75}}],
    "textures": [{"source": 0, "sampler": 0}],
    "samplers": [{"magFilter": 9729, "minFilter": 9987}],
    "images": [{"bufferView": len(views) - 1, "mimeType": "image/jpeg"}],
    "accessors": acessores, "bufferViews": views, "buffers": [{"byteLength": len(bin_)}],
}
js = json.dumps(gltf, separators=(',', ':')).encode()
while len(js) % 4:
    js += b' '
total = 12 + 8 + len(js) + 8 + len(bin_)
with open(saida, 'wb') as fo:
    fo.write(struct.pack('<4sII', b'glTF', 2, total))
    fo.write(struct.pack('<I4s', len(js), b'JSON') + js)
    fo.write(struct.pack('<I4s', len(bin_), b'BIN\0') + bin_)
print('gravado', saida, total // 1024, 'KB')
