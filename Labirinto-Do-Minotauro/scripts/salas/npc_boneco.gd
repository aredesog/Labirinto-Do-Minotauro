extends Node3D
## NPC (Ariadne): animação "parado" em ciclo; anda e arremessa o novelo
## quando o GerenciadorJogo pede (abertura e final).

var _anim: AnimBoneco
var _modelo: AnimModelo
var andando := 0.0


func _ready() -> void:
	_modelo = AnimModelo.new(self)
	if not _modelo.tem():
		_anim = AnimBoneco.new(self)


func _process(delta: float) -> void:
	if _modelo and _modelo.tem():
		_modelo.atualizar(andando)
	elif _anim:
		_anim.atualizar(delta, andando)


func tocar(nome: String, velocidade := 1.0) -> void:
	if _modelo:
		_modelo.tocar(nome, velocidade)
