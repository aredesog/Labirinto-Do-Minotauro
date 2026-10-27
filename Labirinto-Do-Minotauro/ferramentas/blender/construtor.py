"""
Biblioteca de construção de modelos low-poly "de brinquedo" para o
Labirinto do Minotauro.

Convenções (iguais para todos os modelos):
  - 1 unidade do Blender = 1 metro no Godot.
  - Origem no centro da base (z = 0 é o chão).
  - Frente do objeto voltada para -Y no Blender (vira +Z no Godot).
  - Bordas arredondadas por modificador Bevel (aplicado na exportação).
"""

import math

import bpy  # precisa vir antes de bmesh/mathutils quando bpy é usado como módulo
import bmesh
from mathutils import Matrix, Vector


# --------------------------------------------------------------------------
# Paleta (as mesmas cores das folhas de modelo)
# --------------------------------------------------------------------------
PALETA = {
    "pedra_piso": "#cbb68e",
    "pedra_junta": "#a8916b",
    "pedra_clara": "#dccaa5",
    "parede": "#9b8cb0",
    "parede_escura": "#7a6a90",
    "parede_borda": "#b8acc9",
    "marmore": "#ece4d3",
    "marmore_sombra": "#cfc5b0",
    "estatua": "#a9a39a",
    "estatua_escura": "#837d74",
    "terracota": "#c46a3a",
    "preto_vaso": "#2e211b",
    "bronze": "#c9923a",
    "bronze_escuro": "#8a5f22",
    "madeira": "#8a6033",
    "ferro": "#6f6a78",
    "ouro": "#e8b93e",
    "brasa": "#e0542c",
    "chama": "#f2a43a",
    "cristal": "#7fd6ff",
    "espelho": "#e6eaf0",
    "osso": "#f2ead6",
    "pele": "#f2c49b",
    "cabelo": "#4a2e1e",
    "tunica": "#f4ecd8",
    "faixa": "#b8342c",
    "couro": "#8a5a2b",
}


def hex_para_linear(h):
    h = h.lstrip("#")
    srgb = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    lin = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in srgb]
    return (*lin, 1.0)


_cache_materiais = {}

# Pedra e paredes são foscas (senão o piso inteiro reflete o sol na câmera);
# objetos e personagens ficam com brilho de plástico (0.38).
RUGOSIDADE_PADRAO = {
    "pedra_piso": 0.85, "pedra_junta": 0.9, "pedra_clara": 0.85,
    "parede": 0.8, "parede_escura": 0.85, "parede_borda": 0.75,
    "marmore": 0.55, "marmore_sombra": 0.65, "terracota": 0.55, "madeira": 0.7,
}


def material(nome, cor=None, rugosidade=None, metal=0.0, emissao=0.0):
    """Material Principled BSDF com aspecto plástico (estilo brinquedo)."""
    if rugosidade is None:
        rugosidade = RUGOSIDADE_PADRAO.get(nome, 0.38)
    if nome in _cache_materiais and _cache_materiais[nome].name in bpy.data.materials:
        return _cache_materiais[nome]
    cor = cor or PALETA[nome]
    m = bpy.data.materials.new(nome)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    rgba = hex_para_linear(cor)
    bsdf.inputs["Base Color"].default_value = rgba
    bsdf.inputs["Roughness"].default_value = rugosidade
    bsdf.inputs["Metallic"].default_value = metal
    bsdf.inputs["Specular IOR Level"].default_value = 0.35 if rugosidade > 0.6 else 0.5
    if emissao > 0:
        bsdf.inputs["Emission Color"].default_value = rgba
        bsdf.inputs["Emission Strength"].default_value = emissao
    m.diffuse_color = rgba
    _cache_materiais[nome] = m
    return m


def limpar_cena():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _cache_materiais.clear()


# --------------------------------------------------------------------------
# Peça: acumula várias formas (com materiais) numa única malha
# --------------------------------------------------------------------------
class Peca:
    def __init__(self, nome):
        self.nome = nome
        self.bm = bmesh.new()
        self.materiais = []

    def _indice(self, mat):
        if mat not in self.materiais:
            self.materiais.append(mat)
        return self.materiais.index(mat)

    def _juntar(self, bm_parte, mat, matriz=None):
        if matriz is not None:
            bmesh.ops.transform(bm_parte, matrix=matriz, verts=bm_parte.verts)
        idx = self._indice(mat)
        for f in bm_parte.faces:
            f.material_index = idx
        malha = bpy.data.meshes.new("tmp")
        bm_parte.to_mesh(malha)
        bm_parte.free()
        self.bm.from_mesh(malha)
        bpy.data.meshes.remove(malha)

    # -- formas básicas --------------------------------------------------
    def caixa(self, mat, tam, pos=(0, 0, 0), rot=(0, 0, 0)):
        """Caixa com tamanho (x, y, z); pos é o centro da caixa."""
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        m = (Matrix.Translation(pos) @ euler(rot) @ Matrix.Diagonal((*tam, 1.0)))
        self._juntar(bm, mat, m)

    def cilindro(self, mat, raio, altura, pos=(0, 0, 0), rot=(0, 0, 0),
                 lados=24, raio_topo=None):
        """Cilindro (ou cone) com a base em pos (cresce em +Z local)."""
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=lados,
                              radius1=raio,
                              radius2=raio if raio_topo is None else raio_topo,
                              depth=altura)
        m = Matrix.Translation(pos) @ euler(rot) @ Matrix.Translation((0, 0, altura / 2))
        self._juntar(bm, mat, m)

    def esfera(self, mat, raio, pos=(0, 0, 0), escala=(1, 1, 1), rot=(0, 0, 0),
               segs=24, aneis=14):
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=aneis, radius=raio)
        m = Matrix.Translation(pos) @ euler(rot) @ Matrix.Diagonal((*escala, 1.0))
        self._juntar(bm, mat, m)

    def torno(self, mat, perfil, pos=(0, 0, 0), lados=28, rot=(0, 0, 0),
              fechar_base=True, fechar_topo=True):
        """Sólido de revolução a partir de uma lista de (raio, z)."""
        bm = bmesh.new()
        aneis = []
        for r, z in perfil:
            anel = []
            for i in range(lados):
                a = 2 * math.pi * i / lados
                anel.append(bm.verts.new((r * math.cos(a), r * math.sin(a), z)))
            aneis.append(anel)
        for a0, a1 in zip(aneis, aneis[1:]):
            for i in range(lados):
                j = (i + 1) % lados
                bm.faces.new((a0[i], a0[j], a1[j], a1[i]))
        if fechar_base:
            bm.faces.new(list(reversed(aneis[0])))
        if fechar_topo:
            bm.faces.new(aneis[-1])
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        m = Matrix.Translation(pos) @ euler(rot)
        self._juntar(bm, mat, m)

    def toro(self, mat, raio_maior, raio_menor, pos=(0, 0, 0), rot=(0, 0, 0),
             arco=360.0, lados=24, lados_tubo=10):
        bm = bmesh.new()
        n = lados if arco >= 360 else lados + 1
        aneis = []
        for i in range(n):
            u = math.radians(arco) * i / lados
            anel = []
            for k in range(lados_tubo):
                v = 2 * math.pi * k / lados_tubo
                x = (raio_maior + raio_menor * math.cos(v)) * math.cos(u)
                y = (raio_maior + raio_menor * math.cos(v)) * math.sin(u)
                z = raio_menor * math.sin(v)
                anel.append(bm.verts.new((x, y, z)))
            aneis.append(anel)
        pares = list(zip(aneis, aneis[1:]))
        if arco >= 360:
            pares.append((aneis[-1], aneis[0]))
        for a0, a1 in pares:
            for k in range(lados_tubo):
                kk = (k + 1) % lados_tubo
                bm.faces.new((a0[k], a1[k], a1[kk], a0[kk]))
        if arco < 360:
            bm.faces.new(list(reversed(aneis[0])))
            bm.faces.new(aneis[-1])
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        self._juntar(bm, mat, Matrix.Translation(pos) @ euler(rot))

    def tubo(self, mat, pontos, raio, lados=10, pos=(0, 0, 0), rot=(0, 0, 0),
             raio_final=None):
        """Tubo que segue uma lista de pontos 3D (chifres, ossos, ondas)."""
        bm = bmesh.new()
        pts = [Vector(p) for p in pontos]
        n = len(pts)
        aneis = []
        for i, p in enumerate(pts):
            t = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized()
            ref = Vector((0, 0, 1)) if abs(t.z) < 0.9 else Vector((1, 0, 0))
            b1 = t.cross(ref).normalized()
            b2 = t.cross(b1).normalized()
            r = raio if raio_final is None else raio + (raio_final - raio) * i / (n - 1)
            anel = []
            for k in range(lados):
                a = 2 * math.pi * k / lados
                anel.append(bm.verts.new(p + (b1 * math.cos(a) + b2 * math.sin(a)) * r))
            aneis.append(anel)
        for a0, a1 in zip(aneis, aneis[1:]):
            for k in range(lados):
                kk = (k + 1) % lados
                bm.faces.new((a0[k], a0[kk], a1[kk], a1[k]))
        bm.faces.new(list(reversed(aneis[0])))
        bm.faces.new(aneis[-1])
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        self._juntar(bm, mat, Matrix.Translation(pos) @ euler(rot))

    def prisma(self, mat, contorno, altura, pos=(0, 0, 0), rot=(0, 0, 0)):
        """Extruda um polígono 2D (lista de (x, y)) em +Z."""
        bm = bmesh.new()
        base = [bm.verts.new((x, y, 0)) for x, y in contorno]
        topo = [bm.verts.new((x, y, altura)) for x, y in contorno]
        bm.faces.new(list(reversed(base)))
        bm.faces.new(topo)
        k = len(contorno)
        for i in range(k):
            j = (i + 1) % k
            bm.faces.new((base[i], base[j], topo[j], topo[i]))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        self._juntar(bm, mat, Matrix.Translation(pos) @ euler(rot))

    # -- finalização ------------------------------------------------------
    def criar(self, bevel=0.02, segmentos=2, suave=True, pai=None, pos=(0, 0, 0)):
        bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts, dist=1e-5)
        malha = bpy.data.meshes.new(self.nome)
        self.bm.to_mesh(malha)
        self.bm.free()
        for m in self.materiais:
            malha.materials.append(m)
        obj = bpy.data.objects.new(self.nome, malha)
        bpy.context.scene.collection.objects.link(obj)
        if suave:
            malha.shade_smooth()
        if bevel > 0:
            mod = obj.modifiers.new("Bevel", "BEVEL")
            mod.width = bevel
            mod.segments = segmentos
            mod.limit_method = "ANGLE"
            mod.angle_limit = math.radians(35)
            mod.harden_normals = True
            mod.use_clamp_overlap = True
        obj.location = pos
        if pai is not None:
            obj.parent = pai
        return obj


def euler(rot):
    rx, ry, rz = (math.radians(a) for a in rot)
    return (Matrix.Rotation(rz, 4, "Z") @ Matrix.Rotation(ry, 4, "Y")
            @ Matrix.Rotation(rx, 4, "X"))


def vazio(nome, pos=(0, 0, 0), pai=None):
    """Empty: vira um Node3D no Godot (ponto de referência / pivô)."""
    obj = bpy.data.objects.new(nome, None)
    obj.empty_display_size = 0.2
    obj.location = pos
    bpy.context.scene.collection.objects.link(obj)
    if pai is not None:
        obj.parent = pai
    return obj


def raiz(nome):
    return vazio(nome)


def exportar(nome, pasta_glb, pasta_blend):
    import os
    os.makedirs(pasta_glb, exist_ok=True)
    os.makedirs(pasta_blend, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(pasta_blend, nome + ".blend"))
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(pasta_glb, nome + ".glb"),
        export_format="GLB",
        export_apply=True,
        export_yup=True,
        export_animations=False,
        export_cameras=False,
        export_lights=False,
    )
