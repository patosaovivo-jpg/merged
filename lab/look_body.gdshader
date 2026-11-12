shader_type spatial;
render_mode cull_back;
// =============================================================================
// Corpo "vestível" de malha única: pinta pele / camisa / calça / sapato / luva /
// cabelo / cinto / acabamento por REGIÃO (limites calculados por fragmento, em
// coordenadas da pose de repouso => acompanham a animação) e infla um pouco a
// malha nas áreas de roupa para dar volume.
// Dados por vértice (textura 2xN): [0]=(x,y,z de repouso, classe)  [1]=(t,0,0,0)
// classes: 0 pescoço/outros, 1 tronco, 2 quadril, 3 braço, 4 mão, 5 perna, 6 cabeça, 7 pé
// slots de cor: 0 pele, 1 camisa, 2 calça, 3 sapato, 4 luva, 5 cabelo, 6 acabamento, 7 cinto
// =============================================================================

uniform sampler2D vdata : filter_nearest, repeat_disable;

uniform vec4 col0 : source_color = vec4(1.0, 0.8, 0.65, 1.0);
uniform vec4 col1 : source_color = vec4(0.65, 0.12, 0.12, 1.0);
uniform vec4 col2 : source_color = vec4(0.12, 0.28, 0.38, 1.0);
uniform vec4 col3 : source_color = vec4(0.1, 0.1, 0.1, 1.0);
uniform vec4 col4 : source_color = vec4(0.2, 0.2, 0.2, 1.0);
uniform vec4 col5 : source_color = vec4(0.25, 0.15, 0.1, 1.0);
uniform vec4 col6 : source_color = vec4(0.9, 0.9, 0.9, 1.0);
uniform vec4 col7 : source_color = vec4(0.3, 0.2, 0.1, 1.0);
// x = rugosidade, y = metal
uniform vec2 mr0 = vec2(0.7, 0.0);
uniform vec2 mr1 = vec2(0.8, 0.0);
uniform vec2 mr2 = vec2(0.8, 0.0);
uniform vec2 mr3 = vec2(0.6, 0.0);
uniform vec2 mr4 = vec2(0.6, 0.0);
uniform vec2 mr5 = vec2(0.5, 0.0);
uniform vec2 mr6 = vec2(0.8, 0.0);
uniform vec2 mr7 = vec2(0.5, 0.3);
// inflar (metros) por slot
uniform vec4 infl_a = vec4(0.0, 0.01, 0.008, 0.012);
uniform vec4 infl_b = vec4(0.006, 0.0, 0.0, 0.004);

uniform bool shirt_on = true;
uniform bool pants_on = true;
uniform bool shoes_on = true;
uniform bool gloves_on = false;
uniform bool belt_on = false;
uniform bool trim_on = true;
uniform float sleeve = 0.45;       // 0..1 ao longo do braço (ombro -> pulso)
uniform float hem = 1.10;          // altura (m) da barra da camisa
uniform float neck_cut = 1.70;     // altura (m) do decote
uniform float pants_len = 1.0;     // 0..1 ao longo da perna (quadril -> tornozelo)
uniform float boot = 0.0;          // 0..1 altura da bota na perna
uniform float glove_arm = 0.0;     // 0..1 luva subindo pelo antebraço
uniform float belt_y = 1.14;
uniform float belt_w = 0.02;
uniform float trim_w = 0.014;      // espessura do acabamento (m)
uniform float trim_t = 0.03;       // idem em unidades 't'
uniform bool flat_shading = true;
uniform int scalp_style = 0;       // 0 nada, 1 raspado, 2 curto, 3 baixo
uniform vec3 head_min = vec3(-0.1, 1.73, -0.12);
uniform vec3 head_max = vec3(0.1, 2.01, 0.16);

varying vec3 v_rest;
varying flat float v_cls;
varying float v_t;

int region(vec3 p, int cls, float t) {
	int s = 0;
	if (cls == 0) {                       // pescoço / base: a gola da camisa cobre a parte baixa
		if (shirt_on && p.y >= hem && p.y <= neck_cut) s = 1;
		return s;
	}
	if (cls == 6) {
		if (scalp_style > 0) {
			float hh = max(head_max.y - head_min.y, 0.001);
			float h = (p.y - head_min.y) / hh;
			float zc = (head_min.z + head_max.z) * 0.5;
			float front = clamp((p.z - zc) / max((head_max.z - head_min.z) * 0.5, 0.001), 0.0, 1.0);
			float base = scalp_style == 1 ? 0.84 : (scalp_style == 2 ? 0.66 : 0.50);
			if (h > base + 0.13 * front) s = 5;
		}
		return s;
	}
	if (cls == 1) {                       // tronco
		if (shirt_on && p.y >= hem && p.y <= neck_cut) {
			s = 1;
			if (trim_on && (p.y < hem + trim_w || p.y > neck_cut - trim_w * 0.8)) s = 6;
		}
	} else if (cls == 2) {                // quadril
		if (pants_on) s = 2;
		if (shirt_on && p.y >= hem) {
			s = 1;
			if (trim_on && p.y < hem + trim_w) s = 6;
		}
	} else if (cls == 3) {                // braço
		if (shirt_on && t < sleeve) {
			s = 1;
			if (trim_on && t > sleeve - trim_t) s = 6;
		}
		if (gloves_on && glove_arm > 0.0 && t > 1.0 - glove_arm) s = 4;
	} else if (cls == 4) {                // mão
		if (gloves_on) s = 4;
	} else if (cls == 5) {                // perna
		if (pants_on && t < pants_len) {
			s = 2;
			if (trim_on && pants_len < 0.99 && t > pants_len - trim_t) s = 6;
		}
		if (shirt_on && p.y >= hem) {
			s = 1;
			if (trim_on && p.y < hem + trim_w) s = 6;
		}
		if (shoes_on && boot > 0.0 && t > 1.0 - boot) s = 3;
	} else if (cls == 7) {                // pé
		if (shoes_on) s = 3;
	}
	if (belt_on && (cls == 1 || cls == 2) && abs(p.y - belt_y) < belt_w) s = 7;
	return s;
}

float slot_infl(int s) {
	if (s == 1) return infl_a.y;
	if (s == 2) return infl_a.z;
	if (s == 3) return infl_a.w;
	if (s == 4) return infl_b.x;
	if (s == 5) return infl_b.y;
	if (s == 6) return infl_a.y * 0.7;
	if (s == 7) return infl_b.w;
	return infl_a.x;
}

vec4 slot_col(int s) {
	if (s == 1) return col1;
	if (s == 2) return col2;
	if (s == 3) return col3;
	if (s == 4) return col4;
	if (s == 5) return col5;
	if (s == 6) return col6;
	if (s == 7) return col7;
	return col0;
}

vec2 slot_mr(int s) {
	if (s == 1) return mr1;
	if (s == 2) return mr2;
	if (s == 3) return mr3;
	if (s == 4) return mr4;
	if (s == 5) return mr5;
	if (s == 6) return mr6;
	if (s == 7) return mr7;
	return mr0;
}

void vertex() {
	vec4 d0 = texelFetch(vdata, ivec2(VERTEX_ID, 0), 0);
	vec4 d1 = texelFetch(vdata, ivec2(VERTEX_ID, 1), 0);
	v_rest = d0.xyz;
	v_cls = d0.w;
	v_t = d1.x;
	int s = region(v_rest, int(v_cls + 0.5), v_t);
	VERTEX += NORMAL * slot_infl(s);
}

void fragment() {
	int s = region(v_rest, int(v_cls + 0.5), v_t);
	ALBEDO = slot_col(s).rgb;
	vec2 m = slot_mr(s);
	ROUGHNESS = m.x;
	METALLIC = m.y;
	if (flat_shading) {
		NORMAL = -normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	}
}
