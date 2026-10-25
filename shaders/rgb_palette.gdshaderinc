// Neutral stone and the three RGB colour families. Old illustrations contain
// small amber highlights; drain these instead of inventing a fourth colour.
vec3 without_amber(vec3 value) {
	float yellow = min(value.r, value.g) - value.b;
	float amount = smoothstep(0.012, 0.055, yellow);
	float lightness = dot(value, vec3(0.299, 0.587, 0.114));
	return mix(value, vec3(lightness), amount);
}
