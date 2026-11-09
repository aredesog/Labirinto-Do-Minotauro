class_name AnimBoneco
extends RefCounted
## Animação procedural dos bonecos (Teseu, minitaurinhos, atenienses, Ariadne).
## Os modelos do Blender têm pivôs: Cabeca, BracoE, BracoD, PernaE, PernaD
## (e Cauda no minitaurinho). Aqui eles giram por seno, sem esqueleto:
##   andar  -> pernas e braços balançam em oposição, corpo quica
##   parado -> respiração (cabeça sobe e desce de leve)
## Braços "travados" (escudo, golpe) ficam por conta de quem chamou.
##
## Rotação em X: ângulo negativo leva o membro para a frente (+Z no Godot).

var perna_e: Node3D
var perna_d: Node3D
var braco_e: Node3D
var braco_d: Node3D
var cabeca: Node3D
var cauda: Node3D
var travar_braco_e := false
var travar_braco_d := false

var _t := 0.0
var _cabeca_y := 0.0


func _init(raiz: Node) -> void:
	perna_e = raiz.find_child("PernaE", true, false) as Node3D
	perna_d = raiz.find_child("PernaD", true, false) as Node3D
	braco_e = raiz.find_child("BracoE", true, false) as Node3D
	braco_d = raiz.find_child("BracoD", true, false) as Node3D
	cabeca = raiz.find_child("Cabeca", true, false) as Node3D
	cauda = raiz.find_child("Cauda", true, false) as Node3D
	if cabeca:
		_cabeca_y = cabeca.position.y


func tem_pivos() -> bool:
	return braco_e != null or perna_e != null


## andando: 0 (parado) a 1 (velocidade máxima).
func atualizar(delta: float, andando: float, ciclo := 11.0) -> void:
	_t += delta * (ciclo if andando > 0.05 else 2.2)
	var s := sin(_t)
	var amp := 0.55 * andando
	var k := 1.0 - exp(-14.0 * delta)
	if perna_e:
		perna_e.rotation.x = lerpf(perna_e.rotation.x, s * amp, k)
	if perna_d:
		perna_d.rotation.x = lerpf(perna_d.rotation.x, -s * amp, k)
	if braco_e and not travar_braco_e:
		braco_e.rotation.x = lerpf(braco_e.rotation.x, -s * amp * 0.8, k)
	if braco_d and not travar_braco_d:
		braco_d.rotation.x = lerpf(braco_d.rotation.x, s * amp * 0.8, k)
	if cabeca:
		var quique := absf(s) * 0.025 * andando if andando > 0.05 else sin(_t) * 0.006
		cabeca.position.y = _cabeca_y + quique
	if cauda:
		cauda.rotation.z = sin(_t * 0.8) * (0.25 + andando * 0.3)


## Braço para a frente (ângulo em radianos, negativo = frente).
func posar_braco(braco: Node3D, angulo_x: float, delta: float, vel := 18.0) -> void:
	if braco:
		braco.rotation.x = lerpf(braco.rotation.x, angulo_x, 1.0 - exp(-vel * delta))
