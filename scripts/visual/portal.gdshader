shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
// Portal de teletransporte: redemoinho animado em coordenadas polares.
// A cor vem do tipo da sala de destino (definida pelo script da porta).

uniform vec4 cor : source_color = vec4(1.0, 0.8, 0.3, 1.0);
uniform float intensidade : hint_range(0.0, 3.0) = 1.4;
uniform float velocidade = 1.6;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;            // -1..1, centro no meio do portal
	p.y *= 1.1;
	float r = length(p);
	float ang = atan(p.y, p.x);
	// espiral: o ângulo gira com o raio e com o tempo
	float espiral = sin(ang * 3.0 + r * 9.0 - TIME * velocidade * 3.0);
	float aneis = sin(r * 14.0 - TIME * velocidade * 4.0) * 0.5 + 0.5;
	float borda = smoothstep(1.0, 0.75, r);          // some nas bordas
	float miolo = smoothstep(0.55, 0.0, r) * 0.6;    // centro mais claro
	float brilho = (espiral * 0.35 + 0.45) * borda + aneis * 0.15 * borda + miolo;
	ALBEDO = cor.rgb * brilho * intensidade;
}
