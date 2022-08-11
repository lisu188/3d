//
// Created by pbialas on 25.09.2020.
//

#include "app.h"

#include <iostream>
#include <vector>
#include <tuple>
#include <glm/glm.hpp>
#include <glm/gtc/constants.hpp>

#include "Application/utils.h"

float get_color(float x = 0.0f) {
    return x / 255.0f;
};

void SimpleShapeApplication::init()
{
    // A utility function that reads the shader sources, compiles them and creates the program object
    // As everything in OpenGL we reference program by an integer "handle".
    auto program = xe::utils::create_program(
        { {GL_VERTEX_SHADER, std::string(PROJECT_DIR) + "/shaders/base_vs.glsl"},
         {GL_FRAGMENT_SHADER, std::string(PROJECT_DIR) + "/shaders/base_fs.glsl"} });

    if (!program)
    {
        std::cerr << "Invalid program" << std::endl;
        exit(-1);
    }

    // A vector containing the x,y,z vertex coordinates for the triangle.
    std::vector<GLfloat> vertices = {
        -0.5f, 0.0f, 0.0f,      get_color(255.0f), get_color(0.0f), get_color(0.0f), 
        0.5f, 0.0f, 0.0f,       get_color(255.0f), get_color(0.0f), get_color(0.0f), 
        0.0f, 0.5f, 0.0f,       get_color(255.0f), get_color(0.0f), get_color(0.0f),

        -0.5f, 0.0f, 0.0f,      get_color(0.0f), get_color(255.0f), get_color(0.0f),
        0.5f, 0.0f, 0.0f,       get_color(0.0f), get_color(255.0f), get_color(0.0f),
        -0.5f, -0.5f, 0.0f,     get_color(0.0f), get_color(255.0f), get_color(0.0f),

        0.5f, -0.5f, 0.0f,      get_color(0.0f), get_color(255.0f), get_color(0.0f),
    };

    std::vector<GLushort> indices = {
        0,1,2,3,4,5,4,5,6
    };

    // Generating the buffer and loading the vertex data into it.
    GLuint v_buffer_handle;
    glGenBuffers(1, &v_buffer_handle);
    OGL_CALL(glBindBuffer(GL_ARRAY_BUFFER, v_buffer_handle));
    glBufferData(GL_ARRAY_BUFFER, vertices.size() * sizeof(GLfloat), vertices.data(), GL_STATIC_DRAW);
    glBindBuffer(GL_ARRAY_BUFFER, 0);

    // Generating the buffer and loading the index data into it.
    GLuint indicies_buffer_handler;
    glGenBuffers(1, &indicies_buffer_handler);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, indicies_buffer_handler);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, indices.size() * sizeof(GLushort), indices.data(), GL_STATIC_DRAW);

    GLuint lighting_uniform_buffer;
    float strength = 0.8f;
    float color[3] = { 0.7f, 0.2f, 1.0f };
    glGenBuffers(1, &lighting_uniform_buffer);
    glBindBuffer(GL_UNIFORM_BUFFER, lighting_uniform_buffer);
    glBufferData(GL_UNIFORM_BUFFER, 8 * sizeof(float), NULL, GL_STATIC_DRAW);
    glBindBufferBase(GL_UNIFORM_BUFFER, 0, lighting_uniform_buffer);
    glBufferSubData(GL_UNIFORM_BUFFER, 0, 1 * sizeof(float), &strength);
    glBufferSubData(GL_UNIFORM_BUFFER, 4 * sizeof(float), 3 * sizeof(float), &color);

    // TRANSFORMATION UNIFORM BUFFER
    GLuint transform_buffer;
    float theta = 1.0 * glm::pi<float>() / 6.0f;
    auto cs = std::cos(theta);
    auto ss = std::sin(theta);
    glm::mat2 rot{ cs,ss,-ss,cs };
    glm::vec2 trans{ 0.0,  -0.25 };
    glm::vec2 scale{ 0.5, 0.5 };
    glGenBuffers(1, &transform_buffer);
    glBindBuffer(GL_UNIFORM_BUFFER, transform_buffer);
    glBufferData(GL_UNIFORM_BUFFER, 12 * sizeof(float), NULL, GL_STATIC_DRAW);
    glBindBufferBase(GL_UNIFORM_BUFFER, 1, transform_buffer);
    glBufferSubData(GL_UNIFORM_BUFFER, 0 * sizeof(float), 2 * sizeof(float), &scale);
    glBufferSubData(GL_UNIFORM_BUFFER, 2 * sizeof(float), 2 * sizeof(float), &trans);
    glBufferSubData(GL_UNIFORM_BUFFER, 4 * sizeof(float), 2 * sizeof(float), &rot[0]);
    glBufferSubData(GL_UNIFORM_BUFFER, 8 * sizeof(float), 2 * sizeof(float), &rot[1]);




    // This setups a Vertex Array Object (VAO) that  encapsulates
    // the state of all vertex buffers needed for rendering
    glGenVertexArrays(1, &vao_);
    glBindVertexArray(vao_);
    glBindBuffer(GL_ARRAY_BUFFER, v_buffer_handle);

    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, indicies_buffer_handler);

    // This indicates that the data for attribute 0 should be read from a vertex buffer.
    glEnableVertexAttribArray(0);
    // and this specifies how the data is layout in the buffer.
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 6 * sizeof(GLfloat), reinterpret_cast<GLvoid*>(0));

    glEnableVertexAttribArray(1);
    glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 6 * sizeof(GLfloat), reinterpret_cast<GLvoid*>(3 * sizeof(GLfloat)));



    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindVertexArray(0);
    //end of vao "recording"

    // Setting the background color of the rendering window,
    // I suggest not to use white or black for better debuging.
    glClearColor(0.81f, 0.81f, 0.8f, 1.0f);

    // This setups an OpenGL vieport of the size of the whole rendering window.
    auto [w, h] = frame_buffer_size();
    glViewport(0, 0, w, h);

    glUseProgram(program);
}

//This functions is called every frame and does the actual rendering.
void SimpleShapeApplication::frame()
{
    // Binding the VAO will setup all the required vertex buffers.
    glBindVertexArray(vao_);
    glDrawElements(GL_TRIANGLES,9, GL_UNSIGNED_SHORT, 0);
    glBindVertexArray(0);
}
