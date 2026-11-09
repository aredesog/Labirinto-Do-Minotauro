class_name AnimModelo
extends RefCounted
## Toca as animações de esqueleto que vêm no .glb (feitas no Blender por
## ferramentas/blender/personagens_grupo.py): "parado" e "andar" em ciclo,
## e ações de uma vez ("atacar", "dano", "arremessar"...), que voltam
## sozinhas para o ciclo quando terminam.

const CICLOS := ["parado", "andar", "correr", "rugir", "mirar", "atordoado"]
const MISTURA := 0.15

var ap: AnimationPlayer
var _acao := ""
var _segurando := false


func _init(raiz: Node) -> void:
	if raiz == null:
		return
	ap = raiz.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap == null:
		return
	for nome in CICLOS:
		if ap.has_animation(nome):
			ap.get_animation(nome).loop_mode = Animation.LOOP_LINEAR
	if ap.has_animation("parado"):
		ap.play("parado")
		# cada boneco começa num ponto diferente do ciclo (não ficam sincronizados)
		ap.seek(randf() * ap.current_animation_length, true)


func tem() -> bool:
	return ap != null


## andando: 0 (parado) a 1 (velocidade máxima).
func atualizar(andando: float) -> void:
	if ap == null or _segurando:
		return
	if _acao != "":
		if ap.is_playing() and ap.current_animation == _acao:
			return
		_acao = ""
	var nome := "andar" if andando > 0.12 else "parado"
	if not ap.has_animation(nome):
		return
	if ap.current_animation != nome:
		ap.play(nome, MISTURA)
	ap.speed_scale = lerpf(0.7, 1.35, clampf(andando, 0.0, 1.0)) if nome == "andar" else 1.0


## Ação de uma vez (volta ao ciclo no fim).
func tocar(nome: String, velocidade := 1.0) -> void:
	if ap == null or not ap.has_animation(nome):
		return
	_segurando = false
	_acao = nome
	ap.speed_scale = 1.0
	ap.play(nome, 0.06, velocidade)


## Toca e fica parado na última pose até chamar liberar() (ex.: pedra erguida).
func segurar(nome: String) -> void:
	tocar(nome)
	_segurando = ap != null and ap.has_animation(nome)


## Troca direto para uma animação (o Minotauro escolhe pela máquina de
## estados). Ciclos repetem; as outras param na última pose.
func trocar(nome: String, velocidade := 1.0, mistura := MISTURA) -> void:
	if ap == null or not ap.has_animation(nome):
		return
	_acao = ""
	_segurando = true
	ap.speed_scale = 1.0
	ap.play(nome, mistura, velocidade)


func liberar() -> void:
	_segurando = false
	_acao = ""
