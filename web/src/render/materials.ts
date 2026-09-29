/**
 * three.js materials. Moving props share one `MeshStandardMaterial` per surface. Baked scenery
 * uses two materials for everything (opaque and see-through) that read colour, roughness,
 * metalness and glow from vertex attributes instead of uniforms.
 */
import * as THREE from 'three';
import { surfaceKey, toColor, type Surface } from './surfaces';

export class MaterialCache {
  private readonly materials = new Map<string, THREE.MeshStandardMaterial>();

  get(surface: Surface): THREE.MeshStandardMaterial {
    const key = surfaceKey(surface);
    let material = this.materials.get(key);
    if (!material) {
      material = new THREE.MeshStandardMaterial({
        color: toColor(surface.color),
        roughness: surface.roughness,
        metalness: surface.metalness,
        emissive: surface.emissive ? toColor(surface.emissive) : new THREE.Color(0),
        emissiveIntensity: surface.emissiveIntensity,
        transparent: surface.alpha < 0.999,
        opacity: surface.alpha,
        depthWrite: surface.alpha >= 0.999,
        side: surface.doubleSided ? THREE.DoubleSide : THREE.FrontSide,
      });
      this.materials.set(key, material);
    }
    return material;
  }

  dispose(): void {
    for (const material of this.materials.values()) material.dispose();
    this.materials.clear();
  }
}

/**
 * The baked-scenery material: a standard material whose roughness, metalness and emission come
 * from per-vertex attributes (`surface` = roughness, metalness; `glow` = emitted colour), and
 * colour and opacity from the vertex colour.
 */
export function bakedMaterial(transparent: boolean): THREE.MeshStandardMaterial {
  const material = new THREE.MeshStandardMaterial({
    vertexColors: true,
    transparent,
    depthWrite: !transparent,
    roughness: 1,
    metalness: 0,
  });
  material.onBeforeCompile = (shader) => {
    shader.vertexShader = shader.vertexShader
      .replace(
        '#include <common>',
        '#include <common>\nattribute vec2 surface;\nattribute vec3 glow;\nvarying vec2 vSurface;\nvarying vec3 vGlow;',
      )
      .replace('#include <color_vertex>', '#include <color_vertex>\nvSurface = surface;\nvGlow = glow;');
    shader.fragmentShader = shader.fragmentShader
      .replace('#include <common>', '#include <common>\nvarying vec2 vSurface;\nvarying vec3 vGlow;')
      .replace('vec3 totalEmissiveRadiance = emissive;', 'vec3 totalEmissiveRadiance = vGlow;')
      .replace('#include <roughnessmap_fragment>', 'float roughnessFactor = vSurface.x;')
      .replace('#include <metalnessmap_fragment>', 'float metalnessFactor = vSurface.y;');
  };
  material.customProgramCacheKey = () => (transparent ? 'baked-transparent' : 'baked-opaque');
  return material;
}
