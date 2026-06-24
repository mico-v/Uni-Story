class_name DialogueEntry extends RefCounted

## One advance-able beat of the story: an optional lazy block (presentation
## code to run) plus the dialogue text to display.
##
## The lazy block source is compiled and executed when the entry is reached,
## *before* the text is shown. This is what keeps the model replayable: jumping
## or loading re-runs the lazy blocks to rebuild presentation state.

var speaker: String = ""
var text: String = ""

## GDScript source of the `<|...|>` block attached to this entry (may be empty).
var lazy_source: String = ""
var before_checkpoint_source: String = ""
var after_dialogue_source: String = ""

## True when this entry exists only to carry presentation/flow code and has no
## displayable text (e.g. a lone `<| show(...) |>` or a branch trigger).
var is_silent: bool = false


func has_lazy() -> bool:
	return not lazy_source.strip_edges().is_empty()


func has_before_checkpoint() -> bool:
	return not before_checkpoint_source.strip_edges().is_empty()


func has_after_dialogue() -> bool:
	return not after_dialogue_source.strip_edges().is_empty()
