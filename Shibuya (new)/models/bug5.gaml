model TrainBug

global {
	float step <- 1#s;
	float node_tolerance <- 0.0001;
	
	float train_max_speed <- 90 #km/#h;
	float carriage_length <- 19.5#m;
	float space_between_carriages <- 0.3#m;
	int nb_carriages <- 10;
	float time_stop_in_station <- 45#s;

	shape_file bounds <- shape_file("../includes/Shibuya.shp");
	shape_file rail_shape_file <- shape_file("../includes/rail_tracks.shp");	
	geometry shape <- envelope(bounds);
	graph rail_network;


	map<string,float> time_to_spawn;
	list<string> line_names;
	
	init {
		create rail from: rail_shape_file with: [name::string(get("name"))];
		
		// to reverse the train tracks
		ask rail{
			shape <- polyline(reverse(shape.points));
		}
		do clean_railroad;
		
		
		list<point> first_points <- rail collect first(each.shape.points);
		list<point> last_points <- rail collect last(each.shape.points);
			
		ask rail{
			create rail_wp{
				location <- last(myself.shape.points);
				is_traffic_signal <- true;
			}
		}
		float spacing <- carriage_length + space_between_carriages;
		ask rail where not(first(each.shape.points) in last_points){
			float len <- perimeter(self.shape);
			
			create rail_wp{
				location <- first(myself.shape.points);
				is_spawn_location <- true;
				name <- myself.name;
				color <- #grey;
			}
			loop j from: 0 to: nb_carriages-1 {
				point p <- first(points_along(shape,[(j+1)*spacing/len]));
				create rail{
					shape <- polyline([first(points_along(myself.shape,[j*spacing/len])), p]);
					name <- myself.name;
				}
				create rail_wp{
					location <- p;
					is_spawn_location <- true;
					name <- myself.name;
					color <- #grey;
					if j = nb_carriages-1{
						loco_spawn <- true;
						color <- #green;
					}
				}
			}
			int last_index <- 0;
			loop while: perimeter(polyline(first(last_index,shape.points))) < nb_carriages*spacing{
				last_index <- last_index + 1;
			}
			int tmp <- length(shape.points) - last_index;
			shape <- polyline([first(points_along(shape,[nb_carriages*spacing/len]))] + last(tmp,shape.points));		
		}
		rail_network <- as_driving_graph(rail,rail_wp);
		ask rail_wp where each.is_traffic_signal{
			do initialize;
		}
		ask rail_wp{
			final_intersection <- compute_target();
		}
		
		line_names <- remove_duplicates(rail collect(each.name));
		loop l over: line_names{
			time_to_spawn << l::rnd(10.0)#s;
		}
		
		loop l over: line_names{
			do spawn_train(l);
		}
	}
	
	
	action spawn_train(string line_name){
		write "Spawning "+line_name;
		list<train> created_carriages;
		train loco;

		ask rail_wp where (each.name = line_name){
			create train {
				location <- myself.location;
				target <- myself.final_intersection;
				rail out <- rail(first(myself.roads_out));
				heading <- angle_between(first(out.shape.points),first(out.shape.points)+{1.0,0},out.shape.points[1]);
				speed <- 50#km/#h;
				if myself.loco_spawn{
					is_carriage <- false;
					loco <- self;
					max_deceleration <- 2#km/#h/#s;
					name <- line_name+" locomotive";
					write "to: "+target;
				}else{
					name <- line_name+" carriage "+int(self);
					created_carriages << self;
				}
			}
		}
		ask created_carriages{
			locomotive <- loco;
		}
		
		
		write 'end spawn.';	
	}
	
	
	action clean_railroad{
		ask rail{
			list<point> extremities <- [first(shape.points),first(shape.points)];
			loop p over: extremities{
				ask rail - self{
					if distance_to(first(self.shape.points),p) < node_tolerance{
						self.shape <- polyline([p]+last(length(self.shape.points)-1,self.shape.points));
					}
					if distance_to(last(self.shape.points),p) < node_tolerance{
						self.shape <- polyline(first(length(self.shape.points)-1,self.shape.points)+p);
					}
					
				}
			}
		}
	}
}

/*******************************************
 * 
 * 
 *     species definition
 * 
 * 
 * ***************************************** */

species rail skills: [skill_road]{
	float maxspeed <- train_max_speed;
	rgb color <- #black;
	
	aspect default {
		draw shape color: color;
	}
}

species rail_wp skills: [skill_road_node] {
	bool is_traffic_signal <- false;
	bool is_spawn_location <- false;
	rail_wp final_intersection <- nil;
	rgb color <- #white;
	bool loco_spawn <- false;
	float wait_time;
	list<rail> ways;
	bool is_green;

	
	action initialize{
		is_traffic_signal <- true;
		stop << [];
		loop rd over: roads_in {
			ways << rail(rd);
		}
		do to_red;
	}
	
	rail_wp compute_target{
		if empty(roads_out){
			return self;
		}else{
			return rail_wp(rail(first(roads_out)).target_node).compute_target();
		}
	}
	
	action to_green {
		stop[0] <- [];
		is_green <- true;
		color <- #green;
	}
	
	action to_red {
		stop[0] <- ways;
		is_green <- false;
		color <- #red;
	}
	
	reflex turn_to_red when: is_green {
		wait_time <- wait_time + step;
		if wait_time > 15#s{
			do to_green;
			wait_time <- 0.0;
		}
	}
	
	action trigger_signal{
		wait_time <- wait_time + step;
		if wait_time > time_stop_in_station{
			do to_green;
			wait_time <- 0.0;
		}
	}
	
	aspect default{
		draw circle(1.5) color: color;	
		if length(roads_in)> 0{
			geometry r <- first(roads_in);
			draw polyline(points_along(polyline(last(2,r.points)),[0.6,1.0])) color: #blue;
		}
			if length(roads_out)> 0{
			geometry r <- first(roads_out);
			draw polyline(points_along(polyline(first(2,r.points)),[0.0, 0.4])) color: #white;
		}
	}
}



//species train skills: [moving,advanced_driving] schedules: reverse(train){
species train skills: [advanced_driving] schedules: reverse(train){
	point spawn_location;
	rgb color <- rnd_color(255);
	rail_wp target;
	bool is_carriage <- true;
	train locomotive;
	float loco_speed;
	
	init {
		vehicle_length <- 19.5 #m;
		max_speed <- train_max_speed;
	}
	
	//choose a random target and compute the path to it
	reflex choose_path when: !is_carriage and (final_target = nil)   {
		write "choose path "+name+" targ: "+target+" loc: "+location;
		do compute_path graph: rail_network target: target; 
		write "fin path";
	}
	
	reflex carriage_move when: locomotive != nil {
		do goto target: target on: rail_network speed: locomotive.loco_speed;
	}
	
	reflex loco_move when: locomotive = nil and final_target != nil {
		point old_location <- location;
		do drive;	
		loco_speed <- norm(location - old_location)/step;

//if arrived at target, die and create a new car
		if (final_target = nil) {
			do unregister;
			ask train where (each.locomotive = self){
				do unregister;
				do die;
			}
			do die;
		}

		if  distance_to_current_target = 0{
			ask rail_wp(current_target){
				do trigger_signal;
			}
		}
	}
	
	reflex stat when: false{
		float speed_kmh <- round(10*self.speed*3600/1000)/10;
		float acceleration_kmh_s <- round(10*acceleration*3600 / 1000)/10;
		write ""+self+" Speed: "+speed_kmh+"km/h. Acc: "+acceleration_kmh_s+"km/h/s.";
		
	}
	
	aspect default {
		draw rectangle(19.5#m, 2.95#m ) depth: 2#m color: is_carriage?#grey:#green rotate: heading at: location;	
	}
}



experiment "train bug" type: gui  {
	float minimum_cycle_duration <- 0.001#s;
	output {
		display map type: 3d axes: false background: #darkgray{
		//	camera 'default' location: {198.4788,143.3489,64.7132} target: {198.6933,81.909,0.0};
			species rail;
			species train;
			species rail_wp;
		}
	}
}

