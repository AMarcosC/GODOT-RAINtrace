extends Control

signal update_bar(value)

#DEBUG
func find_diff_value(list):
	for value in list:
		if value != 0:
			print(value)

func area_of_pixel(pixel_dens):
	var dim: float  = 1.0/float(pixel_dens)
	return dim*dim

func count_pixels_with_color(image, color):
	var count = 0
	var imgcolor
	for x in range (0, n_x, 1):
		for y in range (0, n_y, 1):
			imgcolor = image.get_pixel(x,y)
			if imgcolor[3] == 1:
				if (imgcolor[0] == color[0] and
				imgcolor[1] == color[1] and
				imgcolor[2] == color[2] and
				imgcolor[3] == color[3]):
					count += 1
	return count

func contribution_area(image, color, pixel_dens):
	var count = count_pixels_with_color(image, color)
	var area: float = count_pixels_with_color(image, color)*area_of_pixel(pixel_dens)
	return [area,count]


func recreate_shader_path():
	var dir = DirAccess.open("res://shader")
	if dir.file_exists("GPU-RT.glsl"):
		dir.remove("GPU-RT.glsl")
	if dir.file_exists("GPU-Rain.glsl"):
		dir.remove("GPU-Rain.glsl")	





func vec4_array_to_csv(data, filename, header):  #usar o header para enviar um array com informações
	var file : FileAccess = FileAccess.open("{0}/{1}.csv".format([out_directory,filename]), FileAccess.WRITE)
	file.store_csv_line(header)
	for i in range(0, n_x*n_y*4, 4):
		var vtemp = [str(data[i]), str(data[i+1]), str(data[i+2]), str(data[i+3])]
		file.store_csv_line(vtemp)
	file.close()


func convert_to_8bit_depth_slice(rgba_pack):
	var values : PackedByteArray = []
	values.resize(tela_x*tela_y*4)
	var v
	for i in range(0,len(rgba_pack),1):
		v = rgba_pack[i]*255
		values.encode_u8(i,int(v))
	return values
	
func convert_to_8bit_depth_frame(rgba_pack):
	var values : PackedByteArray = []
	values.resize(n_x*n_y*4)
	var v
	for i in range(0,len(rgba_pack),1):
		v = rgba_pack[i]*255
		values.encode_u8(i,int(v))
	return values

func polar_to_vector(el,az,off):
	var az_ajustado = 90 - az - off
	var x = cos(deg_to_rad(el))*cos(deg_to_rad(az_ajustado))
	var y = cos(deg_to_rad(el))*sin(deg_to_rad(az_ajustado))
	var z = sin(deg_to_rad(el))
	return [x, y, z]

#FUNÇÕES SEM LIGAÇÃO DIRETA
func parse_obj_file(obj_file):
	var object = FileParser.parse_obj_to_array(obj_file)
	return object

func screen_size(vertices):
	var x_menor = FARAWAY
	var x_maior = - FARAWAY
	var y_menor = FARAWAY
	var y_maior = - FARAWAY
	var z_maior = - FARAWAY
	for v in vertices:
		if v[0] > x_maior:
			x_maior = v[0]
		if v[0] < x_menor:
			x_menor = v[0]
		if v[1] > y_maior:
			y_maior = v[1]
		if v[1] < y_menor:
			y_menor = v[1]
		if v[2] > z_maior:
			z_maior = v[2]
	l = floor(((x_menor)-(forramento))) - 1
	r = ceil(((x_maior)+(forramento))) + 1
	top = ceil(((y_maior)+(forramento))) + 1
	bot = floor(((y_menor)-(forramento))) - 1
	if z_maior <= 0:
		depth = 1
	else:
		depth = ceil(z_maior) + 1
	n_x = abs(r-l)*pixel_dens
	n_y = abs(top-bot)*pixel_dens
	
func screen_size_tlist(list1, list2):
	var x_menor = FARAWAY
	var x_maior = - FARAWAY
	var y_menor = FARAWAY
	var y_maior = - FARAWAY
	var z_maior = - FARAWAY
	for tri1 in list1:
		for i in range(0, 3, 1):
			var vert = tri1[i]
			if vert[0] > x_maior:
				x_maior = vert[0]
			if vert[0] < x_menor:
				x_menor = vert[0]
			if vert[1] > y_maior:
				y_maior = vert[1]
			if vert[1] < y_menor:
				y_menor = vert[1]
			if vert[2] > z_maior:
				z_maior = vert[2]
	for tri2 in list2:
		for j in range(0, 3, 1):
			var vert = tri2[j]
			if vert[0] > x_maior:
				x_maior = vert[0]
			if vert[0] < x_menor:
				x_menor = vert[0]
			if vert[1] > y_maior:
				y_maior = vert[1]
			if vert[1] < y_menor:
				y_menor = vert[1]
			if vert[2] > z_maior:
				z_maior = vert[2]
	l = floor(((x_menor)-(forramento))) - 1
	r = ceil(((x_maior)+(forramento))) + 1
	top = ceil(((y_maior)+(forramento))) + 1
	bot = floor(((y_menor)-(forramento))) - 1
	if z_maior <= 0:
		depth = 1
	else:
		depth = ceil(z_maior) + 1
	n_x = abs(r-l)*pixel_dens
	n_y = abs(top-bot)*pixel_dens


func pixel_pos(i,j):
	var u = l + ((r-l)*(i+0.5))/n_x
	var v = top + ((bot-top)*(j+0.5))/n_y
	return([u, v])

func screen_pixel_coord(n, m):
	var tabela = []
	for i in range (0,n,1):
		var linha = []
		for j in range (0,m,1):
			var x_y = pixel_pos(j,i)
			var z = depth
			linha.append([x_y[0], x_y[1], z, 0])
		tabela.append(linha)
	return tabela
	
func screen_pixel_2top(n, m):
	var tabela = []
	for i in range (0,n/2,1):
		var linha = []
		for j in range (0,m,1):
			var x_y = pixel_pos(j,i)
			var z = depth
			linha.append([x_y[0], x_y[1], z, 0])
		tabela.append(linha)
	return tabela
	
	
func screen_pixel_2bot(n, m):
	var tabela = []
	for i in range (n/2,n,1):
		var linha = []
		for j in range (0,m,1):
			var x_y = pixel_pos(j,i)
			var z = depth
			linha.append([x_y[0], x_y[1], z, 0])
		tabela.append(linha)
	return tabela
	
func screen_pixel_4_1(n, m):
	var tabela = []
	for i in range (0,n/4,1):
		var linha = []
		for j in range (0,m,1):
			var x_y = pixel_pos(j,i)
			var z = depth
			linha.append([x_y[0], x_y[1], z, 0])
		tabela.append(linha)
	return tabela

func screen_pixel_4_2(n, m):
	var tabela = []
	for i in range (n/4,n/2,1):
		var linha = []
		for j in range (0,m,1):
			var x_y = pixel_pos(j,i)
			var z = depth
			linha.append([x_y[0], x_y[1], z, 0])
		tabela.append(linha)
	return tabela
	
func screen_pixel_4_3(n, m):
	var tabela = []
	for i in range (n/2,n*3/4,1):
		var linha = []
		for j in range (0,m,1):
			var x_y = pixel_pos(j,i)
			var z = depth
			linha.append([x_y[0], x_y[1], z, 0])
		tabela.append(linha)
	return tabela

func screen_pixel_4_4(n, m):
	var tabela = []
	for i in range (n*3/4,n,1):
		var linha = []
		for j in range (0,m,1):
			var x_y = pixel_pos(j,i)
			var z = depth
			linha.append([x_y[0], x_y[1], z, 0])
		tabela.append(linha)
	return tabela


func screen_pixel_arbitrary(n, m, a_s, t_s):  #a_s começa em 0 e termina em t_s-1
	var tabela = []
	var current : int  = (n*a_s)/t_s
	var next : int = (n*(a_s+1))/t_s
	for i in range (current,next,1):
		var linha = []
		for j in range (0,m,1):
			var x_y = pixel_pos(j,i)
			var z = depth
			linha.append([x_y[0], x_y[1], z, 0])
		tabela.append(linha)
	return tabela
	
#FUNÇÕES COM SINAIS

# Called when the node enters the scene tree for the first time.
func compute(tm, file_prefix, tela_coord):
	var tela = tela_coord
	tela_x = len(tela[0])
	tela_y = len(tela)
	var tela_pixels = tela_x*tela_y
	var buffer_size = 4*tela_pixels*8  #4 comp. de cores, 8 bytes por compoente, vezes o número de pixels da tela

	# We will be using our own RenderingDevice to handle the compute commands
	var rd : RenderingDevice = RenderingServer.create_local_rendering_device()
	# Create shader and pipeline
	var shader_file := load("res://shader/GPU-RT.glsl")
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	var shader := rd.shader_create_from_spirv(shader_spirv)
	var pipeline := rd.compute_pipeline_create(shader)
	

	########## Triângulos da Parede  ##################		
	# Data for compute shaders has to come as an array of bytes
	var vline_par = FileParser.array3d_to_1d(obj_par)
	var params_par : PackedByteArray = PackedFloat64Array(
		vline_par
		).to_byte_array()
	# Create storage buffer
	# Data not needed, can just create with length
	var params_buffer_par := rd.storage_buffer_create(params_par.size(), params_par)
	# Create uniform set using the storage buffer
	var params_uniform_par := RDUniform.new()
	params_uniform_par.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	params_uniform_par.binding = 0
	params_uniform_par.add_id(params_buffer_par)
	
	########## Triângulos do Telhado  ##################		
	# Data for compute shaders has to come as an array of bytes
	var vline_tel = FileParser.array3d_to_1d(obj_tel)
	var params_tel : PackedByteArray = PackedFloat64Array(
		vline_tel
		).to_byte_array()
	# Create storage buffer
	# Data not needed, can just create with length
	var params_buffer_tel := rd.storage_buffer_create(params_tel.size(), params_tel)
	# Create uniform set using the storage buffer
	var params_uniform_tel := RDUniform.new()
	params_uniform_tel.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	params_uniform_tel.binding = 1
	params_uniform_tel.add_id(params_buffer_tel)
	
	########## Coordenadas da Tela ##################		
	# Data for compute shaders has to come as an array of bytes
	var vline_screen
	if pixel_dens <= 16:
		vline_screen = FileParser.array2d_to_1d(tela)
	else:
		vline_screen = FileParser.array3d_to_1d(tela)
	var params_screen : PackedByteArray = PackedFloat64Array(
		vline_screen
		).to_byte_array()
	# Create storage buffer
	# Data not needed, can just create with length
	var params_buffer_screen := rd.storage_buffer_create(params_screen.size(), params_screen)
	# Create uniform set using the storage buffer
	var params_uniform_screen := RDUniform.new()
	params_uniform_screen.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	params_uniform_screen.binding = 2
	params_uniform_screen.add_id(params_buffer_screen)
	

	########## Variáveis Globais  ##################		
	# Data for compute shaders has to come as an array of bytes
	var time = polar_to_vector(tm[0], tm[1], offset)
	print(time)
	var int_variables = [
		len(obj_par), len(obj_tel), n_x, n_y,
	]
	var float_variables = [
		FARAWAY, kd, ka,
		obj_par_color.r, obj_par_color.g, obj_par_color.b, 1,
		obj_tel_color.r, obj_tel_color.g, obj_tel_color.b, 1,
		direct[0], direct[1], direct[2], 0,
		time[0], time[1], time[2], 0
	]
	var params_int_var : PackedByteArray = PackedInt32Array(
		int_variables
		).to_byte_array()
	var params_float_var : PackedByteArray = PackedFloat64Array(
		float_variables
		).to_byte_array()
	var joint_array : PackedByteArray = []
	joint_array.append_array(params_int_var)
	joint_array.append_array(params_float_var)
	# Create storage buffer
	# Data not needed, can just create with length
	var params_buffer_var := rd.storage_buffer_create(joint_array.size(), joint_array)  #MUDARRRRRRRRR
	# Create uniform set using the storage buffer
	var params_uniform_var := RDUniform.new()
	params_uniform_var.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	params_uniform_var.binding = 3
	params_uniform_var.add_id(params_buffer_var)

	#4 componentes de cor, vezes as coordenadas da tela, 8 bytes por valor, dividido por 2 buffers
	
		########## Buffer de Output - Imagem ##################		
	# Data for compute shaders has to come as an array of bytes
	var params_buffer_out := rd.storage_buffer_create(buffer_size)
	# Create uniform set using the storage buffer
	var params_uniform_out := RDUniform.new()
	params_uniform_out.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	params_uniform_out.binding = 4
	params_uniform_out.add_id(params_buffer_out)
	
	
		########## Buffer de Output - Região  ##################		
	# Data for compute shaders has to come as an array of bytes
	var params_buffer_reg := rd.storage_buffer_create(buffer_size)
	# Create uniform set using the storage buffer
	var params_uniform_reg := RDUniform.new()
	params_uniform_reg.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	params_uniform_reg.binding = 5
	params_uniform_reg.add_id(params_buffer_reg)	

	##### Uniform Set Unificado  #############
	var bindings = [
		params_uniform_par,
		params_uniform_tel,
		params_uniform_screen,
		params_uniform_var,
		params_uniform_out,
		params_uniform_reg,
	]
	var uniform_set := rd.uniform_set_create(bindings, shader, 0)
	# Start compute list to start recording our compute commands

	var compute_list := rd.compute_list_begin()
	# Bind the pipeline, this tells the GPU what shader to use
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	# Binds the uniform set with the data we want to give our shader
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	# Dispatch 1x1x1 (XxYxZ) work groups
	rd.compute_list_dispatch(compute_list, tela_pixels/16, 1, 1)  #len(vline_tel)
	
	#rd.compute_list_add_barrier(compute_list)
	# Tell the GPU we are done with this compute task
	rd.compute_list_end()
	# Force the GPU to start our commands
	rd.submit()
	# Force the CPU to wait for the GPU to finish with the recorded commands
	rd.sync()
	# Now we can grab our data from the storage buffer
	var output_bytes := rd.buffer_get_data(params_buffer_out)
	var output := output_bytes.to_float64_array()
	var hit_bytes := rd.buffer_get_data(params_buffer_reg)
	var output_hit := hit_bytes.to_float64_array()
	rd.free_rid(shader)
	rd.free_rid(pipeline)
	#rd.free_rid(params_buffer_par)
	#rd.free_rid(params_buffer_tel)
	#rd.free_rid(params_buffer_screen)
	#rd.free_rid(params_buffer_var)
	#rd.free_rid(params_buffer_out)
	#rd.free_rid(params_buffer_reg)
	rd.free_rid(uniform_set)
	return [output, output_hit]
	#vec4_array_to_csv(output_hit, "area")
	
func compute_rain(tm, file_prefix, tela_coord):
	var tela = tela_coord
	tela_x = len(tela[0])
	tela_y = len(tela)
	var tela_pixels = tela_x*tela_y
	var buffer_size = 4*tela_pixels*8  #4 comp. de cores, 8 bytes por compoente, vezes o número de pixels da tela

	# We will be using our own RenderingDevice to handle the compute commands
	var gc_r := GPUComputer.new()
	# Create shader and pipeline
	gc_r.shader_file = load("res://shader/GPU-Rain.glsl")
	gc_r._load_shader()

	########## Triângulos da Parede  ##################		
	# Data for compute shaders has to come as an array of bytes
	var vline_par = FileParser.array3d_to_1d(obj_par)
	var params_par : PackedByteArray = PackedFloat64Array(
		vline_par
		).to_byte_array()
	# Create storage buffer
	# Data not needed, can just create with length
	gc_r._add_buffer(0, 0, params_par)

	
	########## Triângulos do Telhado  ##################		
	# Data for compute shaders has to come as an array of bytes
	var vline_tel = FileParser.array3d_to_1d(obj_tel)
	var params_tel : PackedByteArray = PackedFloat64Array(
		vline_tel
		).to_byte_array()
	# Create storage buffer
	# Data not needed, can just create with length
	gc_r._add_buffer(0, 1, params_tel)

	
	########## Coordenadas da Tela ##################		
	# Data for compute shaders has to come as an array of bytes
	var vline_screen
	if pixel_dens <= 16:
		vline_screen = FileParser.array2d_to_1d(tela)
	else:
		vline_screen = FileParser.array3d_to_1d(tela)
	var params_screen : PackedByteArray = PackedFloat64Array(
		vline_screen
		).to_byte_array()
	# Create storage buffer
	# Data not needed, can just create with length
	gc_r._add_buffer(0, 2, params_screen)

	

	########## Variáveis Globais  ##################		
	# Data for compute shaders has to come as an array of bytes
	var time = polar_to_vector(tm[0], tm[1], offset)    #mudar para um nome melhor
	print(time)
	var int_variables = [
		len(obj_par), len(obj_tel), n_x, n_y,
	]
	var float_variables = [
		FARAWAY, kd, ka,
		obj_par_color.r, obj_par_color.g, obj_par_color.b, 1,
		obj_tel_color.r, obj_tel_color.g, obj_tel_color.b, 1,
		time[0], time[1], time[2], 0,      #mudar para um nome melhor
	]
	var params_int_var : PackedByteArray = PackedInt32Array(
		int_variables
		).to_byte_array()
	var params_float_var : PackedByteArray = PackedFloat64Array(
		float_variables
		).to_byte_array()
	var joint_array : PackedByteArray = []
	joint_array.append_array(params_int_var)
	joint_array.append_array(params_float_var)
	# Create storage buffer
	# Data not needed, can just create with length
	gc_r._add_buffer(0, 3, joint_array)
	# Create uniform set using the storage buffer

	#4 componentes de cor, vezes as coordenadas da tela, 8 bytes por valor, dividido por 2 buffers
	
		########## Buffer de Output - Imagem ##################		
	# Data for compute shaders has to come as an array of bytes
	var empty_out_01 : PackedByteArray
	empty_out_01.resize(buffer_size)
	gc_r._add_buffer(0, 4, empty_out_01)

		########## Buffer de Output - Região  ##################		
	# Data for compute shaders has to come as an array of bytes
	var empty_out_02 : PackedByteArray
	empty_out_02.resize(buffer_size)
	gc_r._add_buffer(0, 5, empty_out_01)

	##### Uniform Set Unificado  #############
	gc_r._make_pipeline(Vector3i(tela_pixels/16, 1, 1), true)

	# Force the GPU to start our commands
	gc_r._submit()
	# Force the CPU to wait for the GPU to finish with the recorded commands
	gc_r._sync()
	# Now we can grab our data from the storage buffer
	var output_bytes := gc_r.output(0, 4)
	var output := output_bytes.to_float64_array()
	var hit_bytes := gc_r.output(0, 5)
	var output_hit := hit_bytes.to_float64_array()
	gc_r._free_rid(0, 0)
	gc_r._free_rid(0, 1)
	gc_r._free_rid(0, 2)
	gc_r._free_rid(0, 3)
	gc_r._free_rid(0, 4)
	gc_r._free_rid(0, 5)
	#gc_r._exit_tree()
	return [output, output_hit]
	#vec4_array_to_csv(output_hit, "area")
	


func _ready():
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func choose_split():
	var slices
	if pixel_dens <=16:
		passes = 1
		slices = screen_pixel_coord(n_y, n_x)
	elif pixel_dens >16 and pixel_dens <=26:
		passes = 2
		slices = [screen_pixel_2top(n_y, n_x), screen_pixel_2bot(n_y, n_x)]
	elif pixel_dens >26 and pixel_dens <=36:
		passes = 4
		slices = [screen_pixel_4_1(n_y, n_x), screen_pixel_4_2(n_y, n_x), screen_pixel_4_3(n_y, n_x), screen_pixel_4_4(n_y, n_x)]
	elif pixel_dens > 36 and pixel_dens <= 50:
		passes = 8
		slices = [
			screen_pixel_arbitrary(n_y, n_x, 0, 8),
			screen_pixel_arbitrary(n_y, n_x, 1, 8),
			screen_pixel_arbitrary(n_y, n_x, 2, 8),
			screen_pixel_arbitrary(n_y, n_x, 3, 8),
			screen_pixel_arbitrary(n_y, n_x, 4, 8),
			screen_pixel_arbitrary(n_y, n_x, 5, 8),
			screen_pixel_arbitrary(n_y, n_x, 6, 8),
			screen_pixel_arbitrary(n_y, n_x, 7, 8)]
	elif pixel_dens > 50 and pixel_dens <= 70:
		passes = 16
		slices = [
			screen_pixel_arbitrary(n_y, n_x, 0, 16),
			screen_pixel_arbitrary(n_y, n_x, 1, 16),
			screen_pixel_arbitrary(n_y, n_x, 2, 16),
			screen_pixel_arbitrary(n_y, n_x, 3, 16),
			screen_pixel_arbitrary(n_y, n_x, 4, 16),
			screen_pixel_arbitrary(n_y, n_x, 5, 16),
			screen_pixel_arbitrary(n_y, n_x, 6, 16),
			screen_pixel_arbitrary(n_y, n_x, 7, 16),
			screen_pixel_arbitrary(n_y, n_x, 8, 16),
			screen_pixel_arbitrary(n_y, n_x, 9, 16),
			screen_pixel_arbitrary(n_y, n_x, 10, 16),
			screen_pixel_arbitrary(n_y, n_x, 11, 16),
			screen_pixel_arbitrary(n_y, n_x, 12, 16),
			screen_pixel_arbitrary(n_y, n_x, 13, 16),
			screen_pixel_arbitrary(n_y, n_x, 14, 16),
			screen_pixel_arbitrary(n_y, n_x, 15, 16)]
	elif pixel_dens > 70:
		passes = 24
		slices = [
			screen_pixel_arbitrary(n_y, n_x, 0, 24),
			screen_pixel_arbitrary(n_y, n_x, 1, 24),
			screen_pixel_arbitrary(n_y, n_x, 2, 24),
			screen_pixel_arbitrary(n_y, n_x, 3, 24),
			screen_pixel_arbitrary(n_y, n_x, 4, 24),
			screen_pixel_arbitrary(n_y, n_x, 5, 24),
			screen_pixel_arbitrary(n_y, n_x, 6, 24),
			screen_pixel_arbitrary(n_y, n_x, 7, 24),
			screen_pixel_arbitrary(n_y, n_x, 8, 24),
			screen_pixel_arbitrary(n_y, n_x, 9, 24),
			screen_pixel_arbitrary(n_y, n_x, 10, 24),
			screen_pixel_arbitrary(n_y, n_x, 11, 24),
			screen_pixel_arbitrary(n_y, n_x, 12, 24),
			screen_pixel_arbitrary(n_y, n_x, 13, 24),
			screen_pixel_arbitrary(n_y, n_x, 14, 24),
			screen_pixel_arbitrary(n_y, n_x, 15, 24),
			screen_pixel_arbitrary(n_y, n_x, 16, 24),
			screen_pixel_arbitrary(n_y, n_x, 17, 24),
			screen_pixel_arbitrary(n_y, n_x, 18, 24),
			screen_pixel_arbitrary(n_y, n_x, 19, 24),
			screen_pixel_arbitrary(n_y, n_x, 20, 24),
			screen_pixel_arbitrary(n_y, n_x, 21, 24),
			screen_pixel_arbitrary(n_y, n_x, 22, 24),
			screen_pixel_arbitrary(n_y, n_x, 23, 24)
		]
	return slices

func pre_render():
	for t in range(0, len(traj), 1):
		var t_start = Time.get_ticks_msec()
		$LabelPrompt.text += "Gerando Imagem {0}/{1}\n".format([t+1, len(traj)])
		var sliced_input = choose_split()
		var image_bytes : PackedFloat64Array
		var region_bytes : PackedFloat64Array
		for pa in sliced_input:
			var slice = compute(traj[t], t, pa)
			image_bytes.append_array(slice[0])
			region_bytes.append_array(slice[1])
		var t_finish = Time.get_ticks_msec()
		var im = Image.create_from_data(n_x, n_y, false, Image.FORMAT_RGBA8, convert_to_8bit_depth_frame(image_bytes))
		im.save_png("{0}/{1}-{2}.png".format([out_directory,img_prefix,t]))
		vec4_array_to_csv(region_bytes, "{0}-{1}".format([data_prefix,t]), [n_x, n_y])
		$LabelPrompt.text += "Imagem {0}/{1} Gerada em {2} msec\n".format([t+1, len(traj), t_finish-t_start])
		prog_value += 1
	$LabelPrompt.text += "Processo Finalizado\n"

func pre_render_debug():
	for t in range(0, len(traj_debug_img), 1):
		var t_start = Time.get_ticks_msec()
		$LabelPrompt.text += "Gerando Imagem de teste\n".format([t+1, len(traj)])
		var sliced_input = choose_split()
		var image_bytes : PackedFloat64Array
		var region_bytes : PackedFloat64Array
		for pa in sliced_input:
			var slice = compute(traj_debug_img[t], t, pa)
			image_bytes.append_array(slice[0])
			region_bytes.append_array(slice[1])
		var t_finish = Time.get_ticks_msec()
		var im = Image.create_from_data(n_x, n_y, false, Image.FORMAT_RGBA8, convert_to_8bit_depth_frame(image_bytes))
		im.save_png("{0}/{1}-{2}.png".format([out_directory,img_prefix,t]))
		#vec4_array_to_csv(region_bytes, "{0}-{1}".format([data_prefix,t]), [n_x, n_y])
		$LabelPrompt.text += "Imagem de teste gerada em {2} msec\n".format([t+1, len(traj), t_finish-t_start])
		prog_value += 1
	$LabelPrompt.text += "Processo Finalizado\n"

func rain_render():
	var csv_casefile : FileAccess
	if FileAccess.file_exists("res://output/{0}.csv".format([case_name])):
		csv_casefile = FileAccess.open("res://output/{0}.csv".format([case_name]), FileAccess.READ_WRITE)
		csv_casefile.seek_end(0)
	else:
		csv_casefile = FileAccess.open("res://output/{0}.csv".format([case_name]), FileAccess.WRITE_READ)
	for t in range(0, len(traj), 1):
		var t_start = Time.get_ticks_msec()
		$LabelPrompt.text += "Gerando Imagem {0}/{1}\n".format([t+1, len(traj)])
		var sliced_input = choose_split()
		var image_bytes : PackedFloat64Array
		var region_bytes : PackedFloat64Array
		for pa in sliced_input:
			var slice = compute_rain(traj[t], t, pa)
			image_bytes.append_array(slice[0])
			region_bytes.append_array(slice[1])
		var t_finish = Time.get_ticks_msec()
		var im = Image.create_from_data(n_x, n_y, false, Image.FORMAT_RGBA8, convert_to_8bit_depth_frame(image_bytes))
		var cont_area = contribution_area(im,obj_tel_color,pixel_dens)
		im.save_png("{0}/{1}-{2}-{3}m2.png".format([out_directory,img_prefix,t, snapped(cont_area[0],0.001)]))
		csv_casefile.store_csv_line(PackedStringArray([traj[t][0], traj[t][1], snapped(cont_area[0],0.001)]))
		$LabelPrompt.text += "Imagem {0}/{1} Gerada em {2} msec\n".format([t+1, len(traj), t_finish-t_start])
		prog_value += 1
	csv_casefile.close()
	$LabelPrompt.text += "Processo Finalizado\n"	

func _on_button_pressed():
	#pre_render_debug()
	rain_render()




#VARIÁVEIS GLOBAIS
var timer

var traj_debug_img = [
	[20,70]
]


var traj = [
#[elevação,azimute]  #não pode ter espaço depois da vírgula
#[-0.8330,73.97],
#[4.18,73.26],
[18.33,70.43],
[32.15,65.89],
[45.34,58.37],
[57.08,44.88],
#[65.24,19.86],
#[65.84,344.63],
#[58.45,317.74],
#[47.01,303.09],
#[33.96,295],
#[20.2,290.18],
#[6.09,287.18],
#[-0.833,286.17]
]



var offset = 0
var azim = 65.89
var elev = 32.45
var pixel_dens = 32
var forramento = 2
var FARAWAY = pow(10,40)
var depth = 10


var kd = 0.5
var ka = 0.5

var n_x = 200
var n_y = 150
var l = -4
var r = 4
var top = 3
var bot = -3

var direct = [0,0,-1]
var obj_par
var obj_par_color = Color("#7ABDBD")
var obj_tel
var obj_tel_color = Color("#f2918c")

var out_directory
var data_prefix
var img_prefix
var case_name


var prog_value = 0
var prog_text
var tela_x
var tela_y
var passes
#antigo buffer size 65536


func _on_save_settings_pressed():
	var modelnode = get_node("TabContainer/Modelo/Model_prop/Grid_m")
	var rendnode = get_node("TabContainer/Renderização/Rend_prop/Grid_rend")
	var trajnode = get_node("TabContainer/Trajetória")
	var saidanode = get_node("TabContainer/Saída/out_prop/Grid_out")
	#aba modelo
	obj_tel_color = modelnode.get_child(3).get_pick_color()
	obj_par_color = modelnode.get_child(7).get_pick_color()  #--------
	#obj_tel = parse_obj_file(modelnode.get_child(1).get_text())
	#obj_par = parse_obj_file(modelnode.get_child(5).get_text())
	#aba renderização
	pixel_dens = rendnode.get_child(1).get_text().to_int()
	forramento = rendnode.get_child(3).get_text().to_int()
	kd = rendnode.get_child(5).get_text().to_int()
	ka = rendnode.get_child(7).get_text().to_int()
	#aba trajetória
	offset = trajnode.get_child(0).get_child(0).get_child(1).get_text().to_int()
	traj = FileParser.parse_text_to_array(trajnode.get_child(1).get_text())
	print(traj)
	#aba saída
	data_prefix = saidanode.get_child(3).get_text()
	img_prefix = saidanode.get_child(5).get_text()
	case_name = saidanode.get_child(7).get_text()
	print(case_name)
	screen_size_tlist(obj_par,obj_tel)
	recreate_shader_path()
	FileParser.create_shader_file(len(obj_par), len(obj_tel))
	FileParser.create_rain_shader_file(len(obj_par), len(obj_tel))
	get_node("Button").disabled = false


func _on_out_dir_pressed():
	get_node("wind_out_dir").visible = true

func _on_wind_out_dir_dir_selected(dir):
	out_directory = dir

func _on_wind_tel_file_selected(path):
	print(path)
	obj_tel = parse_obj_file(path)
	print(obj_tel)

func _on_wind_obst_file_selected(path):
	print(path)
	obj_par = parse_obj_file(path)
	print(obj_par)

func _on_b_tel_file_pressed():
	get_node("wind_tel").visible = true

func _on_b_obst_pressed():
	get_node("wind_obst").visible = true
