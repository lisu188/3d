#!/usr/bin/env python3
"""Run bounded image/header checks without downloading graphics dependencies."""
from pathlib import Path
import os
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="image-size-regression-") as directory:
    executable = Path(directory) / "image-size-regression"
    subprocess.run([os.environ.get("CXX", "g++"), "-std=c++17", "-O1", "-g",
                    "-fsanitize=address,undefined", "-fno-sanitize-recover=all",
                    "-fno-omit-frame-pointer", str(root / "tests/image_size_regression.cpp"),
                    "-o", str(executable)], check=True)
    subprocess.run([str(executable)], check=True)
    smoke = Path(directory) / "headers.c"
    smoke.write_text('#define STB_IMAGE_IMPLEMENTATION\n#include "stb_image.h"\n'
                     '#define STB_IMAGE_WRITE_IMPLEMENTATION\n#include "stb_image_write.h"\n')
    subprocess.run([os.environ.get("CC", "gcc"), "-std=c11", "-fsyntax-only",
                    "-I", str(root / "src/3rdParty/stb"), str(smoke)], check=True)
