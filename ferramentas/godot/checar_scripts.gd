extends SceneTree
## Compila todos os scripts do projeto e lista erros (godot --headless --script ...).
func _initialize() -> void:
	var erros := 0
	for caminho in _listar("res://scripts"):
		var s := load(caminho)
		if s == null or (s is GDScript and not (s as GDScript).can_instantiate()):
			print("ERRO: ", caminho)
			erros += 1
	print("SCRIPTS CHECADOS, erros = ", erros)
	quit(erros)

func _listar(pasta: String) -> Array:
	var r := []
	for f in DirAccess.get_files_at(pasta):
		if f.ends_with(".gd") or f.ends_with(".gdshader"):
			r.append(pasta + "/" + f)
	for d in DirAccess.get_directories_at(pasta):
		r += _listar(pasta + "/" + d)
	return r
