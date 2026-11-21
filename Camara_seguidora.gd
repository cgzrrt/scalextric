extends Camera3D

@export var objetivo: SlotCarController
@export var distancia: Vector3 = Vector3(0.0, 5.0, 8.0)
@export var suavizado_movimiento: float = 10.0
@export var suavizado_rotacion: float = 12.0

func _physics_process(delta: float) -> void:
	if not objetivo:
		return

	# Si el coche ha descarrilado, la cámara se queda completamente quieta donde estaba
	if objetivo.esta_descarrilado:
		var mirar_coche := global_transform.looking_at(objetivo.global_position, Vector3.UP)
		global_transform.basis = global_transform.basis.slerp(mirar_coche.basis, suavizado_rotacion * delta)
		return

	var pos_deseada := objetivo.to_global(distancia)
	global_position = global_position.lerp(pos_deseada, suavizado_movimiento * delta)

	var xform_deseada := global_transform.looking_at(objetivo.global_position, Vector3.UP)
	global_transform.basis = global_transform.basis.slerp(xform_deseada.basis, suavizado_rotacion * delta)
