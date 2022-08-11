//
// Created by pbialas on 25.09.2020.
//

#include "app.h"

#include <iostream>
#include <vector>
#include <tuple>
#include "glm/glm.hpp"
#include <glm/gtc/matrix_transform.hpp>
#include <glm/gtc/type_ptr.hpp>


#include "Application/utils.h"


float get_color(float x=0.0f) {
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
    //glEnable(GL_DEPTH_TEST);
    //glEnable(GL_CULL_FACE);

    // A vector containing the x,y,z vertex coordinates for the triangle.



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

    // Vertex buffer (VBO)
    GLuint v_buffer_handle;
    glGenBuffers(1, &v_buffer_handle);
    glBindBuffer(GL_ARRAY_BUFFER, v_buffer_handle);
    glBufferData(GL_ARRAY_BUFFER, vertices.size() * sizeof(GLfloat), vertices.data(), GL_STATIC_DRAW);
    glBindBuffer(GL_ARRAY_BUFFER, 0);

    GLuint indices_buffer_handle;
    glGenBuffers(1, &indices_buffer_handle);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, indices_buffer_handle);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, indices.size() * sizeof(GLushort), indices.data(),
        GL_STATIC_DRAW);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);


    glGenVertexArrays(1, &vao_);
    glBindVertexArray(vao_);
    glm::mat4 P = glm::perspective(glm::radians(45.0f), 650.0f / 480.0f, 0.1f, 100.0f);
    glm::mat4 V = glm::lookAt(
        glm::vec3(-3.5f, -2.0f, -2.0f),
        glm::vec3(0.0f, 0.0f, 0.0f),
        glm::vec3(0.0f, 1.0f, 0.0f)
    );
    glm::mat4 M(1.0f);

    glm::mat4 PVM = P * V * M;


    glBindBuffer(GL_ARRAY_BUFFER, v_buffer_handle);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 6 * sizeof(GLfloat), reinterpret_cast<GLvoid*>(0));
    glEnableVertexAttribArray(1);
    glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 6 * sizeof(GLfloat), reinterpret_cast<GLvoid*>(12));

    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, indices_buffer_handle);


    GLuint uniform_buffer_handle[2];
    glGenBuffers(2, uniform_buffer_handle);
    glBindBuffer(GL_UNIFORM_BUFFER, uniform_buffer_handle[0]);
    float strength = 0.9;
    float light[3] = { 1.0, 0.4, 0.7 };
    glBufferData(GL_UNIFORM_BUFFER, 8 * sizeof(float), nullptr, GL_STATIC_DRAW);
    glBufferSubData(GL_UNIFORM_BUFFER, 0, sizeof(float), &strength);
    glBufferSubData(GL_UNIFORM_BUFFER, 4 * sizeof(float), 3 * sizeof(float), &light);

    glBindBufferBase(GL_UNIFORM_BUFFER, 0, uniform_buffer_handle[0]);
    glUniformBlockBinding(program, glGetUniformBlockIndex(program, "Modifiers"), 0);
    glBindBuffer(GL_UNIFORM_BUFFER, uniform_buffer_handle[1]);
    glBufferData(GL_UNIFORM_BUFFER, sizeof(glm::mat4), nullptr, GL_STATIC_DRAW);
    glBufferSubData(GL_UNIFORM_BUFFER, 0, sizeof(glm::mat4), &PVM[0]);
    glBindBufferBase(GL_UNIFORM_BUFFER, 1, uniform_buffer_handle[1]);
    glUniformBlockBinding(program, glGetUniformBlockIndex(program, "PvmTransformations"), 1);


    glBindBuffer(GL_UNIFORM_BUFFER, 0);
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindVertexArray(0);


    glClearColor(0.81f, 0.81f, 0.8f, 1.0f);
    int w, h;
    std::tie(w, h) = frame_buffer_size();
    glViewport(0, 0, w, h);

    glEnable(GL_DEPTH_TEST);
    glUseProgram(program);

}


void SimpleShapeApplication::frame() {
    glBindVertexArray(vao_);
    glEnable(GL_DEPTH_TEST);
    glDrawElements(GL_TRIANGLES, 18, GL_UNSIGNED_SHORT, nullptr);
    glBindVertexArray(0);
}
