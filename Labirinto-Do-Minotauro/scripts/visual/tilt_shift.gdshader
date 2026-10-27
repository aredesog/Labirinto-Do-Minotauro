shader_type canvas_item;
// Tilt-shift: desfoca o topo e a base da tela para o cenário parecer uma
// maquete em miniatura. Funciona no renderizador Compatibilidade.

uniform sampler2D tela : hint_screen_texture, filter_linear;
uniform float centro_foco : hint_range(0.0, 1.0) = 0.55;   // altura da faixa nítida
uniform float largura_foco : hint_range(0.0, 1.0) = 0.28;  // metade da faixa nítida
uniform float suavidade : hint_range(0.01, 1.0) = 0.25;
uniform float desfoque_max : hint_range(0.0, 8.0) = 2.2;    // em pixels
uniform float saturacao : hint_range(0.0, 2.0) = 1.15;

void fragment() {
	float dist = abs(SCREEN_UV.y - centro_foco);
	float fator = smoothstep(largura_foco, largura_foco + suavidade, dist);
	vec2 px = SCREEN_PIXEL_SIZE * desfoque_max * fator;

	vec3 soma = vec3(0.0);
	float peso_total = 0.0;
	for (int x = -2; x <= 2; x++) {
		for (int y = -2; y <= 2; y++) {
			float peso = 1.0 / (1.0 + float(x * x + y * y));
			soma += texture(tela, SCREEN_UV + vec2(float(x), float(y)) * px).rgb * peso;
			peso_total += peso;
		}
	}
	vec3 cor = soma / peso_total;
	float cinza = dot(cor, vec3(0.299, 0.587, 0.114));
	cor = mix(vec3(cinza), cor, saturacao);
	COLOR = vec4(cor, 1.0);
}
