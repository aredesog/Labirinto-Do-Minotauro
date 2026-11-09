shader_type spatial;
// Contorno por "casca invertida" (inverted hull):
//   1) desenha o modelo de novo, um pouco inflado ao longo da normal;
//   2) cull_front: só as faces de TRÁS aparecem;
//   3) o resultado é uma borda escura em volta da silhueta.
// A espessura é dada em pixels: multiplica pela distância até a câmera
// para o traço não engrossar quando o objeto chega perto.

render_mode unshaded, cull_front, shadows_disabled;

uniform vec4 cor_contorno : source_color = vec4(0.12, 0.08, 0.1, 1.0);
uniform float espessura : hint_range(0.0, 0.05) = 0.012;

void vertex() {
	vec3 n = normalize(NORMAL);
	vec4 pos_vista = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	float dist = clamp(-pos_vista.z / 14.0, 0.6, 2.0);
	VERTEX += n * espessura * dist;
}

void fragment() {
	ALBEDO = cor_contorno.rgb;
}
