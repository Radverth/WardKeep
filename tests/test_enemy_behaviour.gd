extends WardKeepTest
## The five archetypes that do something beyond walking. All of it is
## PROVISIONAL (SPEC_GAPS.md #3 — the suite has no enemy table), so these lock
## in the shape of each behaviour rather than its exact number: a tuning pass
## may move the values, but a support that stops supporting is a regression.

## A straight lane, long enough that nothing under test reaches the end.
static func _lane() -> PackedVector2Array:
	return PackedVector2Array([Vector2.ZERO, Vector2(4000, 0)])

func _spawn(id: StringName, wave: int = 1) -> Enemy:
	var def: EnemyDef = Registry.enemy(id)
	var enemy: Enemy = attach((load(def.scene_path) as PackedScene).instantiate())
	enemy.setup(def, wave, false, _lane())
	return enemy

func test_a_ward_reduces_damage_taken() -> void:
	var warded: Enemy = _spawn(&"grunt")
	var bare: Enemy = _spawn(&"grunt")
	var reduction: float = Registry.enemy(&"shieldbearer").aura_damage_reduction
	assert_gt(reduction, 0.0, "the Shieldbearer wards for something")
	warded.refresh_aura(Enemy.AURA_WARD, reduction, 1.0)
	warded.take_damage(10.0, WK.RuneElement.PHYSICAL)
	bare.take_damage(10.0, WK.RuneElement.PHYSICAL)
	assert_gt(warded.hp, bare.hp, "a warded enemy keeps more health from the same hit")

func test_a_ward_can_never_make_an_enemy_immune() -> void:
	var enemy: Enemy = _spawn(&"grunt")
	# Nothing generates a ward this large, but a later card or archetype could,
	# and an unkillable enemy ends the run with no counterplay at all.
	enemy.refresh_aura(Enemy.AURA_WARD, 5.0, 1.0)
	var before: float = enemy.hp
	enemy.take_damage(10.0, WK.RuneElement.PHYSICAL)
	assert_gt(before, enemy.hp, "damage still lands through an absurd ward")

func test_haste_speeds_an_enemy_up() -> void:
	var enemy: Enemy = _spawn(&"grunt")
	var base: float = enemy.current_speed()
	enemy.refresh_aura(Enemy.AURA_HASTE, Registry.enemy(&"warlord").aura_speed_bonus, 1.0)
	assert_gt(enemy.current_speed(), base, "the Warlord's aura moves the wave along")

func test_healing_stops_at_full_health() -> void:
	var enemy: Enemy = _spawn(&"grunt")
	enemy.take_damage(enemy.max_hp * 0.5, WK.RuneElement.PHYSICAL)
	var hurt: float = enemy.hp
	enemy.heal(1.0)
	assert_gt(enemy.hp, hurt, "a Hexer mends the wounded")
	enemy.heal(9999.0)
	assert_almost_eq(enemy.hp, enemy.max_hp, 0.001, "healing never overfills")

func test_a_phasing_archetype_leaves_and_returns() -> void:
	var shade: Enemy = _spawn(&"shade")
	var def: EnemyDef = Registry.enemy(&"shade")
	assert_gt(def.phase_hidden_seconds, 0.0, "the Shade phases at all")
	assert_true(shade.is_targetable(), "it starts visible")
	shade._tick_phase(def.phase_visible_seconds + 0.01)
	assert_true(not shade.is_targetable(), "and goes untargetable on its cycle")
	assert_true(shade.alive, "while still walking the lane")
	shade._tick_phase(def.phase_hidden_seconds + 0.01)
	assert_true(shade.is_targetable(), "then comes back")

func test_only_the_phasing_archetype_is_ever_untargetable() -> void:
	for def: EnemyDef in Registry.spawnable_enemies():
		if def.phase_hidden_seconds > 0.0:
			continue
		var enemy: Enemy = _spawn(def.id)
		assert_true(enemy.is_targetable(), "%s can always be shot" % def.id)
	
## A pack must not be a discount: budget_cost buys the whole pack, or the wave
## director spends the same points on several times the enemies.
func test_a_pack_costs_what_its_bodies_cost() -> void:
	var swarmling: EnemyDef = Registry.enemy(&"swarmling")
	assert_gt(float(swarmling.pack_size), 1.0, "the Swarmling arrives as a pack")
	var grunt: EnemyDef = Registry.enemy(&"grunt")
	var per_body: float = float(swarmling.budget_cost) / float(swarmling.pack_size)
	assert_true(per_body < float(grunt.budget_cost),
		"a single Swarmling (%.1f) is cheaper than a Grunt (%d)" % [
			per_body, grunt.budget_cost])
	for def: EnemyDef in Registry.spawnable_enemies():
		assert_true(def.pack_size >= 1, "%s spawns at least one body" % def.id)

## Every archetype that draws an aura ring must actually project something, or
## the ring teaches the player to fear a harmless enemy.
func test_every_aura_ring_means_something() -> void:
	for def: EnemyDef in Registry.spawnable_enemies():
		if def.aura_radius_tiles <= 0.0:
			continue
		var projects: bool = def.aura_damage_reduction > 0.0 \
			or def.aura_speed_bonus > 0.0 or def.aura_heal_per_second > 0.0
		assert_true(projects, "%s draws a ring, so it must project something" % def.id)
