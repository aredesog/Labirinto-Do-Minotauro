// Filtro de CINEMA para as cenas (fica por cima da imagem 3D):
//   - correção de cor ("color grading"): tinta multiplicada + saturação + contraste
//   - vinheta (bordas escuras, em elipse corrigida pela proporção da tela)
//   - granulação de filme (ruído que muda a cada quadro)
// "forca" mistura a imagem original (0) com a tratada (1): o HUD anima isso.
shader_type canvas_item;

uniform sampler2D tela : hint_screen_texture, filter_linear;
uniform float forca : hint_range(0.0, 1.0) = 0.0;
uniform vec3 tinta = vec3(1.0, 0.94, 0.85);
uniform float saturacao : hint_range(0.0, 2.0) = 1.0;
uniform float contraste : hint_range(0.5, 1.5) = 1.08;
uniform float vinheta : hint_range(0.0, 1.0) = 0.55;
uniform float grao : hint_range(0.0, 0.2) = 0.035;

void fragment() {
	vec3 c = texture(tela, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 g = mix(vec3(l), c, saturacao) * tinta;
	g = (g - 0.5) * contraste + 0.5;
	vec2 d = SCREEN_UV - 0.5;
	d.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float v = smoothstep(0.95, 0.3, length(d) * 1.25);
	g *= mix(1.0, v, vinheta);
	float n = fract(sin(dot(FRAGCOORD.xy + vec2(TIME * 61.0, TIME * 17.0), vec2(12.9898, 78.233))) * 43758.5453);
	g += (n - 0.5) * grao;
	COLOR = vec4(mix(c, clamp(g, 0.0, 1.0), forca), 1.0);
}
