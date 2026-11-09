"""
Personagens modelados pelo grupo (minitaurinho e Ariadne): otimiza, cria o
esqueleto (rig), pinta os pesos, anima e exporta para o Godot.

Uso:
    # 1) a partir do .blend original do grupo (malha de ~1 milhão de vértices):
    python3 ferramentas/blender/personagens_grupo.py otimizar <original.blend> <nome>
    #    -> assets/modelos/fontes/<nome>_base.blend  (≈9 mil triângulos, textura 1024)
    # 2) rig + animações + exportação (pode rodar quantas vezes quiser):
    python3 ferramentas/blender/personagens_grupo.py montar <nome>
    #    -> assets/modelos/personagens/<nome>.glb  (+ fontes/<nome>.blend)

    <nome> = minitaurinho_grupo | ariadne_grupo | minotauro_grupo

O arremessador de pedras usa o MESMO modelo do minitaurinho, só com a
textura recolorida (pelo mais escuro e roupa azul): <nome>_arremessador.glb.

Convenções (iguais às do resto do projeto):
  - frente do personagem = -Y no Blender (+Z no Godot); esquerda = +X
  - ossos com os nomes dos pivôs usados nos scripts: Quadril, Tronco, Cabeca,
    BracoE/BracoD, PernaE/PernaD, Cauda/Cauda2
  - ações (viram animações no AnimationPlayer do Godot):
      minitaurinho: parado, andar, atacar, erguer, arremessar, dano
      ariadne:      parado, andar, arremessar
      minotauro:    parado, andar, correr, rugir, mirar, erguer, golpe,
                    atordoado, frear, morrer
"""

import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

RAIZ_PROJETO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
PASTA_GLB = os.path.join(RAIZ_PROJETO, "assets", "modelos", "personagens")
PASTA_FONTES = os.path.join(RAIZ_PROJETO, "assets", "modelos", "fontes")
FPS = 24

# --------------------------------------------------------------------------
# Esqueletos: (nome, pai, cabeça, cauda) em metros, coordenadas do Blender
# --------------------------------------------------------------------------
def _espelhar(lista):
    """Duplica os ossos terminados em E para o lado D (x -> -x)."""
    out = []
    for nome, pai, cab, cau in lista:
        out.append((nome, pai, cab, cau))
        if nome.endswith("E"):
            espelho = lambda v: (-v[0], v[1], v[2])
            pai_d = pai[:-1] + "D" if pai and pai.endswith("E") else pai
            out.append((nome[:-1] + "D", pai_d, espelho(cab), espelho(cau)))
    return out


OSSOS = {
    # Minotauro em pose T (braços abertos): cadeia completa de braço e perna
    "minotauro_grupo": _espelhar([
        ("Raiz", None, (0, 0, 0.0), (0, 0, 0.1)),
        ("Quadril", "Raiz", (0, 0, 0.33), (0, 0, 0.42)),
        ("Coluna", "Quadril", (0, 0, 0.42), (0, 0, 0.52)),
        ("Peito", "Coluna", (0, 0, 0.52), (0, 0, 0.68)),
        ("Cabeca", "Peito", (0, -0.01, 0.7), (0, -0.01, 0.9)),
        ("BracoE", "Peito", (0.13, 0, 0.64), (0.28, 0, 0.61)),
        ("AntebracoE", "BracoE", (0.28, 0, 0.61), (0.39, 0, 0.59)),
        ("MaoE", "AntebracoE", (0.39, 0, 0.59), (0.47, 0, 0.58)),
        ("CoxaE", "Quadril", (0.09, 0, 0.36), (0.12, 0, 0.19)),
        ("CanelaE", "CoxaE", (0.12, 0, 0.19), (0.15, 0.01, 0.07)),
        ("PeE", "CanelaE", (0.15, 0.01, 0.07), (0.15, -0.1, 0.02)),
    ]),
    "minitaurinho_grupo": [
        ("Raiz", None, (0, -0.03, 0.0), (0, -0.03, 0.1)),
        ("Quadril", "Raiz", (0, -0.03, 0.2), (0, -0.03, 0.33)),
        ("Tronco", "Quadril", (0, -0.03, 0.33), (0, -0.03, 0.45)),
        ("Cabeca", "Tronco", (0, -0.03, 0.45), (0, -0.03, 0.85)),
        ("BracoE", "Tronco", (0.125, -0.03, 0.42), (0.205, -0.04, 0.27)),
        ("BracoD", "Tronco", (-0.125, -0.03, 0.42), (-0.205, -0.04, 0.27)),
        ("PernaE", "Quadril", (0.095, -0.03, 0.21), (0.1, -0.05, 0.02)),
        ("PernaD", "Quadril", (-0.095, -0.03, 0.21), (-0.1, -0.05, 0.02)),
        ("Cauda", "Quadril", (0.02, 0.1, 0.25), (0.12, 0.19, 0.19)),
        ("Cauda2", "Cauda", (0.12, 0.19, 0.19), (0.24, 0.22, 0.09)),
    ],
    "ariadne_grupo": [
        ("Raiz", None, (0, -0.05, 0.0), (0, -0.05, 0.1)),
        ("Quadril", "Raiz", (0, -0.05, 0.21), (0, -0.05, 0.32)),
        ("Tronco", "Quadril", (0, -0.05, 0.32), (0, -0.05, 0.44)),
        ("Cabeca", "Tronco", (0, -0.03, 0.44), (0, -0.03, 0.8)),
        ("BracoE", "Tronco", (0.09, -0.05, 0.42), (0.13, -0.06, 0.27)),
        ("BracoD", "Tronco", (-0.09, -0.05, 0.42), (-0.13, -0.06, 0.27)),
        ("PernaE", "Quadril", (0.055, -0.05, 0.21), (0.06, -0.08, 0.03)),
        ("PernaD", "Quadril", (-0.055, -0.05, 0.21), (-0.06, -0.08, 0.03)),
    ],
}


# ==========================================================================
# 1) Otimizar a malha original
# ==========================================================================
def otimizar(original, nome, faces=9000, tex=1024):
    bpy.ops.wm.open_mainfile(filepath=original)
    for o in list(bpy.data.objects):
        if o.type != "MESH":
            bpy.data.objects.remove(o)
    ob = [o for o in bpy.data.objects if o.type == "MESH"][0]
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    m = ob.modifiers.new("dizimar", "DECIMATE")
    m.ratio = faces / len(ob.data.polygons)
    bpy.ops.object.modifier_apply(modifier="dizimar")
    bpy.ops.object.shade_smooth()
    mat = ob.data.materials[0]
    nt = mat.node_tree
    bsdf = [n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"][0]
    base = None
    for n in list(nt.nodes):
        if n.type == "TEX_IMAGE":
            if "basecolor" in n.image.name:
                base = n
            else:
                nt.nodes.remove(n)
        elif n.type == "NORMAL_MAP":
            nt.nodes.remove(n)
    bsdf.inputs["Metallic"].default_value = 0.0
    bsdf.inputs["Roughness"].default_value = 0.9
    img = base.image
    img.scale(tex, tex)
    for im in list(bpy.data.images):
        if im != img:
            bpy.data.images.remove(im)
    img.name = nome + "_cor"
    caminho = os.path.join(PASTA_FONTES, nome + "_cor.png")
    os.makedirs(PASTA_FONTES, exist_ok=True)
    img.filepath_raw = caminho
    img.file_format = "PNG"
    img.save()
    img.pack()
    mat.name = nome
    ob.name = "Corpo"
    ob.data.name = nome + "_malha"
    bpy.ops.outliner.orphans_purge(do_recursive=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(PASTA_FONTES, nome + "_base.blend"), compress=True)
    print("otimizado:", nome, len(ob.data.polygons), "faces")


# ==========================================================================
# 2) Rig
# ==========================================================================
def criar_esqueleto(nome):
    arm = bpy.data.armatures.new(nome + "_esqueleto")
    ob = bpy.data.objects.new("Esqueleto", arm)
    bpy.context.scene.collection.objects.link(ob)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode="EDIT")
    for nome_osso, pai, cab, cau in OSSOS[nome]:
        b = arm.edit_bones.new(nome_osso)
        b.head = Vector(cab)
        b.tail = Vector(cau)
        b.roll = 0.0
        if pai:
            b.parent = arm.edit_bones[pai]
            b.use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    return ob


def _dist_segmento(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared))
    return (p - (a + ab * t)).length, t


def pintar_pesos_calor(corpo, esq, nome):
    """Pesos automáticos do Blender (difusão de calor), depois: cabeça e
    cachos 100% na cabeça; nada nas costas preso aos braços."""
    bpy.ops.object.select_all(action="DESELECT")
    corpo.select_set(True)
    esq.select_set(True)
    bpy.context.view_layer.objects.active = esq
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    if "Raiz" in corpo.vertex_groups:
        corpo.vertex_groups.remove(corpo.vertex_groups["Raiz"])
    ossos = {b.name: b for b in esq.data.bones}
    pesc = ossos["Cabeca"].head_local.z
    ombro = ossos["BracoE"].head_local
    g = {gr.name: gr for gr in corpo.vertex_groups}
    ariadne = nome.startswith("ariadne")
    for v in corpo.data.vertices:
        p = v.co
        cabeca = p.z > pesc + 0.015 or (ariadne and abs(p.x) > 0.165 and p.z > ombro.z - 0.1)
        if cabeca:
            for gr in g.values():
                gr.remove([v.index])
            g["Cabeca"].add([v.index], 1.0, "REPLACE")
        elif ariadne and p.y > ombro.y + 0.06:
            # costas (capa): o que era dos braços passa para o tronco
            extra = 0.0
            for lado in ("BracoE", "BracoD"):
                for e in v.groups:
                    if e.group == g[lado].index:
                        extra += e.weight
                g[lado].remove([v.index])
            if extra > 0:
                atual = 0.0
                for e in v.groups:
                    if e.group == g["Tronco"].index:
                        atual = e.weight
                g["Tronco"].add([v.index], atual + extra, "REPLACE")


def pintar_pesos(corpo, esq, nome):
    """Pesos por proximidade aos ossos (inverso da distância^4), com regiões:
    tudo acima do pescoço é só da cabeça; braços só pegam o que está ao lado
    do corpo; pernas só abaixo do quadril; cauda só atrás do quadril."""
    ossos = {b.name: (b.head_local.copy(), b.tail_local.copy()) for b in esq.data.bones}
    pesc = ossos["Cabeca"][0].z
    quad = ossos["PernaE"][0].z
    ombro = ossos["BracoE"][0]
    mao_z = ossos["BracoE"][1].z
    largura_tronco = abs(ombro.x) * 0.62
    cachos = 0.165 if nome.startswith("ariadne") else None
    raio_braco = 0.042 if nome.startswith("ariadne") else 0.06
    for b in ossos:
        if b != "Raiz":
            corpo.vertex_groups.new(name=b)
    for v in corpo.data.vertices:
        p = v.co
        cand = {}
        if p.z > pesc + 0.015:
            cand = {"Cabeca": 1.0}
        elif cachos and abs(p.x) > cachos and p.z > ombro.z - 0.1:
            cand = {"Cabeca": 1.0}  # cachos do cabelo caídos ao lado dos ombros
        else:
            for b, (a, c) in ossos.items():
                if b == "Raiz":
                    continue
                if b.startswith("Braco"):
                    lado = 1 if b.endswith("E") else -1
                    if p.x * lado < largura_tronco or p.z < mao_z - 0.06 or p.z > ombro.z + 0.04:
                        continue
                    if p.y > ombro.y + 0.06:
                        continue  # capa/faixa nas costas fica com o tronco
                    if _dist_segmento(p, a, c)[0] > raio_braco:
                        continue  # roupa encostada no braço não vai junto
                if b.startswith("Perna"):
                    lado = 1 if b.endswith("E") else -1
                    if p.z > quad + 0.03 or p.x * lado < -0.02:
                        continue
                if b.startswith("Cauda") and (p.y < 0.06 or p.z > quad + 0.08):
                    continue
                if b == "Cabeca" and p.z < pesc - 0.03:
                    continue
                d, _ = _dist_segmento(p, a, c)
                cand[b] = 1.0 / (max(d, 0.004) ** 4)
        mais = sorted(cand.items(), key=lambda kv: -kv[1])[:3]
        tot = sum(w for _, w in mais) or 1.0
        for b, w in mais:
            corpo.vertex_groups[b].add([v.index], w / tot, "REPLACE")
    mod = corpo.modifiers.new("Esqueleto", "ARMATURE")
    mod.object = esq
    corpo.parent = esq


def clava(esq):
    """Clava de madeira na mão direita do minitaurinho (100% no osso BracoD)."""
    a, c = esq.data.bones["BracoD"].head_local, esq.data.bones["BracoD"].tail_local
    mao = c + (c - a).normalized() * 0.01
    madeira = bpy.data.materials.new("clava_madeira")
    madeira.diffuse_color = (0.42, 0.24, 0.12, 1)
    madeira.use_nodes = True
    madeira.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.42, 0.24, 0.12, 1)
    escura = bpy.data.materials.new("clava_faixa")
    escura.use_nodes = True
    escura.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.25, 0.13, 0.07, 1)
    # cabo e cabeça, apontando para a frente (-Y) e um pouco para cima
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.017, depth=0.16)
    cabo = bpy.context.object
    bpy.ops.mesh.primitive_cone_add(vertices=10, radius1=0.028, radius2=0.05, depth=0.2)
    cab = bpy.context.object
    cab.location.z = 0.17
    bpy.ops.mesh.primitive_torus_add(major_radius=0.03, minor_radius=0.008, major_segments=10, minor_segments=4)
    faixa = bpy.context.object
    faixa.location.z = 0.1
    cabo.data.materials.append(madeira)
    cab.data.materials.append(madeira)
    faixa.data.materials.append(escura)
    bpy.ops.object.select_all(action="DESELECT")
    for o in (cabo, cab, faixa):
        o.select_set(True)
    bpy.context.view_layer.objects.active = cabo
    bpy.ops.object.join()
    cl = bpy.context.object
    cl.name = "Clava"
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    # pega pela base do cabo; inclina para a frente
    for v in cl.data.vertices:
        v.co.z += 0.06
    cl.rotation_euler = (math.radians(70), 0, 0)
    cl.location = mao
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.object.shade_smooth()
    g = cl.vertex_groups.new(name="BracoD")
    g.add([v.index for v in cl.data.vertices], 1.0, "REPLACE")
    mod = cl.modifiers.new("Esqueleto", "ARMATURE")
    mod.object = esq
    cl.parent = esq


def machado(esq):
    """Machado de duas lâminas na mão direita do Minotauro (100% no osso MaoD).
    Na pose T o cabo aponta para a frente e um pouco para cima."""
    a, c = esq.data.bones["MaoD"].head_local, esq.data.bones["MaoD"].tail_local
    mao = (a + c) * 0.5
    def material(nome, cor, metal=0.0):
        m = bpy.data.materials.new(nome)
        m.use_nodes = True
        b = m.node_tree.nodes["Principled BSDF"]
        b.inputs["Base Color"].default_value = cor
        b.inputs["Metallic"].default_value = metal
        b.inputs["Roughness"].default_value = 0.5
        return m
    madeira = material("machado_cabo", (0.36, 0.2, 0.1, 1))
    ferro = material("machado_lamina", (0.62, 0.64, 0.68, 1), 0.8)
    couro = material("machado_couro", (0.2, 0.1, 0.06, 1))
    partes = []
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.012, depth=0.42)
    cabo = bpy.context.object
    cabo.location.z = 0.13
    cabo.data.materials.append(madeira)
    partes.append(cabo)
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.015, depth=0.07)
    punho = bpy.context.object
    punho.location.z = -0.02
    punho.data.materials.append(couro)
    partes.append(punho)
    for lado in (1, -1):
        # lâmina em forma de meia-lua achatada
        bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.085, depth=0.012)
        lam = bpy.context.object
        # disco achatado em Y, de pé no plano do cabo
        lam.rotation_euler = (math.radians(90), 0, 0)
        lam.scale = (1.0, 1.35, 1.0)
        lam.location = (lado * 0.07, 0, 0.3)
        lam.data.materials.append(ferro)
        partes.append(lam)
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.03, depth=0.06)
    olho = bpy.context.object
    olho.location.z = 0.3
    olho.data.materials.append(ferro)
    partes.append(olho)
    bpy.ops.object.select_all(action="DESELECT")
    for o in partes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = cabo
    bpy.ops.object.join()
    m = bpy.context.object
    m.name = "Machado"
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    # cabo (eixo +Z) -> para a frente (-Y) na pose T; a inclinação para
    # cima vem da rotação da mão (MaoD) nas animações
    m.rotation_euler = (math.radians(90), 0, 0)
    m.location = mao
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    gr = m.vertex_groups.new(name="MaoD")
    gr.add([v.index for v in m.data.vertices], 1.0, "REPLACE")
    mod = m.modifiers.new("Esqueleto", "ARMATURE")
    mod.object = esq
    m.parent = esq


# ==========================================================================
# 3) Animações
# ==========================================================================
def _girar(esq, osso, eixo, graus):
    """Gira o osso em torno de um eixo do MUNDO (X: frente/trás, Y: lado,
    Z: vira). Converte para o espaço local do osso."""
    pb = esq.pose.bones[osso]
    rest = esq.data.bones[osso].matrix_local.to_3x3()
    rot = Matrix.Rotation(math.radians(graus), 3, eixo)
    pb.rotation_mode = "QUATERNION"
    pb.rotation_quaternion = (rest.inverted() @ rot @ rest).to_quaternion()


def _pose(esq, quadro, poses, loc=None):
    """poses = {osso: [(eixo, graus), ...]} — ossos não citados voltam ao zero."""
    for pb in esq.pose.bones:
        pb.rotation_mode = "QUATERNION"
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.location = (0, 0, 0)
    for osso, rots in poses.items():
        if osso not in esq.pose.bones:
            continue
        pb = esq.pose.bones[osso]
        rest = esq.data.bones[osso].matrix_local.to_3x3()
        tot = Matrix.Identity(3)
        for eixo, g in rots:
            tot = Matrix.Rotation(math.radians(g), 3, eixo) @ tot
        pb.rotation_quaternion = (rest.inverted() @ tot @ rest).to_quaternion()
    if loc:
        for osso, d in loc.items():
            pb = esq.pose.bones[osso]
            rest = esq.data.bones[osso].matrix_local.to_3x3()
            pb.location = rest.inverted() @ Vector(d)
    for pb in esq.pose.bones:
        pb.keyframe_insert("rotation_quaternion", frame=quadro)
        pb.keyframe_insert("location", frame=quadro)


def _acao(esq, nome, chaves, ciclo=False):
    """chaves = [(quadro, poses, loc)]; se ciclo, repete a 1ª chave no fim."""
    acao = bpy.data.actions.new(nome)
    acao.use_fake_user = True
    esq.animation_data_create()
    esq.animation_data.action = acao
    for q, poses, loc in chaves:
        _pose(esq, q, poses, loc)
    # interpolação suave; ciclos sem "parada" no fim
    for fc in _curvas(acao):
        for kp in fc.keyframe_points:
            kp.interpolation = "BEZIER"
            kp.handle_left_type = kp.handle_right_type = "AUTO_CLAMPED"
    esq.animation_data.action = None
    return acao


def _curvas(acao):
    if hasattr(acao, "fcurves") and len(getattr(acao, "fcurves", [])):
        return list(acao.fcurves)
    out = []
    for layer in getattr(acao, "layers", []):
        for strip in layer.strips:
            for bag in strip.channelbags:
                out.extend(bag.fcurves)
    return out


X, Y, Z = "X", "Y", "Z"


def anim_minitaurinho(esq):
    # Atenção ao sinal: osso que aponta para BAIXO (braço, perna) vai para a
    # FRENTE com ângulo NEGATIVO em X; osso que aponta para CIMA (tronco,
    # cabeça) inclina para a frente com ângulo POSITIVO.
    def passo(f, s):
        return (f, {
            "PernaE": [(X, -32 * s)], "PernaD": [(X, 32 * s)],
            "BracoE": [(X, 26 * s), (Y, -6)], "BracoD": [(X, -26 * s), (Y, 6)],
            "Tronco": [(Z, 6 * s), (X, 6)], "Cabeca": [(Z, -4 * s)],
            "Cauda": [(Z, 18 * s)], "Cauda2": [(Z, 14 * s)],
        }, {"Quadril": (0, 0, 0.0)})

    def meio(f, s):
        return (f, {
            "Tronco": [(X, 6)], "BracoE": [(Y, -6)], "BracoD": [(Y, 6)],
            "Cauda": [(Z, 0)], "Cabeca": [(X, -3)],
        }, {"Quadril": (0, 0, 0.022)})

    _acao(esq, "andar", [passo(0, 1), meio(4, 1), passo(8, -1), meio(12, -1), passo(16, 1)], True)
    respira = lambda f, k: (f, {
        "Tronco": [(X, -2 * k)], "Cabeca": [(X, 4 * k), (Y, 3 * k)],
        "BracoE": [(Y, -5 - 3 * k), (X, 4 * k)], "BracoD": [(Y, 5 + 3 * k), (X, 4 * k)],
        "Cauda": [(Z, 22 * k)], "Cauda2": [(Z, 18 * k)],
    }, {"Quadril": (0, 0, -0.008 * abs(k))})
    _acao(esq, "parado", [respira(0, 1), respira(12, -1), respira(24, 1)], True)
    # golpe de clava: ergue por cima da cabeça e desce com tudo
    _acao(esq, "atacar", [
        (0, {"BracoD": [(X, 0)]}, None),
        (4, {"BracoD": [(X, -165), (Y, 10)], "Tronco": [(X, -10), (Z, -15)], "Cabeca": [(X, -6)],
             "BracoE": [(X, 20)]}, None),
        (7, {"BracoD": [(X, -40)], "Tronco": [(X, 22), (Z, 10)], "Cabeca": [(X, 8)],
             "BracoE": [(X, -15)], "PernaD": [(X, -12)], "PernaE": [(X, 10)]}, {"Quadril": (0, 0, -0.02)}),
        (10, {"BracoD": [(X, -30)], "Tronco": [(X, 14)]}, {"Quadril": (0, 0, -0.012)}),
        (14, {}, None),
    ])
    # arremessador: ergue a pedra com os dois braços (pose segura) e joga
    erguido = {"BracoE": [(X, -150), (Y, 22)], "BracoD": [(X, -150), (Y, -22)],
               "Tronco": [(X, -8)], "Cabeca": [(X, -6)]}
    _acao(esq, "erguer", [(0, {}, None), (6, erguido, {"Quadril": (0, 0, 0.01)})])
    _acao(esq, "arremessar", [
        (0, erguido, {"Quadril": (0, 0, 0.01)}),
        (4, {"BracoE": [(X, -60)], "BracoD": [(X, -60)], "Tronco": [(X, 18)], "Cabeca": [(X, 6)],
             "PernaD": [(X, -14)], "PernaE": [(X, 8)]}, {"Quadril": (0, 0, -0.015)}),
        (12, {}, None),
    ])
    _acao(esq, "dano", [
        (0, {}, None),
        (2, {"Tronco": [(X, -20)], "Cabeca": [(X, -14)], "BracoE": [(X, 25), (Y, -20)],
             "BracoD": [(X, 25), (Y, 20)]}, {"Quadril": (0, 0.03, 0)}),
        (8, {}, None),
    ])


def anim_minotauro(esq):
    """Pose T no repouso: toda pose parte de BASE (braços abaixados).
    Lado esquerdo = +X. Braço esquerdo desce com +Y, o direito com -Y;
    antebraço vai para a frente com -Z (esq) / +Z (dir)."""
    BASE = {"BracoE": [(Y, 72)], "BracoD": [(Y, -72)],
            "AntebracoE": [(Z, -12)], "AntebracoD": [(Z, 12)],
            "MaoD": [(Z, 40)]}  # inclina o machado para cima

    def P(**extra):
        d = {k: list(v) for k, v in BASE.items()}
        for k, v in extra.items():
            d[k] = d.get(k, []) + v
        return d

    # parado: respiração pesada, machado na mão
    resp = lambda f, k: (f, P(Peito=[(X, -2 * k)], Cabeca=[(X, 3 * k)],
                              BracoE=[(Y, -3 * k)], BracoD=[(Y, 3 * k)]),
                         {"Quadril": (0, 0, -0.005 * abs(k))})
    _acao(esq, "parado", [resp(0, 1), resp(18, -1), resp(36, 1)], True)

    # andar: passos pesados
    def passo(f, s):
        return (f, P(CoxaE=[(X, -28 * s)], CoxaD=[(X, 28 * s)],
                     CanelaE=[(X, 8 if s > 0 else 30)], CanelaD=[(X, 30 if s > 0 else 8)],
                     BracoE=[(X, 18 * s)], BracoD=[(X, -12 * s)],
                     Peito=[(Z, 6 * s), (X, 6)], Cabeca=[(Z, -4 * s)]),
                {"Quadril": (0, 0, -0.01)})

    def apoio(f):
        return (f, P(Peito=[(X, 6)], CanelaE=[(X, 10)], CanelaD=[(X, 10)]), {"Quadril": (0, 0, 0.012)})

    _acao(esq, "andar", [passo(0, 1), apoio(6), passo(12, -1), apoio(18), passo(24, 1)], True)

    # correr (investida): inclinado, chifres para a frente, braços bombeando
    def corrida(f, s):
        return (f, P(CoxaE=[(X, -55 * s)], CoxaD=[(X, 50 * s)],
                     CanelaE=[(X, 15 if s > 0 else 80)], CanelaD=[(X, 80 if s > 0 else 15)],
                     BracoE=[(X, 40 * s)], BracoD=[(X, -40 * s)],
                     AntebracoE=[(Z, -55)], AntebracoD=[(Z, 55)],
                     Coluna=[(X, 12)], Peito=[(X, 18), (Z, 8 * s)], Cabeca=[(X, 28)]),
                {"Quadril": (0, -0.02, -0.02)})

    def voo(f):
        return (f, P(Coluna=[(X, 12)], Peito=[(X, 18)], Cabeca=[(X, 28)],
                     CanelaE=[(X, 40)], CanelaD=[(X, 40)], AntebracoE=[(Z, -55)], AntebracoD=[(Z, 55)]),
                {"Quadril": (0, -0.02, 0.025)})

    _acao(esq, "correr", [corrida(0, 1), voo(4), corrida(8, -1), voo(12), corrida(16, 1)], True)

    # rugir (entrada na arena): peito estufado, braços flexionados
    def ruge(f, k):
        return (f, {"BracoE": [(Y, -20 + 4 * k)], "BracoD": [(Y, 20 - 4 * k)],
                    "AntebracoE": [(Y, -85)], "AntebracoD": [(Y, 85)],
                    "Peito": [(X, -14 + 2 * k)], "Cabeca": [(X, -28 + 3 * k)],
                    "CoxaE": [(Y, -6)], "CoxaD": [(Y, 6)]}, {"Quadril": (0, 0, -0.01)})

    _acao(esq, "rugir", [ruge(0, 1), ruge(3, -1), ruge(6, 1), ruge(9, -1), ruge(12, 1)], True)

    # mirar: abaixa os chifres e cava o chão com o casco
    def cava(f, k):
        return (f, P(Peito=[(X, 22)], Coluna=[(X, 8)], Cabeca=[(X, 35)],
                     BracoE=[(X, -15)], BracoD=[(X, -15)],
                     CoxaE=[(X, -10)], CanelaE=[(X, 25)],
                     CoxaD=[(X, -20 if k > 0 else 18)], CanelaD=[(X, 40 if k > 0 else 10)]),
                {"Quadril": (0, 0, -0.03)})

    _acao(esq, "mirar", [cava(0, 1), cava(6, -1), cava(12, 1)], True)

    # erguer o machado por cima da cabeça (segura no fim)
    alto = P(BracoD=[(X, -175)], AntebracoD=[(Z, -70)], Peito=[(X, -14), (Z, -10)],
             Cabeca=[(X, -8)], BracoE=[(X, -20)])
    _acao(esq, "erguer", [(0, P(), None), (14, alto, {"Quadril": (0, 0, 0.01)})])
    # golpe: desce com tudo (segura a pose baixa)
    baixo = P(BracoD=[(X, -55)], AntebracoD=[(Z, -5)], MaoD=[(Z, -95)], Peito=[(X, 28), (Z, 10)], Coluna=[(X, 10)],
              Cabeca=[(X, 18)], BracoE=[(X, 20)], CoxaD=[(X, -25)], CanelaD=[(X, 30)],
              CoxaE=[(X, 15)], CanelaE=[(X, 20)])
    _acao(esq, "golpe", [(0, alto, {"Quadril": (0, 0, 0.01)}), (4, baixo, {"Quadril": (0, 0, -0.05)}),
                         (8, baixo, {"Quadril": (0, 0, -0.05)})])
    # atordoado: curvado, cabeça balançando
    tonto = lambda f, k: (f, P(Peito=[(X, 30), (Z, 8 * k)], Coluna=[(X, 10)], Cabeca=[(X, 30), (Y, 14 * k)],
                               BracoE=[(X, -15)], BracoD=[(X, -15)], AntebracoE=[(Z, -10)], AntebracoD=[(Z, 10)],
                               CoxaE=[(X, -15)], CoxaD=[(X, -15)], CanelaE=[(X, 30)], CanelaD=[(X, 30)]),
                          {"Quadril": (0, 0, -0.035)})
    _acao(esq, "atordoado", [tonto(0, 1), tonto(14, -1), tonto(28, 1)], True)
    # frear: joga o corpo para trás e finca os cascos
    _acao(esq, "frear", [(0, P(), None), (5, P(Peito=[(X, -24)], Cabeca=[(X, -14)],
                                              CoxaE=[(X, -40)], CoxaD=[(X, -30)], CanelaE=[(X, 20)], CanelaD=[(X, 35)],
                                              BracoE=[(X, 35), (Y, -25)], BracoD=[(X, 35), (Y, 25)]),
                                            {"Quadril": (0, 0.02, -0.04)})])
    # morrer: cai de joelhos e tomba para a frente
    joelhos = P(CoxaE=[(X, -85)], CoxaD=[(X, -85)], CanelaE=[(X, 95)], CanelaD=[(X, 95)],
                Peito=[(X, 15)], Cabeca=[(X, 20)], BracoE=[(X, -10)], BracoD=[(X, -10)])
    tombado = P(CoxaE=[(X, -85)], CoxaD=[(X, -85)], CanelaE=[(X, 95)], CanelaD=[(X, 95)],
                Coluna=[(X, 25)], Peito=[(X, 45)], Cabeca=[(X, 25)], BracoE=[(X, -60)], BracoD=[(X, -60)])
    _acao(esq, "morrer", [(0, P(), None), (10, joelhos, {"Quadril": (0, 0, -0.14)}),
                          (16, joelhos, {"Quadril": (0, 0, -0.14)}), (28, tombado, {"Quadril": (0, -0.04, -0.16)})])


def anim_ariadne(esq):
    respira = lambda f, k: (f, {
        "Tronco": [(X, -1.5 * k), (Y, 1.5 * k)], "Cabeca": [(Y, 4 * k), (X, 2 * k)],
        "BracoE": [(Y, -4 - 2 * k)], "BracoD": [(Y, 4 + 2 * k)],
    }, {"Quadril": (0, 0, -0.005 * abs(k))})
    _acao(esq, "parado", [respira(0, 1), respira(18, -1), respira(36, 1)], True)

    def passo(f, s):
        return (f, {"PernaE": [(X, -14 * s)], "PernaD": [(X, 14 * s)],
                    "BracoE": [(X, 14 * s), (Y, -4)], "BracoD": [(X, -14 * s), (Y, 4)],
                    "Tronco": [(Z, 4 * s)], "Cabeca": [(Z, -3 * s)]}, None)

    def meio(f):
        return (f, {"BracoE": [(Y, -4)], "BracoD": [(Y, 4)]}, {"Quadril": (0, 0, 0.012)})

    _acao(esq, "andar", [passo(0, 1), meio(5), passo(10, -1), meio(15), passo(20, 1)], True)
    # joga o novelo para o Teseu (braço esquerdo, de baixo para cima)
    _acao(esq, "arremessar", [
        (0, {}, None),
        (5, {"BracoE": [(X, 40)], "Tronco": [(X, -6), (Z, -6)]}, None),
        (9, {"BracoE": [(X, -110)], "Tronco": [(X, 8), (Z, 5)], "Cabeca": [(X, 3)]}, None),
        (18, {}, None),
    ])


# ==========================================================================
# 4) Textura do arremessador (mesmo modelo, outras cores)
# ==========================================================================
def recolorir_arremessador(img):
    """Pelo marrom -> marrom-acinzentado escuro; roupa vermelha -> azul.
    Faz a troca em HSV, pixel a pixel (numpy)."""
    import numpy as np
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    rgb = px[..., :3]
    mx = rgb.max(-1)
    mn = rgb.min(-1)
    d = mx - mn + 1e-6
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    hue = np.where(mx == r, ((g - b) / d) % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4)) * 60.0
    sat = np.where(mx > 0, d / (mx + 1e-6), 0)
    val = mx
    vermelho = ((hue < 14) | (hue > 340)) & (sat > 0.55) & (val > 0.3)
    pelo = (hue >= 10) & (hue < 40) & (sat > 0.35) & (val < 0.75) & ~vermelho
    novo = rgb.copy()
    # roupa: vermelho -> azul (mantém o brilho)
    azul = np.stack([val * 0.22, val * 0.42, val * 0.95], -1)
    novo[vermelho] = azul[vermelho]
    # pelo: escurece e tira saturação
    cinza = rgb.mean(-1, keepdims=True)
    escuro = (rgb * 0.45 + cinza * 0.55) * 0.68
    novo[pelo] = escuro[pelo]
    px[..., :3] = novo
    img.pixels[:] = px.ravel()
    img.update()


# ==========================================================================
# Montagem
# ==========================================================================
def montar(nome):
    bpy.ops.wm.open_mainfile(filepath=os.path.join(PASTA_FONTES, nome + "_base.blend"))
    for o in list(bpy.data.objects):
        if o.name != "Corpo":
            bpy.data.objects.remove(o)
    corpo = bpy.data.objects["Corpo"]
    bpy.context.scene.render.fps = FPS
    esq = criar_esqueleto(nome)
    if nome.startswith("minitaurinho"):
        pintar_pesos(corpo, esq, nome)
        clava(esq)
        anim_minitaurinho(esq)
    elif nome.startswith("minotauro"):
        pintar_pesos_calor(corpo, esq, nome)
        machado(esq)
        anim_minotauro(esq)
    else:
        pintar_pesos_calor(corpo, esq, nome)
        anim_ariadne(esq)
    # deixa a ação "parado" como padrão (aparece no Blender e no Godot)
    esq.animation_data.action = bpy.data.actions["parado"]
    bpy.context.scene.frame_set(0)
    os.makedirs(PASTA_GLB, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(PASTA_FONTES, nome + ".blend"), compress=True)
    _exportar(os.path.join(PASTA_GLB, nome + ".glb"))
    if nome.startswith("minitaurinho"):
        bpy.data.objects.remove(bpy.data.objects["Clava"])
        img = corpo.data.materials[0].node_tree.nodes
        img = [n for n in img if n.type == "TEX_IMAGE"][0].image
        recolorir_arremessador(img)
        img.name = nome + "_arremessador_cor"
        img.pack()
        corpo.data.materials[0].name = nome + "_arremessador"
        _exportar(os.path.join(PASTA_GLB, nome + "_arremessador.glb"))


def _exportar(caminho):
    bpy.ops.export_scene.gltf(
        filepath=caminho,
        export_format="GLB",
        export_yup=True,
        export_animations=True,
        export_animation_mode="ACTIONS",
        export_force_sampling=True,
        export_frame_range=False,
        export_def_bones=False,
        export_cameras=False,
        export_lights=False,
        export_image_format="JPEG",
        export_jpeg_quality=88,
    )
    print("exportado:", caminho)


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    if args[0] == "otimizar":
        otimizar(args[1], args[2])
    elif args[0] == "montar":
        montar(args[1])
