extends RigidBody3D
class_name SlotCarController

@export_group("Referencias")
@export var guia_carril: PathFollow3D
@export var label_velocimetro: Label3D

@export_group("Controles")
@export var accion_acelerar: StringName = &"acelerar_j1"

@export_group("Estadísticas del Coche")
@export var velocidad_maxima: float = 25.0
@export var aceleracion: float = 15.0
@export var frenado_inercia: float = 10.0
@export var limite_agarre: float = 180.0
@export var tolerancia_derrape: float = 0.12

@export_group("Penalización")
@export var tiempo_penalizacion: float = 3.0
@export var fuerza_desvio_derecha: float = 4.0

var velocidad_actual: float = 0.0
var esta_descarrilado: bool = false
var tiempo_sobrepasando_limite: float = 0.0
var _curva: Curve3D
var _longitud_pista: float = 0.0

func _ready() -> void:
	freeze = true
	if guia_carril and guia_carril.get_parent() is Path3D:
		var path := guia_carril.get_parent() as Path3D
		_curva = path.curve
		_longitud_pista = _curva.get_baked_length()
		guia_carril.progress = 0.0
		global_transform = guia_carril.global_transform

func _physics_process(delta: float) -> void:
	_actualizar_velocimetro()

	if esta_descarrilado or not guia_carril:
		return

	_gestionar_aceleracion(delta)
	_mover_por_carril(delta)
	_comprobar_descarrilamiento(delta)

func _gestionar_aceleracion(delta: float) -> void:
	if Input.is_action_pressed(accion_acelerar):
		velocidad_actual = move_toward(velocidad_actual, velocidad_maxima, aceleracion * delta)
	else:
		velocidad_actual = move_toward(velocidad_actual, 0.0, frenado_inercia * delta)

func _mover_por_carril(delta: float) -> void:
	# PathFollow3D avanza directamente en metros reales
	guia_carril.progress += velocidad_actual * delta
	global_transform = guia_carril.global_transform

func _comprobar_descarrilamiento(delta: float) -> void:
	if velocidad_actual < 2.0 or not _curva:
		tiempo_sobrepasando_limite = 0.0
		return

	var prog_actual := guia_carril.progress
	var prog_atras := fposmod(prog_actual - 0.5, _longitud_pista)
	var prog_adelante := fposmod(prog_actual + 0.5, _longitud_pista)

	# -basis.z es el vector "hacia adelante" en Godot
	var dir_atras := -_curva.sample_baked_with_rotation(prog_atras).basis.z
	var dir_adelante := -_curva.sample_baked_with_rotation(prog_adelante).basis.z

	var angulo_curva := rad_to_deg(dir_atras.angle_to(dir_adelante))
	var fuerza_centrifuga := (velocidad_actual * velocidad_actual) * angulo_curva * 0.05

	if fuerza_centrifuga > limite_agarre:
		tiempo_sobrepasando_limite += delta
		if tiempo_sobrepasando_limite >= tolerancia_derrape:
			tiempo_sobrepasando_limite = 0.0
			_iniciar_descarrilamiento()
	else:
		tiempo_sobrepasando_limite = move_toward(tiempo_sobrepasando_limite, 0.0, delta * 2.0)

func _iniciar_descarrilamiento() -> void:
	esta_descarrilado = true
	
	# Levantamos unos milímetros para evitar roce con el suelo y activamos físicas
	global_position += Vector3.UP * 0.15
	freeze = false

	var forward := -global_transform.basis.z
	var right := global_transform.basis.x

	# Impulso hacia adelante + desvío leve a la derecha + pequeño salto
	linear_velocity = (forward * velocidad_actual * 0.8) + (right * fuerza_desvio_derecha) + (Vector3.UP * 1.5)
	angular_velocity = Vector3(0.0, 2.5, 0.0)

	# Esperamos los segundos de penalización
	await get_tree().create_timer(tiempo_penalizacion).timeout

	# Devolvemos el coche congelado a su carril
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	freeze = true
	velocidad_actual = 0.0
	global_transform = guia_carril.global_transform
	
	esta_descarrilado = false

func _actualizar_velocimetro() -> void:
	if not label_velocimetro:
		return
	var vel_visual := 0.0 if esta_descarrilado else velocidad_actual
	var kmh := roundi(vel_visual * 1.0)
	label_velocimetro.text = str(kmh) + " KM/H"
	
	var porcentaje := vel_visual / velocidad_maxima
	label_velocimetro.modulate = Color.WHITE.lerp(Color.RED, porcentaje)
