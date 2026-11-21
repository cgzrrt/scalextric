@tool
extends Node3D

@export var largo_objetivo: float = 2.0 # Todos los coches medirán exactamente 2 metros de largo
@export var centrar_y_apoyar_en_suelo: bool = true
@export var ajustar_ahora: bool = false:
	set(valor):
		if valor:
			_normalizar_tamano()

func _normalizar_tamano() -> void:
	scale = Vector3.ONE
	position = Vector3.ZERO
	
	var mallas: Array[MeshInstance3D] = []
	var nodo_raiz: Node = self
	if nodo_raiz is MeshInstance3D:
		mallas.append(nodo_raiz)
	for hijo in find_children("*", "MeshInstance3D", true, false):
		mallas.append(hijo as MeshInstance3D)
		
	if mallas.is_empty():
		push_warning("No se encontró ninguna malla 3D dentro de este nodo.")
		return

	# Calculamos el tamaño real respecto a este nodo padre
	var aabb_total := AABB()
	var primero := true
	var inv_transform := global_transform.affine_inverse()

	for m in mallas:
		if not m.mesh:
			continue
		var transform_local := inv_transform * m.global_transform
		var aabb_malla := transform_local * m.get_aabb()
		if primero:
			aabb_total = aabb_malla
			primero = false
		else:
			aabb_total = aabb_total.merge(aabb_malla)

	# Tomamos la medida horizontal más larga (funciona aunque el modelo venga girado 90 grados)
	var largo_actual := maxf(aabb_total.size.x, aabb_total.size.z)
	
	if largo_actual > 0.0001:
		var factor := largo_objetivo / largo_actual
		scale = Vector3.ONE * factor
		
		if centrar_y_apoyar_en_suelo:
			var centro := aabb_total.get_center() * factor
			var base_y := aabb_total.position.y * factor
			# Centra en X y Z, y deja la base de las ruedas tocando Y = 0
			position = Vector3(-centro.x, -base_y, -centro.z)
			
		print("¡Listo! Modelo escalado a ", largo_objetivo, "m (Factor: ", snapped(factor, 0.001), ")")
