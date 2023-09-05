extends Object
class_name FileParser

static func parse_text_to_array(string):
	var strip = string.strip_escapes()
	var split = strip.split(",", false)
	var result = []
	for i in range (0,len(split), 2):
		var par = [split[i].to_float(), split[i+1].to_float()]
		result.append(par)
	return result


static func parse_obj_to_array(path):
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	var full_string = file.get_as_text()
	var lines = full_string.split("\n", false)
	var vertices = []
	var normais = []
	var faces = []
	var data
	var list = []
	var info
	for line in lines:
		data = line.split(" ")
		if data[0] == 'v':
			vertices.append([
				float(data[1]),
				float(data[2]),
				float(data[3])
			])
		elif data[0] == 'vn':
			normais.append([
				float(data[1]),
				float(data[2]),
				float(data[3])
			])
		elif data[0] == 'f':
			var f1 = data[1].split("/")
			var f2 = data[2].split("/")
			var f3 = data[3].split("/")
			var ft1 = [int(f1[0]), int(f1[1]), int(f1[2])]
			var ft2 = [int(f2[0]), int(f2[1]), int(f2[2])]
			var ft3 = [int(f3[0]), int(f3[1]), int(f3[2])]
			faces.append([ft1, ft2, ft3])
	file.close()
	for face in faces:
		info = []
		var normal = 0
		var normalvec
		for coord in face:
			info.append(vertices[coord[0]-1])
			if normal != coord[2]:
				normalvec = normais[coord[2]-1]
		info.append(normalvec)
		list.append(info)
	return list
	
static func array2d_to_1d(array):
	var new_array = []
	for i in range (0, len(array),1):
		for j in range (0, len(array[0]), 1):
			new_array.append(array[i][j])
	return new_array 

static func array3d_to_1d(array):
	var new_array = []
	for i in range (0, len(array),1):
		for j in range (0, len(array[0]), 1):
			for k in range (0, len(array[0][0]), 1):
				new_array.append(array[i][j][k])
	return new_array
 
static func create_shader_file(n_par, n_tel):
	if FileAccess.file_exists("res://shader/GPU-RT.glsl"):
		return
	else:
		var file = FileAccess.open("res://shader/GPU-RT.glsl", FileAccess.WRITE)
		var string_init = "#[compute]
#version 450
#define TP {0}
#define TT {1}
		".format([n_par, n_tel])
		var string_code = """
layout(local_size_x = 16) in;

layout(set = 0, binding = 0, std430) restrict buffer TrianglesPar {
	double vectors[];
}
tr_par;

layout(set = 0, binding = 1, std430) restrict buffer TrianglesTel {
	double vectors[];
}
tr_tel;

layout(set = 0, binding = 2, std430) restrict buffer Tela {
	double coord[];
}
screen;

layout(set = 0, binding = 3, std430) restrict buffer Variables {
	highp int len_par;
	highp int len_tel;
	highp int n_x;
	highp int n_y;
	double faraway;
	double kd;
	double ka;
	double color_par[4];
	double color_tel[4];
	double direct[4];
	double bounce[4];
}
var_glob;

layout(set = 0, binding = 4, std430) restrict buffer Output {
	dvec4 vectors[];
}
deb_out;

layout(set = 0, binding = 5, std430) restrict buffer Region {
	dvec4 vectors[];
}
region;

struct Triangle
{
	dvec3 v1;
	dvec3 v2;
	dvec3 v3;
	dvec3 n;
};

uint trind(uint ind, uint val){
	uint at = ind*12;
	return at+val;
}

uint telaind(uint ind, uint val){
	uint at = ind*4;
	return at+val;
}

dvec4 ray_p_camera(double t, uint i_e){
	double ex = screen.coord[telaind(i_e, 0)];
	double ey = screen.coord[telaind(i_e, 1)];
	double ez = screen.coord[telaind(i_e, 2)];
	double p_2 = ez - t;
	dvec4 vect;
	vect.xyzw = dvec4(ex, ey, p_2, 0);
	return vect;
}


dvec4 ray_p_bounce(double t, double origin[3], double dir[4]){
	double ex = origin[0];
	double ey = origin[1];
	double ez = origin[2];
	double p_0 = ex + (dir[0]*t);
	double p_1 = ey + (dir[1]*t);
	double p_2 = ez + (dir[2]*t);
	return dvec4(p_0, p_1, p_2, 0);
}

double determ33(double a[3][3]){
	double pos = a[0][0]*a[1][1]*a[2][2] + a[0][1]*a[1][2]*a[2][0] + a[0][2]*a[1][0]*a[2][1];
	double neg = - a[0][2]*a[1][1]*a[2][0] - a[0][1]*a[1][0]*a[2][2] - a[0][0]*a[1][2]*a[2][1];
	return pos + neg;
}

dvec3 ls_solve(double a[3][3], double b[3]){
	double xx[3][3] = {
		{b[0], a[0][1], a[0][2]},
		{b[1], a[1][1], a[1][2]},
		{b[2], a[2][1], a[2][2]}
	};
	double yy[3][3] = {
		{a[0][0], b[0], a[0][2]},
		{a[1][0], b[1], a[1][2]},
		{a[2][0], b[2], a[2][2]}
	};
	double zz[3][3] = {
		{a[0][0], a[0][1], b[0]},
		{a[1][0], a[1][1], b[1]},
		{a[2][0], a[2][1], b[2]}
	};
	double x = determ33(xx)/determ33(a);
	double y = determ33(yy)/determ33(a);
	double z = determ33(zz)/determ33(a);
	return dvec3(x, y, z);
}




// i_t - Índice do triângulo (lista de triângulos)
// i_e - Índice da coordenada do pixel na tela

bool interc_tri_bool_par(uint i_t, double bou[3], double dir[4]){
	double v1x = tr_par.vectors[trind(i_t, 0)];
	double v1y = tr_par.vectors[trind(i_t, 1)];
	double v1z = tr_par.vectors[trind(i_t, 2)];
	double v2x = tr_par.vectors[trind(i_t, 3)];
	double v2y = tr_par.vectors[trind(i_t, 4)];
	double v2z = tr_par.vectors[trind(i_t, 5)];
	double v3x = tr_par.vectors[trind(i_t, 6)];
	double v3y = tr_par.vectors[trind(i_t, 7)];
	double v3z = tr_par.vectors[trind(i_t, 8)];
	double nx = tr_par.vectors[trind(i_t, 9)];
	double ny = tr_par.vectors[trind(i_t, 10)];
	double nz = tr_par.vectors[trind(i_t, 11)];
	double ex = bou[0];
	double ey = bou[1];
	double ez = bou[2];
	double a[3][3] = {
		{v1x - v2x, v1x - v3x, dir[0]},
		{v1y - v2y, v1y - v3y, dir[1]},		
		{v1z - v2z, v1z - v3z, dir[2]}
	};
	double b[3] = {
		v1x - ex, v1y - ey, v1z - ez
	};
	if(determ33(a) != 0){
		dvec3 x = ls_solve(a, b);
		if(x.x > 0 && x.y > 0 && (x.x + x.y < 1) && x.z > 0 && x.z < var_glob.faraway){
			return true;
		}else{
			return false;
		}
	}else{
		return false;
	}

}

bool interc_tri_bool_par_deb(uint i_t, dvec4 origin, double dir[4]){
	double v1x = tr_par.vectors[trind(i_t, 0)];
	double v1y = tr_par.vectors[trind(i_t, 1)];
	double v1z = tr_par.vectors[trind(i_t, 2)];
	double v2x = tr_par.vectors[trind(i_t, 3)];
	double v2y = tr_par.vectors[trind(i_t, 4)];
	double v2z = tr_par.vectors[trind(i_t, 5)];
	double v3x = tr_par.vectors[trind(i_t, 6)];
	double v3y = tr_par.vectors[trind(i_t, 7)];
	double v3z = tr_par.vectors[trind(i_t, 8)];
	double nx = tr_par.vectors[trind(i_t, 9)];
	double ny = tr_par.vectors[trind(i_t, 10)];
	double nz = tr_par.vectors[trind(i_t, 11)];
	double ex = origin.x;
	double ey = origin.y;
	double ez = origin.z;
	double a[3][3] = {
		{v1x - v2x, v1x - v3x, dir[0]},
		{v1y - v2y, v1y - v3y, dir[1]},		
		{v1z - v2z, v1z - v3z, dir[2]}
	};
	double b[3] = {
		v1x - ex, v1y - ey, v1z - ez
	};
	if(determ33(a) != 0){
		dvec3 x = ls_solve(a, b);
		if(x.x > 0 && x.y > 0 && (x.x + x.y < 1) && x.z > 0 && x.z < var_glob.faraway){
			return true;
		}else{
			return false;
		}
	}else{
		return false;
	}

}


double interc_tri_par(uint i_t, uint i_e, double dir[4]){
	double v1x = tr_par.vectors[trind(i_t, 0)];
	double v1y = tr_par.vectors[trind(i_t, 1)];
	double v1z = tr_par.vectors[trind(i_t, 2)];
	double v2x = tr_par.vectors[trind(i_t, 3)];
	double v2y = tr_par.vectors[trind(i_t, 4)];
	double v2z = tr_par.vectors[trind(i_t, 5)];
	double v3x = tr_par.vectors[trind(i_t, 6)];
	double v3y = tr_par.vectors[trind(i_t, 7)];
	double v3z = tr_par.vectors[trind(i_t, 8)];
	double nx = tr_par.vectors[trind(i_t, 9)];
	double ny = tr_par.vectors[trind(i_t, 10)];
	double nz = tr_par.vectors[trind(i_t, 11)];
	double ex = screen.coord[telaind(i_e, 0)];
	double ey = screen.coord[telaind(i_e, 1)];
	double ez = screen.coord[telaind(i_e, 2)];
	double a[3][3] = {
		{v1x - v2x, v1x - v3x, dir[0]},
		{v1y - v2y, v1y - v3y, dir[1]},		
		{v1z - v2z, v1z - v3z, dir[2]}
	};
	double b[3] = {
		v1x - ex, v1y - ey, v1z - ez
	};
	if(determ33(a) != 0){
		dvec3 x = ls_solve(a, b);
		if(x.x > 0 && x.y > 0 && (x.x + x.y < 1) && x.z > 0 && x.z < var_glob.faraway){
			return x.z;
		}else{
			return var_glob.faraway;
		}
	}else{
		return var_glob.faraway;
	}
}





double interc_tri_par_bounce_debug(uint i_t, double bou[3], double dir[4]){
	double v1x = tr_par.vectors[trind(i_t, 0)];
	double v1y = tr_par.vectors[trind(i_t, 1)];
	double v1z = tr_par.vectors[trind(i_t, 2)];
	double v2x = tr_par.vectors[trind(i_t, 3)];
	double v2y = tr_par.vectors[trind(i_t, 4)];
	double v2z = tr_par.vectors[trind(i_t, 5)];
	double v3x = tr_par.vectors[trind(i_t, 6)];
	double v3y = tr_par.vectors[trind(i_t, 7)];
	double v3z = tr_par.vectors[trind(i_t, 8)];
	double nx = tr_par.vectors[trind(i_t, 9)];
	double ny = tr_par.vectors[trind(i_t, 10)];
	double nz = tr_par.vectors[trind(i_t, 11)];
	double ex = bou[0];
	double ey = bou[1];
	double ez = bou[2];
	double a[3][3] = {
		{v1x - v2x, v1x - v3x, dir[0]},
		{v1y - v2y, v1y - v3y, dir[1]},		
		{v1z - v2z, v1z - v3z, dir[2]}
	};
	double b[3] = {
		v1x - ex, v1y - ey, v1z - ez
	};
	if(determ33(a) != 0){
		dvec3 x = ls_solve(a, b);
		if(x.x > 0 && x.y > 0 && (x.x + x.y < 1) && x.z > 0 && x.z < var_glob.faraway){
			return x.z;
		}else{
			return var_glob.faraway;
		}
	}else{
		return var_glob.faraway;
	}
}

double interc_tri_tel(uint i_t, uint i_e, double dir[4]){
	double v1x = tr_tel.vectors[trind(i_t, 0)];
	double v1y = tr_tel.vectors[trind(i_t, 1)];
	double v1z = tr_tel.vectors[trind(i_t, 2)];
	double v2x = tr_tel.vectors[trind(i_t, 3)];
	double v2y = tr_tel.vectors[trind(i_t, 4)];
	double v2z = tr_tel.vectors[trind(i_t, 5)];
	double v3x = tr_tel.vectors[trind(i_t, 6)];
	double v3y = tr_tel.vectors[trind(i_t, 7)];
	double v3z = tr_tel.vectors[trind(i_t, 8)];
	double nx = tr_tel.vectors[trind(i_t, 9)];
	double ny = tr_tel.vectors[trind(i_t, 10)];
	double nz = tr_tel.vectors[trind(i_t, 11)];
	double ex = screen.coord[telaind(i_e, 0)];
	double ey = screen.coord[telaind(i_e, 1)];
	double ez = screen.coord[telaind(i_e, 2)];
	double a[3][3] = {
		{v1x - v2x, v1x - v3x, dir[0]},
		{v1y - v2y, v1y - v3y, dir[1]},		
		{v1z - v2z, v1z - v3z, dir[2]}
	};
	double b[3] = {
		v1x - ex, v1y - ey, v1z - ez
	};
	if(determ33(a) != 0){
		dvec3 x = ls_solve(a, b);
		if(x.x > 0 && x.y > 0 && (x.x + x.y < 1) && x.z > 0 && x.z < var_glob.faraway){
			return x.z;
		}else{
			return var_glob.faraway;
		}
	}else{
		return var_glob.faraway;
	}
}


dvec4 trace_debug(uint index){
	uint i;
	uint j;
	uint k;
	dvec4 intercept_point = dvec4(0, 0, 0, 0);
	dvec4 color = dvec4(0, 0, 0, 0);
	double dist_atual = var_glob.faraway;
	double temp;
	int a_int = 0;
	for(i=0; i < TP; i++){
		temp = interc_tri_par(i, index, var_glob.direct);
		if(temp < dist_atual){
			dist_atual = temp;
			a_int = 1;
			color = dvec4(
				var_glob.color_par[0],
				var_glob.color_par[1],
				var_glob.color_par[2],
				var_glob.color_par[3]
				);
		}
	}
	for(k=0; k < TT; k++){
		temp = interc_tri_tel(k, index, var_glob.direct);
		if(temp < dist_atual){
			dist_atual = temp;
			a_int = 2;
			color = dvec4(
				var_glob.color_tel[0],
				var_glob.color_tel[1],
				var_glob.color_tel[2],
				var_glob.color_tel[3]
				);
		}
	}
	region.vectors[index] = ray_p_camera(dist_atual, index);
	if(a_int == 2){
		for(j=0; j < TP; j++){
			if(interc_tri_bool_par_deb(j, region.vectors[index], var_glob.bounce)){
				color = dvec4(0,0,0,1);
				region.vectors[index].w = 3;
			}
		}
	}
	return color;
}



void main(){
		uint index = gl_GlobalInvocationID.x;
		deb_out.vectors[index] = trace_debug(index);
	}
	"""
		file.store_string(string_init)
		file.store_string(string_code)
		file.close()
	
static func create_rain_shader_file(n_par, n_tel):
	if FileAccess.file_exists("res://shader/GPU-Rain.glsl"):
		return
	else:
		var file = FileAccess.open("res://shader/GPU-Rain.glsl", FileAccess.WRITE)
		var string_init = "#[compute]
#version 450
#define TP {0}
#define TT {1}
		".format([n_par, n_tel])
		var string_code = """
layout(local_size_x = 16) in;

layout(set = 0, binding = 0, std430) restrict buffer TrianglesPar {
	double vectors[];
}
tr_par;

layout(set = 0, binding = 1, std430) restrict buffer TrianglesTel {
	double vectors[];
}
tr_tel;

layout(set = 0, binding = 2, std430) restrict buffer Tela {
	double coord[];
}
screen;

layout(set = 0, binding = 3, std430) restrict buffer Variables {
	highp int len_par;
	highp int len_tel;
	highp int n_x;
	highp int n_y;
	double faraway;
	double kd;
	double ka;
	double color_par[4];
	double color_tel[4];
	double direct[4];
}
var_glob;

layout(set = 0, binding = 4, std430) restrict buffer Output {
	dvec4 vectors[];
}
deb_out;


layout(set = 0, binding = 5, std430) restrict buffer Region {
	dvec4 vectors[];
}
region;

struct Triangle
{
	dvec3 v1;
	dvec3 v2;
	dvec3 v3;
	dvec3 n;
};

uint trind(uint ind, uint val){
	uint at = ind*12;
	return at+val;
}

uint telaind(uint ind, uint val){
	uint at = ind*4;
	return at+val;
}

dvec4 ray_p_camera(double t, uint i_e){
	double ex = screen.coord[telaind(i_e, 0)];
	double ey = screen.coord[telaind(i_e, 1)];
	double ez = screen.coord[telaind(i_e, 2)];
	double p_2 = ez - t;
	dvec4 vect;
	vect.xyzw = dvec4(ex, ey, p_2, 0);
	return vect;
}


dvec4 ray_p_bounce(double t, double origin[3], double dir[4]){
	double ex = origin[0];
	double ey = origin[1];
	double ez = origin[2];
	double p_0 = ex + (dir[0]*t);
	double p_1 = ey + (dir[1]*t);
	double p_2 = ez + (dir[2]*t);
	return dvec4(p_0, p_1, p_2, 0);
}

double determ33(double a[3][3]){
	double pos = a[0][0]*a[1][1]*a[2][2] + a[0][1]*a[1][2]*a[2][0] + a[0][2]*a[1][0]*a[2][1];
	double neg = - a[0][2]*a[1][1]*a[2][0] - a[0][1]*a[1][0]*a[2][2] - a[0][0]*a[1][2]*a[2][1];
	return pos + neg;
}

dvec3 ls_solve(double a[3][3], double b[3]){
	double xx[3][3] = {
		{b[0], a[0][1], a[0][2]},
		{b[1], a[1][1], a[1][2]},
		{b[2], a[2][1], a[2][2]}
	};
	double yy[3][3] = {
		{a[0][0], b[0], a[0][2]},
		{a[1][0], b[1], a[1][2]},
		{a[2][0], b[2], a[2][2]}
	};
	double zz[3][3] = {
		{a[0][0], a[0][1], b[0]},
		{a[1][0], a[1][1], b[1]},
		{a[2][0], a[2][1], b[2]}
	};
	double x = determ33(xx)/determ33(a);
	double y = determ33(yy)/determ33(a);
	double z = determ33(zz)/determ33(a);
	return dvec3(x, y, z);
}



// i_t - Índice do triângulo (lista de triângulos)
// i_e - Índice da coordenada do pixel na tela

bool interc_tri_bool_par(uint i_t, double bou[3], double dir[4]){
	double v1x = tr_par.vectors[trind(i_t, 0)];
	double v1y = tr_par.vectors[trind(i_t, 1)];
	double v1z = tr_par.vectors[trind(i_t, 2)];
	double v2x = tr_par.vectors[trind(i_t, 3)];
	double v2y = tr_par.vectors[trind(i_t, 4)];
	double v2z = tr_par.vectors[trind(i_t, 5)];
	double v3x = tr_par.vectors[trind(i_t, 6)];
	double v3y = tr_par.vectors[trind(i_t, 7)];
	double v3z = tr_par.vectors[trind(i_t, 8)];
	double nx = tr_par.vectors[trind(i_t, 9)];
	double ny = tr_par.vectors[trind(i_t, 10)];
	double nz = tr_par.vectors[trind(i_t, 11)];
	double ex = bou[0];
	double ey = bou[1];
	double ez = bou[2];
	double a[3][3] = {
		{v1x - v2x, v1x - v3x, dir[0]},
		{v1y - v2y, v1y - v3y, dir[1]},		
		{v1z - v2z, v1z - v3z, dir[2]}
	};
	double b[3] = {
		v1x - ex, v1y - ey, v1z - ez
	};
	if(determ33(a) != 0){
		dvec3 x = ls_solve(a, b);
		if(x.x > 0 && x.y > 0 && (x.x + x.y < 1) && x.z > 0 && x.z < var_glob.faraway){
			return true;
		}else{
			return false;
		}
	}else{
		return false;
	}

}

bool interc_tri_bool_par_deb(uint i_t, dvec4 origin, double dir[4]){
	double v1x = tr_par.vectors[trind(i_t, 0)];
	double v1y = tr_par.vectors[trind(i_t, 1)];
	double v1z = tr_par.vectors[trind(i_t, 2)];
	double v2x = tr_par.vectors[trind(i_t, 3)];
	double v2y = tr_par.vectors[trind(i_t, 4)];
	double v2z = tr_par.vectors[trind(i_t, 5)];
	double v3x = tr_par.vectors[trind(i_t, 6)];
	double v3y = tr_par.vectors[trind(i_t, 7)];
	double v3z = tr_par.vectors[trind(i_t, 8)];
	double nx = tr_par.vectors[trind(i_t, 9)];
	double ny = tr_par.vectors[trind(i_t, 10)];
	double nz = tr_par.vectors[trind(i_t, 11)];
	double ex = origin.x;
	double ey = origin.y;
	double ez = origin.z;
	double a[3][3] = {
		{v1x - v2x, v1x - v3x, dir[0]},
		{v1y - v2y, v1y - v3y, dir[1]},		
		{v1z - v2z, v1z - v3z, dir[2]}
	};
	double b[3] = {
		v1x - ex, v1y - ey, v1z - ez
	};
	if(determ33(a) != 0){
		dvec3 x = ls_solve(a, b);
		if(x.x > 0 && x.y > 0 && (x.x + x.y < 1) && x.z > 0 && x.z < var_glob.faraway){
			return true;
		}else{
			return false;
		}
	}else{
		return false;
	}

}


double interc_tri_par(uint i_t, uint i_e, double dir[4]){
	double v1x = tr_par.vectors[trind(i_t, 0)];
	double v1y = tr_par.vectors[trind(i_t, 1)];
	double v1z = tr_par.vectors[trind(i_t, 2)];
	double v2x = tr_par.vectors[trind(i_t, 3)];
	double v2y = tr_par.vectors[trind(i_t, 4)];
	double v2z = tr_par.vectors[trind(i_t, 5)];
	double v3x = tr_par.vectors[trind(i_t, 6)];
	double v3y = tr_par.vectors[trind(i_t, 7)];
	double v3z = tr_par.vectors[trind(i_t, 8)];
	double nx = tr_par.vectors[trind(i_t, 9)];
	double ny = tr_par.vectors[trind(i_t, 10)];
	double nz = tr_par.vectors[trind(i_t, 11)];
	double ex = screen.coord[telaind(i_e, 0)];
	double ey = screen.coord[telaind(i_e, 1)];
	double ez = screen.coord[telaind(i_e, 2)];
	double a[3][3] = {
		{v1x - v2x, v1x - v3x, dir[0]},
		{v1y - v2y, v1y - v3y, dir[1]},		
		{v1z - v2z, v1z - v3z, dir[2]}
	};
	double b[3] = {
		v1x - ex, v1y - ey, v1z - ez
	};
	if(determ33(a) != 0){
		dvec3 x = ls_solve(a, b);
		if(x.x > 0 && x.y > 0 && (x.x + x.y < 1) && x.z > 0 && x.z < var_glob.faraway){
			return x.z;
		}else{
			return var_glob.faraway;
		}
	}else{
		return var_glob.faraway;
	}
}





double interc_tri_par_bounce_debug(uint i_t, double bou[3], double dir[4]){
	double v1x = tr_par.vectors[trind(i_t, 0)];
	double v1y = tr_par.vectors[trind(i_t, 1)];
	double v1z = tr_par.vectors[trind(i_t, 2)];
	double v2x = tr_par.vectors[trind(i_t, 3)];
	double v2y = tr_par.vectors[trind(i_t, 4)];
	double v2z = tr_par.vectors[trind(i_t, 5)];
	double v3x = tr_par.vectors[trind(i_t, 6)];
	double v3y = tr_par.vectors[trind(i_t, 7)];
	double v3z = tr_par.vectors[trind(i_t, 8)];
	double nx = tr_par.vectors[trind(i_t, 9)];
	double ny = tr_par.vectors[trind(i_t, 10)];
	double nz = tr_par.vectors[trind(i_t, 11)];
	double ex = bou[0];
	double ey = bou[1];
	double ez = bou[2];
	double a[3][3] = {
		{v1x - v2x, v1x - v3x, dir[0]},
		{v1y - v2y, v1y - v3y, dir[1]},		
		{v1z - v2z, v1z - v3z, dir[2]}
	};
	double b[3] = {
		v1x - ex, v1y - ey, v1z - ez
	};
	if(determ33(a) != 0){
		dvec3 x = ls_solve(a, b);
		if(x.x > 0 && x.y > 0 && (x.x + x.y < 1) && x.z > 0 && x.z < var_glob.faraway){
			return x.z;
		}else{
			return var_glob.faraway;
		}
	}else{
		return var_glob.faraway;
	}
}

double interc_tri_tel(uint i_t, uint i_e, double dir[4]){
	double v1x = tr_tel.vectors[trind(i_t, 0)];
	double v1y = tr_tel.vectors[trind(i_t, 1)];
	double v1z = tr_tel.vectors[trind(i_t, 2)];
	double v2x = tr_tel.vectors[trind(i_t, 3)];
	double v2y = tr_tel.vectors[trind(i_t, 4)];
	double v2z = tr_tel.vectors[trind(i_t, 5)];
	double v3x = tr_tel.vectors[trind(i_t, 6)];
	double v3y = tr_tel.vectors[trind(i_t, 7)];
	double v3z = tr_tel.vectors[trind(i_t, 8)];
	double nx = tr_tel.vectors[trind(i_t, 9)];
	double ny = tr_tel.vectors[trind(i_t, 10)];
	double nz = tr_tel.vectors[trind(i_t, 11)];
	double ex = screen.coord[telaind(i_e, 0)];
	double ey = screen.coord[telaind(i_e, 1)];
	double ez = screen.coord[telaind(i_e, 2)];
	double a[3][3] = {
		{v1x - v2x, v1x - v3x, dir[0]},
		{v1y - v2y, v1y - v3y, dir[1]},		
		{v1z - v2z, v1z - v3z, dir[2]}
	};
	double b[3] = {
		v1x - ex, v1y - ey, v1z - ez
	};
	if(determ33(a) != 0){
		dvec3 x = ls_solve(a, b);
		if(x.x > 0 && x.y > 0 && (x.x + x.y < 1) && x.z > 0 && x.z < var_glob.faraway){
			return x.z;
		}else{
			return var_glob.faraway;
		}
	}else{
		return var_glob.faraway;
	}
}


dvec4 trace_debug(uint index){
	uint i;
	uint j;
	uint k;
	dvec4 intercept_point = dvec4(0, 0, 0, 0);
	dvec4 color = dvec4(0, 0, 0, 0);
	double dist_atual = var_glob.faraway;
	double temp;
	int a_int = 0;
	for(i=0; i < TP; i++){
		temp = interc_tri_par(i, index, var_glob.direct);
		if(temp < dist_atual){
			dist_atual = temp;
			a_int = 1;
			color = dvec4(
				var_glob.color_par[0],
				var_glob.color_par[1],
				var_glob.color_par[2],
				var_glob.color_par[3]
				);
		}
	}
	for(k=0; k < TT; k++){
		temp = interc_tri_tel(k, index, var_glob.direct);
		if(temp < dist_atual){
			dist_atual = temp;
			a_int = 2;
			color = dvec4(
				var_glob.color_tel[0],
				var_glob.color_tel[1],
				var_glob.color_tel[2],
				var_glob.color_tel[3]
				);
		}
	}
	return color;
}


void main(){
		uint index = gl_GlobalInvocationID.x;
		deb_out.vectors[index] = trace_debug(index);
	}
"""
		file.store_string(string_init)
		file.store_string(string_code)
		file.close()
