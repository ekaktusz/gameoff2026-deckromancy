extends Control

signal dismissed

const INTRO := (
	"This [mark]City[/mark] has long been an [mark]Oasis[/mark] for all the wanderers of the "
	+ "[mark]Desert[/mark]. It is the source of the [mark]Water of Life[/mark]. And as always, "
	+ "power over the [mark]City[/mark] corrupted those who were not worthy. [mark]Darius[/mark] "
	+ "took it for himself and kept it all, leaving nothing for the Living. The "
	+ "[mark]Source[/mark] went dry and with that, the [mark]City[/mark] died."
)
const CEMETERY := (
	"I got some of the [mark]Power[/mark]. I am a necromancer born from the last drop of the "
	+ "[mark]Water of Life[/mark]. I can twist the forms of the living\n\n"
	+ "[mark]YOU CAN RESURRECT CREATURES BY SPENDING RESURRECTION POINTS (RiP)[/mark]"
)
const FIRST_FIGHT := (
	"Every creature has its own unique ability. They are [mark]shifting[/mark]. "
	+ "You collect [mark]RiP[/mark] by defeating enemies. You can [mark]revive[/mark] any "
	+ "defeated creature. You can rearrange your army position at the beginning of each encounter."
)
const AFTER_BOSS := [
	(
		"I knew I was on the right path to freeing the [mark]City[/mark]. "
		+ "I could feel the [mark]Power of Nature[/mark] flowing through me. "
		+ "The [mark]City[/mark] grew greener."
	),
	(
		"I kept pushing on. I could feel the support of all the living dead. "
		+ "The [mark]City[/mark] grew greener again."
	),
	(
		"I knew I was getting closer on the final encounter. [mark]Darius[/mark] was waiting for me "
		+ "at the Source of Water, just as I was waiting for [mark]Him[/mark]. "
		+ "The [mark]City[/mark] grew greener one more time."
	),
	(
		"I was exhausted. The last fight had taken all my strength and I was [mark]shifting[/mark] "
		+ "between [mark]Life[/mark] and [mark]Death[/mark]. Darius was defeated thus I was of no "
		+ "use anymore. Peace was restored and the City grew greener one last time."
	),
]

var _backdrop: CanvasItem
var _backdrop_modulate: Color

@onready var _margin: MarginContainer = $Margin
@onready var _panel: PanelContainer = $Margin/Panel
@onready var _copy: RichTextLabel = $Margin/Panel/Content/Copy


func display(text: String, backdrop: CanvasItem, centered: bool = false) -> void:
	var mark_tag := "[color=#%s]" % Card2D.MARK_COLOR.to_html(false)
	_copy.text = text.replace("[mark]", mark_tag).replace("[/mark]", "[/color]")
	_margin.add_theme_constant_override("margin_left", 0 if centered else 40)
	_margin.add_theme_constant_override("margin_top", 0 if centered else 32)
	var alignment := Control.SIZE_SHRINK_CENTER if centered else Control.SIZE_SHRINK_BEGIN
	_panel.size_flags_horizontal = alignment
	_panel.size_flags_vertical = alignment
	_backdrop = backdrop
	if _backdrop != null:
		_backdrop_modulate = _backdrop.self_modulate
		_backdrop.self_modulate = Color.WHITE
	show()
	grab_focus()


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.button_index == MOUSE_BUTTON_LEFT and click.pressed:
		accept_event()
		if click.double_click:
			if _backdrop != null:
				_backdrop.self_modulate = _backdrop_modulate
			hide()
			dismissed.emit()
