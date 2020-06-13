@import simd;

simd_float4x4 identity(void);

simd_float4x4 rotation_about_axis(simd_float3 axis, float angle);

simd_float4x4 translation(simd_float4 t);

simd_float4x4 perspective_projection(float aspect, float fovy, float near, float far);

simd_float3x3 upper_left3x3(const simd_float4x4 mat4x4);
