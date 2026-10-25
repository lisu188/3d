# Image size regression checks

Run `python3 tests/run_image_size_regression.py` on a system with GCC, G++ and
AddressSanitizer/UndefinedBehaviorSanitizer. The runner uses a temporary build
directory and downloads no graphics dependencies.

The checks exercise the actual vendored image headers and the screenshot size
helper. They cover 96 PNG round trips across component counts, filters, vertical
flips, padded rows and negative row strides; reject oversized dimensions before
reading the pixel buffer; exercise 16-bit conversion and large stretchy-buffer
capacity calculations; decode a three-frame GIF with restore-previous disposal;
and inject failure into every allocation of a small PNG write. C11 header syntax
is checked separately. The test allocator refuses requests above 1 MiB.

PNG/zlib input is limited to `(INT_MAX - 8) / 2` filtered bytes. This preserves the
existing int-based compressor indices and counts while leaving room for its
temporary compressed data and output framing. Screenshot sizing uses the same
limit. Allocation and capacity failures return the existing failure result.

These checks do not build or run the OpenGL application, exercise a real
framebuffer, or replace a fresh CodeQL analysis of the pull request.
