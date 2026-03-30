#include <GL/glew.h>  
#include <GLFW/glfw3.h>  
#include <stdlib.h>  
#include <stdio.h>  

GLuint shaderProgram;  
GLuint VAO, VBO, EBO;  
  
// Function to load shader source from a file  
char* loadShaderSource(const char* filePath) {  
    FILE* file = fopen(filePath, "r");  
    if (!file) {  
        fprintf(stderr, "Could not open file %s\n", filePath);  
        return NULL;  
    }  
    fseek(file, 0, SEEK_END);  
    long length = ftell(file);  
    fseek(file, 0, SEEK_SET);  
    char* source = (char*)malloc(length + 1);  
    fread(source, 1, length, file);  
    source[length] = '\0';  
    fclose(file);  
    return source;  
}  
  
// Function to compile a shader  
GLuint compileShader(GLenum type, const char* source) {  
    GLuint shader = glCreateShader(type);  
    glShaderSource(shader, 1, &source, NULL);  
    glCompileShader(shader);  
    GLint success;  
    glGetShaderiv(shader, GL_COMPILE_STATUS, &success);  
    if (!success) {  
        GLchar infoLog[512];  
        glGetShaderInfoLog(shader, 512, NULL, infoLog);  
        fprintf(stderr, "ERROR::SHADER::COMPILATION_FAILED\n%s\n", infoLog);  
    }  
    return shader;  
}  
  
// Function to link shaders into a program  
GLuint linkShaders(GLuint vertexShader, GLuint fragmentShader) {  
    GLuint program = glCreateProgram();  
    glAttachShader(program, vertexShader);  
    glAttachShader(program, fragmentShader);  
    glLinkProgram(program);  
    glDeleteShader(vertexShader);  
    glDeleteShader(fragmentShader);  
    return program;  
}  
  
// Function to initialize cube geometry  
void initCube() {  
    GLfloat vertices[] = {  
        // Positions          
        -0.5f, -0.5f, -0.5f,  
         0.5f, -0.5f, -0.5f,  
         0.5f,  0.5f, -0.5f,  
         0.5f,  0.5f, -0.5f,  
        -0.5f,  0.5f, -0.5f,  
        -0.5f, -0.5f, -0.5f,  
        // ... (other cube vertices)  
    };  
    GLuint indices[] = {  
        0, 1, 2,  
        2, 3, 0,  
        // ... (other cube indices)  
    };  
    glGenVertexArrays(1, &VAO);  
    glGenBuffers(1, &VBO);  
    glGenBuffers(1, &EBO);  
    glBindVertexArray(VAO);  
    glBindBuffer(GL_ARRAY_BUFFER, VBO);  
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);  
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, EBO);  
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(indices), indices, GL_STATIC_DRAW);  
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(GLfloat), (GLvoid*)0);  
    glEnableVertexAttribArray(0);  
    glBindBuffer(GL_ARRAY_BUFFER, 0);  
    glBindVertexArray(0);  
}  
  
// Function to render the cube  
void renderCube() {  
    glUseProgram(shaderProgram);  
    glBindVertexArray(VAO);  
    glDrawElements(GL_TRIANGLES, 36, GL_UNSIGNED_INT, 0);  
    glBindVertexArray(0);  
}  
  
// Main function  
int main() {  
    // Initialize GLFW, create window, etc.  
    // Load shaders  
    char* vertexShaderSource = loadShaderSource("vertex_shader.glsl");  
    char* fragmentShaderSource = loadShaderSource("fragment_shader.glsl");  
    GLuint vertexShader = compileShader(GL_VERTEX_SHADER, vertexShaderSource);  
    GLuint fragmentShader = compileShader(GL_FRAGMENT_SHADER, fragmentShaderSource);  
    shaderProgram = linkShaders(vertexShader, fragmentShader);  
    initCube();  
    // Render loop  
    while (!glfwWindowShouldClose(window)) {  
        renderCube();  
        // Swap buffers, poll events, etc.  
    }  
    free(vertexShaderSource);  
    free(fragmentShaderSource);  
    return 0;  
}