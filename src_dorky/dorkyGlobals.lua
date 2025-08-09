local g = {}

g.game = Game()
g.sfx = SFXManager()
g.PLAYER_DORKY = Isaac.GetPlayerTypeByName("Dorky", false)
g.PLAYER_SPIRIT = Isaac.GetPlayerTypeByName("The Void", true)
g.COSTUME_DORKY = Isaac.GetCostumeIdByPath("gfx/characters/costume_dorky.anm2")
g.COSTUME_SPIRIT = Isaac.GetCostumeIdByPath("gfx/characters/costume_spirit.anm2")
g.COSTUME_DORKY_TONGUE = Isaac.GetCostumeIdByPath("gfx/characters/costume_dorky_tongueout.anm2")
g.COSTUME_DORKY_FLIGHT = Isaac.GetCostumeIdByPath("gfx/characters/costume_dorky_flight.anm2")
g.COLLECTIBLE_TONGUE_GRAPPLE = Isaac.GetItemIdByName("Tongue Grapple")
g.COLLECTIBLE_SOUL_DRAIN = Isaac.GetItemIdByName("Soul Drain")
g.DORKY_TONGUE_ROPE_HANDLER = Isaac.GetEntityVariantByName("Dorky Tongue Rope Movement Handler")
g.DORKY_TONGUE_DUMMY_TARGET = Isaac.GetEntityVariantByName("Dorky Tongue Dummy Target")
g.SPIRIT_SPIKE_ROPE_HANDLER = Isaac.GetEntityVariantByName("Spirit Spike Rope Movement Handler")
g.SPIRIT_SPIKE_DUMMY_TARGET = Isaac.GetEntityVariantByName("Spirit Spike Dummy Target")
g.SPIRIT_DEATH_EXPLOSION = Isaac.GetEntityVariantByName("Spirit Custom Death Explosion")

return g
