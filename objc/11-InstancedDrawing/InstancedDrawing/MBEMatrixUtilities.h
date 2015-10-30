@import simd;

matrix_float4x4 matrix_identity();

matrix_float4x4 matrix_rotation(vector_float3 axis, float angle);

matrix_float4x4 matrix_translation(vector_float3 t) __attribute((overloadable));

matrix_float4x4 matrix_scale(vector_float3 s) __attribute((overloadable));

matrix_float4x4 matrix_uniform_scale(float s);

matrix_float4x4 matrix_perspective_projection(float aspect, float fovy, float near, float far);

matrix_float3x3 matrix_upper_left3x3(const matrix_float4x4 mat4x4);
