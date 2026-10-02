class_name ReorgAnimCell
extends RefCounted
## One block sliding to its new grid cell while the World 1 boss rearranges.

var from_r: int = 0
var from_c: int = 0
var to_r: int = 0
var to_c: int = 0
var val: int = Tile.DIRT
var start_frame: int = 0
var end_frame: int = 0
