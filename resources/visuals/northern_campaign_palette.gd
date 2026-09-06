extends RefCounted

## Shared visual palette for the restrained northern command-table baseline.
## This resource is presentation-only: it owns no gameplay or saved state.

const GROUND_WARM := Color("d8cead")
const GROUND_SAND := Color("c9be9b")
const GROUND_PALE := Color("e1d8bb")
const GROUND_COOL := Color("b8b294")
const GROUND_MARK := Color("9d987e")

const ROAD_SURFACE := Color("8d805f")
const ROAD_DUST := Color("a99a73")
const ROAD_EDGE := Color("5e5543")
const ROAD_RUT := Color("c0b184")
const WALL_STONE := Color("666b60")
const WALL_HIGHLIGHT := Color("85897a")

const INK_BLUE := Color("102229")
const INK_TEAL := Color("17353a")
const INK_SOFT := Color("24474a")
const JADE := Color("4fa89a")
const JADE_PALE := Color("83c4b7")
const COPPER_GOLD := Color("c69a4b")
const COPPER_PALE := Color("dfbd73")
const HOSTILE_RUST := Color("a45742")
const HOSTILE_PALE := Color("c77b61")

const TEXT_WARM := Color("f2e9d2")
const TEXT_MUTED := Color("aebdb8")
const SHADOW := Color(0.055, 0.085, 0.085, 0.32)
const SHADOW_DEEP := Color(0.025, 0.045, 0.05, 0.52)


static func with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, clampf(alpha, 0.0, 1.0))
