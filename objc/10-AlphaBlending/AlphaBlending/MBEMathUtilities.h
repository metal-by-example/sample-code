@import Foundation;
@import simd;

/// Returns random float between min and max, inclusive
float random_float(float min, float max);

/// Returns a vector that is orthogonal to the input vector
vector_float3 vector_orthogonal(vector_float3 v);

matrix_float4x4 matrix_identity();

matrix_float4x4 matrix_rotation(vector_float3 axis, float angle);

matrix_float4x4 matrix_translation(vector_float3 t) __attribute((overloadable));

matrix_float4x4 matrix_scale(vector_float3 s) __attribute((overloadable));

matrix_float4x4 matrix_uniform_scale(float s);

matrix_float4x4 matrix_perspective_projection(float aspect, float fovy, float near, float far);

matrix_float4x4 matrix_extract_linear(const matrix_float4x4 mat4x4);
