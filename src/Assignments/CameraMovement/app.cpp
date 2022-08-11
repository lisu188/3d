//
// Created by pbialas on 25.09.2020.
//

#include "app.h"

#include <iostream>
#include <vector>
#include <tuple>

#include "Application/utils.h"

float get_color(float x = 0.0f) {
    return x / 255.0f;
};


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
        std::cerr << "Invalid program" << std::endl;
        exit(-1);
    }

    // A vector containing the x,y,z vertex coordinates for the triangle.
    std::vector<GLfloat> vertices = {
        // podstawa (0,1,2,3) #ff0080 cyan
        0.0f, 0.0f, 0.0f, get_color(0.0f),get_color(255.0f),get_color(255.0f),
        0.0f, 0.0f, 1.0f, get_color(0.0f),get_color(255.0f),get_color(255.0f),
        1.0f, 0.0f, 0.0f, get_color(0.0f),get_color(255.0f),get_color(255.0f),
        1.0f, 0.0f, 1.0f, get_color(0.0f),get_color(255.0f),get_color(255.0f),

        // FW (4,5,6) #FF0000 RED
        0.0f, 0.0f, 0.0f, get_color(255.0f),get_color(0.0f),get_color(0.0f),
        1.0f, 0.0f, 0.0f, get_color(255.0f),get_color(0.0f),get_color(0.0f),
        0.5f, 1.0f, 0.5f, get_color(255.0f),get_color(0.0f),get_color(0.0f),

        //lw (7,8,9) #00FF00 GREEN
        0.0f, 0.0f, 0.0f, get_color(0.0f),get_color(255.0f),get_color(0.0f),
        0.0f, 0.0f, 1.0f, get_color(0.0f),get_color(255.0f),get_color(0.0f),
        0.5f, 1.0f, 0.5f, get_color(0.0f),get_color(255.0f),get_color(0.0f),
        // bw (10,11,12) #0000FF BLUE
        1.0f, 0.0f, 1.0f,get_color(0.0f),get_color(0.0f),get_color(255.0f),
        0.0f, 0.0f, 1.0f, get_color(0.0f),get_color(0.0f),get_color(255.0f),
        0.5f, 1.0f, 0.5f, get_color(0.0f),get_color(0.0f),get_color(255.0f),

        // RW (13,14,15) #FF0000 YELLOW
        1.0f, 0.0f, 1.0f, get_color(255.0f),get_color(255.0f),get_color(0.0f),
        1.0f, 0.0f, 0.0f, get_color(255.0f),get_color(255.0f),get_color(0.0f),
        0.5f, 1.0f, 0.5f, get_color(255.0f),get_color(255.0f),get_color(0.0f),
    };

    std::vector<GLushort> indices = {
            1,0,2,
            3,1,2,
            5,4,6,
            7,8,9,
            12,11,10,
            13,14,15
    };

    // Generating the buffer and loading the vertex data into it.
    GLuint v_buffer_handle;
    glGenBuffers(1, &v_buffer_handle);
    OGL_CALL(glBindBuffer(GL_ARRAY_BUFFER, v_buffer_handle));
    glBufferData(GL_ARRAY_BUFFER, vertices.size() * sizeof(GLfloat), vertices.data(), GL_STATIC_DRAW);
    glBindBuffer(GL_ARRAY_BUFFER, 0);

    set_camera(new Camera);
    set_controler(new CameraControler(camera()));

    int w, h;
    std::tie(w, h) = frame_buffer_size();
    camera_->perspective(glm::pi<float>() / 4.0f, (float)w / h, 0.1f, 100.0f);

    camera_->look_at(glm::vec3{ 0.0f, 5.0f, 5.0f },
        glm::vec3{ 0.0f, 0.0f, 0.0f },
        glm::vec3{ 0.0f, 0.0f, -1.0f });

    glm::mat4 PVM = camera_->projection() * camera_->view();

    // Generating the buffer and loading the index data into it.
    GLuint indicies_buffer_handle;
    glGenBuffers(1, &indicies_buffer_handle);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, indicies_buffer_handle);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, indices.size() * sizeof(GLushort), indices.data(), GL_STATIC_DRAW);

    // UNIFORM BUFFER
    GLuint uniform_buffer_handle;
    glGenBuffers(1, &uniform_buffer_handle);
    glBindBuffer(GL_UNIFORM_BUFFER, uniform_buffer_handle);
    glBufferData(GL_UNIFORM_BUFFER, 8*sizeof(float), NULL, GL_STATIC_DRAW);
    glBindBufferBase(GL_UNIFORM_BUFFER , 0, uniform_buffer_handle);
    float strength = 1.0;
    float color[3] = {1.0f, 1.0f, 1.0f};
    glBufferSubData(GL_UNIFORM_BUFFER, 0, 1*sizeof(float), &strength);
    glBufferSubData(GL_UNIFORM_BUFFER, 4*sizeof(float), 3*sizeof(float), &color);


    glGenBuffers(1, &u_pvm_buffer_);
    glBindBuffer(GL_UNIFORM_BUFFER, u_pvm_buffer_);
    glBufferData(GL_UNIFORM_BUFFER, sizeof(glm::mat4), NULL, GL_STATIC_DRAW);
    glBindBufferBase(GL_UNIFORM_BUFFER, 1, u_pvm_buffer_);
    glBindBuffer(GL_UNIFORM_BUFFER, 0);

    // This setups a Vertex Array Object (VAO) that  encapsulates
    // the state of all vertex buffers needed for rendering
    glGenVertexArrays(1, &vao_);
    glBindVertexArray(vao_);
    glBindBuffer(GL_ARRAY_BUFFER, v_buffer_handle);

    // tu dodałem linijkę :) // w zadaniu indices
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, indicies_buffer_handle);

    // This indicates that the data for attribute 0 should be read from a vertex buffer.
    glEnableVertexAttribArray(0);
    // and this specifies how the data is layout in the buffer.
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 6 * sizeof(GLfloat), reinterpret_cast<GLvoid *>(0));

    glEnableVertexAttribArray(1);
    glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 6 * sizeof(GLfloat), reinterpret_cast<GLvoid *>(3 * sizeof(GLfloat)));

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

    // Binding the VAO will setup all the required vertex buffers.
    glBindVertexArray(vao_);
    glDrawElements(GL_TRIANGLES, 18, GL_UNSIGNED_SHORT, (void*)0);
    glBindVertexArray(0);
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
