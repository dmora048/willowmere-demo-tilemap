extends Node2D

## Willowmere is a small playable RPG scene. Replace this placeholder with your
## Google AI Studio key, or paste one into the in-game Settings panel.
const GEMINI_API_KEY: String = "YOUR_API_KEY_HERE"
const GEMINI_MODEL: String = "gemini-3.6-flash"
const GEMINI_ENDPOINT: String = "https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent?key=" % GEMINI_MODEL

const WORLD_SIZE := Vector2(1152, 720)
const PLAYER_SPEED := 145.0
const NPC_INTERACT_DISTANCE := 68.0
const ACTOR_FRAME_SIZE := 32
const FARM_PLOT_COLUMNS := 6
const FARM_PLOT_ROWS := 5
const FARM_PLOT_START := Vector2(416, 354)
const FARM_PLOT_SPACING := Vector2(68, 52)
const HOTBAR_SIZE := 9
const INVENTORY_GRID_SIZE := 27

const CROP_INFO := {
	"turnip": {"name": "Turnip", "seed_name": "Turnip Seeds", "seed_price": 10, "grow_days": 2, "sell_price": 18, "color": Color("#F0D8B7")},
	"potato": {"name": "Potato", "seed_name": "Potato Seeds", "seed_price": 15, "grow_days": 3, "sell_price": 28, "color": Color("#D9B66D")},
	"carrot": {"name": "Carrot", "seed_name": "Carrot Seeds", "seed_price": 20, "grow_days": 4, "sell_price": 36, "color": Color("#F39A50")}
}

const COLOR_BORDER := Color("#35506B")
const COLOR_TEXT := Color("#F6F0DB")
const COLOR_MUTED := Color("#A5B3B1")
const COLOR_FAINT := Color("#71838B")
const COLOR_ACCENT := Color("#F2B35F")
const COLOR_MINT := Color("#77D3B0")
const COLOR_RED := Color("#F58D78")

const PLAYER_IDLE_TEXTURE: Texture2D = preload("res://asset_pack/Character/Idle.png")
const PLAYER_WALK_TEXTURE: Texture2D = preload("res://asset_pack/Character/Walk.png")
const INTERIOR_TEXTURE: Texture2D = preload("res://asset_pack/Objects/Interior.png")
const SPRING_CROPS_TEXTURE: Texture2D = preload("res://asset_pack/Objects/Spring Crops.png")

const ITEM_INFO := {
	"tool_hoe": {"name": "Hoe", "kind": "tool", "tool": "Hoe", "sheet": "interior", "region": Rect2(0, 0, 16, 16), "tint": Color("#F3C777")},
	"tool_seed_bag": {"name": "Seed Bag", "kind": "tool", "tool": "Seed Bag", "sheet": "interior", "region": Rect2(16, 0, 16, 16), "tint": Color("#C6A572")},
	"tool_watering_can": {"name": "Watering Can", "kind": "tool", "tool": "Watering Can", "sheet": "interior", "region": Rect2(32, 0, 16, 16), "tint": Color("#87B9C8")},
	"tool_harvest_knife": {"name": "Harvest Knife", "kind": "tool", "tool": "Harvest Knife", "sheet": "interior", "region": Rect2(48, 0, 16, 16), "tint": Color("#D4DCE0")},
	"turnip_seed": {"name": "Turnip Seeds", "kind": "seed", "crop": "turnip", "sheet": "crops", "region": Rect2(128, 0, 16, 16), "tint": Color.WHITE},
	"potato_seed": {"name": "Potato Seeds", "kind": "seed", "crop": "potato", "sheet": "crops", "region": Rect2(144, 0, 16, 16), "tint": Color.WHITE},
	"carrot_seed": {"name": "Carrot Seeds", "kind": "seed", "crop": "carrot", "sheet": "crops", "region": Rect2(160, 0, 16, 16), "tint": Color.WHITE},
	"turnip": {"name": "Turnip", "kind": "crop", "crop": "turnip", "sheet": "crops", "region": Rect2(176, 64, 16, 16), "tint": Color.WHITE},
	"potato": {"name": "Potato", "kind": "crop", "crop": "potato", "sheet": "crops", "region": Rect2(192, 64, 16, 16), "tint": Color.WHITE},
	"carrot": {"name": "Carrot", "kind": "crop", "crop": "carrot", "sheet": "crops", "region": Rect2(208, 64, 16, 16), "tint": Color.WHITE}
}

var world: Node2D
var town_world: Node2D
var farm_world: Node2D
var house_world: Node2D
var player: CharacterBody2D
var player_sprite: AnimatedSprite2D
var actor_frames: SpriteFrames
var player_facing := "down"
var player_last_direction := Vector2.DOWN
var npcs: Array = []
var active_location := "town"
var day_number := 1
var money := 60
var inventory: Dictionary = {
	"turnip_seed": 0, "potato_seed": 0, "carrot_seed": 0,
	"turnip": 0, "potato": 0, "carrot": 0
}
var selected_tool := "Hoe"
var selected_seed := "turnip"
var selected_hotbar_slot := 0
var hotbar_items: Array[String] = ["tool_hoe", "tool_seed_bag", "tool_watering_can", "tool_harvest_knife", "", "", "", "", ""]
var farm_plots: Array[Dictionary] = []
var shop_overlay: Control
var shop_rows: VBoxContainer
var shop_wallet_label: Label
var inventory_overlay: Control
var inventory_grid: GridContainer
var inventory_grid_buttons: Array[Button] = []
var hotbar_buttons: Array[Button] = []
var hotbar_panel: PanelContainer
var item_icon_cache: Dictionary = {}
var toast_timer := 0.0
var toast_message := ""

var hud: Control
var interaction_panel: PanelContainer
var interaction_label: Label
var dialogue_panel: PanelContainer
var dialogue_list: VBoxContainer
var dialogue_scroll: ScrollContainer
var dialogue_input: LineEdit
var dialogue_send_button: Button
var dialogue_npc_name: Label
var dialogue_npc_role: Label
var dialogue_api_status: Label
var dialogue_typing_row: Control
var api_status_label: Label
var settings_overlay: Control
var title_overlay: Control
var quest_title_label: Label
var quest_detail_label: Label
var day_money_label: Label
var location_subtitle_label: Label
var quest_action_button: Button
var quest_action_status: Label
var game_started := false
var dialogue_open := false
var active_npc: Dictionary = {}
var dialogue_history: Array[Dictionary] = []
var request_in_flight := false
var pending_user_text := ""
var api_key: String = GEMINI_API_KEY
var quests: Array[Dictionary] = [
	{"id": "mira_turnips", "npc_id": "mira", "npc_name": "Mira", "crop": "turnip", "amount": 3, "reward": 90, "accepted": false, "complete": false},
	{"id": "bram_potatoes", "npc_id": "bram", "npc_name": "Bram", "crop": "potato", "amount": 2, "reward": 100, "accepted": false, "complete": false},
	{"id": "juno_carrots", "npc_id": "juno", "npc_name": "Juno", "crop": "carrot", "amount": 3, "reward": 150, "accepted": false, "complete": false}
]


func _ready() -> void:
	town_world = get_node("World") as Node2D
	farm_world = get_node("Farm") as Node2D
	house_world = get_node("House") as Node2D
	world = town_world
	farm_world.visible = false
	house_world.visible = false
	player = world.get_node("Player") as CharacterBody2D
	actor_frames = _create_actor_frames()
	player_sprite = player.get_node("AnimatedSprite2D") as AnimatedSprite2D
	player_sprite.sprite_frames = actor_frames
	player_sprite.play("idle_down")
	player_sprite.visible = true
	var player_preview := player.get_node("EditorPreview") as Sprite2D
	player_preview.visible = false

	_create_storefront()
	_load_scene_npcs()
	_initialize_farm_plots()

	_build_hud()
	_update_api_status()
	_update_quest_tracker()
	_build_title_screen()
	_update_interaction_prompt()


func _create_storefront() -> void:
	var storefront := Node2D.new()
	storefront.name = "WillowmereSeedStore"
	storefront.position = Vector2(730, 202)
	storefront.z_index = 160
	town_world.add_child(storefront)
	var shop_shadow := Polygon2D.new()
	shop_shadow.polygon = PackedVector2Array([-70, -72, 70, -72, 70, 8, -70, 8])
	shop_shadow.color = Color("#75513A")
	storefront.add_child(shop_shadow)
	var shop_body := Polygon2D.new()
	shop_body.polygon = PackedVector2Array([-64, -80, 64, -80, 64, 4, -64, 4])
	shop_body.color = Color("#F0D0A0")
	shop_body.z_index = 1
	storefront.add_child(shop_body)
	var shop_roof := Polygon2D.new()
	shop_roof.polygon = PackedVector2Array([-76, -74, 0, -124, 76, -74])
	shop_roof.color = Color("#934D3D")
	shop_roof.z_index = 2
	storefront.add_child(shop_roof)
	var awning := Polygon2D.new()
	awning.polygon = PackedVector2Array([-58, -42, 58, -42, 58, -19, -58, -19])
	awning.color = Color("#55977A")
	awning.z_index = 3
	storefront.add_child(awning)
	var door := Polygon2D.new()
	door.polygon = PackedVector2Array([-17, -18, 17, -18, 17, 4, -17, 4])
	door.color = Color("#684333")
	door.z_index = 4
	storefront.add_child(door)
	var store_sign := Label.new()
	store_sign.text = "SEEDS  ·  PRODUCE"
	store_sign.position = Vector2(-72, -107)
	store_sign.size = Vector2(144, 20)
	store_sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	store_sign.add_theme_font_size_override("font_size", 10)
	store_sign.add_theme_color_override("font_color", Color("#FFF0CC"))
	store_sign.add_theme_color_override("font_outline_color", Color("#382C27"))
	store_sign.add_theme_constant_override("outline_size", 4)
	store_sign.z_index = 5
	storefront.add_child(store_sign)

	var clerk := StaticBody2D.new()
	clerk.name = "NPC_Clerk"
	clerk.position = Vector2(0, 18)
	clerk.z_index = 280
	clerk.collision_layer = 1
	clerk.collision_mask = 1
	clerk.add_to_group("village_npc")
	storefront.add_child(clerk)
	var clerk_collision := CollisionShape2D.new()
	var clerk_shape := CapsuleShape2D.new()
	clerk_shape.radius = 8.0
	clerk_shape.height = 18.0
	clerk_collision.shape = clerk_shape
	clerk.add_child(clerk_collision)
	var clerk_sprite := AnimatedSprite2D.new()
	clerk_sprite.name = "AnimatedSprite2D"
	clerk_sprite.position = Vector2(0, -15)
	clerk_sprite.scale = Vector2(1.35, 1.35)
	clerk_sprite.modulate = Color("#E8C987")
	clerk_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clerk.add_child(clerk_sprite)
	var clerk_name := Label.new()
	clerk_name.name = "NameLabel"
	clerk_name.text = "ROWAN"
	clerk_name.position = Vector2(-50, -59)
	clerk_name.size = Vector2(100, 18)
	clerk_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clerk_name.add_theme_font_size_override("font_size", 10)
	clerk_name.add_theme_color_override("font_color", Color("#F3D99B"))
	clerk_name.add_theme_color_override("font_outline_color", Color("#263B3B"))
	clerk_name.add_theme_constant_override("outline_size", 4)
	clerk.add_child(clerk_name)


func _load_scene_npcs() -> void:
	var npc_profiles := {
		"mira": {
			"id": "mira", "name": "Mira", "role": "Village gardener",
			"color": Color("#F0B6C7"),
			"greeting": "Morning, traveler! The seedlings are finally enjoying the spring sun.",
			"persona": "You are Mira, an optimistic village gardener. You know the crops, seasons, birds, and quiet paths around Willowmere. You are curious about the player and offer practical, kind advice. You would love three turnips for your kitchen."
		},
		"bram": {
			"id": "bram", "name": "Bram", "role": "Innkeeper & storyteller",
			"color": Color("#B7D5EF"),
			"greeting": "Welcome to Willowmere. If you have a tale to trade, you've found the right innkeeper.",
			"persona": "You are Bram, the warm and theatrical innkeeper of Willowmere. You collect local rumors and love telling short stories, but you never reveal secrets that would harm villagers. You need two potatoes for tonight's stew."
		},
		"juno": {
			"id": "juno", "name": "Juno", "role": "Wandering cartographer",
			"color": Color("#D6B8F0"),
			"greeting": "Oh! A new face. Every good map starts with a conversation—where are you headed?",
			"persona": "You are Juno, a thoughtful wandering cartographer resting in Willowmere. You speak about exploration, landmarks, and the wider world with poetic but useful detail. You would be grateful for three carrots for the road."
		},
		"clerk": {
			"id": "clerk", "name": "Rowan", "role": "Seed & produce merchant",
			"color": Color("#E8C987"),
			"greeting": "Welcome to the seed shop! I've got spring seeds to sell and a fair price for anything you've grown.",
			"persona": "You are Rowan, the cheerful seed and produce merchant in Willowmere. You sell turnip, potato, and carrot seeds, and buy fresh crops from local growers."
		}
	}
	var idle_frames := {"mira": 1, "bram": 2, "juno": 3, "clerk": 0}
	for npc_instance in get_tree().get_nodes_in_group("village_npc"):
		var npc_node := npc_instance as Node2D
		var npc_id := npc_node.name.trim_prefix("NPC_").to_lower()
		if not npc_profiles.has(npc_id):
			continue
		var npc_data: Dictionary = npc_profiles[npc_id].duplicate()
		npc_data["node"] = npc_node
		npcs.append(npc_data)
		var npc_sprite := npc_node.get_node("AnimatedSprite2D") as AnimatedSprite2D
		npc_sprite.sprite_frames = actor_frames
		npc_sprite.play("idle_down")
		npc_sprite.frame = int(idle_frames[npc_id])
		npc_sprite.visible = true
		if npc_node.has_node("EditorPreview"):
			var npc_preview := npc_node.get_node("EditorPreview") as Sprite2D
			npc_preview.visible = false


func _initialize_farm_plots() -> void:
	var plot_layer := Node2D.new()
	plot_layer.name = "FarmPlots"
	farm_world.add_child(plot_layer)
	for row in range(FARM_PLOT_ROWS):
		for column in range(FARM_PLOT_COLUMNS):
			var plot_position := FARM_PLOT_START + Vector2(column * FARM_PLOT_SPACING.x, row * FARM_PLOT_SPACING.y)
			var visual := Node2D.new()
			visual.name = "Plot_%d_%d" % [column, row]
			visual.position = plot_position
			visual.z_index = int(plot_position.y)
			plot_layer.add_child(visual)
			farm_plots.append({
				"position": plot_position,
				"tilled": false,
				"crop": "",
				"growth_days": 0,
				"watered": false,
				"node": visual
			})
			_render_farm_plot(farm_plots.size() - 1)


func _render_farm_plot(plot_index: int) -> void:
	var plot: Dictionary = farm_plots[plot_index]
	var visual := plot["node"] as Node2D
	for child in visual.get_children():
		visual.remove_child(child)
		child.free()
	var tile_color := Color("#719450")
	if bool(plot["tilled"]):
		tile_color = Color("#584638") if bool(plot["watered"]) else Color("#805A3F")
	_add_plot_polygon(visual, PackedVector2Array([-28, -20, 28, -20, 28, 20, -28, 20]), tile_color, 0)
	if bool(plot["tilled"]):
		for furrow_y in [-10.0, 0.0, 10.0]:
			var furrow := Line2D.new()
			furrow.points = PackedVector2Array([Vector2(-22, furrow_y), Vector2(22, furrow_y)])
			furrow.width = 1.0
			furrow.default_color = Color("#A67A54") if not bool(plot["watered"]) else Color("#71827A")
			furrow.z_index = 1
			visual.add_child(furrow)
	var crop_name := str(plot["crop"])
	if crop_name.is_empty():
		return
	var growth_days := int(plot["growth_days"])
	var ripe := growth_days >= int(CROP_INFO[crop_name]["grow_days"])
	var leaf_color := Color("#5E9A55") if growth_days < 2 else Color("#42874C")
	_add_plot_polygon(visual, PackedVector2Array([-2, 11, 2, 11, 2, -10, -2, -10]), Color("#467747"), 2)
	_add_plot_polygon(visual, PackedVector2Array([-2, 1, -17, -7, -14, -12, -1, -5]), leaf_color, 3)
	_add_plot_polygon(visual, PackedVector2Array([2, -1, 17, -9, 14, -14, 1, -6]), leaf_color, 3)
	if growth_days >= 2 or ripe:
		_add_plot_polygon(visual, PackedVector2Array([-2, -7, -14, -18, -11, -23, 0, -12]), Color("#70AC57"), 3)
		_add_plot_polygon(visual, PackedVector2Array([2, -8, 14, -19, 12, -23, 0, -12]), Color("#70AC57"), 3)
	if ripe:
		var crop_color: Color = CROP_INFO[crop_name]["color"]
		_add_plot_polygon(visual, _circle_points(Vector2(0, 4), 7.0, 8), crop_color, 4)
		_add_plot_polygon(visual, PackedVector2Array([-2, -3, 0, -9, 2, -3]), Color("#498448"), 5)


func _add_plot_polygon(parent: Node2D, points: PackedVector2Array, color: Color, draw_order: int) -> void:
	var polygon := Polygon2D.new()
	polygon.polygon = points
	polygon.color = color
	polygon.z_index = draw_order
	parent.add_child(polygon)


func _circle_points(center: Vector2, radius: float, sides: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for side in range(sides):
		var angle := TAU * float(side) / float(sides)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points


# Town art, collision, props, crops, villagers, and player structure are authored in World.tscn.

func _create_actor_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	_add_direction_animations(frames, "idle", PLAYER_IDLE_TEXTURE, 4, 5.0)
	_add_direction_animations(frames, "walk", PLAYER_WALK_TEXTURE, 6, 9.0)
	return frames


func _add_direction_animations(frames: SpriteFrames, prefix: String, texture: Texture2D, column_count: int, speed: float) -> void:
	var directions := ["down", "up", "side"]
	for direction_index in range(directions.size()):
		var animation_name: String = prefix + "_" + directions[direction_index]
		frames.add_animation(animation_name)
		frames.set_animation_speed(animation_name, speed)
		frames.set_animation_loop(animation_name, true)
		for column in range(column_count):
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(column * ACTOR_FRAME_SIZE, direction_index * ACTOR_FRAME_SIZE, ACTOR_FRAME_SIZE, ACTOR_FRAME_SIZE)
			frames.add_frame(animation_name, atlas)


# -----------------------------------------------------------------------------
# Player movement and interaction
# -----------------------------------------------------------------------------

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(player):
		return
	if not game_started or dialogue_open or is_instance_valid(settings_overlay) or is_instance_valid(shop_overlay) or is_instance_valid(inventory_overlay):
		player.velocity = Vector2.ZERO
		_update_player_animation(Vector2.ZERO)
		return

	var move_input := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		move_input.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		move_input.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		move_input.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		move_input.y += 1.0
	if move_input.length_squared() > 1.0:
		move_input = move_input.normalized()
	player.velocity = move_input * PLAYER_SPEED
	player.move_and_slide()
	player.position.x = clamp(player.position.x, 18.0, WORLD_SIZE.x - 18.0)
	player.position.y = clamp(player.position.y, 18.0, WORLD_SIZE.y - 18.0)
	player.z_index = int(player.position.y)
	_update_player_animation(move_input)


func _update_player_animation(move_input: Vector2) -> void:
	if move_input.length_squared() > 0.01:
		if abs(move_input.x) > abs(move_input.y):
			player_facing = "side"
			player_last_direction = Vector2(sign(move_input.x), 0)
			player_sprite.flip_h = move_input.x < 0
		elif move_input.y < 0:
			player_facing = "up"
			player_last_direction = Vector2.UP
			player_sprite.flip_h = false
		else:
			player_facing = "down"
			player_last_direction = Vector2.DOWN
			player_sprite.flip_h = false
		var walking_animation := "walk_" + player_facing
		if player_sprite.animation != walking_animation:
			player_sprite.play(walking_animation)
	else:
		var idle_animation := "idle_" + player_facing
		if player_sprite.animation != idle_animation:
			player_sprite.play(idle_animation)


func _process(delta: float) -> void:
	if toast_timer > 0.0:
		toast_timer = maxf(0.0, toast_timer - delta)
	if game_started and not dialogue_open and not is_instance_valid(settings_overlay) and not is_instance_valid(inventory_overlay):
		_update_interaction_prompt()
	if is_instance_valid(player):
		player.z_index = int(player.position.y)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if is_instance_valid(settings_overlay):
				_close_settings()
			elif is_instance_valid(shop_overlay):
				_close_shop()
			elif is_instance_valid(inventory_overlay):
				_close_inventory()
			elif dialogue_open:
				_close_dialogue()
			return
		if not game_started:
			if not is_instance_valid(settings_overlay) and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE):
				_start_game()
			return
		if event.keycode == KEY_I:
			if not dialogue_open and not is_instance_valid(settings_overlay) and not is_instance_valid(shop_overlay):
				if is_instance_valid(inventory_overlay):
					_close_inventory()
				else:
					_open_inventory()
			return
		if dialogue_open or is_instance_valid(settings_overlay) or is_instance_valid(shop_overlay) or is_instance_valid(inventory_overlay):
			return
		if event.keycode >= KEY_1 and event.keycode <= KEY_9:
			_select_hotbar_slot(event.keycode - KEY_1)
		if active_location == "farm" and event.keycode == KEY_Q:
			_cycle_seed()
		if event.keycode == KEY_E:
			_interact()


func _nearest_npc() -> Dictionary:
	var closest: Dictionary = {}
	var closest_distance := NPC_INTERACT_DISTANCE
	if not is_instance_valid(player) or active_location != "town":
		return closest
	for npc in npcs:
		var npc_node: Node2D = npc.get("node")
		if not is_instance_valid(npc_node):
			continue
		var distance := player.global_position.distance_to(npc_node.global_position)
		if distance <= closest_distance:
			closest_distance = distance
			closest = npc
	return closest


func _nearest_farm_plot() -> int:
	if not is_instance_valid(player) or active_location != "farm":
		return -1
	var closest_index := -1
	var closest_distance := 48.0
	for index in range(farm_plots.size()):
		var plot: Dictionary = farm_plots[index]
		var distance: float = player.position.distance_to(plot["position"])
		if distance <= closest_distance:
			closest_distance = distance
			closest_index = index
	return closest_index


func _interact() -> void:
	if not is_instance_valid(player):
		return
	if active_location == "town":
		var nearby := _nearest_npc()
		if not nearby.is_empty():
			if str(nearby.get("id", "")) == "clerk":
				_open_shop()
			else:
				_open_dialogue(nearby)
			return
		if player.position.distance_to(Vector2(576, 670)) <= 72.0:
			_switch_location("farm", Vector2(576, 610))
		return
	if active_location == "farm":
		if player.position.distance_to(Vector2(160, 270)) <= 58.0:
			_switch_location("house", Vector2(575, 580))
			return
		if player.position.distance_to(Vector2(576, 682)) <= 68.0:
			_switch_location("town", Vector2(576, 580))
			return
		var plot_index := _nearest_farm_plot()
		if plot_index >= 0:
			_use_farm_tool(plot_index)
		return
	if active_location == "house":
		if player.position.distance_to(Vector2(810, 294)) <= 86.0:
			_sleep_until_morning()
		elif player.position.distance_to(Vector2(576, 625)) <= 74.0:
			_switch_location("farm", Vector2(160, 292))


func _switch_location(destination: String, spawn_position: Vector2) -> void:
	var destination_world: Node2D
	match destination:
		"town":
			destination_world = town_world
		"farm":
			destination_world = farm_world
		"house":
			destination_world = house_world
		_:
			return
	if world == destination_world:
		return
	_set_world_collisions_enabled(world, false)
	if player.get_parent() != null:
		player.get_parent().remove_child(player)
	world.visible = false
	world = destination_world
	world.visible = true
	world.add_child(player)
	_set_world_collisions_enabled(world, true)
	player.position = spawn_position
	player.velocity = Vector2.ZERO
	active_location = destination
	var camera := player.get_node("TownCamera") as Camera2D
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(WORLD_SIZE.x)
	camera.limit_bottom = int(WORLD_SIZE.y)
	camera.make_current()
	camera.reset_smoothing()
	_update_location_hud()
	_update_interaction_prompt()
	_show_toast("Willowmere %s" % destination.capitalize())


func _set_world_collisions_enabled(map_root: Node2D, enabled: bool) -> void:
	for collision_node in map_root.find_children("*", "CollisionShape2D", true, false):
		(collision_node as CollisionShape2D).disabled = not enabled


func _sleep_until_morning() -> void:
	for index in range(farm_plots.size()):
		var plot: Dictionary = farm_plots[index]
		if str(plot["crop"]) != "" and bool(plot["watered"]):
			plot["growth_days"] = int(plot["growth_days"]) + 1
		plot["watered"] = false
		farm_plots[index] = plot
		_render_farm_plot(index)
	day_number += 1
	_update_location_hud()
	_update_inventory_hud()
	_show_toast("Day %d · Your watered crops have grown." % day_number)


func _tool_item_id(tool_name: String) -> String:
	match tool_name:
		"Hoe":
			return "tool_hoe"
		"Seed Bag":
			return "tool_seed_bag"
		"Watering Can":
			return "tool_watering_can"
		"Harvest Knife":
			return "tool_harvest_knife"
	return ""


func _select_tool(tool_name: String) -> void:
	selected_tool = tool_name
	var tool_item_id := _tool_item_id(tool_name)
	var slot_index := hotbar_items.find(tool_item_id)
	if slot_index >= 0:
		selected_hotbar_slot = slot_index
	_update_tool_hud()
	_show_toast("Selected %s%s" % [tool_name, " · " + str(CROP_INFO[selected_seed]["name"]) if tool_name == "Seed Bag" else ""])


func _cycle_seed() -> void:
	var crop_names := ["turnip", "potato", "carrot"]
	var start_index: int = crop_names.find(selected_seed)
	for offset in range(1, crop_names.size() + 1):
		var candidate: String = crop_names[(start_index + offset) % crop_names.size()]
		if int(inventory.get(candidate + "_seed", 0)) > 0:
			selected_seed = candidate
			selected_tool = "Seed Bag"
			var seed_slot := hotbar_items.find(candidate + "_seed")
			selected_hotbar_slot = seed_slot if seed_slot >= 0 else maxi(0, hotbar_items.find("tool_seed_bag"))
			_update_tool_hud()
			_show_toast("Selected %s Seeds." % CROP_INFO[selected_seed]["name"])
			return
	_show_toast("No other seeds in your satchel.")


func _use_farm_tool(plot_index: int) -> void:
	var plot: Dictionary = farm_plots[plot_index]
	var crop_name := str(plot["crop"])
	match selected_tool:
		"Hoe":
			if crop_name.is_empty() and not bool(plot["tilled"]):
				plot["tilled"] = true
				farm_plots[plot_index] = plot
				_render_farm_plot(plot_index)
				_show_toast("Soil prepared. Select the Seed Bag to plant.")
			else:
				_show_toast("That tile is already prepared or growing a crop.")
		"Seed Bag":
			var seed_key := selected_seed + "_seed"
			if not bool(plot["tilled"]):
				_show_toast("Till this patch first with the Hoe.")
			elif not crop_name.is_empty():
				_show_toast("Something is already planted here.")
			elif int(inventory.get(seed_key, 0)) <= 0:
				_show_toast("You're out of %s. Visit Rowan's shop in town." % CROP_INFO[selected_seed]["seed_name"])
			else:
				inventory[seed_key] = int(inventory[seed_key]) - 1
				plot["crop"] = selected_seed
				plot["growth_days"] = 0
				plot["watered"] = false
				farm_plots[plot_index] = plot
				_render_farm_plot(plot_index)
				_update_inventory_hud()
				_show_toast("Planted %s. Water it before bed." % CROP_INFO[selected_seed]["name"])
		"Watering Can":
			if crop_name.is_empty():
				_show_toast("Plant a seed before watering this patch.")
			elif bool(plot["watered"]):
				_show_toast("This crop has already been watered today.")
			elif int(plot["growth_days"]) >= int(CROP_INFO[crop_name]["grow_days"]):
				_show_toast("This crop is ready to harvest with the Harvest Knife.")
			else:
				plot["watered"] = true
				farm_plots[plot_index] = plot
				_render_farm_plot(plot_index)
				_show_toast("Watered %s. Sleep to help it grow." % CROP_INFO[crop_name]["name"])
		"Harvest Knife":
			if crop_name.is_empty():
				_show_toast("There's nothing to harvest here.")
			elif int(plot["growth_days"]) < int(CROP_INFO[crop_name]["grow_days"]):
				_show_toast("%s needs %d more day(s) to ripen." % [CROP_INFO[crop_name]["name"], int(CROP_INFO[crop_name]["grow_days"]) - int(plot["growth_days"])])
			else:
				inventory[crop_name] = int(inventory.get(crop_name, 0)) + 1
				_ensure_hotbar_item(crop_name)
				plot["crop"] = ""
				plot["growth_days"] = 0
				plot["watered"] = false
				farm_plots[plot_index] = plot
				_render_farm_plot(plot_index)
				_update_inventory_hud()
				_update_quest_tracker()
				_show_toast("Harvested a %s." % CROP_INFO[crop_name]["name"])
		"":
			_show_toast("Select a tool or seed in the hotbar first.")
	_update_interaction_prompt()


func _show_toast(message: String) -> void:
	if not is_instance_valid(interaction_label) or not is_instance_valid(interaction_panel):
		return
	interaction_label.text = message
	interaction_panel.visible = true
	interaction_panel.modulate = Color.WHITE
	toast_message = message
	toast_timer = 2.2


func _update_interaction_prompt() -> void:
	if not is_instance_valid(interaction_panel):
		return
	if toast_timer > 0.0:
		interaction_panel.visible = true
		interaction_label.text = toast_message
		return
	var prompt := ""
	if active_location == "town":
		var nearby := _nearest_npc()
		if not nearby.is_empty():
			prompt = "E   SHOP WITH ROWAN" if str(nearby.get("id", "")) == "clerk" else "E   TALK TO " + str(nearby.get("name", "VILLAGER")).to_upper()
		elif player.position.distance_to(Vector2(576, 670)) <= 72.0:
			prompt = "E   TRAVEL TO YOUR FARM"
	elif active_location == "farm":
		if player.position.distance_to(Vector2(160, 270)) <= 58.0:
			prompt = "E   ENTER YOUR HOUSE"
		elif player.position.distance_to(Vector2(576, 682)) <= 68.0:
			prompt = "E   WALK TO TOWN"
		elif _nearest_farm_plot() >= 0:
			prompt = "E   %s" % (selected_tool.to_upper() if not selected_tool.is_empty() else "SELECT A FARM TOOL")
	elif active_location == "house":
		if player.position.distance_to(Vector2(810, 294)) <= 86.0:
			prompt = "E   SLEEP UNTIL MORNING"
		elif player.position.distance_to(Vector2(576, 625)) <= 74.0:
			prompt = "E   RETURN TO THE FARM"
	interaction_panel.visible = not prompt.is_empty()
	if not prompt.is_empty():
		interaction_label.text = prompt


# -----------------------------------------------------------------------------
# HUD and dialogue window
# -----------------------------------------------------------------------------

func _build_hud() -> void:
	hud = get_node("HUDLayer/HUD") as Control
	_full_rect(hud)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var top_card := PanelContainer.new()
	top_card.position = Vector2(20, 18)
	top_card.size = Vector2(390, 88)
	top_card.add_theme_stylebox_override("panel", _panel_style(Color("#142336"), 13, COLOR_BORDER, 1))
	hud.add_child(top_card)
	var top_margin := _margin(16, 16, 11, 11)
	top_card.add_child(top_margin)
	var top_copy := VBoxContainer.new()
	top_copy.add_theme_constant_override("separation", 2)
	top_margin.add_child(top_copy)
	var location := Label.new()
	location.text = "WILLOWMERE"
	location.add_theme_font_size_override("font_size", 20)
	location.add_theme_color_override("font_color", COLOR_TEXT)
	top_copy.add_child(location)
	location_subtitle_label = Label.new()
	location_subtitle_label.text = "TOWN  ·  SPRINGFALL"
	location_subtitle_label.add_theme_font_size_override("font_size", 10)
	location_subtitle_label.add_theme_color_override("font_color", COLOR_ACCENT)
	top_copy.add_child(location_subtitle_label)
	var controls := Label.new()
	controls.text = "WASD MOVE   E USE   I INVENTORY   1-9 HOTBAR"
	controls.add_theme_font_size_override("font_size", 9)
	controls.add_theme_color_override("font_color", COLOR_FAINT)
	top_copy.add_child(controls)

	var quest_card := PanelContainer.new()
	quest_card.position = Vector2(20, 112)
	quest_card.size = Vector2(310, 132)
	quest_card.add_theme_stylebox_override("panel", _panel_style(Color("#142336"), 13, COLOR_BORDER, 1))
	hud.add_child(quest_card)
	var quest_margin := _margin(14, 14, 10, 10)
	quest_card.add_child(quest_margin)
	var quest_copy := VBoxContainer.new()
	quest_copy.add_theme_constant_override("separation", 4)
	quest_margin.add_child(quest_copy)
	quest_title_label = Label.new()
	quest_title_label.text = "VILLAGE CROP REQUESTS"
	quest_title_label.add_theme_font_size_override("font_size", 10)
	quest_title_label.add_theme_color_override("font_color", COLOR_ACCENT)
	quest_copy.add_child(quest_title_label)
	quest_detail_label = Label.new()
	quest_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quest_detail_label.add_theme_font_size_override("font_size", 10)
	quest_detail_label.add_theme_color_override("font_color", COLOR_TEXT)
	quest_copy.add_child(quest_detail_label)

	var status_card := PanelContainer.new()
	status_card.anchor_left = 1.0
	status_card.anchor_right = 1.0
	status_card.offset_left = -318
	status_card.offset_top = 18
	status_card.offset_right = -20
	status_card.offset_bottom = 98
	status_card.add_theme_stylebox_override("panel", _panel_style(Color("#142336"), 13, COLOR_BORDER, 1))
	hud.add_child(status_card)
	var status_margin := _margin(14, 12, 11, 11)
	status_card.add_child(status_margin)
	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 9)
	status_margin.add_child(status_row)
	var status_copy := VBoxContainer.new()
	status_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_copy.add_theme_constant_override("separation", 1)
	status_row.add_child(status_copy)
	day_money_label = Label.new()
	day_money_label.text = "DAY 1  ·  60g"
	day_money_label.add_theme_font_size_override("font_size", 13)
	day_money_label.add_theme_color_override("font_color", COLOR_MINT)
	status_copy.add_child(day_money_label)
	api_status_label = Label.new()
	api_status_label.text = "GEMINI  /  DEMO MODE"
	api_status_label.add_theme_font_size_override("font_size", 9)
	api_status_label.add_theme_color_override("font_color", COLOR_ACCENT)
	status_copy.add_child(api_status_label)
	var settings_button := _ghost_button("Settings")
	settings_button.custom_minimum_size = Vector2(73, 32)
	settings_button.pressed.connect(_show_settings)
	status_row.add_child(settings_button)

	interaction_panel = PanelContainer.new()
	interaction_panel.anchor_left = 0.5
	interaction_panel.anchor_right = 0.5
	interaction_panel.anchor_top = 1.0
	interaction_panel.anchor_bottom = 1.0
	interaction_panel.offset_left = -174
	interaction_panel.offset_top = -150
	interaction_panel.offset_right = 174
	interaction_panel.offset_bottom = -106
	interaction_panel.add_theme_stylebox_override("panel", _panel_style(Color("#172A38"), 12, Color("#5B9A87"), 1))
	interaction_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(interaction_panel)
	interaction_label = Label.new()
	interaction_label.text = "E   TALK"
	interaction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interaction_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	interaction_label.add_theme_font_size_override("font_size", 12)
	interaction_label.add_theme_color_override("font_color", COLOR_MINT)
	interaction_panel.add_child(interaction_label)
	interaction_panel.visible = false

	_build_dialogue_panel()
	_build_hotbar()
	_update_location_hud()
	_update_hotbar_ui()


func _build_hotbar() -> void:
	var panel := PanelContainer.new()
	hotbar_panel = panel
	panel.name = "Hotbar"
	panel.anchor_left = 0.5
	panel.anchor_top = 1.0
	panel.anchor_right = 0.5
	panel.anchor_bottom = 1.0
	panel.offset_left = -270
	panel.offset_top = -90
	panel.offset_right = 270
	panel.offset_bottom = -18
	panel.z_index = 50
	panel.visible = game_started
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#101B29"), 9, Color("#81908A"), 2))
	hud.add_child(panel)
	var margin := _margin(6, 6, 5, 5)
	panel.add_child(margin)
	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", 6)
	margin.add_child(slots)
	for index in range(HOTBAR_SIZE):
		var button := _create_item_slot_button(true, index)
		button.pressed.connect(_select_hotbar_slot.bind(index))
		hotbar_buttons.append(button)
		slots.add_child(button)


func _create_item_slot_button(is_hotbar: bool, index: int) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(52, 52)
	button.focus_mode = Control.FOCUS_NONE
	button.text = ""
	var icon := TextureRect.new()
	icon.name = "ItemIcon"
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 7
	icon.offset_top = 7
	icon.offset_right = -7
	icon.offset_bottom = -7
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)
	var key_label := Label.new()
	key_label.name = "KeyLabel"
	key_label.text = str(index + 1) if is_hotbar else ""
	key_label.position = Vector2(3, 1)
	key_label.size = Vector2(14, 13)
	key_label.add_theme_font_size_override("font_size", 8)
	key_label.add_theme_color_override("font_color", Color("#D8E0D6"))
	key_label.add_theme_color_override("font_shadow_color", Color("#17202A"))
	key_label.add_theme_constant_override("shadow_offset_x", 1)
	key_label.add_theme_constant_override("shadow_offset_y", 1)
	key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(key_label)
	var count_label := Label.new()
	count_label.name = "CountLabel"
	count_label.anchor_left = 1.0
	count_label.anchor_top = 1.0
	count_label.anchor_right = 1.0
	count_label.anchor_bottom = 1.0
	count_label.offset_left = -24
	count_label.offset_top = -17
	count_label.offset_right = -3
	count_label.offset_bottom = -2
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	count_label.add_theme_font_size_override("font_size", 10)
	count_label.add_theme_color_override("font_color", Color.WHITE)
	count_label.add_theme_color_override("font_shadow_color", Color("#17202A"))
	count_label.add_theme_constant_override("shadow_offset_x", 1)
	count_label.add_theme_constant_override("shadow_offset_y", 1)
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(count_label)
	return button


func _open_inventory() -> void:
	if is_instance_valid(inventory_overlay):
		return
	inventory_overlay = Control.new()
	_full_rect(inventory_overlay)
	inventory_overlay.z_index = 40
	inventory_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	hud.add_child(inventory_overlay)
	var shade := ColorRect.new()
	_full_rect(shade)
	shade.color = Color(0.025, 0.045, 0.065, 0.72)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	inventory_overlay.add_child(shade)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -330
	panel.offset_top = -245
	panel.offset_right = 330
	panel.offset_bottom = 140
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#182536"), 12, Color("#82918B"), 2))
	inventory_overlay.add_child(panel)
	var margin := _margin(20, 20, 16, 16)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	margin.add_child(content)

	var header := HBoxContainer.new()
	content.add_child(header)
	var title_copy := VBoxContainer.new()
	title_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_copy.add_theme_constant_override("separation", 2)
	header.add_child(title_copy)
	var title := Label.new()
	title.text = "BACKPACK"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", COLOR_TEXT)
	title_copy.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "TOOLS  ·  SEEDS  ·  HARVEST"
	subtitle.add_theme_font_size_override("font_size", 9)
	subtitle.add_theme_color_override("font_color", COLOR_ACCENT)
	title_copy.add_child(subtitle)
	var wallet := Label.new()
	wallet.text = "%d gold" % money
	wallet.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	wallet.add_theme_font_size_override("font_size", 12)
	wallet.add_theme_color_override("font_color", COLOR_MINT)
	header.add_child(wallet)
	var close_button := _ghost_button("Esc  ×")
	close_button.custom_minimum_size = Vector2(68, 32)
	close_button.pressed.connect(_close_inventory)
	header.add_child(close_button)

	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 1)
	divider.color = COLOR_BORDER
	content.add_child(divider)
	inventory_grid = GridContainer.new()
	inventory_grid.columns = 9
	inventory_grid.add_theme_constant_override("h_separation", 7)
	inventory_grid.add_theme_constant_override("v_separation", 7)
	content.add_child(inventory_grid)
	inventory_grid_buttons.clear()
	for index in range(INVENTORY_GRID_SIZE):
		var button := _create_item_slot_button(false, index)
		button.pressed.connect(_on_inventory_slot_pressed.bind(index))
		inventory_grid_buttons.append(button)
		inventory_grid.add_child(button)
	var hint := Label.new()
	hint.text = "Select a hotbar slot, then click a backpack item to place it there.  ·  I / Esc to close"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 9)
	hint.add_theme_color_override("font_color", COLOR_MUTED)
	content.add_child(hint)
	_update_inventory_grid()
	_update_hotbar_ui()


func _close_inventory() -> void:
	if is_instance_valid(inventory_overlay):
		inventory_overlay.queue_free()
	inventory_overlay = null
	inventory_grid = null
	inventory_grid_buttons.clear()
	_update_interaction_prompt()


func _inventory_item_ids() -> Array[String]:
	var result: Array[String] = []
	for item_variant in ITEM_INFO.keys():
		var item_id := str(item_variant)
		var item_data: Dictionary = ITEM_INFO[item_id]
		if str(item_data["kind"]) == "tool":
			if not hotbar_items.has(item_id):
				result.append(item_id)
		elif int(inventory.get(item_id, 0)) > 0 and not hotbar_items.has(item_id):
			result.append(item_id)
	return result


func _update_inventory_grid() -> void:
	if not is_instance_valid(inventory_grid):
		return
	var item_ids := _inventory_item_ids()
	for index in range(inventory_grid_buttons.size()):
		var item_id := item_ids[index] if index < item_ids.size() else ""
		_set_item_slot_visual(inventory_grid_buttons[index], item_id, false, "")


func _update_hotbar_ui() -> void:
	for index in range(hotbar_buttons.size()):
		var item_id := hotbar_items[index] if index < hotbar_items.size() else ""
		_set_item_slot_visual(hotbar_buttons[index], item_id, index == selected_hotbar_slot, str(index + 1))


func _set_item_slot_visual(button: Button, item_id: String, selected: bool, shortcut: String) -> void:
	if not is_instance_valid(button):
		return
	var fill := Color("#6B5737") if selected else Color("#29394A")
	var border := Color("#F2B35F") if selected else Color("#52677A")
	var border_width := 2 if selected else 1
	button.add_theme_stylebox_override("normal", _panel_style(fill, 4, border, border_width))
	button.add_theme_stylebox_override("hover", _panel_style(Color("#405267"), 4, Color("#EAC078"), 2))
	button.add_theme_stylebox_override("pressed", _panel_style(Color("#243545"), 4, COLOR_MINT, 2))
	var icon := button.get_node("ItemIcon") as TextureRect
	var key_label := button.get_node("KeyLabel") as Label
	var count_label := button.get_node("CountLabel") as Label
	key_label.text = shortcut
	if item_id.is_empty() or not ITEM_INFO.has(item_id):
		icon.texture = null
		count_label.text = ""
		button.tooltip_text = "Empty slot"
		return
	var item_data: Dictionary = ITEM_INFO[item_id]
	icon.texture = _get_item_icon(item_id)
	icon.modulate = item_data["tint"]
	var amount := int(inventory.get(item_id, 0))
	count_label.text = str(amount) if amount > 0 else ""
	button.tooltip_text = str(item_data["name"]) + ("  × %d" % amount if amount > 1 else "")


func _get_item_icon(item_id: String) -> Texture2D:
	if item_icon_cache.has(item_id):
		return item_icon_cache[item_id] as Texture2D
	if not ITEM_INFO.has(item_id):
		return null
	var item_data: Dictionary = ITEM_INFO[item_id]
	var atlas := AtlasTexture.new()
	atlas.atlas = INTERIOR_TEXTURE if str(item_data["sheet"]) == "interior" else SPRING_CROPS_TEXTURE
	atlas.region = item_data["region"]
	item_icon_cache[item_id] = atlas
	return atlas


func _ensure_hotbar_item(item_id: String) -> void:
	if hotbar_items.has(item_id):
		return
	for index in range(4, HOTBAR_SIZE):
		if hotbar_items[index].is_empty():
			hotbar_items[index] = item_id
			return


func _cleanup_hotbar() -> void:
	for index in range(hotbar_items.size()):
		var item_id := hotbar_items[index]
		if item_id.is_empty() or not ITEM_INFO.has(item_id):
			continue
		if str(ITEM_INFO[item_id]["kind"]) == "tool":
			continue
		if int(inventory.get(item_id, 0)) <= 0:
			hotbar_items[index] = ""
			if selected_hotbar_slot == index:
				selected_hotbar_slot = 0
				selected_tool = "Hoe"


func _select_hotbar_slot(index: int) -> void:
	if index < 0 or index >= HOTBAR_SIZE:
		return
	selected_hotbar_slot = index
	var item_id := hotbar_items[index]
	if item_id.is_empty() or not ITEM_INFO.has(item_id):
		selected_tool = ""
		_show_toast("Empty hotbar slot.")
	else:
		var item_data: Dictionary = ITEM_INFO[item_id]
		match str(item_data["kind"]):
			"tool":
				selected_tool = str(item_data["tool"])
			"seed":
				selected_seed = str(item_data["crop"])
				selected_tool = "Seed Bag"
			"crop":
				selected_tool = ""
				_show_toast("%s · deliver it to a villager or sell it in town." % item_data["name"])
	_update_hotbar_ui()
	_update_interaction_prompt()


func _on_inventory_slot_pressed(slot_index: int) -> void:
	var item_ids := _inventory_item_ids()
	if slot_index < 0 or slot_index >= item_ids.size():
		return
	var item_id := item_ids[slot_index]
	hotbar_items[selected_hotbar_slot] = item_id
	_select_hotbar_slot(selected_hotbar_slot)
	_update_inventory_hud()


func _update_quest_tracker() -> void:
	if not is_instance_valid(quest_detail_label):
		return
	quest_title_label.text = "VILLAGE CROP REQUESTS"
	var lines := PackedStringArray()
	for quest in quests:
		var crop_name: String = CROP_INFO[str(quest["crop"])]["name"]
		if bool(quest["complete"]):
			lines.append("%s  ·  Complete  (+%dg)" % [quest["npc_name"], quest["reward"]])
		elif bool(quest["accepted"]):
			lines.append("%s  ·  %d/%d %s" % [quest["npc_name"], inventory.get(str(quest["crop"]), 0), quest["amount"], crop_name])
		else:
			lines.append("%s  ·  Ask for a request" % quest["npc_name"])
	quest_detail_label.text = "\n".join(lines)


func _update_location_hud() -> void:
	if is_instance_valid(location_subtitle_label):
		var location_name: String = "WILLOWMERE"
		match active_location:
			"town":
				location_name = "TOWN"
			"farm":
				location_name = "YOUR FARM"
			"house":
				location_name = "MEADOW HOUSE"
		location_subtitle_label.text = "%s  ·  DAY %d" % [location_name, day_number]
	if is_instance_valid(day_money_label):
		day_money_label.text = "DAY %d  ·  %dg" % [day_number, money]


func _update_inventory_hud() -> void:
	_cleanup_hotbar()
	_update_hotbar_ui()
	_update_inventory_grid()
	_update_quest_tracker()


func _update_tool_hud() -> void:
	_update_hotbar_ui()


func _build_title_screen() -> void:
	title_overlay = Control.new()
	_full_rect(title_overlay)
	title_overlay.z_index = 20
	title_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	hud.add_child(title_overlay)

	var shade := ColorRect.new()
	_full_rect(shade)
	shade.color = Color(0.035, 0.075, 0.09, 0.82)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	title_overlay.add_child(shade)

	var card := PanelContainer.new()
	card.anchor_left = 0.5
	card.anchor_top = 0.5
	card.anchor_right = 0.5
	card.anchor_bottom = 0.5
	card.offset_left = -350
	card.offset_top = -260
	card.offset_right = 350
	card.offset_bottom = 260
	card.add_theme_stylebox_override("panel", _panel_style(Color("#142336"), 22, Color("#789185"), 2))
	title_overlay.add_child(card)
	var margin := _margin(42, 42, 34, 30)
	card.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)

	var eyebrow := Label.new()
	eyebrow.text = "A QUIET LITTLE VILLAGE  ·  SPRINGFALL"
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.add_theme_font_size_override("font_size", 11)
	eyebrow.add_theme_color_override("font_color", COLOR_ACCENT)
	content.add_child(eyebrow)
	var title := Label.new()
	title.text = "Willowmere"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", COLOR_TEXT)
	content.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "A small springtime adventure"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 17)
	subtitle.add_theme_color_override("font_color", COLOR_MINT)
	content.add_child(subtitle)

	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 1)
	divider.color = COLOR_BORDER
	content.add_child(divider)
	var description := Label.new()
	description.text = "Make a home in Willowmere: grow a little farm, meet the townsfolk, and earn a living from your harvest."
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size = Vector2(0, 48)
	description.add_theme_font_size_override("font_size", 14)
	description.add_theme_color_override("font_color", COLOR_MUTED)
	content.add_child(description)
	var objective := Label.new()
	objective.text = "PLANT  ·  WATER  ·  SLEEP  ·  HARVEST  ·  SELL OR DELIVER"
	objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective.add_theme_font_size_override("font_size", 11)
	objective.add_theme_color_override("font_color", COLOR_ACCENT)
	content.add_child(objective)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(spacer)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	content.add_child(actions)
	var start_button := Button.new()
	start_button.text = "Begin exploring"
	start_button.custom_minimum_size = Vector2(190, 48)
	start_button.add_theme_font_size_override("font_size", 14)
	_apply_button_style(start_button, Color("#337C75"), Color("#4D9E91"), Color("#28655F"))
	start_button.add_theme_color_override("font_color", Color.WHITE)
	start_button.pressed.connect(_start_game)
	actions.add_child(start_button)
	var settings_button := _ghost_button("Gemini settings")
	settings_button.custom_minimum_size = Vector2(150, 48)
	settings_button.pressed.connect(_show_settings)
	actions.add_child(settings_button)

	var controls := Label.new()
	controls.text = "ENTER BEGIN  ·  WASD MOVE  ·  E USE  ·  I INVENTORY  ·  1-9 SELECT HOTBAR"
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.add_theme_font_size_override("font_size", 10)
	controls.add_theme_color_override("font_color", COLOR_FAINT)
	content.add_child(controls)


func _start_game() -> void:
	game_started = true
	if is_instance_valid(hotbar_panel):
		hotbar_panel.visible = true
	if is_instance_valid(title_overlay):
		title_overlay.queue_free()
	title_overlay = null
	_update_interaction_prompt()


func _build_dialogue_panel() -> void:
	dialogue_panel = PanelContainer.new()
	dialogue_panel.anchor_left = 0.5
	dialogue_panel.anchor_right = 0.5
	dialogue_panel.anchor_top = 1.0
	dialogue_panel.anchor_bottom = 1.0
	dialogue_panel.offset_left = -475
	dialogue_panel.offset_top = -424
	dialogue_panel.offset_right = 475
	dialogue_panel.offset_bottom = -104
	dialogue_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	dialogue_panel.add_theme_stylebox_override("panel", _panel_style(Color("#101C2B"), 15, Color("#496477"), 1))
	hud.add_child(dialogue_panel)
	var margin := _margin(17, 17, 14, 14)
	dialogue_panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 9)
	margin.add_child(content)

	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 42)
	header.add_theme_constant_override("separation", 10)
	content.add_child(header)
	var npc_avatar := PanelContainer.new()
	npc_avatar.custom_minimum_size = Vector2(39, 39)
	npc_avatar.add_theme_stylebox_override("panel", _panel_style(Color("#3E5A5B"), 11, COLOR_MINT, 1))
	var avatar_symbol := Label.new()
	avatar_symbol.text = "✦"
	avatar_symbol.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	avatar_symbol.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	avatar_symbol.add_theme_font_size_override("font_size", 20)
	avatar_symbol.add_theme_color_override("font_color", COLOR_MINT)
	npc_avatar.add_child(avatar_symbol)
	header.add_child(npc_avatar)
	var name_copy := VBoxContainer.new()
	name_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_copy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_copy.add_theme_constant_override("separation", 1)
	header.add_child(name_copy)
	dialogue_npc_name = Label.new()
	dialogue_npc_name.text = "VILLAGER"
	dialogue_npc_name.add_theme_font_size_override("font_size", 15)
	dialogue_npc_name.add_theme_color_override("font_color", COLOR_TEXT)
	name_copy.add_child(dialogue_npc_name)
	dialogue_npc_role = Label.new()
	dialogue_npc_role.text = ""
	dialogue_npc_role.add_theme_font_size_override("font_size", 10)
	dialogue_npc_role.add_theme_color_override("font_color", COLOR_ACCENT)
	name_copy.add_child(dialogue_npc_role)
	dialogue_api_status = Label.new()
	dialogue_api_status.text = "GEMINI LINK"
	dialogue_api_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dialogue_api_status.add_theme_font_size_override("font_size", 10)
	dialogue_api_status.add_theme_color_override("font_color", COLOR_MINT)
	header.add_child(dialogue_api_status)
	var close_button := _ghost_button("Esc  ×")
	close_button.custom_minimum_size = Vector2(67, 31)
	close_button.pressed.connect(_close_dialogue)
	header.add_child(close_button)

	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 1)
	divider.color = COLOR_BORDER
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(divider)

	dialogue_scroll = ScrollContainer.new()
	dialogue_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dialogue_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dialogue_scroll.custom_minimum_size = Vector2(0, 102)
	content.add_child(dialogue_scroll)
	dialogue_list = VBoxContainer.new()
	dialogue_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dialogue_list.add_theme_constant_override("separation", 7)
	dialogue_scroll.add_child(dialogue_list)

	var quest_action_row := HBoxContainer.new()
	quest_action_row.custom_minimum_size = Vector2(0, 35)
	quest_action_row.add_theme_constant_override("separation", 10)
	content.add_child(quest_action_row)
	quest_action_button = Button.new()
	quest_action_button.custom_minimum_size = Vector2(170, 34)
	quest_action_button.add_theme_font_size_override("font_size", 10)
	_apply_button_style(quest_action_button, Color("#337C75"), Color("#4D9E91"), Color("#28655F"))
	quest_action_button.add_theme_color_override("font_color", Color.WHITE)
	quest_action_button.pressed.connect(_on_quest_action_pressed)
	quest_action_row.add_child(quest_action_button)
	quest_action_status = Label.new()
	quest_action_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quest_action_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	quest_action_status.add_theme_font_size_override("font_size", 10)
	quest_action_status.add_theme_color_override("font_color", COLOR_MUTED)
	quest_action_row.add_child(quest_action_status)
	quest_action_row.visible = false

	var input_row := HBoxContainer.new()
	input_row.custom_minimum_size = Vector2(0, 40)
	input_row.add_theme_constant_override("separation", 8)
	content.add_child(input_row)
	dialogue_input = LineEdit.new()
	dialogue_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dialogue_input.placeholder_text = "Say something to this villager..."
	dialogue_input.add_theme_font_size_override("font_size", 12)
	dialogue_input.add_theme_color_override("font_color", COLOR_TEXT)
	dialogue_input.add_theme_color_override("font_placeholder_color", COLOR_FAINT)
	dialogue_input.add_theme_stylebox_override("normal", _panel_style(Color("#0A1523"), 9, COLOR_BORDER, 1))
	dialogue_input.add_theme_stylebox_override("focus", _panel_style(Color("#0A1523"), 9, COLOR_MINT, 1))
	dialogue_input.text_submitted.connect(_on_dialogue_text_submitted)
	input_row.add_child(dialogue_input)
	dialogue_send_button = Button.new()
	dialogue_send_button.text = "Send  ↗"
	dialogue_send_button.custom_minimum_size = Vector2(93, 38)
	dialogue_send_button.add_theme_font_size_override("font_size", 11)
	_apply_button_style(dialogue_send_button, Color("#337C75"), Color("#4D9E91"), Color("#28655F"))
	dialogue_send_button.add_theme_color_override("font_color", Color.WHITE)
	dialogue_send_button.pressed.connect(_send_dialogue_message)
	input_row.add_child(dialogue_send_button)
	dialogue_panel.visible = false


func _open_dialogue(npc: Dictionary) -> void:
	if dialogue_open:
		return
	if str(npc.get("id", "")) == "clerk":
		_open_shop()
		return
	active_npc = npc
	dialogue_open = true
	interaction_panel.visible = false
	dialogue_panel.visible = true
	dialogue_npc_name.text = str(npc.get("name", "VILLAGER")).to_upper()
	dialogue_npc_role.text = str(npc.get("role", "TOWNSPERSON")).to_upper()
	dialogue_api_status.text = "GEMINI LINK  ·  READY" if _has_api_key() else "DEMO MODE  ·  KEY NEEDED"
	dialogue_api_status.add_theme_color_override("font_color", COLOR_MINT if _has_api_key() else COLOR_ACCENT)
	for child in dialogue_list.get_children():
		child.free()
	dialogue_history.clear()
	var greeting := str(npc.get("greeting", "Hello there."))
	var quest := _quest_for_npc(str(npc.get("id", "")))
	if not quest.is_empty():
		var crop_name: String = CROP_INFO[str(quest["crop"])]["name"]
		if bool(quest["complete"]):
			greeting += " Thanks again for bringing me those %s!" % crop_name.to_lower()
		elif bool(quest["accepted"]):
			greeting += " I'm still hoping for %d %s. Have you got them?" % [quest["amount"], crop_name.to_lower()]
		else:
			greeting += " Could you grow and bring me %d %s? I'll pay you %d gold." % [quest["amount"], crop_name.to_lower(), quest["reward"]]
	dialogue_history.append({"role": "model", "text": greeting})
	_add_dialogue_line(str(npc.get("name", "Villager")), greeting, false, false)
	_update_npc_quest_actions()
	dialogue_input.clear()
	dialogue_input.editable = true
	dialogue_input.grab_focus()
	_scroll_dialogue_to_bottom()


func _close_dialogue() -> void:
	if not dialogue_open:
		return
	if request_in_flight:
		($GeminiRequest as HTTPRequest).cancel_request()
		request_in_flight = false
		pending_user_text = ""
		_remove_dialogue_typing()
		_set_dialogue_request_state(false)
	dialogue_open = false
	active_npc = {}
	dialogue_panel.visible = false
	if is_instance_valid(quest_action_button):
		quest_action_button.get_parent().visible = false
	_update_interaction_prompt()


func _quest_for_npc(npc_id: String) -> Dictionary:
	for quest in quests:
		if str(quest["npc_id"]) == npc_id:
			return quest
	return {}


func _update_npc_quest_actions() -> void:
	if not is_instance_valid(quest_action_button):
		return
	var quest := _quest_for_npc(str(active_npc.get("id", "")))
	var action_row := quest_action_button.get_parent() as Control
	action_row.visible = not quest.is_empty()
	if quest.is_empty():
		return
	var crop_name: String = CROP_INFO[str(quest["crop"])]["name"]
	var held := int(inventory.get(str(quest["crop"]), 0))
	if bool(quest["complete"]):
		quest_action_button.text = "Request complete"
		quest_action_button.disabled = true
		quest_action_status.text = "They appreciate your delivery."
	elif not bool(quest["accepted"]):
		quest_action_button.text = "Accept request"
		quest_action_button.disabled = false
		quest_action_status.text = "%d %s  ·  %dg reward" % [quest["amount"], crop_name, quest["reward"]]
	elif held >= int(quest["amount"]):
		quest_action_button.text = "Deliver %d %s" % [quest["amount"], crop_name]
		quest_action_button.disabled = false
		quest_action_status.text = "In your satchel: %d" % held
	else:
		quest_action_button.text = "Request accepted"
		quest_action_button.disabled = true
		quest_action_status.text = "Bring %d %s  ·  You have %d" % [quest["amount"], crop_name.to_lower(), held]


func _on_quest_action_pressed() -> void:
	var quest := _quest_for_npc(str(active_npc.get("id", "")))
	if quest.is_empty() or bool(quest["complete"]):
		return
	var crop_name := str(quest["crop"])
	var display_crop: String = CROP_INFO[crop_name]["name"]
	if not bool(quest["accepted"]):
		quest["accepted"] = true
		var accepted_line := "Thank you! Bring me %d %s when your harvest is ready." % [quest["amount"], display_crop.to_lower()]
		_add_dialogue_line(str(active_npc.get("name", "Villager")), accepted_line, false, false)
		dialogue_history.append({"role": "model", "text": accepted_line})
	else:
		var required := int(quest["amount"])
		if int(inventory.get(crop_name, 0)) < required:
			return
		inventory[crop_name] = int(inventory[crop_name]) - required
		_cleanup_hotbar()
		money += int(quest["reward"])
		quest["complete"] = true
		var delivered_line := "These are perfect! Here's %d gold for your %s. Thank you!" % [quest["reward"], display_crop.to_lower()]
		_add_dialogue_line(str(active_npc.get("name", "Villager")), delivered_line, false, false)
		dialogue_history.append({"role": "model", "text": delivered_line})
		_update_inventory_hud()
		_update_location_hud()
	_update_npc_quest_actions()
	_update_quest_tracker()


func _open_shop() -> void:
	if is_instance_valid(shop_overlay):
		return
	shop_overlay = Control.new()
	_full_rect(shop_overlay)
	shop_overlay.z_index = 45
	shop_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	hud.add_child(shop_overlay)
	var shade := ColorRect.new()
	_full_rect(shade)
	shade.color = Color(0.02, 0.05, 0.08, 0.8)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shop_overlay.add_child(shade)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -292
	panel.offset_top = -252
	panel.offset_right = 292
	panel.offset_bottom = 252
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#142336"), 17, Color("#668675"), 2))
	shop_overlay.add_child(panel)
	var margin := _margin(24, 24, 20, 20)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	margin.add_child(content)

	var header := HBoxContainer.new()
	content.add_child(header)
	var title_copy := VBoxContainer.new()
	title_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_copy.add_theme_constant_override("separation", 2)
	header.add_child(title_copy)
	var title := Label.new()
	title.text = "Rowan's Seed & Produce"
	title.add_theme_font_size_override("font_size", 21)
	title.add_theme_color_override("font_color", COLOR_TEXT)
	title_copy.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "BUY SEEDS  ·  SELL YOUR HARVEST"
	subtitle.add_theme_font_size_override("font_size", 9)
	subtitle.add_theme_color_override("font_color", COLOR_ACCENT)
	title_copy.add_child(subtitle)
	var close_button := _ghost_button("Esc  ×")
	close_button.custom_minimum_size = Vector2(68, 32)
	close_button.pressed.connect(_close_shop)
	header.add_child(close_button)

	shop_wallet_label = Label.new()
	shop_wallet_label.add_theme_font_size_override("font_size", 12)
	shop_wallet_label.add_theme_color_override("font_color", COLOR_MINT)
	content.add_child(shop_wallet_label)
	var greeting := Label.new()
	greeting.text = "Rowan: Welcome to the seed shop! I've got seeds to sell and fair prices for your harvest."
	greeting.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	greeting.add_theme_font_size_override("font_size", 10)
	greeting.add_theme_color_override("font_color", COLOR_TEXT)
	content.add_child(greeting)
	var explainer := Label.new()
	explainer.text = "Water crops each day, then sleep to help them grow."
	explainer.add_theme_font_size_override("font_size", 10)
	explainer.add_theme_color_override("font_color", COLOR_MUTED)
	content.add_child(explainer)
	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 1)
	divider.color = COLOR_BORDER
	content.add_child(divider)
	shop_rows = VBoxContainer.new()
	shop_rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shop_rows.add_theme_constant_override("separation", 8)
	content.add_child(shop_rows)
	var hint := Label.new()
	hint.text = "Plant with 2 · Cycle seeds with Q   /   Esc to close"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 9)
	hint.add_theme_color_override("font_color", COLOR_FAINT)
	content.add_child(hint)
	_refresh_shop_menu()


func _refresh_shop_menu() -> void:
	if not is_instance_valid(shop_rows):
		return
	for child in shop_rows.get_children():
		shop_rows.remove_child(child)
		child.queue_free()
	if is_instance_valid(shop_wallet_label):
		shop_wallet_label.text = "Wallet: %d gold" % money
	for crop_variant in CROP_INFO.keys():
		var crop_name := str(crop_variant)
		var crop_data: Dictionary = CROP_INFO[crop_name]
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 68)
		row.add_theme_constant_override("separation", 7)
		shop_rows.add_child(row)
		var item_copy := VBoxContainer.new()
		item_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item_copy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		item_copy.add_theme_constant_override("separation", 2)
		row.add_child(item_copy)
		var crop_title := Label.new()
		crop_title.text = str(crop_data["name"]).to_upper()
		crop_title.add_theme_font_size_override("font_size", 12)
		crop_title.add_theme_color_override("font_color", COLOR_TEXT)
		item_copy.add_child(crop_title)
		var crop_details := Label.new()
		crop_details.text = "Seeds %d gold  ·  %d days  ·  Sell %d gold" % [crop_data["seed_price"], crop_data["grow_days"], crop_data["sell_price"]]
		crop_details.add_theme_font_size_override("font_size", 9)
		crop_details.add_theme_color_override("font_color", COLOR_MUTED)
		item_copy.add_child(crop_details)
		var buy_button := Button.new()
		buy_button.text = "Buy seed\n%dg" % crop_data["seed_price"]
		buy_button.custom_minimum_size = Vector2(86, 50)
		buy_button.add_theme_font_size_override("font_size", 9)
		_apply_button_style(buy_button, Color("#337C75"), Color("#4D9E91"), Color("#28655F"))
		buy_button.add_theme_color_override("font_color", Color.WHITE)
		buy_button.pressed.connect(_buy_seed.bind(crop_name))
		row.add_child(buy_button)
		var sell_button := Button.new()
		sell_button.text = "Sell 1\n%dg" % crop_data["sell_price"]
		sell_button.custom_minimum_size = Vector2(82, 50)
		sell_button.add_theme_font_size_override("font_size", 9)
		_apply_button_style(sell_button, Color("#34495A"), Color("#496174"), Color("#253849"))
		sell_button.add_theme_color_override("font_color", COLOR_TEXT)
		sell_button.disabled = int(inventory.get(crop_name, 0)) <= 0
		sell_button.pressed.connect(_sell_crop.bind(crop_name))
		row.add_child(sell_button)
		var select_button := _ghost_button("Use")
		select_button.custom_minimum_size = Vector2(54, 48)
		select_button.disabled = selected_seed == crop_name
		select_button.pressed.connect(_select_seed.bind(crop_name))
		row.add_child(select_button)


func _buy_seed(crop_name: String) -> void:
	var price := int(CROP_INFO[crop_name]["seed_price"])
	if money < price:
		_show_toast("You need %d more gold." % (price - money))
		return
	money -= price
	var seed_key := crop_name + "_seed"
	inventory[seed_key] = int(inventory.get(seed_key, 0)) + 1
	_ensure_hotbar_item(seed_key)
	selected_seed = crop_name
	selected_tool = "Seed Bag"
	var seed_slot := hotbar_items.find(seed_key)
	if seed_slot >= 0:
		selected_hotbar_slot = seed_slot
	_update_location_hud()
	_update_inventory_hud()
	_update_tool_hud()
	_refresh_shop_menu()
	_show_toast("Bought %s." % CROP_INFO[crop_name]["seed_name"])


func _sell_crop(crop_name: String) -> void:
	if int(inventory.get(crop_name, 0)) <= 0:
		return
	inventory[crop_name] = int(inventory[crop_name]) - 1
	money += int(CROP_INFO[crop_name]["sell_price"])
	_update_location_hud()
	_update_inventory_hud()
	_update_npc_quest_actions()
	_refresh_shop_menu()
	_show_toast("Sold 1 %s for %d gold." % [CROP_INFO[crop_name]["name"].to_lower(), CROP_INFO[crop_name]["sell_price"]])


func _select_seed(crop_name: String) -> void:
	selected_seed = crop_name
	selected_tool = "Seed Bag"
	var seed_slot := hotbar_items.find(crop_name + "_seed")
	if seed_slot >= 0:
		selected_hotbar_slot = seed_slot
	else:
		var bag_slot := hotbar_items.find("tool_seed_bag")
		if bag_slot >= 0:
			selected_hotbar_slot = bag_slot
	_update_tool_hud()
	_refresh_shop_menu()
	_show_toast("Selected %s Seeds." % CROP_INFO[crop_name]["name"])


func _close_shop() -> void:
	if is_instance_valid(shop_overlay):
		shop_overlay.queue_free()
	shop_overlay = null
	shop_rows = null
	shop_wallet_label = null
	_update_interaction_prompt()


func _on_dialogue_text_submitted(_text: String) -> void:
	_send_dialogue_message()


func _send_dialogue_message() -> void:
	if not dialogue_open or request_in_flight:
		return
	var text := dialogue_input.text.strip_edges()
	if text.is_empty():
		return
	dialogue_input.clear()
	_add_dialogue_line("You", text, true, false)

	if not _has_api_key():
		_add_dialogue_line("Gemini", "This villager is waiting for a Gemini API key. Open Settings to connect the conversation.", false, true)
		return

	dialogue_history.append({"role": "user", "text": text})
	pending_user_text = text
	request_in_flight = true
	_set_dialogue_request_state(true)
	_add_dialogue_typing()

	var npc_name := str(active_npc.get("name", "Villager"))
	var npc_persona := str(active_npc.get("persona", "You are a friendly villager."))
	var system_prompt := npc_persona + " You live in the small spring town of Willowmere. The player is speaking with you in person. Stay in character, answer naturally, and keep replies to one or three short paragraphs. Never mention prompts, API calls, or being a language model. If asked about something outside your knowledge, be honest in a charming in-world way."
	var payload := {
		"systemInstruction": {"parts": [{"text": system_prompt}]},
		"contents": _build_dialogue_contents(),
		"generationConfig": {"temperature": 0.8, "maxOutputTokens": 1024}
	}
	var error := ($GeminiRequest as HTTPRequest).request(
		GEMINI_ENDPOINT + api_key.strip_edges(),
		PackedStringArray(["Content-Type: application/json"]),
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)
	if error != OK:
		_handle_dialogue_failure("The connection could not be started. Check your key and try again.")


func _build_dialogue_contents() -> Array:
	var contents: Array = []
	for turn in dialogue_history:
		var text: String = str(turn.get("text", ""))
		if not text.is_empty():
			contents.append({
				"role": str(turn.get("role", "model")),
				"parts": [{"text": text}]
			})
	return contents


func _on_gemini_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if not request_in_flight:
		return
	_remove_dialogue_typing()
	request_in_flight = false
	_set_dialogue_request_state(false)
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		_handle_dialogue_failure(_read_api_error(parsed, response_code))
		return
	if not parsed is Dictionary:
		_handle_dialogue_failure("The villager's reply was unreadable. Try again.")
		return
	var reply := _extract_gemini_reply(parsed)
	if reply.is_empty():
		_handle_dialogue_failure("The villager had no answer this time. Try again.")
		return
	dialogue_history.append({"role": "model", "text": reply})
	pending_user_text = ""
	_add_dialogue_line(str(active_npc.get("name", "Villager")), reply, false, false)


func _extract_gemini_reply(data: Dictionary) -> String:
	var candidates: Variant = data.get("candidates", [])
	if not candidates is Array or candidates.is_empty():
		return ""
	var first: Variant = candidates[0]
	if not first is Dictionary:
		return ""
	var content: Variant = first.get("content", {})
	if not content is Dictionary:
		return ""
	var parts: Variant = content.get("parts", [])
	if not parts is Array:
		return ""
	var reply := ""
	for part in parts:
		if part is Dictionary and part.has("text"):
			reply += str(part.get("text", ""))
	return reply.strip_edges()


func _read_api_error(data: Variant, response_code: int) -> String:
	if data is Dictionary:
		var api_error: Variant = data.get("error", {})
		if api_error is Dictionary:
			var message := str(api_error.get("message", ""))
			if not message.is_empty():
				return "Gemini: " + message
	return "Gemini returned HTTP %d. Check your API key and try again." % response_code


func _handle_dialogue_failure(message: String) -> void:
	_remove_dialogue_typing()
	if request_in_flight:
		request_in_flight = false
		_set_dialogue_request_state(false)
	if not dialogue_history.is_empty() and str(dialogue_history.back().get("text", "")) == pending_user_text:
		dialogue_history.pop_back()
	pending_user_text = ""
	if dialogue_open:
		_add_dialogue_line("Gemini", message, false, true)


func _set_dialogue_request_state(busy: bool) -> void:
	if is_instance_valid(dialogue_send_button):
		dialogue_send_button.disabled = busy
		dialogue_send_button.text = "Thinking..." if busy else "Send  ↗"
	if is_instance_valid(dialogue_input):
		dialogue_input.editable = not busy
	if is_instance_valid(dialogue_api_status):
		dialogue_api_status.text = "GEMINI LINK  ·  THINKING..." if busy else ("GEMINI LINK  ·  READY" if _has_api_key() else "DEMO MODE  ·  KEY NEEDED")


func _add_dialogue_line(speaker: String, text: String, from_player: bool, is_error: bool) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	if from_player:
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(spacer)
	var bubble := PanelContainer.new()
	bubble.custom_minimum_size = Vector2(320 if from_player else 390, 0)
	bubble.size_flags_horizontal = Control.SIZE_SHRINK_END if from_player else Control.SIZE_SHRINK_BEGIN
	var fill_color := Color("#23424A") if from_player else Color("#1A2B3A")
	var border_color := Color("#467D78") if from_player else Color("#365368")
	if is_error:
		fill_color = Color("#382731")
		border_color = Color("#875060")
	bubble.add_theme_stylebox_override("panel", _panel_style(fill_color, 9, border_color, 1))
	var margin := _margin(11, 11, 7, 7)
	bubble.add_child(margin)
	var copy := VBoxContainer.new()
	copy.add_theme_constant_override("separation", 3)
	margin.add_child(copy)
	var speaker_label := Label.new()
	speaker_label.text = speaker.to_upper()
	speaker_label.add_theme_font_size_override("font_size", 9)
	speaker_label.add_theme_color_override("font_color", COLOR_RED if is_error else (COLOR_ACCENT if from_player else COLOR_MINT))
	copy.add_child(speaker_label)
	var body := Label.new()
	body.text = text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_font_size_override("font_size", 12)
	body.add_theme_color_override("font_color", Color("#FFD8D3") if is_error else COLOR_TEXT)
	copy.add_child(body)
	row.add_child(bubble)
	if not from_player:
		var end_space := Control.new()
		end_space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(end_space)
	dialogue_list.add_child(row)
	_scroll_dialogue_to_bottom()


func _add_dialogue_typing() -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dialogue_typing_row = row
	var bubble := PanelContainer.new()
	bubble.custom_minimum_size = Vector2(170, 31)
	bubble.add_theme_stylebox_override("panel", _panel_style(Color("#1A2B3A"), 9, COLOR_BORDER, 1))
	var margin := _margin(10, 10, 5, 5)
	bubble.add_child(margin)
	var label := Label.new()
	label.text = "Thinking with Gemini..."
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", COLOR_MUTED)
	margin.add_child(label)
	row.add_child(bubble)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	dialogue_list.add_child(row)
	_scroll_dialogue_to_bottom()


func _remove_dialogue_typing() -> void:
	if is_instance_valid(dialogue_typing_row):
		dialogue_typing_row.free()
	dialogue_typing_row = null


func _scroll_dialogue_to_bottom() -> void:
	if not is_instance_valid(dialogue_scroll):
		return
	await get_tree().process_frame
	if is_instance_valid(dialogue_scroll):
		dialogue_scroll.scroll_vertical = int(dialogue_scroll.get_v_scroll_bar().max_value)


# -----------------------------------------------------------------------------
# API settings
# -----------------------------------------------------------------------------

func _has_api_key() -> bool:
	var candidate := api_key.strip_edges()
	if candidate.is_empty() or candidate == "GEMINI_API_HERE":
		return false
	if candidate.begins_with("PASTE_YOUR_") or candidate.begins_with("YOUR_"):
		return false
	return true


func _update_api_status() -> void:
	if not is_instance_valid(api_status_label):
		return
	if _has_api_key():
		api_status_label.text = "GEMINI  /  CONNECTED"
		api_status_label.add_theme_color_override("font_color", COLOR_MINT)
	else:
		api_status_label.text = "GEMINI  /  DEMO MODE"
		api_status_label.add_theme_color_override("font_color", COLOR_ACCENT)


func _show_settings() -> void:
	if is_instance_valid(settings_overlay):
		return
	settings_overlay = Control.new()
	_full_rect(settings_overlay)
	settings_overlay.z_index = 50
	settings_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	hud.add_child(settings_overlay)

	var shade := ColorRect.new()
	_full_rect(shade)
	shade.color = Color(0.02, 0.05, 0.08, 0.78)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.gui_input.connect(_on_settings_shade_input)
	settings_overlay.add_child(shade)

	var dialog := PanelContainer.new()
	dialog.anchor_left = 0.5
	dialog.anchor_top = 0.5
	dialog.anchor_right = 0.5
	dialog.anchor_bottom = 0.5
	dialog.offset_left = -255
	dialog.offset_top = -165
	dialog.offset_right = 255
	dialog.offset_bottom = 165
	dialog.add_theme_stylebox_override("panel", _panel_style(Color("#142336"), 15, Color("#55717D"), 1))
	settings_overlay.add_child(dialog)
	var margin := _margin(22, 22, 20, 20)
	dialog.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 11)
	margin.add_child(content)

	var title_row := HBoxContainer.new()
	title_row.custom_minimum_size = Vector2(0, 33)
	content.add_child(title_row)
	var title_copy := VBoxContainer.new()
	title_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_copy.add_theme_constant_override("separation", 1)
	title_row.add_child(title_copy)
	var title := Label.new()
	title.text = "Connect Gemini"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", COLOR_TEXT)
	title_copy.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "NPC CONVERSATIONS  /  API KEY"
	subtitle.add_theme_font_size_override("font_size", 9)
	subtitle.add_theme_color_override("font_color", COLOR_ACCENT)
	title_copy.add_child(subtitle)
	var close := _ghost_button("Close")
	close.custom_minimum_size = Vector2(64, 30)
	close.pressed.connect(_close_settings)
	title_row.add_child(close)

	var intro := Label.new()
	intro.text = "Add a Google AI Studio key to let the villagers answer in character. It stays in memory for this session."
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.custom_minimum_size = Vector2(0, 39)
	intro.add_theme_font_size_override("font_size", 12)
	intro.add_theme_color_override("font_color", COLOR_MUTED)
	content.add_child(intro)

	var key_input := LineEdit.new()
	key_input.custom_minimum_size = Vector2(0, 43)
	key_input.placeholder_text = "Paste your Gemini API key"
	key_input.secret = true
	key_input.text = api_key if _has_api_key() else ""
	key_input.add_theme_font_size_override("font_size", 12)
	key_input.add_theme_color_override("font_color", COLOR_TEXT)
	key_input.add_theme_color_override("font_placeholder_color", COLOR_FAINT)
	key_input.add_theme_stylebox_override("normal", _panel_style(Color("#0A1523"), 9, COLOR_BORDER, 1))
	key_input.add_theme_stylebox_override("focus", _panel_style(Color("#0A1523"), 9, COLOR_MINT, 1))
	content.add_child(key_input)
	var hint := Label.new()
	hint.text = "Get a key at aistudio.google.com  ·  Model: " + GEMINI_MODEL
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", COLOR_FAINT)
	content.add_child(hint)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(fill)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	content.add_child(actions)
	var action_spacer := Control.new()
	action_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(action_spacer)
	var cancel := _ghost_button("Cancel")
	cancel.custom_minimum_size = Vector2(80, 36)
	cancel.pressed.connect(_close_settings)
	actions.add_child(cancel)
	var save := Button.new()
	save.text = "Save & connect"
	save.custom_minimum_size = Vector2(132, 36)
	save.add_theme_font_size_override("font_size", 11)
	_apply_button_style(save, Color("#337C75"), Color("#4D9E91"), Color("#28655F"))
	save.add_theme_color_override("font_color", Color.WHITE)
	save.pressed.connect(_save_api_key.bind(key_input))
	actions.add_child(save)
	key_input.grab_focus()


func _on_settings_shade_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close_settings()


func _save_api_key(key_input: LineEdit) -> void:
	var value := key_input.text.strip_edges()
	api_key = value if not value.is_empty() else GEMINI_API_KEY
	_update_api_status()
	if dialogue_open:
		dialogue_api_status.text = "GEMINI LINK  ·  READY" if _has_api_key() else "DEMO MODE  ·  KEY NEEDED"
		dialogue_api_status.add_theme_color_override("font_color", COLOR_MINT if _has_api_key() else COLOR_ACCENT)
	_close_settings()


func _close_settings() -> void:
	if is_instance_valid(settings_overlay):
		settings_overlay.queue_free()
	settings_overlay = null


# -----------------------------------------------------------------------------
# Shared UI styling
# -----------------------------------------------------------------------------

func _full_rect(control: Control) -> void:
	control.anchor_left = 0.0
	control.anchor_top = 0.0
	control.anchor_right = 1.0
	control.anchor_bottom = 1.0
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0


func _margin(left: int, right: int, top: int, bottom: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_bottom", bottom)
	return margin


func _panel_style(color: Color, radius: int = 10, border: Color = Color.TRANSPARENT, border_width: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.border_color = border
	return style


func _apply_button_style(button: Button, normal: Color, hover: Color, pressed: Color) -> void:
	button.add_theme_stylebox_override("normal", _panel_style(normal, 8))
	button.add_theme_stylebox_override("hover", _panel_style(hover, 8))
	button.add_theme_stylebox_override("pressed", _panel_style(pressed, 8))
	button.add_theme_stylebox_override("focus", _panel_style(hover, 8, COLOR_MINT, 1))


func _ghost_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 10)
	button.add_theme_color_override("font_color", COLOR_MUTED)
	button.add_theme_color_override("font_hover_color", COLOR_TEXT)
	button.add_theme_stylebox_override("normal", _panel_style(Color.TRANSPARENT, 8, COLOR_BORDER, 1))
	button.add_theme_stylebox_override("hover", _panel_style(Color("#22384A"), 8, Color("#568080"), 1))
	button.add_theme_stylebox_override("pressed", _panel_style(Color("#2A4C55"), 8, COLOR_MINT, 1))
	button.add_theme_stylebox_override("focus", _panel_style(Color("#22384A"), 8, COLOR_MINT, 1))
	return button
