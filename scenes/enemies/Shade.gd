extends Enemy
class_name Shade
## Fast ethereal. Slips out of the world on a cycle: it keeps walking and still
## takes splash it happens to be standing in, but no tower can acquire it while
## it is out, so raw single-target damage on the lane is not enough by itself.
##
## Stats live in res://resources/enemies/shade.tres, not here. The whole enemy
## roster is PROVISIONAL — the document suite has no enemy table
## (SPEC_GAPS.md #3).

const DEF_PATH: String = "res://resources/enemies/shade.tres"
