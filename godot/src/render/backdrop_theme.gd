class_name BackdropTheme
extends RefCounted
## Visual configuration only; world IDs remain the stable internal IDs.

static var PALETTES: Array[PackedColorArray] = [
	PackedColorArray([Color("#101b24"), Color("#15212b"), Color("#1b2933"), Color("#121d26")]),
	PackedColorArray([Color("#201b17"), Color("#28221c"), Color("#30291f"), Color("#231e19")]),
	PackedColorArray([Color("#201921"), Color("#28202a"), Color("#302733"), Color("#241c26")]),
	PackedColorArray([Color("#101e25"), Color("#15262d"), Color("#1b2e36"), Color("#122129")]),
	PackedColorArray([Color("#1a1727"), Color("#221e30"), Color("#2a2539"), Color("#1e1a2b")]),
	# Sensors, ice, sand, rails and TNT: quiet hues of their materials.
	PackedColorArray([Color("#101f19"), Color("#162b21"), Color("#20372b"), Color("#14271d")]),
	PackedColorArray([Color("#111e2b"), Color("#172a38"), Color("#203645"), Color("#142432")]),
	PackedColorArray([Color("#241e14"), Color("#30271b"), Color("#3b3021"), Color("#2a2218")]),
	PackedColorArray([Color("#221725"), Color("#2a1d2e"), Color("#322436"), Color("#251a28")]),
	PackedColorArray([Color("#261616"), Color("#301d1d"), Color("#3e2626"), Color("#2b1919")]),
]


const SUPPORT_TYPES: Array[Array] = [[0, 1, 2], [3, 4, 1], [5, 0, 3], [6, 1, 4], [7, 6, 2], [0, 6, 4], [6, 1, 0], [3, 4, 2], [5, 7, 1], [7, 3, 4]]
const EQUIPMENT: Array[Array] = [
	["培養槽", "操作台", "營養泵", "樣本架", "抽氣格柵", "接線柱"],
	["回收壓床", "廢料桶", "進料斗", "液壓泵", "壓力表", "配電柱"],
	["聚合攪拌槽", "材料捲盤", "控制台", "試劑桶", "壓力表", "配電柱"],
	["冷卻塔", "電容組", "冷卻泵", "濾料斗", "通風格柵", "配電柱"],
	["隔離閘門", "維修櫃", "備援電源", "補給架", "監控面板", "配電柱"],
]


static func variant(bay: int, world: int) -> int:
	return posmod(bay * 7 + world * 3, 4)
