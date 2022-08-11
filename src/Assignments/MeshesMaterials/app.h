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
#include "camera_controler.h"
#include "Engine/Mesh.h"
#include "Engine/Material.h"


class SimpleShapeApplication : public xe::Application
{
public:
    SimpleShapeApplication(int width, int height, std::string title, bool debug) : Application(width, height, title, debug) {}

    void init() override;

    void frame() override;
    void framebuffer_resize_callback(int w, int h) override; 
    void scroll_callback(double xoffset, double yoffset) override;
    void mouse_button_callback(int button, int action, int mods) override;
    void cursor_position_callback(double x, double y) override;
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
    CameraControler *controler_;
    void set_controler(CameraControler *controler) { controler_ = controler; }
    
    std::vector<xe::Mesh*> meshes_;
    void add_submesh(xe::Mesh *mesh) {
        meshes_.push_back(mesh);
    }
};