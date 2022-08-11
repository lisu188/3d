//
// Created by pbialas on 25.09.2020.
//

#include "app.h"

#include <iostream>
#include <vector>
#include <tuple>

#include "Application/utils.h"

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
        // House base RECT
        -0.2,0.2f,0.0f, //0
        -0.2f,-0.2f,0.0f, //1
        0.2f,-0.2f,0.0f,  //2
        -0.2f,0.2f,0.0f,  //3
        0.2f,0.2f,0.0f,  //4
        //ROOF Triangle     
        0.0f,0.5f,0.0f //5
    };

    std::vector<GLfloat> vertices2 = {
        // House base RECT
        -0.2,0.2f,0.0f,
        -0.2f,-0.2f,0.0f,
        0.2f,-0.2f,0.0f,
        -0.2f,0.2f,0.0f,
        0.2f,0.2f,0.0f,
        0.2f,-0.2f,0.0f,
        //ROOF Triangle
        -0.2f,0.2f,0.0f,
        0.2f,0.2f,0.0f,
        0.0f,0.5f,0.0f
    };
 


    // Generating the buffer and loading the vertex data into it.
    GLuint v_buffer_handle;
    glGenBuffers(1, &v_buffer_handle);
    OGL_CALL(glBindBuffer(GL_ARRAY_BUFFER, v_buffer_handle));
    glBufferData(GL_ARRAY_BUFFER, vertices.size() * sizeof(GLfloat), vertices.data(), GL_STATIC_DRAW);
    glBindBuffer(GL_ARRAY_BUFFER, 0);


    std::vector<GLushort> indices = { 0,1,2,3,4,2,3,4,5 };
    int wo_indicies = vertices2.size() * sizeof(GLfloat);
    int w_indicies = vertices.size() * sizeof(GLfloat) + indices.size() * sizeof(GLushort);
    int diff = wo_indicies - w_indicies;
    std::cout << " Memory used w/o use of indicies " << wo_indicies << " bytes" << std::endl << "Mem used w/ indicies " << w_indicies << "bytes" << std::endl << "Mem Diff " << diff <<"bytes.";
    GLuint v_indices_buffer;
    glGenBuffers(1, &v_indices_buffer);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, v_indices_buffer);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, indices.size() * sizeof(GLushort), indices.data(), GL_STATIC_DRAW);
    

    // This setups a Vertex Array Object (VAO) that  encapsulates
    // the state of all vertex buffers needed for rendering
    glGenVertexArrays(1, &vao_);
    glBindVertexArray(vao_);
    glBindBuffer(GL_ARRAY_BUFFER, v_buffer_handle);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, v_indices_buffer);

    // This indicates that the data for attribute 0 should be read from a vertex buffer.
    glEnableVertexAttribArray(0);
    // and this specifies how the data is layout in the buffer.
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(GLfloat), reinterpret_cast<GLvoid *>(0));

    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, v_indices_buffer);
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
    glDrawElements(GL_TRIANGLES,9, GL_UNSIGNED_SHORT,0);
    glBindVertexArray(0);
}
