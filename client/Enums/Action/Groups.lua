--!strict

return {
	-- Group Flags
	STATIONARY = bit32.lshift(0, 6),
	MOVING = bit32.lshift(1, 6),
	AIRBORNE = bit32.lshift(2, 6),
	SUBMERGED = bit32.lshift(3, 6),
	CUTSCENE = bit32.lshift(4, 6),
	AUTOMATIC = bit32.lshift(5, 6),
	OBJECT = bit32.lshift(6, 6),

	-- Mask for capturing these Flags
	GROUP_MASK = 0b_000000111000000,
}
