extends Control

const RUTA_CLASICO := "res://scenes/circuito.tscn"
const RUTA_MONTANAS := "res://scenes/circuito_entre_montanas.tscn"
const RUTA_MONACO := "res://scenes/circuito_monaco_f1.tscn"

var mapa_actual: String = RUTA_CLASICO

@onready var label_seleccionado: Label = $GridContainer/MapaSeleccionado

func _ready() -> void:
	$GridContainer/Circuito_Clasico.pressed.connect(_elegir_mapa.bind(RUTA_CLASICO, "Circuito Clásico"))
	$GridContainer/Circuito_Montanas.pressed.connect(_elegir_mapa.bind(RUTA_MONTANAS, "Circuito entre Montañas"))
	$GridContainer/Circuito_Monaco_f1.pressed.connect(_elegir_mapa.bind(RUTA_MONACO, "Circuito Monaco F1"))
	$GridContainer/Jugar.pressed.connect(_on_jugar_pressed)
	$GridContainer/Volver.pressed.connect(_on_volver_pressed)

func _elegir_mapa(ruta: String, nombre: String) -> void:
	mapa_actual = ruta
	label_seleccionado.text = "Seleccionado: " + nombre

func _on_jugar_pressed() -> void:
	get_tree().change_scene_to_file(mapa_actual)

func _on_volver_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
