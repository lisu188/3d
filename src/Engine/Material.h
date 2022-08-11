//
// Created by Piotr Białas on 02/11/2021.
//

#pragma once

#include <glad/gl.h>
#include <glm/glm.hpp>

#include "Application/utils.h"

namespace xe {

    GLuint create_texture(const std::string &name);

    class Material {
    public:
        virtual void bind() = 0;

        virtual void unbind() {};
    };

    class ColorMaterial : public Material {
    public:
        ColorMaterial(const glm::vec4 color) : color_(color) {
            texture_ = 0;
            texture_unit_ = 0;
        }
        ColorMaterial(const GLuint texture, GLuint texture_unit) {
            color_ = {1.0f, 1.0f, 1.0f, 0.8f};
            texture_ = texture;
            texture_unit_ = texture_unit;
        }

        void bind();
        void unbind();

        static void init();

        static GLuint program() { return shader_; }

        GLuint texture() { return texture_;};
        void texture(GLuint t) { texture_ = t; }

        GLuint texture_unit() { return texture_unit_;};
        void texture_unit(GLuint t) { texture_unit_ = t; }

    private:
        static GLuint shader_;
        static GLuint color_uniform_buffer_;

        glm::vec4 color_;

        static GLint uniform_map_Kd_location_;
        GLuint texture_;
        GLuint texture_unit_;
    };


}


