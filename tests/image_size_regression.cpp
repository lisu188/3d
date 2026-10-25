#include <cassert>
#include <climits>
#include <cstdlib>
#include <cstring>
#include <vector>
#include <cstdio>

static size_t requested_reallocation = 0;
static long fail_after = -1;
static long allocation_attempts = 0;
static bool fail_this_allocation()
{
    const long attempt = allocation_attempts++;
    return fail_after >= 0 && attempt == fail_after;
}
static void *bounded_malloc(size_t bytes)
{
    if (fail_this_allocation() || bytes > 1024 * 1024) return NULL;
    return std::malloc(bytes);
}
static void *bounded_realloc(void *pointer, size_t bytes)
{
    requested_reallocation = bytes;
    if (fail_this_allocation() || bytes > 1024 * 1024) return NULL;
    return std::realloc(pointer, bytes);
}

#define STBIW_REALLOC(pointer, bytes) bounded_realloc(pointer, bytes)
#define STBIW_MALLOC(bytes) bounded_malloc(bytes)
#define STBIW_FREE(pointer) std::free(pointer)
// The capacity arithmetic probe deliberately refuses a huge allocation.
#define STBIW_ASSERT(condition) ((void) 0)
#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "../src/3rdParty/stb/stb_image_write.h"
#define STB_IMAGE_IMPLEMENTATION
#include "../src/3rdParty/stb/stb_image.h"
#include "../src/Application/image_buffer_size.h"

static void png_round_trips()
{
    for (int channels = 1; channels <= 4; ++channels) {
        const int width = 3, height = 2, stride = width * channels + 5;
        std::vector<unsigned char> pixels(stride * height, 0);
        for (int row = 0; row < height; ++row)
            for (int byte = 0; byte < width * channels; ++byte)
                pixels[row * stride + byte] = static_cast<unsigned char>(row * 90 + byte * 7);
        for (int flip = 0; flip <= 1; ++flip)
            for (int backwards = 0; backwards <= 1; ++backwards)
                for (int filter = -1; filter <= 4; ++filter) {
                    stbi_flip_vertically_on_write(flip);
                    stbi_write_force_png_filter = filter;
                    const unsigned char *first = pixels.data() + (backwards ? stride : 0);
                    int length = 0, decoded_width = 0, decoded_height = 0, decoded_channels = 0;
                    unsigned char *png = stbi_write_png_to_mem(first, backwards ? -stride : stride,
                                                             width, height, channels, &length);
                    assert(png != NULL);
                    unsigned char *decoded = stbi_load_from_memory(png, length, &decoded_width,
                                                                  &decoded_height, &decoded_channels, channels);
                    assert(decoded && decoded_width == width && decoded_height == height);
                    for (int row = 0; row < height; ++row) {
                        const int source_row = (flip != backwards) ? height - 1 - row : row;
                        assert(std::memcmp(decoded + row * width * channels,
                                           pixels.data() + source_row * stride, width * channels) == 0);
                    }
                    stbi_image_free(decoded);
                    std::free(png);
                }
    }
}

static void oversized_images_fail_before_reading_pixels()
{
    unsigned char pixel[4] = {0};
    int length = 0;
    assert(!stbi_write_png_to_mem(pixel, 0, INT_MAX, 1, 4, &length));
    assert(!stbi_write_png_to_mem(pixel, 0, 50000, 50000, 4, &length));
    assert(!stbi_write_png_to_mem(pixel, 0, 1, INT_MAX, 1, &length));
    assert(!stbi_write_png_to_mem(pixel, INT_MIN, 1, 1, 1, &length));
    assert(!stbi_write_png_to_mem(pixel, 0, -1, 1, 3, &length));
    assert(!stbi_write_png_to_mem(pixel, 0, 1, 1, 5, &length));
    assert(!stbi_write_png_to_mem(NULL, 0, 1, 1, 3, &length));
    assert(!stbi_zlib_compress(pixel, INT_MAX, &length, 8));
    stbi__uint16 *short_pixels = static_cast<stbi__uint16 *>(std::malloc(sizeof(stbi__uint16)));
    assert(!stbi__convert_format16(short_pixels, 1, 4, 65536U, 65536U));
    assert(!stbi__mul2sizes_valid(2, INT_MAX - 1));
}

static void stretchy_buffer_capacity_is_widened_before_multiplication()
{
    int header[4] = {INT_MAX / 2 + 100, 0, 0, 0};
    void *array = header + 2;
    stbiw__sbgrowf(&array, 1, sizeof(void *));
    const size_t max_items = ((size_t) -1 - sizeof(int) * 2) / sizeof(void *);
    const size_t expected_items = max_items < INT_MAX ? max_items : INT_MAX;
    assert(requested_reallocation == expected_items * sizeof(void *) + sizeof(int) * 2);
    assert(array == header + 2);
}

static void png_allocation_failures_return_without_writing_past_buffers()
{
    unsigned char pixels[32 * 3 * 3];
    for (size_t index = 0; index < sizeof(pixels); ++index)
        pixels[index] = static_cast<unsigned char>(index * 71 + index / 7);
    stbi_flip_vertically_on_write(0);
    stbi_write_force_png_filter = -1;
    int length = 0;
    allocation_attempts = 0;
    unsigned char *png = stbi_write_png_to_mem(pixels, 0, 32, 3, 3, &length);
    assert(png != NULL);
    std::free(png);
    const long attempts = allocation_attempts;
    assert(attempts > 5 && attempts < 2048);
    for (long failure = 0; failure < attempts; ++failure) {
        allocation_attempts = 0;
        fail_after = failure;
        png = stbi_write_png_to_mem(pixels, 0, 32, 3, 3, &length);
        assert(png == NULL);
    }
    fail_after = -1;
    std::printf("checked %ld individual PNG allocation failures\n", attempts);
}

static void gif_multiple_frames_and_disposal_remain_valid()
{
    const unsigned char header[] = {'G','I','F','8','9','a', 1,0,1,0,0x80,0,0, 0,0,0, 255,255,255};
    std::vector<unsigned char> gif(header, header + sizeof(header));
    for (int index = 0; index < 3; ++index) {
        const unsigned char frame[] = {0x21,0xf9,4,12,1,0,0,0,
            0x2c,0,0,0,0,1,0,1,0,0, 2,2,(unsigned char)(index == 1 ? 0x4c : 0x44),1,0};
        gif.insert(gif.end(), frame, frame + sizeof(frame));
    }
    gif.push_back(0x3b);
    int *delays = NULL, width = 0, height = 0, frames = 0, channels = 0;
    unsigned char *decoded = stbi_load_gif_from_memory(gif.data(), (int)gif.size(), &delays,
                                                       &width, &height, &frames, &channels, 3);
    assert(decoded && width == 1 && height == 1 && frames == 3);
    assert(decoded[0] == 0 && decoded[3] == 255 && decoded[6] == 0);
    assert(delays && delays[0] == 10 && delays[1] == 10 && delays[2] == 10);
    stbi_image_free(decoded);
    stbi_image_free(delays);
}

static void screenshot_storage_is_checked_without_allocating()
{
    size_t bytes = 0;
    int stride = 0;
    assert(xe::detail::png_rgb_storage_size(3, 2, bytes, stride));
    assert(bytes == 18 && stride == 9);
    assert(xe::detail::png_rgb_storage_size(4096, 4096, bytes, stride));
    assert(bytes == 4096U * 4096U * 3U);
    assert(!xe::detail::png_rgb_storage_size(INT_MAX, 1, bytes, stride));
    assert(!xe::detail::png_rgb_storage_size(50000, 50000, bytes, stride));
    assert(!xe::detail::png_rgb_storage_size(0, 1, bytes, stride));
    assert(!xe::detail::png_rgb_storage_size(1, -1, bytes, stride));
}

int main()
{
    png_round_trips();
    oversized_images_fail_before_reading_pixels();
    stretchy_buffer_capacity_is_widened_before_multiplication();
    png_allocation_failures_return_without_writing_past_buffers();
    gif_multiple_frames_and_disposal_remain_valid();
    screenshot_storage_is_checked_without_allocating();
    std::puts("image size regression checks passed");
}
