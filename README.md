# 3D Graphics Coursework

A university coursework archive for introductory **C++ / OpenGL / CMake** graphics-programming exercises.

## Provenance

This repository is based on the course starter project originally provided by **Krzysztof Przystalski** (`kprzystalski/3d`). The starter supplied the OpenGL/CMake scaffolding and assignment structure; this repository was used as my working copy for course exercises.

It is kept public as a historical record of graphics-programming study, **not** as an independently authored graphics engine or portfolio flagship.

## Contents

- `Assignments/` and `src/` — coursework exercises and supporting code
- `javascript/` — related browser/graphics experiments
- `scripts/` — helper tooling used while working through assignments
- `CMakeLists.txt` — project build configuration inherited/evolved from the course starter

## Build

The project uses CMake and expects a C++17-capable toolchain plus the graphics dependencies configured by the starter project.

Typical command-line workflow:

```bash
mkdir -p build
cd build
cmake ..
cmake --build .
```

## Status

**Historical coursework / archived experiment.** For current engineering work, see the actively maintained repositories on my GitHub profile such as `fall-of-nouraajd`, `clash-disassembly`, `clash-hd` and `winrisk`.
