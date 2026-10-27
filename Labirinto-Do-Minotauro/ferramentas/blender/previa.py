"""Renderiza uma folha de contato com todos os .glb (para conferir o visual)."""
import glob
import math
import os
import sys

import bpy

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SAIDA = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else os.path.join(RAIZ, "previa.png")
FILTRO = sys.argv[sys.argv.index("--") + 2:] if "--" in sys.argv else []

bpy.ops.wm.read_factory_settings(use_empty=True)
cena = bpy.context.scene

arquivos = sorted(glob.glob(os.path.join(RAIZ, "assets", "modelos", "*", "*.glb")))
if FILTRO:
    arquivos = [a for a in arquivos if os.path.basename(a)[:-4] in FILTRO]

colunas = 6 if len(arquivos) > 6 else len(arquivos)
esp = 3.6
for i, caminho in enumerate(arquivos):
    antes = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=caminho)
    novos = [o for o in bpy.data.objects if o not in antes]
    linha, col = divmod(i, colunas)
    for o in novos:
        if o.parent is None:
            o.location.x += col * esp
            o.location.y -= -linha * esp
    # piso de base
    bpy.ops.mesh.primitive_cylinder_add(radius=1.5, depth=0.1,
                                        location=(col * esp, linha * esp, -0.08))
    base = bpy.context.active_object
    mb = bpy.data.materials.get("base_previa") or bpy.data.materials.new("base_previa")
    mb.use_nodes = True
    mb.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.55, 0.5, 0.42, 1)
    base.data.materials.append(mb)

linhas = math.ceil(len(arquivos) / colunas)
cx, cy = (colunas - 1) * esp / 2, (linhas - 1) * esp / 2

cam_dados = bpy.data.cameras.new("cam")
cam_dados.type = "ORTHO"
cam_dados.ortho_scale = max(colunas, linhas * 1.6) * esp * 1.05
cam = bpy.data.objects.new("cam", cam_dados)
cena.collection.objects.link(cam)
cam.location = (cx, cy - 30, 26)
cam.rotation_euler = (math.radians(50), 0, 0)
cena.camera = cam

sol = bpy.data.lights.new("sol", "SUN")
sol.energy = 3.5
sol.angle = math.radians(12)
so = bpy.data.objects.new("sol", sol)
so.rotation_euler = (math.radians(40), math.radians(15), math.radians(-30))
cena.collection.objects.link(so)

mundo = bpy.data.worlds.new("m")
mundo.use_nodes = True
mundo.node_tree.nodes["Background"].inputs[0].default_value = (0.85, 0.82, 0.9, 1)
mundo.node_tree.nodes["Background"].inputs[1].default_value = 0.9
cena.world = mundo

cena.render.engine = "CYCLES"
cena.cycles.device = "CPU"
cena.cycles.samples = 24
cena.cycles.use_denoising = True
cena.render.resolution_x = 1800
cena.render.resolution_y = int(1800 * (linhas * 1.0) / colunas * 0.85) + 200
cena.render.filepath = SAIDA
cena.view_settings.view_transform = "Standard"
bpy.ops.render.render(write_still=True)
print("PREVIA", SAIDA)
