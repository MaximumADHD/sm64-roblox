--!strict

local System = script.Parent
local Assets = System.Assets
local Sounds = Assets.Sounds

local Data = {
	ACTION_BONK = Sounds.ACTION_BONK,
	ACTION_FLYING_FAST = Sounds.ACTION_FLYING_FAST,
	ACTION_HIT = Sounds.ACTION_HIT,
	ACTION_METAL_BONK = Sounds.ACTION_METAL_BONK,
	ACTION_METAL_HEAVY_LANDING = Sounds.ACTION_METAL_HEAVY_LANDING,
	ACTION_METAL_LANDING = Sounds.ACTION_METAL_LANDING,
	ACTION_METAL_STEP = Sounds.ACTION_METAL_STEP,
	ACTION_PAT_BACK = Sounds.ACTION_PAT_BACK,
	ACTION_SIDE_FLIP = Sounds.ACTION_SIDE_FLIP,
	ACTION_SPIN = Sounds.ACTION_SPIN,
	ACTION_HEAVY_LANDING = Sounds.ACTION_HEAVY_LANDING,
	ACTION_TERRAIN_BODY_HIT_GROUND = Sounds.ACTION_TERRAIN_BODY_HIT_GROUND,
	ACTION_TERRAIN_JUMP = Sounds.ACTION_TERRAIN_JUMP,
	ACTION_TERRAIN_LANDING = Sounds.ACTION_TERRAIN_LANDING,
	ACTION_TERRAIN_STEP = Sounds.ACTION_TERRAIN_STEP,
	ACTION_THROW = Sounds.ACTION_THROW,
	ACTION_TWIRL = Sounds.ACTION_TWIRL,

	MARIO_ATTACKED = Sounds.MARIO_ATTACKED,
	MARIO_DOH = Sounds.MARIO_DOH,
	MARIO_GROUND_POUND_WAH = Sounds.MARIO_GROUND_POUND_WAH,
	MARIO_HAHA = Sounds.MARIO_HAHA,
	MARIO_HOO = Sounds.MARIO_HOO,
	MARIO_HOOHOO = Sounds.MARIO_HOOHOO,
	MARIO_IMA_TIRED = Sounds.MARIO_IMA_TIRED,
	MARIO_MAMA_MIA = Sounds.MARIO_MAMA_MIA,
	MARIO_ON_FIRE = Sounds.MARIO_ON_FIRE,
	MARIO_OOOF = Sounds.MARIO_OOOF,
	MARIO_PANTING = Sounds.MARIO_PANTING,
	MARIO_PUNCH_YAH = Sounds.MARIO_PUNCH_YAH,
	MARIO_PUNCH_WAH = Sounds.MARIO_PUNCH_WAH,
	MARIO_PUNCH_HOO = Sounds.MARIO_PUNCH_HOO,
	MARIO_SNORING1 = Sounds.MARIO_SNORING1,
	MARIO_SNORING2 = Sounds.MARIO_SNORING2,
	MARIO_SNORING3 = Sounds.MARIO_SNORING3,
	MARIO_UH = Sounds.MARIO_UH,
	MARIO_UH2 = Sounds.MARIO_UH2,
	MARIO_WAAAOOOW = Sounds.MARIO_WAAAOOOW,
	MARIO_WAH = Sounds.MARIO_WAH,
	MARIO_WAHA = Sounds.MARIO_WAHA,
	MARIO_WHOA = Sounds.MARIO_WHOA,
	MARIO_YAH = Sounds.MARIO_YAH,
	MARIO_YAHOO = Sounds.MARIO_YAHOO,
	MARIO_YAWNING = Sounds.MARIO_YAWNING,
	MARIO_YIPPEE = Sounds.MARIO_YIPPEE,

	MOVING_FLYING = Sounds.MOVING_FLYING,
	MOVING_LAVA_BURN = Sounds.MOVING_LAVA_BURN,
	MOVING_TERRAIN_SLIDE = Sounds.MOVING_TERRAIN_SLIDE,

	MARIO_JUMP = Sounds.MARIO_JUMP,
	MARIO_YAH_WAH_HOO = Sounds.MARIO_YAH_WAH_HOO,
	MARIO_YAHOO_WAHA_YIPPEE = Sounds.MARIO_YAHOO_WAHA_YIPPEE,

	ACTION_TERRAIN_STEP_DEFAULT = Sounds.ACTION_TERRAIN_STEP_DEFAULT,
	ACTION_TERRAIN_STEP_GRASS = Sounds.ACTION_TERRAIN_STEP_GRASS,
	ACTION_TERRAIN_STEP_ICE = Sounds.ACTION_TERRAIN_STEP_ICE,
	ACTION_TERRAIN_STEP_METAL = Sounds.ACTION_TERRAIN_STEP_METAL,
	ACTION_TERRAIN_STEP_SAND = Sounds.ACTION_TERRAIN_STEP_SAND,
	ACTION_TERRAIN_STEP_SNOW = Sounds.ACTION_TERRAIN_STEP_SNOW,
	ACTION_TERRAIN_STEP_SPOOKY = Sounds.ACTION_TERRAIN_STEP_SPOOKY,
	ACTION_TERRAIN_STEP_STONE = Sounds.ACTION_TERRAIN_STEP_STONE,

	ACTION_TERRAIN_LANDING_DEFAULT = Sounds.ACTION_TERRAIN_LANDING_DEFAULT,
	ACTION_TERRAIN_LANDING_GRASS = Sounds.ACTION_TERRAIN_LANDING_GRASS,
	ACTION_TERRAIN_LANDING_ICE = Sounds.ACTION_TERRAIN_LANDING_ICE,
	ACTION_TERRAIN_LANDING_METAL = Sounds.ACTION_TERRAIN_LANDING_METAL,
	ACTION_TERRAIN_LANDING_SAND = Sounds.ACTION_TERRAIN_LANDING_SAND,
	ACTION_TERRAIN_LANDING_SNOW = Sounds.ACTION_TERRAIN_LANDING_SNOW,
	ACTION_TERRAIN_LANDING_SPOOKY = Sounds.ACTION_TERRAIN_LANDING_SPOOKY,
	ACTION_TERRAIN_LANDING_STONE = Sounds.ACTION_TERRAIN_LANDING_STONE,

	ACTION_TERRAIN_JUMP_DEFAULT = Sounds.ACTION_TERRAIN_LANDING_DEFAULT,
	ACTION_TERRAIN_JUMP_GRASS = Sounds.ACTION_TERRAIN_LANDING_GRASS,
	ACTION_TERRAIN_JUMP_ICE = Sounds.ACTION_TERRAIN_LANDING_ICE,
	ACTION_TERRAIN_JUMP_METAL = Sounds.ACTION_TERRAIN_LANDING_METAL,
	ACTION_TERRAIN_JUMP_SAND = Sounds.ACTION_TERRAIN_LANDING_SAND,
	ACTION_TERRAIN_JUMP_SNOW = Sounds.ACTION_TERRAIN_LANDING_SNOW,
	ACTION_TERRAIN_JUMP_SPOOKY = Sounds.ACTION_TERRAIN_LANDING_SPOOKY,
	ACTION_TERRAIN_JUMP_STONE = Sounds.ACTION_TERRAIN_LANDING_STONE,
}

setmetatable(Data, {
	__index = function(t, k)
		warn("UNKNOWN SOUND:", k)
	end,
})

return table.freeze(Data)
