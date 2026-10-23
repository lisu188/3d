# Black Hole Flyby — self-consistent N-body orbits (Godot 4.4)

This project simulates the gravitational response of the **Sun, Earth, Moon, and an incoming 10-solar-mass black hole**. It replaces the old hand-keyframed distances with actual integrations of Newton's mutual four-body equations.

## Physical model and reproducibility

* **Four mutually gravitating point masses.** Their adopted gravitational parameters are JPL DE440/DE441 values for the Sun, Earth, and Moon, and ten times the Sun's parameter for the black hole.
* **Epoch:** 2026-10-23 00:00 **TDB**, when JPL Horizons geometric vectors are available. The optional fallback uses explicitly *idealized* circular orbital initial conditions, **not historical ephemerides**. The generated `data/four_body.json` identifies the actual source used.
* **Reference frame:** solar-system-barycentric, ICRF Cartesian coordinates (where available); the black hole is added as a hypothetical fourth gravitating body.
* **Encounter:** black hole initially 0.8 au radially outward from Earth, plus a 0.38 au transverse offset and 0.006 au normal offset, travelling radially inward at 200 km/s relative to the initial Sun. This is a **specified hypothetical initial state**, not an observation or guaranteed impact trajectory.
* **Integration:** SciPy's adaptive eighth-order DOP853, relative tolerance `3×10⁻¹¹`, 20 mm absolute position tolerance, 20 nm/s velocity tolerance, max internal step 2 h. Output 1201 physical state vectors covering 15 days and cubic Hermite interpolation in Godot using 64-bit scalar positions and velocities.
* **Physical-time playback:** 15 days compressed to 80 seconds of screen time; the camera's apparent sizes and optical distortions are deliberately stylized. Trajectory panels, distances, and two-body energy diagnostics are computed from the trajectory, not hand-animated.
* **Conservation checks:** `data/four_body.json` contains recorded total energy, linear/angular momentum drift and a repeat integration with tenfold tighter error tolerances. For the deterministic idealized initialization, total relative energy drift was ≈1.4×10⁻¹⁵ and position differences from the tighter integration stayed below 0.4 m. These figures apply **to the numerical four-body model**, not to astronomical prediction error.

## What the visualization shows

The main view has the curved Earth limb and background Sun/Moon as context. Their illustrative sizes and positions **are not sky ephemerides**. The right-hand diagrams are the physical simulation: an inertial view of the Sun/Earth/black-hole and a geocentric view of the lunar trajectory. Colored trails are from numerical integrations, with future paths shown faintly. The blue reference circle in the lunar plot marks Earth's usual lunar orbital radius.

The instantaneous Earth-relative Moon specific orbital energy is diagnostic only: positive instantaneous energy does not guarantee permanent escape in an active four-body gravitational encounter. For an accurate long-term escape verdict, integration would have to be extended until the encounter's tidal interactions become negligible.

The baseline without the black hole is integrated separately from the same initial Sun/Earth/Moon state. Absolute displacements between perturbed and unperturbed simulations are stored in the report, including the Sun's displacement.

## Limits of accuracy

This is a high-accuracy numerical solution of the **specified Newtonian point-mass problem**, **not** an exact prediction of real-world trajectories. It omits the other planets, extended-body tides, lunar/Earth collisions and material deformation, solar mass multipoles, relativistic corrections, gravitational waves, and the uncertainty in a hypothetical black hole's initial state. If Earth and Moon or other modeled bodies collide, the generator aborts rather than silently continuing through an invalid point-mass passage.

## Run

Requirements: Python 3.10+, `numpy`, `scipy`, and Godot 4.4+.

```bash
python -m pip install numpy scipy
cd black-hole-flyby
python scripts/generate_orbits.py --initial horizons --epoch '2026-10-23 00:00' --output data/four_body.csv --reference-validation
godot --path .
```

Without internet access, use `--initial idealized` and treat the outcome as an explicitly idealized experiment.

Controls: Space pause/resume, Left/Right ±3 seconds, `1`–`5` animation stages, R restart, click/drag the timeline. `-- --capture-dir=/absolute/path` exports four real Godot screenshots.

The GitHub Actions workflow validates the generated data, tests the existing physics formulas, renders four frames, exports the full 80-second film at 1280×720, 15 fps and converts the result to H.264 MP4.

## Primary references

* [NASA/JPL astrodynamic gravitational parameters](https://ssd.jpl.nasa.gov/astro_par.html)
* [NASA/JPL Horizons API](https://ssd-api.jpl.nasa.gov/doc/horizons.html)
* [JPL Horizons user manual](https://ssd.jpl.nasa.gov/horizons/manual.html)
* [DOP853 method implemented in SciPy solve_ivp](https://docs.scipy.org/doc/scipy/reference/generated/scipy.integrate.solve_ivp.html)

Original inspiration: ["What if a black hole passed by Earth?"](https://www.youtube.com/shorts/9KLW4rp-ou8).