import numpy as np
from scipy.ndimage import gaussian_filter, map_coordinates
from PIL import Image
from pathlib import Path

rng = np.random.default_rng(20261025)
n = 512
y, x = np.mgrid[:n, :n].astype(np.float32)
x = (x - (n - 1) / 2) / (n / 2)
y = (y - (n - 1) / 2) / (n / 2)
r = np.sqrt(x * x + y * y)
valid = r <= 0.999
z = np.sqrt(np.maximum(0.0, 1.0 - r * r))
rough = np.zeros((n, n), dtype=np.float32)
for scale, amp in [(65, 0.08), (24, 0.055), (7, 0.033), (2.5, 0.020)]:
    rough += gaussian_filter(rng.normal(size=(n, n)).astype(np.float32), scale) * amp * scale
albedo = np.full((n,n),0.46,dtype=np.float32) + rough
for i in range(175):
    center = rng.uniform(-0.93, 0.93, size=2)
    if center @ center >= 0.92:
        continue
    radius = np.exp(rng.uniform(np.log(0.008), np.log(0.070)))
    rx = (x-center[0]) / radius
    ry = (y-center[1]) / radius
    dist = np.sqrt(rx*rx + ry*ry)
    albedo += np.exp(-((dist-1.05)/0.12)**2) * 0.035
    albedo -= np.exp(-(dist / 0.68)**4) * 0.04
albedo = np.clip(albedo, 0.11, 0.82)
shape = (0.91 + 0.08 * z)
rgb = np.stack([albedo * 0.99, albedo * 0.98, albedo * 0.97], axis=-1) * shape[...,None]
alpha = np.clip((1.0-r)*90.0,0.0,1.0) * valid
out = np.uint8(np.clip(np.concatenate([rgb,alpha[...,None]],axis=-1)*255.0,0,255))
Image.fromarray(out,"RGBA").save(Path(__file__).resolve().parent.parent / 'assets' / 'moon-disk.png')
