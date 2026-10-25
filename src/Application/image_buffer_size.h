#pragma once

#include <climits>
#include <cstddef>

namespace xe {
namespace detail {

inline bool png_rgb_storage_size(int width, int height, std::size_t &bytes, int &stride)
{
    if (width <= 0 || height <= 0 || width > (INT_MAX - 1) / 3)
        return false;
    stride = width * 3;
    if (height > ((INT_MAX - 8) / 2) / (stride + 1))
        return false;
    bytes = static_cast<std::size_t>(stride) * static_cast<std::size_t>(height);
    return true;
}

}
}
