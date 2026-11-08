shader_type spatial;
// Cel shading (iluminação "de desenho"), no estilo do Link's Awakening.
//
// Phong/Lambert normal:   difusa = max(N·L, 0)          (degradê contínuo)
// Toon (este shader):     difusa = degraus(N·L)          (2-3 faixas de luz)
//
//   N·L  -> quantizado em "faixas" com smoothstep (borda macia de 1 pixel)
//   especular de Blinn-Phong  (N·H)^brilho  -> vira uma mancha de corte seco
//   rim light                 1 - N·V       -> contorno claro do lado da luz
//
// ATTENUATION já traz a sombra projetada e o decaimento das tochas.

uniform vec4 cor : source_color = vec4(1.0);
uniform sampler2D textura : source_color, filter_linear_mipmap, repeat_enable;
uniform bool usar_textura = false;
uniform float faixas : hint_range(1.0, 5.0) = 2.0;
uniform float suavidade : hint_range(0.0, 0.2) = 0.03;
uniform float forca_luz : hint_range(0.0, 3.0) = 1.0;
uniform float tamanho_brilho : hint_range(0.0, 1.0) = 0.0;
uniform float forca_rim : hint_range(0.0, 1.0) = 0.25;

void fragment() {
	vec3 base = cor.rgb;
	if (usar_textura) {
		base *= texture(textura, UV).rgb;
	}
	ALBEDO = base;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

// quantiza x (0..1) em n degraus, com borda suavizada
float degraus(float x, float n) {
	float y = x * n;
	float i = floor(y);
	float f = y - i;
	return (i + smoothstep(0.5 - suavidade * n, 0.5 + suavidade * n, f)) / n;
}

void light() {
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float luz = ndl * ATTENUATION;
	float q = degraus(luz, faixas);
	DIFFUSE_LIGHT += LIGHT_COLOR * q * forca_luz / PI;

	// brilho especular de corte seco (Blinn-Phong quantizado)
	if (tamanho_brilho > 0.0) {
		vec3 h = normalize(VIEW + LIGHT);
		float spec = pow(clamp(dot(NORMAL, h), 0.0, 1.0), 48.0);
		SPECULAR_LIGHT += LIGHT_COLOR * step(1.0 - tamanho_brilho, spec) * luz * 0.5 / PI;
	}

	// rim light: borda iluminada só do lado em que bate luz
	float rim = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float r = smoothstep(0.62, 0.68, rim) * q;
	DIFFUSE_LIGHT += LIGHT_COLOR * r * forca_rim / PI;
}
