extends RefCounted
## Single source of truth for the RGB identities.
##
## Two different bit orders exist on purpose:
## - Journey order is red / blue / green (GameState.LEVELS, collected_mask).
## - Light-channel order is red / green / blue (prism_circuit.COLORS,
##   GameState.colored_rays, shadow seals).
## Keep both lists derived from the same three colours so the hex values are
## never duplicated across gameplay, HUD, chase and finale.

const RED := Color("#FF637E")
const BLUE := Color("#59CFFF")
const GREEN := Color("#73E2A5")

const JOURNEY_COLORS := [RED, BLUE, GREEN]
const CHANNEL_COLORS := [RED, GREEN, BLUE]
const CHANNEL_NAMES := ["红", "绿", "蓝"]
