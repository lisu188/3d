from __future__ import annotations

import argparse
import datetime as dt
import csv
import json
import math
import re
import urllib.parse
import urllib.request
from pathlib import Path

import numpy as np
from scipy.integrate import solve_ivp

AU_M = 149597870700.0
DAY_S = 86400.0
GMS = np.array([1.32712440041279419e20, 398600.435507e9, 4902.800118e9, 1.32712440041279419e21], dtype=np.float64)
NAMES = ('Sun', 'Earth', 'Moon', 'BlackHole')
EARTH_RADIUS = 6371008.4
MOON_RADIUS = 1737400.0
SUN_RADIUS = 695700000.0
C = 299792458.0
EPOCH_DEFAULT = '2026-10-23 00:00'
DURATION_DAYS = 15.0
SAMPLES = 1200
API_URL = 'https://ssd.jpl.nasa.gov/api/horizons.api'


def get_horizons_vector(body_id: str, epoch: str) -> np.ndarray:
    args = {
        'format': 'text', 'COMMAND': f"'{body_id}'", 'OBJ_DATA': "'NO'", 'MAKE_EPHEM': "'YES'",
        'EPHEM_TYPE': "'VECTORS'", 'CENTER': "'500@0'", 'START_TIME': f"'{epoch}'",
        'STOP_TIME': f"'{(dt.datetime.strptime(epoch, '%Y-%m-%d %H:%M') + dt.timedelta(days=1)).strftime('%Y-%m-%d %H:%M')}'", 'STEP_SIZE': "'1 d'", 'TIME_TYPE': "'TDB'",
        'VEC_TABLE': "'2'", 'VEC_LABELS': "'NO'", 'VEC_CORR': "'NONE'",
        'OUT_UNITS': "'KM-S'", 'REF_PLANE': "'FRAME'", 'REF_SYSTEM': "'ICRF'",
        'CSV_FORMAT': "'YES'", 'TIME_DIGITS': "'FRACSEC'"
    }
    url = API_URL + '?' + urllib.parse.urlencode(args)
    req = urllib.request.Request(url, headers={'User-Agent': 'Godot-NBody-Gravity-Study/1.0'})
    with urllib.request.urlopen(req, timeout=40) as response:
        content = response.read().decode('utf-8')
    if '$$SOE' not in content or '$$EOE' not in content:
        raise RuntimeError(f'Horizons did not provide vectors for {body_id}: {content[-1800:]}')
    block = content.split('$$SOE', 1)[1].split('$$EOE', 1)[0]
    numbers = []
    for line in block.splitlines():
        pieces = line.strip().split(',')
        if len(pieces) >= 8:
            try:
                numbers = [float(piece.replace('D', 'E').strip()) for piece in pieces[2:8]]
                break
            except ValueError:
                pass
    if len(numbers) != 6:
        raise RuntimeError(f'Unrecognized JPL Cartesian vector for {body_id}: {block[:700]}')
    vector = np.array(numbers, dtype=np.float64)
    vector[:3] *= 1000.0
    vector[3:] *= 1000.0
    return vector


def initial_state(mode: str, epoch: str, impact_offset_au: float) -> tuple[np.ndarray, str]:
    bodies = np.zeros((4, 6), dtype=np.float64)
    if mode == 'horizons':
        for i, body_id in enumerate(('10', '399', '301')):
            bodies[i] = get_horizons_vector(body_id, epoch)
        source = f'JPL Horizons barycentric ICRF geometric vectors, {epoch} TDB, Sun=10 Earth=399 Moon=301'
    elif mode == 'idealized':
        bodies[1, :3] = (AU_M, 0.0, 0.0)
        tilt = math.radians(5.145)
        bodies[2, :3] = bodies[1, :3] + np.array((0.0, 384400000.0 * math.cos(tilt), 384400000.0 * math.sin(tilt)))
        bodies[1, 3:] = (0.0, 29784.6918, 0.0)
        bodies[2, 3:] = bodies[1, 3:] + np.array((-1018.3, 0.0, 0.0))
        bodies[0, 3:] = -(GMS[1] * bodies[1, 3:] + GMS[2] * bodies[2, 3:]) / GMS[0]
        source = 'Idealized initial circular Sun-Earth-Moon orbits; not dated ephemerides'
    else:
        raise ValueError(f'Unsupported mode: {mode}')
    radial = bodies[1, :3] - bodies[0, :3]
    radial /= np.linalg.norm(radial)
    orbital_velocity = bodies[1, 3:] - bodies[0, 3:]
    tangential = orbital_velocity - radial * np.dot(orbital_velocity, radial)
    tangential /= np.linalg.norm(tangential)
    normal = np.cross(radial, tangential)
    normal /= np.linalg.norm(normal)
    bodies[3, :3] = bodies[1, :3] + AU_M * (0.8 * radial + impact_offset_au * tangential + 0.006 * normal)
    bodies[3, 3:] = bodies[0, 3:] - 200000.0 * radial
    return bodies, source


def derivative(_: float, flat: np.ndarray, gms: np.ndarray) -> np.ndarray:
    state = flat.reshape(4, 6)
    deltas = state[np.newaxis, :, :3] - state[:, np.newaxis, :3]
    r2 = np.einsum('ijk,ijk->ij', deltas, deltas)
    np.fill_diagonal(r2, np.inf)
    inv_r3 = 1.0 / (r2 * np.sqrt(r2))
    acceleration = np.einsum('ij,ijk,j->ik', inv_r3, deltas, gms)
    out = np.empty_like(state)
    out[:, :3] = state[:, 3:]
    out[:, 3:] = acceleration
    return out.ravel()


def invariants(state: np.ndarray, gms: np.ndarray) -> tuple[float, np.ndarray, np.ndarray]:
    energy_times_g = 0.5 * np.sum(gms * np.einsum('ij,ij->i', state[:, 3:], state[:, 3:]))
    for i in range(4):
        for j in range(i + 1, 4):
            distance = np.linalg.norm(state[i, :3] - state[j, :3])
            energy_times_g -= gms[i] * gms[j] / distance
    linear_momentum_times_g = np.sum(gms[:, None] * state[:, 3:], axis=0)
    angular_momentum_times_g = np.sum(gms[:, None] * np.cross(state[:, :3], state[:, 3:]), axis=0)
    return energy_times_g, linear_momentum_times_g, angular_momentum_times_g


def run_solver(initial: np.ndarray, gms: np.ndarray, duration_days: float, samples: int, tolerance: float):
    duration = duration_days * DAY_S
    points = np.linspace(0.0, duration, samples + 1)
    tolerances = np.tile(np.array((0.02, 0.02, 0.02, 2e-8, 2e-8, 2e-8), dtype=np.float64), 4)
    solution = solve_ivp(derivative, (0.0, duration), initial.ravel(), args=(gms,), method='DOP853',
                         t_eval=points, rtol=tolerance, atol=tolerances, max_step=7200.0)
    if not solution.success:
        raise RuntimeError(f'Integration failed: {solution.message}')
    return points, np.transpose(solution.y, (1, 0)).reshape((-1, 4, 6)), solution.nfev


def measure(states: np.ndarray) -> dict:
    sun, earth, moon, hole = (states[:, i, :] for i in range(4))
    rel_moon = moon[:, :3] - earth[:, :3]
    moon_distance = np.linalg.norm(rel_moon, axis=1)
    rel_bh = hole[:, :3] - earth[:, :3]
    hole_distance = np.linalg.norm(rel_bh, axis=1)
    sun_distance = np.linalg.norm(sun[:, :3] - earth[:, :3], axis=1)
    moon_speed = np.linalg.norm(moon[:, 3:] - earth[:, 3:], axis=1)
    moon_specific_energy = 0.5 * moon_speed * moon_speed - (GMS[1] + GMS[2]) / moon_distance
    tidal_ratio = 2 * GMS[3] * EARTH_RADIUS / hole_distance ** 3 / 9.80665
    return {
        'closest_black_hole_to_earth_km': float(hole_distance.min() / 1000),
        'closest_earth_moon_km': float(moon_distance.min() / 1000),
        'maximum_earth_moon_km': float(moon_distance.max() / 1000),
        'final_earth_sun_au': float(sun_distance[-1] / AU_M),
        'final_moon_orbital_energy_j_kg': float(moon_specific_energy[-1]),
        'lunar_bound_at_end_two_body_diagnostic': bool(moon_specific_energy[-1] < 0),
        'max_black_hole_earth_tidal_g': float(tidal_ratio.max()),
    }


def generate(args: argparse.Namespace) -> dict:
    initial, source = initial_state(args.initial, args.epoch, args.impact_offset_au)
    times, states, evaluations = run_solver(initial, GMS, args.duration_days, args.samples, args.rtol)
    earth_moon = np.linalg.norm(states[:, 1, :3] - states[:, 2, :3], axis=1)
    sun_bh = np.linalg.norm(states[:, 0, :3] - states[:, 3, :3], axis=1)
    if np.min(earth_moon) <= EARTH_RADIUS + MOON_RADIUS:
        raise RuntimeError('Earth/Moon collision occurs: point-mass model cannot continue reliably')
    if np.min(sun_bh) <= SUN_RADIUS + (2 * GMS[3] / C ** 2):
        raise RuntimeError('Black hole intersects Sun: point-mass model invalid')
    e0, p0, l0 = invariants(states[0], GMS)
    e1, p1, l1 = invariants(states[-1], GMS)
    energy_error = abs((e1 - e0) / e0)
    momentum_error = float(np.linalg.norm(p1 - p0) / np.sum(GMS * np.linalg.norm(initial[:, 3:], axis=1)))
    angular_momentum_error = float(np.linalg.norm(l1 - l0) / np.linalg.norm(l0))
    if not np.all(np.isfinite(states)) or energy_error > args.max_energy_error:
        raise RuntimeError(f'Conservation check failed: relative energy drift {energy_error:.3e}')
    _, without_bh, _ = run_solver(initial, np.array((GMS[0], GMS[1], GMS[2], 0.0)), args.duration_days, args.samples, args.rtol)
    separation_control = np.linalg.norm(without_bh[-1, :, :3] - states[-1, :, :3], axis=1) / 1000
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open('w', encoding='utf-8', newline='') as fp:
        writer = csv.writer(fp, lineterminator='\n')
        writer.writerow(['days'] + [f'{name}.{component}' for name in NAMES for component in ('x_au', 'y_au', 'z_au', 'vx_au_day', 'vy_au_day', 'vz_au_day')])
        for time, state in zip(times, states):
            vals = []
            for body in state:
                vals.extend(body[:3] / AU_M)
                vals.extend(body[3:] * DAY_S / AU_M)
            writer.writerow([f'{time / DAY_S:.10f}'] + [f'{v:.15e}' for v in vals])
    result = {
        'model': 'Newtonian mutual gravity, four point masses, no post-Newtonian corrections, no material deformation',
        'ephemeris_source': source,
        'epoch_tdb': args.epoch if args.initial == 'horizons' else 'not tied to any civil date',
        'initial_conditions': {name: {'position_m': [float(v) for v in initial[i, :3]], 'velocity_m_s': [float(v) for v in initial[i, 3:]]} for i, name in enumerate(NAMES)},
        'gravitational_parameters_m3_s2': {name: float(GMS[i]) for i, name in enumerate(NAMES)},
        'sun_mass_equivalent_black_hole': 10.0,
        'incoming_heliocentric_radial_velocity_m_s': -200000.0,
        'initial_radial_offset_au': 0.8,
        'initial_tangential_offset_au': args.impact_offset_au,
        'initial_out_of_plane_offset_au': 0.006,
        'duration_days': args.duration_days,
        'samples': args.samples,
        'integrator': 'scipy.integrate.solve_ivp(DOP853) - adaptive order-8, max step 7200 s',
        'rtol': args.rtol,
        'position_atol_m': 0.02,
        'velocity_atol_m_s': 2e-8,
        'rhs_evaluations': evaluations,
        'relative_energy_drift': float(energy_error),
        'relative_momentum_drift': momentum_error,
        'relative_angular_momentum_drift': angular_momentum_error,
        'orbit_perturbation_km_at_end_vs_without_bh': {name: float(separation_control[i]) for i, name in enumerate(NAMES[:3])},
        'physical_limits': ['no Sun internal deformation', 'no tides/solid-body hydrodynamics', 'no full general relativity', 'the comparison scenario includes only Sun Earth Moon, not all other planets'],
    }
    result.update(measure(states))
    report_path = output.with_suffix('.json')
    report_path.write_text(json.dumps(result, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
    if args.reference_validation:
        times_hi, states_hi, _ = run_solver(initial, GMS, args.duration_days, args.samples, min(args.rtol * 0.1, 1e-12))
        result['max_position_difference_m_vs_tighter_tolerance'] = float(np.max(np.linalg.norm(states[:, :, :3] - states_hi[:, :, :3], axis=2)))
        report_path.write_text(json.dumps(result, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
    print(json.dumps({k: v for k, v in result.items() if k in (
        'ephemeris_source', 'relative_energy_drift', 'relative_momentum_drift',
        'closest_black_hole_to_earth_km', 'closest_earth_moon_km',
        'maximum_earth_moon_km', 'lunar_bound_at_end_two_body_diagnostic',
        'orbit_perturbation_km_at_end_vs_without_bh',
        'max_position_difference_m_vs_tighter_tolerance')}, indent=2))
    return result


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description='Accurate numerical four-body flyby scenario for Godot')
    parser.add_argument('--initial', choices=('horizons', 'idealized'), default='idealized')
    parser.add_argument('--epoch', default=EPOCH_DEFAULT)
    parser.add_argument('--duration-days', type=float, default=DURATION_DAYS)
    parser.add_argument('--samples', type=int, default=SAMPLES)
    parser.add_argument('--impact-offset-au', type=float, default=0.38)
    parser.add_argument('--rtol', type=float, default=3e-11)
    parser.add_argument('--max-energy-error', type=float, default=3e-9)
    parser.add_argument('--output', default='data/four_body.csv')
    parser.add_argument('--reference-validation', action='store_true')
    return parser.parse_args()


if __name__ == '__main__':
    generate(parse_args())