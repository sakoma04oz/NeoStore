extends Node3D

const PLAYER_SCRIPT = preload("res://Player.gd")
const BOT_SCRIPT = preload("res://Bot.gd")
var player: CharacterBody3D
var zone: MeshInstance3D
var zone_radius := 90.0
var elapsed := 0.0
var status_label: Label
var alive_bots := 8

func _ready() -> void:
    randomize()
    _make_environment()
    _make_island()
    _make_player()
    _spawn_bots()
    _make_hud()
    _make_zone()

func _process(delta: float) -> void:
    elapsed += delta
    zone_radius = maxf(18.0, 90.0 - elapsed * 0.32)
    if is_instance_valid(zone):
        zone.scale = Vector3(zone_radius / 90.0, 1.0, zone_radius / 90.0)
    if is_instance_valid(player):
        var distance := Vector2(player.global_position.x, player.global_position.z).length()
        if distance > zone_radius:
            player.take_damage(4.0 * delta)
        alive_bots = get_tree().get_nodes_in_group("bots").size()
        status_label.text = "NEO BATTLE  |  Bots: %d  |  HP: %d  |  Zone: %dm" % [alive_bots, int(player.health), int(zone_radius)]

func _make_environment() -> void:
    var env := WorldEnvironment.new()
    var e := Environment.new()
    e.background_mode = Environment.BG_SKY
    e.sky = Sky.new()
    e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    e.ambient_light_color = Color(0.65, 0.72, 0.82)
    e.ambient_light_energy = 0.8
    env.environment = e
    add_child(env)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-55, -25, 0)
    sun.light_energy = 1.2
    add_child(sun)

func _make_island() -> void:
    var ground := StaticBody3D.new()
    var mesh := MeshInstance3D.new()
    var plane := PlaneMesh.new()
    plane.size = Vector2(220, 220)
    mesh.mesh = plane
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.22, 0.42, 0.27)
    mat.roughness = 1.0
    mesh.material_override = mat
    ground.add_child(mesh)
    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(220, 1, 220)
    collision.shape = shape
    collision.position.y = -0.5
    ground.add_child(collision)
    add_child(ground)
    for i in range(22):
        var block := StaticBody3D.new()
        var bmesh := MeshInstance3D.new()
        var box := BoxMesh.new()
        var w := randf_range(4.0, 10.0)
        box.size = Vector3(w, randf_range(3.0, 8.0), w)
        bmesh.mesh = box
        var bm := StandardMaterial3D.new()
        bm.albedo_color = [Color(0.55,0.48,0.36), Color(0.38,0.43,0.48), Color(0.43,0.52,0.36)][i % 3]
        bmesh.material_override = bm
        block.add_child(bmesh)
        var bc := CollisionShape3D.new()
        var bs := BoxShape3D.new()
        bs.size = box.size
        bc.shape = bs
        block.add_child(bc)
        block.position = Vector3(randf_range(-75,75), box.size.y/2, randf_range(-75,75))
        add_child(block)

func _make_player() -> void:
    player = CharacterBody3D.new()
    player.name = "Player"
    player.set_script(PLAYER_SCRIPT)
    player.position = Vector3(0, 2, 0)
    add_child(player)

func _spawn_bots() -> void:
    for i in range(8):
        var bot := CharacterBody3D.new()
        bot.set_script(BOT_SCRIPT)
        bot.add_to_group("bots")
        bot.target = player
        var angle := TAU * float(i) / 8.0
        bot.position = Vector3(cos(angle) * randf_range(24, 48), 2, sin(angle) * randf_range(24, 48))
        add_child(bot)

func _make_zone() -> void:
    zone = MeshInstance3D.new()
    var cylinder := CylinderMesh.new()
    cylinder.top_radius = 90
    cylinder.bottom_radius = 90
    cylinder.height = 0.12
    zone.mesh = cylinder
    var m := StandardMaterial3D.new()
    m.albedo_color = Color(0.15, 0.65, 1.0, 0.17)
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    zone.material_override = m
    zone.position.y = 0.08
    add_child(zone)

func _make_hud() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    status_label = Label.new()
    status_label.position = Vector2(18, 16)
    status_label.add_theme_font_size_override("font_size", 19)
    status_label.add_theme_color_override("font_color", Color.WHITE)
    layer.add_child(status_label)
    var help := Label.new()
    help.text = "WASD / الأسهم للحركة • Space للقفز • زر FIRE للإطلاق"
    help.position = Vector2(18, 48)
    help.add_theme_font_size_override("font_size", 15)
    help.add_theme_color_override("font_color", Color(0.92,0.95,1))
    layer.add_child(help)
    var fire := Button.new()
    fire.text = "FIRE"
    fire.position = Vector2(1080, 590)
    fire.size = Vector2(150, 90)
    fire.add_theme_font_size_override("font_size", 24)
    layer.add_child(fire)
    fire.pressed.connect(func(): player.shoot())
    var jump := Button.new()
    jump.text = "JUMP"
    jump.position = Vector2(920, 610)
    jump.size = Vector2(130, 70)
    layer.add_child(jump)
    jump.pressed.connect(func(): player.jump_now())

