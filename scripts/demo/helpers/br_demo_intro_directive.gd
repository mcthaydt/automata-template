extends RefCounted

const U_SD_DIRECTIVE_BUILDER := preload("res://scripts/core/utils/scene_director/u_sd_directive_builder.gd")

func build() -> RS_SceneDirective:
	return U_SD_DIRECTIVE_BUILDER.new(&"demo_intro") \
		.target(&"demo_room") \
		.desc("Demo room introductory directive (2 beats).") \
		.beat(&"intro_beat_1").instant() \
			.desc("Publishes the initial gameplay intro event.") \
			.publish(&"scene_director_intro_beat_1", {"beat_id": &"intro_beat_1"}) \
			.publish(&"signpost_message", {"message": "hud.scene_director_intro_beat_1", "message_duration_sec": 1.8}) \
		.beat(&"intro_beat_2").timed(0.05) \
			.desc("Publishes a follow-up intro event after a short delay.") \
			.publish(&"scene_director_intro_beat_2", {"beat_id": &"intro_beat_2"}) \
			.publish(&"signpost_message", {"message": "hud.scene_director_intro_beat_2", "message_duration_sec": 2.2}) \
		.build()
