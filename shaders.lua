teleportShader = love.graphics.newShader[[
uniform ArrayImage MainTex; 
uniform float corners[5];
uniform float renderedAmount;
uniform bool hidden;

#define border 0.02
#define radius 0.47 // 0.5 is too much

const vec3 purplePixel = normalize(vec3(236, 2, 178));
const float blackVal = float(0);
const vec2 center = vec2(0.5, 0.5);
const vec2 startPos = vec2(0.5, 0.5-(radius+border)); 

vec2 calcCornerPos(float degree){
    float rad = radians(float(degree));
    vec2 start = startPos - center;
    vec2 newPos = vec2(start.x*cos(rad) + start.y*sin(rad), start.y*cos(rad) - start.x*sin(rad));
    newPos += center;
    return newPos;
}


vec2 cornerPositions[5] = vec2[](
    calcCornerPos(corners[0]),
    calcCornerPos(corners[1]),
    calcCornerPos(corners[2]),
    calcCornerPos(corners[3]),
    calcCornerPos(corners[4])
);


float drawLine(vec2 p1, vec2 p2, vec2 uv) {
    
    float a = abs(distance(p1, uv));
    float b = abs(distance(p2, uv));
    float c = abs(distance(p1, p2));
    
    if ( a >= c || b >=  c ) return 0.0;
    
    float p = (a + b + c) * 0.5;
    
    // median to (p1, p2) vector
    float h = 2 / c * sqrt( p * ( p - a) * ( p - b) * ( p - c));
    
    return mix(1.0, 0.0, smoothstep(0.5 * border, 1.5 * border, h));
}

float isPixelPartOfStar(vec2 corners[5], vec2 uv){
    float value1 = drawLine(corners[0], corners[2], uv);
    float value2 = drawLine(corners[0], corners[3], uv);
    float value3 = drawLine(corners[1], corners[3], uv);
    float value4 = drawLine(corners[1], corners[4], uv);
    float value5 = drawLine(corners[2], corners[4], uv);
    if( value1 > 0.0 ||
    value2 > 0.0 ||
    value3 > 0.0 ||
    value4 > 0.0 ||
    value5 > 0.0 ){
    
    float maxVal = max(
    max(
        max(max(max(value1, value2), max(value1, value3)), max(max(value1, value4), max(value1, value5))),
        max(max(max(value2, value3), max(value2, value4)), max(max(value2, value5), max(value3, value4)))),
        max(max(value3, value5), max(value4, value5)));
        
    return maxVal;
    }
    return 0.0;
}

float sign(vec2 p1, vec2 p2, vec2 p3){
    return (p1.x - p3.x) * (p2.y - p3.y) - (p2.x - p3.x) * (p1.y - p3.y);
}  

bool calcTriangleArea(vec2 v1, vec2 v2, vec2 v3, vec2 pos){
    bool has_neg, has_pos;

    float d1 = sign(pos, v1, v2);
    float d2 = sign(pos, v2, v3);
    float d3 = sign(pos, v3, v1);

    has_neg = ((d1 < 0) || (d2 < 0) || (d3 < 0));
    has_pos = ((d1 > 0) || (d2 > 0) || (d3 > 0));

    return !(has_neg && has_pos);
}

bool isAngleBetween(float target, float angle1, float angle2) {
    float startAngle = min(angle1, angle2);
    float endAngle = max(angle1, angle2);

    if (endAngle - startAngle < 0.1) {
    return false;
    }

    target = mod((360. + (mod(target, 360.))), 360.);
    startAngle = mod((3600000. + startAngle), 360.);
    endAngle = mod((3600000. + endAngle), 360.);

    if (startAngle < endAngle) return startAngle <= target && target <= endAngle;
    return startAngle <= target || target <= endAngle;
}

bool isStarFinished = false;
bool isPartOfSector = false;

bool setStarAndSector(vec2 pos, float dist){
    if(renderedAmount >= (radius-border)){
    
    isStarFinished = true;
    //float amount = (renderedAmount - (radius-border)) * 4;
    float amount2 = (renderedAmount - (radius-border));

    float angle1 = ceil(amount2 * 360) + 90.0;

    if(angle1 >= 270.){
        angle1 = 270.;
    }

    float angle2 = ceil(amount2 * 360)*-1 + 90.0;

    if(angle2 <= -90.){
        angle2 = -90.;
    }

    vec2 uvToCenter = pos - center;
    float angle = degrees(atan(uvToCenter.y, uvToCenter.x));

    if (isAngleBetween(angle, angle1, angle2)) {
        isPartOfSector = true;
    }

    }

    if((isStarFinished && isPartOfSector) || (dist <= renderedAmount && dist <= (radius-border))){
    return true;
    }

    return false;

}

void effect(){
    vec2 pos = VaryingTexCoord.xy;
    vec4 pixel = Texel(MainTex, VaryingTexCoord.xyz) * VaryingColor;
    float dist = distance(pos, center);
    
    if(VaryingTexCoord.z == 2){
    
    bool shouldDraw = true;

    if (hidden){
        shouldDraw = setStarAndSector(pos, dist);
    }

    if ( dist <= (radius+border)){
        if (dist >= (radius-border) && shouldDraw){
        pixel.a = 0.0;
        }else{
        float value = isPixelPartOfStar(cornerPositions, pos);
        if (value > 0.0 && shouldDraw){
            pixel.a = abs(value - 1.0);
        }
        }
    }        
    love_PixelColor = pixel;
        
    }else if(VaryingTexCoord.z == 0){

    bool shouldDraw = setStarAndSector(pos, dist);
    
    if(shouldDraw){
        float factor = VaryingTexCoord.y;
        pixel.r = purplePixel.r + ((blackVal-purplePixel.r) * factor);
        pixel.g = purplePixel.g + ((blackVal-purplePixel.g) * factor);
        pixel.b = purplePixel.b + ((blackVal-purplePixel.b) * factor);
        love_PixelColor = pixel;
    }else{
        love_PixelColor = pixel;
    }
    }else{
    love_PixelColor = pixel;
    }
}

]]

shadingShader = love.graphics.newShader[[
uniform vec2 positions[2];
uniform vec2 center; 

varying vec4 vpos;
const vec3 yellowPixel = normalize(vec3(255, 165, 0)); 

#ifdef VERTEX
vec4 position( mat4 transform_projection, vec4 vertex_position )
{
    vpos = transform_projection * vertex_position;
    return vpos;
}
#endif
 
#ifdef PIXEL
vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords){
    vec4 pixel = Texel(tex, texture_coords);
    float dist = distance(texture_coords, center)*2;

    float radiusX = distance(center, positions[0]);
    float radiusY = distance(center, positions[1]);
    float e1 =  ( screen_coords.x - center.x ) / ( radiusX );
    float e2 =  ( screen_coords.y - center.y ) / ( radiusY );
    
    float d  = (e1 * e1) + (e2 * e2);
    float maxRad = max(radiusX, radiusY);
    if( d < maxRad) {
        //d *= 2;
        pixel.r = abs(pixel.r + (-1 * d)) * color.r;
        pixel.g = abs(pixel.g + (-1 * d)) * color.g;
        pixel.b = abs(pixel.b + (-1 * d)) * color.b;
        pixel.a = abs(d + 0.2);
    }    
    
    return pixel;
}
#endif
]]

chargeBarShader = love.graphics.newShader[[
uniform vec3 color;
uniform float value;
uniform float maxValue;

vec3 nC = normalize(color);

#define border 0.02

float newValue = (value * (1.0 - (border*2))/maxValue) + border;

vec4 effect( vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords ){
    vec4 pixel = Texel(texture, texture_coords ); //This is the current pixel color
    if(pixel.r == 0.0 && texture_coords.x <= newValue){
        pixel.r = nC.r * newValue;
        pixel.g = nC.g * newValue;
        pixel.b = nC.b * newValue;
    }else if(pixel.r == 0.0){
        pixel.a = 0.0;
    }
    return pixel;
}
]]