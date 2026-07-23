class_name FlowChartNode extends RefCounted

## A node in the story flow chart, corresponding to one `label(...)`.
## Holds the ordered dialogue entries plus the transition (fall-through jump or
## a set of branches) that fires once the node's entries are exhausted.

enum Type { NORMAL, CHAPTER, END }
enum BranchMode { NORMAL, JUMP, SHOW, ENABLE }

var name: StringName
var display_name: String
var type: int = Type.NORMAL
var is_start: bool = false
var is_unlocked_start: bool = false
var is_debug: bool = false
var is_save_point: bool = false

## Array[DialogueEntry]
var entries: Array = []

## Set by jump_to(): unconditional next node name. Empty if none.
var jump_target: StringName = &""

## Array of {
##   "dest": StringName,
##   "text": String,
##   "mode": int,
##   "cond": String,
##   "image": String
## } Set by branch().
var branches: Array = []

## Ending name set by is_end(name). Empty if unnamed or not an end node.
var end_name: String = ""


func add_entry(entry) -> void:
	entries.append(entry)


func has_transition() -> bool:
	return jump_target != &"" or not branches.is_empty()
