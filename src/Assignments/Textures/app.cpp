//
// Created by pbialas on 25.09.2020.
//

#include "app.h"

#include <iostream>
#include <vector>
#include <tuple>

#include "Application/utils.h"

#include "3rdParty/stb/stb_image.h"

// export GALLIUM_DRIVER=llvmpipe !!!

void SimpleShapeApplication::init()
{
    // A utility function that reads the shader sources, compiles them and creates the program object
    // As everything in OpenGL we reference program by an integer "handle".
    auto program = xe::utils::create_program(
        {{GL_VERTEX_SHADER, std::string(PROJECT_DIR) + "/shaders/base_vs.glsl"},
         {GL_FRAGMENT_SHADER, std::string(PROJECT_DIR) + "/shaders/base_fs.glsl"}});

    if (!program)
    {
        std::cerr << "Invalid program1" << std::endl;
        exit(-1);
    }

    xe::ColorMaterial::init();

    stbi_set_flip_vertically_on_load(true);
    GLint width, height, channels;
    auto texture_file = std::string(ROOT_DIR) + "/Models/multicolor.png";
    auto img = stbi_load(texture_file.c_str(), &width, &height, &channels, 0);
    if (!img) {
        // spdlog::warn("Could not read image from file `{}'", texture_file); // no spdlog lib
        std::cerr << "Invalid program2" << std::endl;
    }
    GLuint textures_ptr;
    glGenTextures(1, &textures_ptr);
    glBindTexture(GL_TEXTURE_2D, textures_ptr);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, width, height, 0, GL_RGB, GL_UNSIGNED_BYTE, img);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glBindTexture(GL_TEXTURE_2D, 0);

    // A vector containing the x,y,z vertex coordinates for the triangle.
    std::vector<GLfloat> vertices = {
        // F
        -0.5f, -0.5f, -0.5f,    0.191f, 0.5f,
        0.0f, 0.5f, 0.0f,       0.0f, 1.0f,
        0.5f, -0.5f, -0.5f,     0.5f, 0.809f,
        // L
        -0.5f, -0.5f, 0.5f,     0.5f, 0.809f,
        0.0f, 0.5f, 0.0f,       1.0f, 1.0f,
        -0.5f, -0.5f, -0.5f,    0.809f, 0.5f,
        // R
        0.5f, -0.5f, -0.5f,     0.5f, 0.191f,
        0.0f, 0.5f, 0.0f,       0.0f, 0.0f,
        0.5f, -0.5f, 0.5f,      0.191f, 0.5f,
        // B
        0.5f, -0.5f, 0.5f,      0.809f, 0.5f,
        0.0f, 0.5f, 0.0f,       1.0f, 0.0f,
        -0.5f, -0.5f, 0.5f,     0.5f, 0.191f,
        // D1
        -0.5f, -0.5f, -0.5f,    0.191f, 0.5f,
        0.5f, -0.5f, -0.5f,     0.5f, 0.809f,
        -0.5f, -0.5f, 0.5f,     0.5f, 0.191f,
        // D2
        0.5f, -0.5f, 0.5f,      0.809f, 0.5f,
        -0.5f, -0.5f, 0.5f,     0.5f, 0.809f,
        0.5f, -0.5f, -0.5f,     0.5f, 0.191f,
    };

    indices = {
        0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17
    };

    // MeshesMaterials
    auto pyramid = new xe::Mesh;
    pyramid->allocate_vertex_buffer(vertices.size() * sizeof(GLfloat), GL_STATIC_DRAW);
    pyramid->load_vertices(0, vertices.size() * sizeof(GLfloat), vertices.data());
    pyramid->vertex_attrib_pointer(0, 3, GL_FLOAT, 5 * sizeof(GLfloat), 0);
    pyramid->vertex_attrib_pointer(1, 2, GL_FLOAT, 5 * sizeof(GLfloat), 3 * sizeof(GLfloat));
    //GLuint index, GLuint size, GLenum type, GLsizei stride, GLsizei offset

    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 6 * sizeof(GLfloat), reinterpret_cast<GLvoid *>(0));

    glEnableVertexAttribArray(1);
    glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 6 * sizeof(GLfloat), reinterpret_cast<GLvoid *>(3 * sizeof(GLfloat)));

    pyramid->allocate_index_buffer(indices.size() * sizeof(GLfloat), GL_STATIC_DRAW);
    pyramid->load_indices(0, indices.size() * sizeof(GLfloat), indices.data());

    pyramid->add_submesh(0, 3, new xe::ColorMaterial(   textures_ptr, 0) );
    pyramid->add_submesh(3, 6, new xe::ColorMaterial(   textures_ptr, 1) );
    pyramid->add_submesh(6, 9, new xe::ColorMaterial(   textures_ptr, 2) );
    pyramid->add_submesh(9, 12, new xe::ColorMaterial(  textures_ptr, 3) );
    pyramid->add_submesh(12, 18, new xe::ColorMaterial( textures_ptr, 4) ); 
    add_submesh(pyramid);

    // UNIFORM BUFFER
    GLuint uniform_buffer;
    glGenBuffers(1, &uniform_buffer);
    glBindBuffer(GL_UNIFORM_BUFFER, uniform_buffer);
    glBufferData(GL_UNIFORM_BUFFER, 8*sizeof(float), NULL, GL_STATIC_DRAW);
    glBindBufferBase(GL_UNIFORM_BUFFER , 0, uniform_buffer);
    float strength = 1.0;
    float color[3] = {1.0f, 1.0f, 1.0f};
    glBufferSubData(GL_UNIFORM_BUFFER, 0, 1*sizeof(float), &strength);
    glBufferSubData(GL_UNIFORM_BUFFER, 4*sizeof(float), 3*sizeof(float), &color);

    // PWM
    set_camera(new Camera);
    set_controler(new CameraControler(camera()));

    int w, h;
    std::tie(w, h) = frame_buffer_size();
    camera_->perspective(glm::pi<float>()/4.0f, (float)w/h, 0.1f, 100.0f);
    
    camera_->look_at(glm::vec3{0.0f, 5.0f, 5.0f},
        glm::vec3{0.0f, 0.0f, 0.0f},
        glm::vec3{0.0f, 0.0f, -1.0f});

    glm::mat4 PVM = camera_->projection() * camera_->view();

    glGenBuffers(1, &u_pvm_buffer_);
    glBindBuffer(GL_UNIFORM_BUFFER, u_pvm_buffer_);
    glBufferData(GL_UNIFORM_BUFFER, sizeof(glm::mat4), NULL, GL_STATIC_DRAW);
    glBindBufferBase(GL_UNIFORM_BUFFER, 1, u_pvm_buffer_);
    glBindBuffer(GL_UNIFORM_BUFFER, 0);

    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindVertexArray(0);
    //end of vao "recording"

    // Setting the background color of the rendering window,
    // I suggest not to use white or black for better debuging.
    glClearColor(0.81f, 0.81f, 0.8f, 1.0f);

    // This setups an OpenGL vieport of the size of the whole rendering window.

    glViewport(0, 0, w, h);

    glEnable(GL_DEPTH_TEST);
    glEnable(GL_CULL_FACE);
    glUseProgram(program);
}

//This functions is called every frame and does the actual rendering.
void SimpleShapeApplication::frame()
{
    glm::mat4 PVM = camera_->projection() * camera_->view();
    glBindBuffer(GL_UNIFORM_BUFFER, u_pvm_buffer_);
    glBufferSubData(GL_UNIFORM_BUFFER, 0, sizeof(glm::mat4), &PVM[0]);
    glBindBufferBase(GL_UNIFORM_BUFFER, 1, u_pvm_buffer_);
    glBindBuffer(GL_UNIFORM_BUFFER, 0);

    // MeshesMaterials
    for (auto m: meshes_) {
        m->draw();
    }
}

void SimpleShapeApplication::framebuffer_resize_callback(int w, int h) {
    Application::framebuffer_resize_callback(w, h);
    glViewport(0,0,w,h); 
    // P_ = glm::perspective(fov_, aspect_, near_, far_);
    camera_->set_aspect((float) w / h);
}

void SimpleShapeApplication::scroll_callback(double xoffset, double yoffset)  {
         Application::scroll_callback(xoffset, yoffset);   
         camera()->zoom(yoffset / -30.0f);
     }
void SimpleShapeApplication::mouse_button_callback(int button, int action, int mods) {
    Application::mouse_button_callback(button, action, mods);

    if (controler_) {
        double x, y;
        glfwGetCursorPos(window_, &x, &y);

        if (button == GLFW_MOUSE_BUTTON_LEFT && action == GLFW_PRESS)
            controler_->LMB_pressed(x, y);

        if (button == GLFW_MOUSE_BUTTON_LEFT && action == GLFW_RELEASE)
            controler_->LMB_released(x, y);
    }

}

void SimpleShapeApplication::cursor_position_callback(double x, double y) {
    Application::cursor_position_callback(x, y);
    if (controler_) {
        controler_->mouse_moved(x, y);
    }
}
