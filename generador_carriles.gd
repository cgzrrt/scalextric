@tool
extends Node3D

@export var eje_central: Path3D
@export var carril_izquierdo: Path3D
@export var carril_derecho: Path3D

@export var separacion_del_centro: float = 1.0:
	set(valor):
		separacion_del_centro = valor
		generar_carriles()

@export var actualizar_ahora: bool = false:
	set(valor):
		generar_carriles()

@export var margen_sobre_suelo: float = 0.05

@export var pegar_al_terreno: bool = false:
	set(valor):
		_ajustar_eje_al_terreno()

func _ajustar_eje_al_terreno() -> void:
	if not eje_central or not eje_central.curve:
		return
	
	var espacio_fisico := get_world_3d().direct_space_state
	var curva := eje_central.curve
	
	for i in range(curva.point_count):
		var pos_global := eje_central.to_global(curva.get_point_position(i))
		# Lanzamos un rayo desde 100 metros arriba hasta 100 metros abajo
		var origen := Vector3(pos_global.x, pos_global.y + 100.0, pos_global.z)
		var destino := Vector3(pos_global.x, pos_global.y - 100.0, pos_global.z)
		
		var consulta := PhysicsRayQueryParameters3D.create(origen, destino)
		var resultado := espacio_fisico.intersect_ray(consulta)
		
		if resultado:
			var nueva_pos_global := Vector3(pos_global.x, resultado.position.y + margen_sobre_suelo, pos_global.z)
			curva.set_point_position(i, eje_central.to_local(nueva_pos_global))
	
	# Regeneramos los carriles automáticamente tras cambiar la altura
	generar_carriles()

func generar_carriles() -> void:
	if not eje_central or not carril_izquierdo or not carril_derecho:
		return
	if not eje_central.curve or eje_central.curve.point_count < 2:
		return

	carril_izquierdo.curve = _crear_curva_desplazada(eje_central.curve, -separacion_del_centro)
	carril_derecho.curve = _crear_curva_desplazada(eje_central.curve, separacion_del_centro)

func _crear_curva_desplazada(original: Curve3D, desplazamiento: float) -> Curve3D:
	var nueva_curva := Curve3D.new()
	var total_puntos := original.point_count
	var longitud := original.get_baked_length()

	for i in range(total_puntos):
		var pos_punto := original.get_point_position(i)
		var offset := original.get_closest_offset(pos_punto)
		var xform := original.sample_baked_with_rotation(offset)
		
		# En Godot, basis.x apunta hacia la derecha
		var dir_derecha := xform.basis.x.normalized()
		var nueva_pos := pos_punto + (dir_derecha * desplazamiento)
		
		nueva_curva.add_point(
			nueva_pos,
			original.get_point_in(i),
			original.get_point_out(i)
		)
	
	# Cerramos la curva si el primer y último punto coinciden
	if total_puntos > 2 and original.get_point_position(0).distance_to(original.get_point_position(total_puntos - 1)) < 0.1:
		nueva_curva.add_point(nueva_curva.get_point_position(0))

	return nueva_curva
