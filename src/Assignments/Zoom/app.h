//
// Created by pbialas on 05.08.2020.
//

#pragma once

#include <vector>

#include <glm/glm.hpp>
#include <glm/gtc/constants.hpp>
#include <glm/gtc/matrix_transform.hpp>

#include "glad/gl.h"
#include "Application/application.h"
#include "Application/utils.h"
#include "camera.h"


class SimpleShapeApplication : public xe::Application
{
public:
    SimpleShapeApplication(int width, int height, std::string title, bool debug) : Application(width, height, title, debug) {}

    void init() override;

    void frame() override;
    void framebuffer_resize_callback(int w, int h) override; 
    void scroll_callback(double xoffset, double yoffset) override;
    ~SimpleShapeApplication() {
        if (camera_) {
            delete camera_;
        }
    }

private:
    GLuint vao_;
    std::vector<GLushort> indices;
    GLuint u_pvm_buffer_;

    Camera *camera_;
    void set_camera(Camera *camera) { camera_ = camera; }
    Camera *camera() { return camera_; }
};
float get_color();