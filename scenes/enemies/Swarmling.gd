extends Enemy
class_name Swarmling
## Fastest and frailest, and never alone: the wave plan spends one entry on a
## whole pack (see EnemyDef.pack_size and Arena._spawn_next). Its budget cost
## covers the pack, so a pack does not buy extra enemies out of the wave budget.
##
## Stats live in res://resources/enemies/swarmling.tres, not here. The whole
## enemy roster is PROVISIONAL — the document suite has no enemy table
## (SPEC_GAPS.md #3).

const DEF_PATH: String = "res://resources/enemies/swarmling.tres"
