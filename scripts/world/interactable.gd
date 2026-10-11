class_name TemporalInteractable
extends StaticBody3D

var interaction_id: String = ""
var kind: String = "evidence"
var display_name: String = ""
var marker: Label3D


func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.24
	shape.shape = sphere
	add_child(shape)
	marker = Label3D.new()
	marker.text = "◇"
	marker.font_size = 42
	marker.modulate = Color(0.55, 0.9, 0.9)
	marker.position.y = 0.4
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.no_depth_test = false
	marker.visible = false
	add_child(marker)
	add_to_group("interactables")


func prompt() -> String:
	match kind:
		"evidence":
			return "Examinar · %s" % display_name
		"console":
			return "Comparar la línea temporal" if CaseState.phase == "debrief" else "Abrir el expediente"
		"portal":
			return "Viajar · Guiza, c. 2560 a. C."
		"anchor":
			if not CaseState.repaired:
				return "Estabilizar el ancla temporal"
			return "Regresar al centro de operaciones"
		"device":
			if not CaseState.collected.has("device"):
				return "Examinar el resonador"
			return "Resonador desconectado" if CaseState.neutralized else "Desconectar el resonador"
	return display_name
