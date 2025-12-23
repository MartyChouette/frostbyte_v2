extends StaticBody2D

func destroy() -> void:
	# Add particle effect or sound here
	queue_free()
