extends RigidBody3D
class_name SlotCarController

@export_group("Referencias")

# Path follow que existe
@export var guia_carril: PathFollow3D
@export var label_velocimetro: Label3D

# para que no salga uno encima de otro
@export var progreso_inicial: float = 0.0

@export_group("Apariencia")

@export var modelo: PackedScene
@export var malla_carroceria: Mesh
@export var tenir := false
@export var color: Color = Color.WHITE

# ajustar el tamaño
@export var normalizar_tamano := true
@export var largo_objetivo: float = 2.0
@export var centrar_y_apoyar_en_suelo := true

# ajuste manual
@export var escala_modelo: float = 1.0
@export var offset_modelo := Vector3.ZERO
@export_range(-180.0, 180.0, 90.0) var rotacion_y_modelo: float = 0.0

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
	_aplicar_apariencia() # cargar el coche con la apariencia
	if guia_carril and guia_carril.get_parent() is Path3D:
		var path := guia_carril.get_parent() as Path3D
		_curva = path.curve
		_longitud_pista = _curva.get_baked_length()
		guia_carril.progress = progreso_inicial
		global_transform = guia_carril.global_transform

# cambia el modelo de esta instancia
func _aplicar_apariencia() -> void:
	var carroceria := get_node_or_null("Carroceria") as MeshInstance3D
	var visual: Node3D = null

	if modelo:
		if carroceria:
			carroceria.visible = false
		visual = Node3D.new()
		visual.name = "ModeloVisual"
		add_child(visual)
		visual.add_child(modelo.instantiate())
	elif carroceria:
		if malla_carroceria:
			carroceria.mesh = malla_carroceria
		visual = carroceria

	if visual == null:
		return

	if normalizar_tamano:
		_normalizar_tamano(visual)
	elif modelo or malla_carroceria:
		visual.position = offset_modelo
		visual.rotation_degrees.y = rotacion_y_modelo
		visual.scale = Vector3.ONE * escala_modelo

	if tenir:
		_tenir_recursivo(visual)

# escala la raiz para que sea como largo_obbjetivo
func _normalizar_tamano(raiz: Node3D) -> void:
	raiz.transform = Transform3D.IDENTITY

	var mallas: Array[MeshInstance3D] = []
	if raiz is MeshInstance3D:
		mallas.append(raiz as MeshInstance3D)
	for hijo in raiz.find_children("*", "MeshInstance3D", true, false):
		mallas.append(hijo as MeshInstance3D)

	# Tamaño real del modelo medido en el espacio de "raiz"
	var aabb_total := AABB()
	var primero := true
	var inv_transform := raiz.global_transform.affine_inverse()
	for m in mallas:
		if not m.mesh:
			continue
		var aabb_malla := (inv_transform * m.global_transform) * m.get_aabb()
		if primero:
			aabb_total = aabb_malla
			primero = false
		else:
			aabb_total = aabb_total.merge(aabb_malla)

	if primero:
		push_warning("%s: no se encontró ninguna malla para ajustar el tamaño." % name)
		return

	# La medida horizontal más larga funciona aunque el modelo venga girado 90 grados
	var largo_actual := maxf(aabb_total.size.x, aabb_total.size.z)
	if largo_actual <= 0.0001:
		return

	var factor := largo_objetivo / largo_actual
	var giro := Basis(Vector3.UP, deg_to_rad(rotacion_y_modelo))
	raiz.basis = giro * Basis.from_scale(Vector3.ONE * factor)

	var pos := offset_modelo
	if centrar_y_apoyar_en_suelo:
		var centro := giro * (aabb_total.get_center() * factor)
		# Centra en X y Z, y deja la base de las ruedas tocando Y = 0
		pos += Vector3(-centro.x, -aabb_total.position.y * factor, -centro.z)
	raiz.position = pos

func _tenir_recursivo(nodo: Node) -> void:
	if nodo is MeshInstance3D:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		(nodo as MeshInstance3D).material_override = mat
	for hijo in nodo.get_children():
		_tenir_recursivo(hijo)

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

	# -basis.z es el vector hacia adelante
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
	
	# levantamos unos milímetros para evitar roce con el suelo y activamos físicas
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
