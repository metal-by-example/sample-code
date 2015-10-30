#import "MBEMathUtilities.h"

matrix_float4x4 matrix_float4x4_translation(vector_float3 t)
{
    vector_float4 X = { 1, 0, 0, 0 };
    vector_float4 Y = { 0, 1, 0, 0 };
    vector_float4 Z = { 0, 0, 1, 0 };
    vector_float4 W = { t.x, t.y, t.z, 1 };

    matrix_float4x4 mat = { X, Y, Z, W };
    return mat;
}

matrix_float4x4 matrix_float4x4_uniform_scale(float scale)
{
    vector_float4 X = { scale, 0, 0, 0 };
    vector_float4 Y = { 0, scale, 0, 0 };
    vector_float4 Z = { 0, 0, scale, 0 };
    vector_float4 W = { 0, 0, 0, 1 };

    matrix_float4x4 mat = { X, Y, Z, W };
    return mat;
}

matrix_float4x4 matrix_float4x4_rotation(vector_float3 axis, float angle)
{
    float c = cos(angle);
    float s = sin(angle);
    
    vector_float4 X;
    X.x = axis.x * axis.x + (1 - axis.x * axis.x) * c;
    X.y = axis.x * axis.y * (1 - c) - axis.z * s;
    X.z = axis.x * axis.z * (1 - c) + axis.y * s;
    X.w = 0.0;
    
    vector_float4 Y;
    Y.x = axis.x * axis.y * (1 - c) + axis.z * s;
    Y.y = axis.y * axis.y + (1 - axis.y * axis.y) * c;
    Y.z = axis.y * axis.z * (1 - c) - axis.x * s;
    Y.w = 0.0;
    
    vector_float4 Z;
    Z.x = axis.x * axis.z * (1 - c) - axis.y * s;
    Z.y = axis.y * axis.z * (1 - c) + axis.x * s;
    Z.z = axis.z * axis.z + (1 - axis.z * axis.z) * c;
    Z.w = 0.0;
    
    vector_float4 W;
    W.x = 0.0;
    W.y = 0.0;
    W.z = 0.0;
    W.w = 1.0;
    
    matrix_float4x4 mat = { X, Y, Z, W };
    return mat;
}

matrix_float4x4 matrix_float4x4_perspective(float aspect, float fovy, float near, float far)
{
    float yScale = 1 / tan(fovy * 0.5);
    float xScale = yScale / aspect;
    float zRange = far - near;
    float zScale = -(far + near) / zRange;
    float wzScale = -2 * far * near / zRange;

    vector_float4 P = { xScale, 0, 0, 0 };
    vector_float4 Q = { 0, yScale, 0, 0 };
    vector_float4 R = { 0, 0, zScale, -1 };
    vector_float4 S = { 0, 0, wzScale, 0 };

    matrix_float4x4 mat = { P, Q, R, S };
    return mat;
}


matrix_float3x3 matrix_float4x4_extract_linear(matrix_float4x4 m)
{
    vector_float3 X = m.columns[0].xyz;
    vector_float3 Y = m.columns[1].xyz;
    vector_float3 Z = m.columns[2].xyz;
    matrix_float3x3 l = { X, Y, Z };
    return l;
}
