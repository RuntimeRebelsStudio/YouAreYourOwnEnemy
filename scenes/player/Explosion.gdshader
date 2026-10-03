shader_type spatial;

// Stelle den Multiplier im Inspector auf ca. 2.0 bis 3.0
uniform float glow_multiplier : hint_range(1.0, 10.0) = 2.5;

void fragment() {
    vec4 particle_color = COLOR;
    
    ALBEDO = particle_color.rgb;
    ALPHA = particle_color.a;
    
    // Berechnet die Helligkeit des Pixels
    float brightness = dot(particle_color.rgb, vec3(0.299, 0.587, 0.114));
    
    // Wenn das Partikel hell genug ist (Feuer/Gelb am Anfang) -> Boost für Glow!
    // Rauch am Ende ist dunkel (brightness < 0.3) -> fällt durch
    if (brightness > 0.35) {
        ALBEDO = particle_color.rgb * glow_multiplier;
    }
}
//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
