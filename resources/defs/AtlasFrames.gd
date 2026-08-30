extends Resource
class_name AtlasFrames
## Frame rectangles baked out of a source pack's spritesheet .xml at build
## time (tools/gen_resources.gd), so the runtime never has to ship or parse
## the XML. Technical Architecture §6: one texture, an AtlasTexture per frame.

@export var texture_path: String = ""
## frame name (e.g. "medievalStructure_16.png") -> Rect2i in the sheet.
@export var frames: Dictionary = {}

func has_frame(name: String) -> bool:
	return frames.has(name)

func rect(name: String) -> Rect2i:
	return frames.get(name, Rect2i())
