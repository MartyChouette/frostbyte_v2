extends Area2D

func _ready() -> void:
	connect("body_entered", _on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("collect_axe"):
		body.collect_axe()
		queue_free()
