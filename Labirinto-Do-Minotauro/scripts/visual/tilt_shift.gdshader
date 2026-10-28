shader_type canvas_item;
// Tilt-shift: desfoca o topo e a base da tela para o cenário parecer uma
// maquete em miniatura. Funciona no renderizador Compatibilidade.
//
// Otimizado para GPU integrada: a faixa nítida do meio não amostra nada
// além do próprio pixel, e o desfoque usa 9 amostras (antes eram 25).
// O GerenciadorJogo diminui o desfoque na arena do Minotauro.

uniform sampler2D tela : hint_screen_texture, filter_linear;
uniform float centro_foco : hint_range(0.0, 1.0) = 0.55;   // altura da faixa nítida
uniform float largura_foco : hint_range(0.0, 1.0) = 0.34;  // metade da faixa nítida
uniform float suavidade : hint_range(0.01, 1.0) = 0.25;
uniform float desfoque_max : hint_range(0.0, 8.0) = 1.6;    // em pixels
uniform float saturacao : hint_range(0.0, 2.0) = 1.12;

void fragment() {
	float dist = abs(SCREEN_UV.y - centro_foco);
	float fator = smoothstep(largura_foco, largura_foco + suavidade, dist);
	vec3 cor = texture(tela, SCREEN_UV).rgb;
	if (fator * desfoque_max > 0.05) {
		// 3x3 com espaçamento de 1,5 px: a filtragem linear mistura vizinhos
		vec2 px = SCREEN_PIXEL_SIZE * desfoque_max * fator * 1.5;
		vec3 soma = cor * 4.0;
		soma += (texture(tela, SCREEN_UV + vec2(px.x, 0.0)).rgb
			+ texture(tela, SCREEN_UV - vec2(px.x, 0.0)).rgb
			+ texture(tela, SCREEN_UV + vec2(0.0, px.y)).rgb
			+ texture(tela, SCREEN_UV - vec2(0.0, px.y)).rgb) * 2.0;
		soma += texture(tela, SCREEN_UV + px).rgb
			+ texture(tela, SCREEN_UV - px).rgb
			+ texture(tela, SCREEN_UV + vec2(px.x, -px.y)).rgb
			+ texture(tela, SCREEN_UV + vec2(-px.x, px.y)).rgb;
		cor = soma / 16.0;
	}
	float cinza = dot(cor, vec3(0.299, 0.587, 0.114));
	cor = mix(vec3(cinza), cor, saturacao);
	COLOR = vec4(cor, 1.0);
}
