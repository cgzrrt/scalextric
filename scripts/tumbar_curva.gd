@tool
extends EditorScript

func _run() -> void:
	var escena := get_scene()
	if not escena:
		return
		
	var eje: Path3D = escena.find_child("EjeCentral", true, false)
	if not eje or not eje.curve:
		push_warning("No se encontró EjeCentral en la escena abierta.")
		return

	var curva := eje.curve
	for i in range(curva.point_count):
		curva.set_point_position(i, _transformar(curva.get_point_position(i)))
		curva.set_point_in(i, _transformar(curva.get_point_in(i)))
		curva.set_point_out(i, _transformar(curva.get_point_out(i)))

	print("Pista girada 90° a la izquierda y reflejada.")

func _transformar(v: Vector3) -> Vector3:
	# 1. Girar 90° a la izquierda (en vista superior X-Z)
	var rotado := Vector3(v.z, v.y, -v.x)
	
	# 2. Espejo horizontal (izquierda <-> derecha). 
	# Si buscabas espejo vertical (arriba <-> abajo), cambia esta línea por: return Vector3(rotado.x, rotado.y, -rotado.z)
	return Vector3(-rotado.x, rotado.y, rotado.z)
