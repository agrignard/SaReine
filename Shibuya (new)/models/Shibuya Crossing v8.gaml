/**
* Name: ShibuyaCrossing
* Based on the internal skeleton template. 
* Author: Patrick Taillandier
* Tags: 
*/

model ShibuyaCrossing

global {
	int nb_people <- 180;
	float step <- 0.1#s;
	
	float car_spawning_interval <- 4#s;
	float global_max_speed <- 40 #km / #h;
	float precision <- 0.2;
	float factor <- 1.0;
	float mesh_size <- 4.0;
	
	list<float> schedule_times <- [ 15#s, // pedestrian light to green
									60#s, // pedestrian light to red
									85#s, // car group 1 to green
									100#s,// car group 1 to red
									105#s,// car group 2 to green
									120#s // car group 2 to red
								  ];
	
	
	
	
	shape_file bounds <- shape_file("../includes/Shibuya.shp");
	image_file photo <- (image_file(("../includes/Shibuya.png")));

	shape_file building_polygon_shape_file <- shape_file("../includes/building_polygon.shp");
	shape_file fake_building_polygon_shape_file <- shape_file("../includes/fake_buildings.shp");
	shape_file crosswalk_shape_file <- shape_file("../includes/crosswalk.shp");
	shape_file walking_area_shape_file <- shape_file("../includes/walking area.shp");
	shape_file road_shape_file <- shape_file("../includes/roads.shp");

	
	geometry shape <- envelope(bounds);
	
	
	float P_shoulder_length <- 1.0 parameter: true;
	float P_proba_detour <- 0.5 parameter: true ;
	bool P_avoid_other <- true parameter: true ;
	float P_obstacle_consideration_distance <- 3.0 parameter: true ;
	float P_pedestrian_consideration_distance <- 3.0 parameter: true ;
	float P_tolerance_target <- 0.1 parameter: true;
	bool P_use_geometry_target <- true parameter: true;
	
	
	string P_model_type <- "simple" among: ["simple", "advanced"] parameter: true ; 
	string pedestrian_path_init <- "grid" among: ["voronoi", "grid"] parameter: true ; 
	
	//float P_A_pedestrian_SFM_advanced parameter: true <- 0.16 category: "SFM advanced" ;
	float P_A_pedestrian_SFM_advanced parameter: true <- 0.0001 category: "SFM advanced" ;
	float P_A_obstacles_SFM_advanced parameter: true <- 1.9 category: "SFM advanced" ;
	float P_B_pedestrian_SFM_advanced parameter: true <- 0.1 category: "SFM advanced" ;
	float P_B_obstacles_SFM_advanced parameter: true <- 1.0 category: "SFM advanced" ;
	float P_relaxion_SFM_advanced  parameter: true <- 0.5 category: "SFM advanced" ;
	float P_gama_SFM_advanced parameter: true <- 0.35 category: "SFM advanced" ;
	float P_lambda_SFM_advanced <- 0.1 parameter: true category: "SFM advanced" ;
	float P_minimal_distance_advanced <- 0.25 parameter: true category: "SFM advanced" ;
	
	float P_n_prime_SFM_simple parameter: true <- 3.0 category: "SFM simple" ;
	float P_n_SFM_simple parameter: true <- 2.0 category: "SFM simple" ;
	float P_lambda_SFM_simple <- 2.0 parameter: true category: "SFM simple" ;
	float P_gama_SFM_simple parameter: true <- 0.35 category: "SFM simple" ;
	float P_relaxion_SFM_simple parameter: true <- 0.54 category: "SFM simple" ;
	float P_A_pedestrian_SFM_simple parameter: true <-4.5category: "SFM simple" ;
	graph network;
	

	bool can_cross <- false;
	float time_since_last_spawn <- 0.0;
	
	people the_people;
	point endpoint;
	int schedule_step <- 0;
	float schedule_time <- 0.0;
	float time_to_clear_crossing <- 0.0;
	float percent_time_remaining <- 1.0;
	
	geometry open_area;
	geometry bounds_shape;
	
	graph road_network;

	list<geometry> walking_area_divided;
	list<point> nodes;
	list<geometry> nodes_inside;
	list<geometry> voronoi_diagram;
	
	init {
		create road from: road_shape_file with: [group::int(get("group"))];
		ask road {
			point p <- last(shape.points);
			if length(intersection where (each.location = p))=0{
				create intersection{
					location <- p;
					group <- myself.group;
				}
			}
		}
		
		// create spawn intersections and the corresponding destination
		ask road where (each.group > 0){
			create intersection{
				location <- first(myself.shape.points);
				color <- #blue;
				is_spawn_location <- true;
			}
		}
		
		road_network <- as_driving_graph(road,intersection);
		
		ask intersection where (each.group > 0) {
			do initialize;
		}
		
		ask intersection where (each.is_spawn_location){
			final_intersection <- compute_target();
		}
			
		create building from: building_polygon_shape_file with:[height::float(get("height")),floor::float(get("floor"))]{
			location <- location + {0,0,floor};
		}
		
		create fake_building from: fake_building_polygon_shape_file{
			height <- 3.0;
		}
		
		create crosswalk from:crosswalk_shape_file ;
		create walking_area from:walking_area_shape_file;
		
		ask crosswalk{
			ends <- walking_area overlapping self;
		}
		
		loop w over:  walking_area{
			loop c over: (crosswalk overlapping w){
				create waiting_area{
					shape <- intersection(w.shape,c.shape);
					my_crosswalk <- c;
					my_walking_area <- w;
					w.waiting_areas <+ self;
					c.waiting_areas <+ self;
				}
			}
		}
		
		loop c over: crosswalk{
			loop w over: c.waiting_areas{
				w.opposite <- first(c.waiting_areas - w);
			}
		}
		
		
		open_area <- union(walking_area collect each.shape);
		bounds_shape <- open_area - union(building collect each.shape);
		list<geometry> lg;
		
		
		if pedestrian_path_init = "voronoi"{
			loop w over: walking_area{	
				walking_area_divided <- walking_area_divided + split_geometry(w - union(building collect (each.shape)),mesh_size);
			}
			
			voronoi_diagram <- voronoi(walking_area_divided accumulate(each.points));
			voronoi_diagram <- voronoi_diagram collect((each inter (open_area - 0.5)) - (union(building collect (each.shape))+0.5));
			lg <- voronoi_diagram accumulate (to_segments(each));
			create pedestrian_path from: lg;
		}else{
			float minx <- min(envelope(open_area).points accumulate each.x);
			float maxx <- max(envelope(open_area).points accumulate each.x);
	//		float area_width <- maxx-minx;
			float miny <- min(envelope(open_area).points accumulate each.y);
			float maxy <- max(envelope(open_area).points accumulate each.y);
	//		float area_height <- maxx-minx;
						
//				list<geometry> lines;
//				int num <- int(area_width/mesh_size);
//				loop k from: 0 to: num {
//					lines << line([{k * area_width/num, 0}, {k * area_width/num, area_height}]);	
//				}
//				num <- int(area_height/mesh_size);
//				loop k from: 0 to: num {
//					lines << line([{0, k * area_height/num, 0}, {area_width, k * area_height/num}]);	
//				}
//				
//				lines <- clean_network(union(lines).geometries, 0.00, true, true);
//				create pedestrian_path from: lines;
			
			list<geometry> lines;
			float i <-  float(floor(minx));
			loop  while: i < maxx{
				float j <-  float(floor(miny));
				loop  while: j < maxy{
					lines << polyline([{i,j},{i+mesh_size,j}]);
					lines << polyline([{i,j},{i,j+mesh_size}]);
					lines <<polyline([{i,j},{i+mesh_size,j+mesh_size}]);
					lines << polyline([{i,j+mesh_size},{i+mesh_size,j}]);
					j <- j + mesh_size;
				}
				i <- i + mesh_size;
			}
			
			lines <- lines where (bounds_shape covers each);
//			write "cleaning";
//			lines <- clean_network(union(lines).geometries, 0.001, true, false);
//			write "cleaned";
			create pedestrian_path from: lines;
			
//			float i <-  float(floor(minx));
//			loop  while: i < maxx{
//				float j <-  float(floor(miny));
//				loop  while: j < maxy{
//					create pedestrian_path{
//						shape <- polyline([{i,j},{i+mesh_size,j}]);
//					}
//					create pedestrian_path{
//						shape <- polyline([{i,j},{i,j+mesh_size}]);
//					}
//					create pedestrian_path{
//						shape <- polyline([{i,j},{i+mesh_size,j+mesh_size}]);
//					}
//					create pedestrian_path{
//						shape <- polyline([{i,j+mesh_size},{i+mesh_size,j}]);
//					}
//					j <- j + mesh_size;
//				}
//				i <- i + mesh_size;
//			}		
//			
//			ask pedestrian_path{
//				if  !(bounds_shape covers self.shape){
//					do die;
//				}
//			}
		}
		

		
		ask pedestrian_path   {
			free_space <- shape + (mesh_size*0.6);
//			my_area <- first(walking_area overlapping self);
//			if my_area = nil{
//				write "gz";
//				color <- #red;
//			}
		}
		
		
		
		nodes <-remove_duplicates(pedestrian_path accumulate ([first(each.shape.points),last(each.shape.points)]));		
		nodes_inside <- (nodes collect geometry(each)) inside open_area;
		
		ask waiting_area{
			do compute_direction;
		}
		
		network <- as_edge_graph(pedestrian_path);
		
//		ask walking_area{
//			write self;
//			write waiting_areas.values;
//		}	
//		ask pedestrian_path {
//			do build_intersection_areas pedestrian_graph: network;
//		}
		
	//	write walking_area[0];
	
		point start_point <- any_location_in(one_of(walking_area));
		endpoint <- any_location_in(open_area);
		create people number:nb_people{
			//location <- start_point; //any_location_in(one_of(walking_area));
			obstacle_species<-[building];
			current_area <- one_of(walking_area);
			location <- any_location_in(current_area);
			dest <- location;
			final_dest <- location;
			current_waiting_area <- nil;

			obstacle_consideration_distance <-P_obstacle_consideration_distance;
			pedestrian_consideration_distance <-P_pedestrian_consideration_distance;
			shoulder_length <- P_shoulder_length;
			avoid_other <- P_avoid_other;
			proba_detour <- P_proba_detour;
			
			use_geometry_waypoint <- P_use_geometry_target;
			tolerance_waypoint<- P_tolerance_target;
			pedestrian_species <- [people];
			
			pedestrian_model <- P_model_type;
			
		
			if (pedestrian_model = "simple") {
				A_pedestrians_SFM <- P_A_pedestrian_SFM_simple;
				relaxion_SFM <- P_relaxion_SFM_simple;
				gama_SFM <- P_gama_SFM_simple;
				lambda_SFM <- P_lambda_SFM_simple;
				n_prime_SFM <- P_n_prime_SFM_simple;
				n_SFM <- P_n_SFM_simple;
			} else {
				A_pedestrians_SFM <- P_A_pedestrian_SFM_advanced;
				A_obstacles_SFM <- P_A_obstacles_SFM_advanced;
				B_pedestrians_SFM <- P_B_pedestrian_SFM_advanced;
				B_obstacles_SFM <- P_B_obstacles_SFM_advanced;
				relaxion_SFM <- P_relaxion_SFM_advanced;
				gama_SFM <- P_gama_SFM_advanced;
				lambda_SFM <- P_lambda_SFM_advanced;
				minimal_distance <- P_minimal_distance_advanced;
			
			}
		}	
	
		create debug;
		do spawn_car;
		
		
		ask intersection where (each.group > 0) {
			list<point> lp <- last(2,first(roads_in).shape.points);
			create traffic_light_3d{
				location <- myself.location;
				group <- myself.group;
				heading <- towards(lp[0],lp[1]) + 90;
			}
		
		}
	}
	
//	list<geometry> make_convex(geometry g){
//		if length(g.points)<3{
//			return [g];
//		}else{
//			int pos <- 0;
//			int index <- 0;
//			list<point> l <- g.points+(g.points[1]);
//			int nl <- length(l);
//			bool last_angle <- mod(angle_between(l[nl-2],l[nl-3],l[nl-1]),360) < 180;
//			
//			loop i from: 1 to: length(l) - 2{
//				if mod(angle_between(l[i],l[i-1],l[i+1]),360) < 180{
//					pos <- pos+1;
//					if last_angle = false{
//						index <- i;
//					}
//					last_angle <- true;
//				}else{
//					last_angle <- false;
//				}
//					
//			}
//			if (pos = 0) or (pos=length(g.points)-1){
//				return [g];
//			}else if pos < length(g.points)-1 - pos{
//				return make_convex(polygon(reverse(g.points)));
//			}else{
//				geometry sol <- polygon([l[index-1],l[index],l[index+1]]);
//				geometry sol2 <- g - sol;				
//				if sol2 != nil{
//					return (sol2.geometries accumulate make_convex(each))+sol;
//				}else{
//					return [sol];
//				}
//			}			
//		}
//
//	}
//	
	bool is_convex(geometry g){
		int pos <- 0;
		list<point> l <- g.points+g.points[2];
		loop i from: 1 to: length(l) - 2{
			if mod(angle_between(l[i],l[i-1],l[i+1]),360) < 180{
				pos <- pos+1;
			}
		}
		return (pos = 0) or (pos = length(g.points)-1);
	}
	
	action spawn_car{
		intersection i <- one_of(intersection where (each.is_spawn_location));
		create car with: (location: i.location, target: i.final_intersection);
		
	}
	

	//reflex switch_traffic_light when: mod(cycle,timing)=200{
	action switch_pedestrian_lights{
		can_cross <- !can_cross;
		if can_cross {
			ask people{
				waiting <- false;
			}
		}else{
			loop w over: waiting_area{
				ask people inside w{
					waiting <- true;
				}
			}
		}
	}
	
	reflex main_scheduler{
		int cycle_time <- 1200;
		bool advance_step <- false;
		
		// spawn cars
		
		if time_since_last_spawn > car_spawning_interval {
			do spawn_car;
			time_since_last_spawn <- 0.0;
		}else{
			time_since_last_spawn <- time_since_last_spawn + step;
		}
		
		// change traffic lights
		
		if schedule_step = 1{
			percent_time_remaining <- (schedule_times[1] - schedule_time)/(schedule_times[1] - schedule_times[0]);
		}else if schedule_step = 0{
			percent_time_remaining <- (schedule_times[0] - schedule_time)/(schedule_times[5] + schedule_times[0] - schedule_times[1]);
		}else{
			percent_time_remaining <- (schedule_times[0]+schedule_times[5] - schedule_time)/(schedule_times[5] + schedule_times[0] - schedule_times[1]);			
		}
				
		switch schedule_step{		
			match 0{
				if  schedule_time > schedule_times[0]{
					do switch_pedestrian_lights;
					schedule_step <- schedule_step + 1;
					percent_time_remaining <- 1.0;
				}
			}
			match 1{
				if schedule_time > schedule_times[1]{
					do switch_pedestrian_lights;
					schedule_step <- schedule_step + 1;
					time_to_clear_crossing <- schedule_times[2]-schedule_times[1];
					percent_time_remaining <- 1.0;
				}
			}
			match 2{
				time_to_clear_crossing <- time_to_clear_crossing - step;
				if schedule_time > schedule_times[2]{
					ask intersection where (each.group = 1){
						do to_green;
					}
					schedule_step <- schedule_step + 1;
				}
			}
			match 3 {
				if schedule_time > schedule_times[3]-3#s{
					ask intersection where (each.group = 1){
						do to_orange;
					}
				}
				if schedule_time > schedule_times[3]{
					ask intersection where (each.group = 1){
						do to_red;
					}
					schedule_step <- schedule_step + 1;
				}
			}
			match 4 {
				if schedule_time > schedule_times[4]{
					ask intersection where (each.group = 2){
						do to_green;
					}
					schedule_step <- schedule_step + 1;
				}
			}
			match 5{
					if schedule_time > schedule_times[5]-3#s{
					ask intersection where (each.group = 2){
						do to_orange;
					}
				}
				if schedule_time > schedule_times[5]{
					ask intersection where (each.group = 2){
						do to_red;
					}
					schedule_step <- 0;
					schedule_time <- - step;
				}
			}
		}
		
		schedule_time <- schedule_time + step;
	}
}

/*******************************************
 * 
 * 
 *     species definition
 * 
 * 
 * ***************************************** */


species road skills: [skill_road]{
	int group;
	int num_lanes <- 1;
	float maxspeed <- global_max_speed;
	
	aspect default {
		draw shape color: #red;
	}
}


species intersection skills: [skill_road_node] {
	bool is_traffic_signal <- false;
	bool is_spawn_location <- false;
	int group;
	intersection final_intersection <- nil;
	rgb color <- #white;
//	float counter <- rnd(time_to_change);
	
	//take into consideration the roads coming from both direction (for traffic light)
	list<road> ways;
	//list<road> ways2;
	
	//if the traffic light is green
	bool is_green;
	string current_color <- "red";
//	rgb color <- #yellow;

	aspect default{
		draw circle(0.5) color: color;
	}
	
	action initialize{
		is_traffic_signal <- true;
		stop << [];
		loop rd over: roads_in {
			ways << road(rd);
		}
		do to_red;
	}
	
	intersection compute_target{
		if empty(roads_out){
			return self;
		}else{
			return intersection(road(first(roads_out)).target_node).compute_target();
		}
	}
	
	action to_green {
		stop[0] <- [];
		is_green <- true;
		color <- #green;
		current_color <- "green";
	}
	
	action to_orange{
		current_color <- "orange";
	}

	//shift the traffic light to red
	action to_red {
		stop[0] <- ways;
		is_green <- false;
		current_color <- "red";
		color <- #red;
	}
}

species car skills: [advanced_driving] {
	rgb color <- rnd_color(255);
	intersection target;
	
	init {
		vehicle_length <- 4.0 #m;
		//car occupies 2 lanes
		num_lanes_occupied <-1;
		max_speed <- global_max_speed;
				
	//	proba_block_node <- proba_block_node_car;
		proba_respect_priorities <- 1.0;
		proba_respect_stops <- [1.0];
		proba_use_linked_road <- 0.0;

		lane_change_limit <- 2;
		linked_lane_limit <- 0;
		
	}
	//choose a random target and compute the path to it
	reflex choose_path when: final_target = nil {
		do compute_path graph: road_network target: target; 
	}
	reflex move when: final_target != nil {
		do drive;
		//if arrived at target, kill it and create a new car
		if (final_target = nil) {
			do unregister;
			do die;
		}
	}
	

	
	aspect default {
		if (current_road != nil) {
			draw rectangle(3.8#m, 1.7#m ) depth: 0.7#m color: color rotate: heading at: location+{0,0,0.2#m};	
	//	draw circle(0.5) at: location color: color;
			draw (circle(0.3#m)rotated_by(90::{1,0,0})) rotate: heading  color: #black depth: 0.3#m at: location + {0,0,0.3} + ({1#m,0.6,0} rotated_by (heading::{0,0,1}));
			draw (circle(0.3#m)rotated_by(90::{1,0,0})) rotate: heading  color: #black depth: 0.3#m at: location +  {0,0,0.3} + ({-1#m,0.6,0} rotated_by (heading::{0,0,1}));
			draw (circle(0.3#m)rotated_by(-90::{1,0,0})) rotate: heading  color: #black depth: 0.3#m at: location +  {0,0,0.3} + ({1#m,-0.6,0} rotated_by (heading::{0,0,1}));
			draw (circle(0.3#m)rotated_by(-90::{1,0,0})) rotate: heading  color: #black depth: 0.3#m at: location +  {0,0,0.3} + ({-1#m,-0.6,0} rotated_by (heading::{0,0,1}));
			draw (triangle(0.5#m,0.5#m)rotated_by(-90::{1,0,0})) rotate: heading  color: #black depth: 1.6#m at: location +  {0,0,1} + ({-1#m,0.8,0} rotated_by (heading::{0,0,1}));
			draw (triangle(1#m,0.5#m)rotated_by(-90::{1,0,0})) rotate: heading  color: #black depth: 1.6#m at: location +  {0,0,1} + ({0.6#m,0.8,0} rotated_by (heading::{0,0,1}));
			draw (square(0.05#m)rotated_by(26::{0,1,0})) rotate: heading  color: color depth: 0.52#m at: location +  {0,0,0.87} + ({-1.22#m,0.8,0} rotated_by (heading::{0,0,1}));
 			draw (square(0.05#m)rotated_by(26::{0,1,0})) rotate: heading  color: color depth: 0.52#m at: location +  {0,0,0.87} + ({-1.22#m,-0.8,0} rotated_by (heading::{0,0,1}));
 			draw (square(0.05#m)rotated_by(-45::{0,1,0})) rotate: heading  color: color depth: 0.65#m at: location +  {0,0,0.87} + ({1.08#m,0.8,0} rotated_by (heading::{0,0,1}));
 			draw (square(0.05#m)rotated_by(-45::{0,1,0})) rotate: heading  color: color depth: 0.65#m at: location +  {0,0,0.87} + ({1.08#m,-0.8,0} rotated_by (heading::{0,0,1}));
 			draw rectangle(1.65#m, 1.65#m ) depth: 0.05#m color: color rotate: heading at: location+{0,0,1.3#m}+ ({-0.19#m,0,0} rotated_by (heading::{0,0,1}));	
 			draw rectangle(1.65#m, 1.6#m ) depth: 0.4#m color: #black rotate: heading at: location+{0,0,0.9#m}+ ({-0.19#m,0,0} rotated_by (heading::{0,0,1}));	
			draw (square(0.05#m)rotated_by(3::{1,0,0})) rotate: heading  color: color depth: 0.47#m at: location +  {0,0,0.87} + ({-0.4#m,0.825,0} rotated_by (heading::{0,0,1}));
 			draw (square(0.05#m)rotated_by(-3::{1,0,0})) rotate: heading  color: color depth: 0.47#m at: location +  {0,0,0.87} + ({-0.4#m,-0.825,0} rotated_by (heading::{0,0,1}));
  
			
		//	draw rectangle(3.8#m, 1.7#m ) depth: 0.8#m color: rgb(color,20) rotate: heading at: location+{0,0,0.1#m};	
		}
	}

}







species pedestrian_path skills: [pedestrian_road]{
	rgb color <- #gray;
	walking_area my_area;
	
	aspect default { 
		draw shape  color: color;
	}
	aspect free_area_aspect {
		draw shape  color: color;
		draw free_space color: rgb(color,20) border: #black;// rgb(255,174,201,20) border: #black;
		
		
	}
}


species building {
	float height;
	float floor <- 0.0;
	
	aspect default {
		draw shape color: #gray depth: height;		
	}
}

species fake_building {
	float height;
	
	aspect default {
		draw shape color: #gray depth: height;		
	}
}

species walking_area {
	list<waiting_area> waiting_areas;
	aspect default {
		switch int(self){
			match 0 {
				draw shape color: #green border: #black;
			}
			match 1 {
				draw shape color: #blue border: #black;
			}
			match 2 {
				draw shape color: #orange border: #black;
			}
			match 3 {
				draw shape color: #red border: #black;
			}
		}
		
		
//		loop g over: waiting_areas.values{
//			draw g color: #yellow border: #black;
//		}
	}
}

species crosswalk {
	list<walking_area> ends;
	list<waiting_area> waiting_areas;
	
	aspect default {
		draw shape color: #gray border: #black;
	}
}

species waiting_area{
	crosswalk my_crosswalk;
	walking_area my_walking_area;
	waiting_area opposite;
	point direction;
	geometry waiting_front;
	
	action compute_direction{
		float norm <- 0.0;
		direction <- {0,0};
		loop i from: 0 to: length(my_crosswalk.shape.points)-2{
			if norm(my_crosswalk.shape.points[i+1]-my_crosswalk.shape.points[i]) > norm{
				direction <- my_crosswalk.shape.points[i+1]-my_crosswalk.shape.points[i];
				norm <- norm(direction);
			}	
		}
		if direction.x * (opposite.location.x - self.location.x) + direction.y * (opposite.location.y - self.location.y) < 0{
			direction <- -direction;
		}
		waiting_front <- polyline((shape.points where (direction.x*(each.x -location.x)+direction.y*(each.y -location.y)>0)) collect each);
		
	}
	
	aspect default {
		draw shape color: #yellow border: #black;
//		draw polyline([location,location+direction]) width: 2 color: #yellow;
		draw waiting_front width: 5 color: #red;
	}
}




species people skills: [pedestrian] control: fsm{
	rgb color <- rnd_color(255);
	float normal_speed <- gauss(5.2,1.5) #km/#h min: 2.5 #km/#h;
	float scale <- rnd(0.9,1.1);
	point dest;
	point final_dest;
	walking_area final_area;
	walking_area current_area;
	waiting_area current_waiting_area;
	waiting_area last_waiting_area;
	bool going_to_cross <- false;
	bool waiting <- false;
	point wait_location;
	list<point> tracking;
	string last_state;
	int essai <- 0;
	bool tester <- false;

	
	state find_new_destination initial: true{
		speed <- normal_speed;
		//final_dest <- any_location_in(open_area);
		final_dest <- one_of(nodes_inside).location;
		final_area <- walking_area closest_to final_dest;
		current_waiting_area <- nil;
		current_area <- walking_area closest_to self.location;	
		tracking <- [location];
	//	transition to: go_to_final_destination when: current_area = final_area;
		transition to: go_to_grid_before_final_destination when: current_area = final_area;
		//transition to: go_to_crosswalk when: current_area != final_area;
		transition to: go_to_grid_before_crosswalk when: current_area != final_area;
		last_state <- "find_new_destination";
	}
	
	state go_to_grid_before_final_destination{
		enter{
			speed <- normal_speed;		
			dest <- nodes closest_to self;
			tracking <+ dest;
		}
		do walk_to target: dest;
		if  norm(location - dest) < precision{
			location <- dest;
		}
		transition to: go_to_final_destination when: norm(location - dest) < precision;
	//	transition to: go_to_final_destination when: location = dest ;
	}
	
	state go_to_final_destination{
		enter{
			essai <- 1;
			dest <- final_dest;
			essai <- 2;
			dest <- nodes closest_to dest;
			tracking <+ dest;
			essai <- 4;
		//	location <- nodes closest_to self;
			if norm(location - dest)>= precision{	
				do compute_virtual_path pedestrian_graph:network target: dest;
			}
			essai <- 5;
		}
		//do walk_to target: desti;
		if norm(location - dest)>= precision{	
			do walk;
		}
		essai <- 6;
		transition to: find_new_destination when: norm(location - dest) < precision;
	}
	
		state go_to_grid_before_crosswalk{
		enter{
			speed <- normal_speed;
			dest <- nodes closest_to self;
			tracking <+ dest;
		}
		do walk_to target: dest;
		last_state <- "go_to_final_destination";
		if  norm(location - dest) < precision{
			location <- dest;
		}
	//	transition to: go_to_final_destination when: norm(location - dest) < precision;
		transition to: go_to_crosswalk when: norm(location - dest) < precision ;
	}
	
	state go_to_crosswalk{
		enter{
			current_waiting_area <- 
				first(current_area.waiting_areas where (each.opposite.my_walking_area = final_area));
			if current_waiting_area = nil{
				current_waiting_area <- one_of(current_area.waiting_areas);
			}				
			dest <- any_location_in(current_waiting_area);
			dest <- nodes closest_to dest;
			tracking <+ dest;
		//	location <- nodes closest_to self;
			essai <- 4;
			if norm(location - dest)>= precision{	
				do compute_virtual_path pedestrian_graph:network target: dest;
			}
			essai <- 5;
			
		}
		essai <- 6;
		if norm(location - dest)>= precision{	
			do walk;
		}
		essai <- 7;
			//	do walk_to target: desti;
			last_state <- "go_to_crosswalk";
		transition to: waiting_to_cross when: (norm(location - dest) < precision) or (distance_to(self,current_waiting_area)< shoulder_length);
	}
	
	state waiting_to_cross{
		enter{
	//		dest <- first(point(intersection(polyline(current_waiting_area.shape.points),polyline([location, location+current_waiting_area.direction]))));
			dest <- first(point(intersection(polyline(current_area.shape.points),polyline([location, location+current_waiting_area.direction]))));
			if dest = nil{
				dest <- any_location_in(current_waiting_area);
			}
			tracking <+ dest;
		}	
		do walk_to target: dest;
		last_state <- "waiting_to_cross";
		transition to: crossing when: can_cross and (norm(location - dest) < 2);
	}
	
	state crossing{
		enter{
			geometry crossing_target <- intersection(current_waiting_area.opposite.shape,polyline([wait_location-current_waiting_area.direction,wait_location+current_waiting_area.direction]));
			if crossing_target != nil{
				dest <- any_location_in(crossing_target);
			}else{
				dest <- any_location_in(current_waiting_area.opposite);
			}
			tracking <+ dest;
			current_area <- walking_area closest_to current_waiting_area.opposite;
		}
		if !can_cross{// boost to finish crossing before green light
			speed <- max(1,norm(dest-location)/(1#s+time_to_clear_crossing)) * normal_speed;
		}
		do walk_to target: dest;
		bool other_side_reached <- self.location distance_to current_area < 1#m;
		//transition to: go_to_crosswalk when: other_side_reached and (current_area != final_area);
		last_state <- "crossing";
		transition to: go_to_grid_before_crosswalk when: other_side_reached and (current_area != final_area);
		transition to: go_to_grid_before_final_destination when: other_side_reached and (current_area = final_area);
	}


	
	
	
	aspect default {
		draw square(shoulder_length/2 ) at: location+{shoulder_length/5, shoulder_length/5}color: #black;
		draw square(shoulder_length/2 ) at: location+{0,0,0.1} color: color;
	//	draw essai width: 2 color: color;
	
//		draw circle(0.5*shoulder_length) color: color at: dest;
//		draw square(0.5*shoulder_length) color: color at: final_dest;
//		draw polyline([location,final_dest]) width: 1 color: color;		
//		draw polyline([location,dest]) width: 2 color: color;
	//	draw polyline(waypoints) width: 2 color: color;
	}
	
	aspect 3d {		
		draw pyramid(scale*shoulder_length/2) color: color;
		draw sphere(scale*shoulder_length/4) at: location + {0,0,scale*shoulder_length/2} color: #black;
		draw sphere(scale*shoulder_length*7/32) at: location + ({scale*shoulder_length/16,0,0} rotated_by (heading::{0,0,1}))+ {0,0,scale*shoulder_length*15/32} color: rgb(191,181,164);	
//		draw circle(0.5*shoulder_length) color: color at: dest;
//		draw polyline([location,dest]) width: 1 color: color;
		if tester{
			draw polyline(waypoints) width: 3 color: color;
		}
	}
	
		aspect debug {		
		draw pyramid(shoulder_length/2) color: color;
		draw sphere(shoulder_length/4) at: location + {0,0,shoulder_length/2} color: #black;
		draw sphere(shoulder_length*7/32) at: location + ({shoulder_length/16,0,0} rotated_by (heading::{0,0,1}))+ {0,0,shoulder_length*15/32} color: rgb(191,181,164);
		draw circle(0.5*shoulder_length) color: color at: dest;
		draw square(0.5*shoulder_length) color: color at: final_dest depth: 10;
		//draw polyline([location,dest]) width: 2 color: color;
		draw polyline([location,final_dest]) width: 1 color: color;
		draw polyline([location,dest]) width: 1 color: color;
		draw circle(0.5*shoulder_length) color: color at: dest depth: 3;
		if state = "go_to_crosswalk" or state = "go_to_final_destination"{
			draw polyline(waypoints) width: 3 color: color;
		}
	//	draw polyline(tracking) width: 2 color: #grey;
		
	}
}

species debug{
	aspect default{
		//	draw bounds_shape color: can_cross?#green:#red;	
			//loop e over: walking_area_divided  {
			loop e over: voronoi_diagram  {
				draw e color: world.is_convex(e)?#blue:#red border: #black;
		//		draw e color: #blue border: #black;
//				list<geometry> truc <- triangulate(e);
//				loop t over: truc{
//									draw t color: #blue border: #black;
//		
		//		write e.geometries;
			
			
				draw circle(0.1) color: #red at: e.location;
			}


	}
	
	aspect traffic_light{
		draw union(crosswalk collect(each.shape)) color: can_cross?#green:#red;	
		ask intersection where each.is_traffic_signal{
			draw circle(3) at: location color: is_green?#green:#red;
		}
	}
	
	aspect grid{
		draw open_area color: #pink;
		loop p over: nodes{
			draw circle(0.5) at: p color: #yellow;
		}
		loop p over: nodes_inside{
			draw circle(0.2) at: p.location color: #red;
		}
	}
}

species traffic_light_3d{
	int group;
	string current_color <- "red";
	float light_z <- 5#m;
	float light_x <- 2#m;
	float t_x <- 1.4#m;
	float t_z <- 3.5#m;
	float heading;

	
	reflex find_color{
		current_color <- first(intersection where (each.group = self.group)).current_color;
	}
	
	
	aspect default{
		draw circle(0.15#m) depth: 6#m color: #grey;
		draw circle(0.05#m) rotated_by(-90,{0,1,0}) depth: light_x at: location+{0,0,light_z} rotate: heading color: #grey;
		draw rectangle(1,0.3) depth: 0.3#m at: location+({light_x,0,light_z-0.15} rotated_by (heading::{0,0,1})) 
			rotate: heading color: #grey;
		draw sphere(0.1#m) at: location+({light_x-0.3,0.15,light_z-0.1} rotated_by (heading::{0,0,1}))
			color: current_color="green"?#green:rgb(100,100,100);
		draw sphere(0.1#m) at: location+({light_x,0.15,light_z-0.1} rotated_by (heading::{0,0,1}))
			color: current_color="orange"?#orange:rgb(100,100,100);
		draw sphere(0.1#m) at: location+({light_x+0.3,0.15,light_z-0.1} rotated_by (heading::{0,0,1}))
			color: current_color="red"?#red:rgb(100,100,100);
		draw square(0.04#m) rotated_by(-90,{0,1,0}) depth: t_x at: location+{0,0,t_z} rotate: heading+90 color: #grey;
		draw rectangle(0.3,0.15) depth: 0.6 at: location+({0,t_x,t_z-0.65} rotated_by (heading::{0,0,1})) rotate: heading+90 color: #grey;
		draw square(0.04) depth: 0.05 at: location+({0,t_x-0.02,t_z-0.05} rotated_by (heading::{0,0,1})) rotate: heading+90 color: #grey;
		draw triangle(0.15,0.2) rotated_by(-90,{1,0,0}) at: location+({0.08,t_x,t_z-0.25} rotated_by (heading::{0,0,1})) 
			rotate: heading+90 color: world.schedule_step = 1?rgb(100,100,100):#red;
		draw circle(0.05) rotated_by(-90,{1,0,0}) at: location+({0.08,t_x,t_z-0.15} rotated_by (heading::{0,0,1})) 
			rotate: heading+90 color: world.schedule_step = 1?rgb(100,100,100):#red;
			
		if world.schedule_step = 1{
			draw rectangle(0.03,0.02) depth: 0.2*world.percent_time_remaining at: location+({0.07,t_x+0.11,t_z-0.61} rotated_by (heading::{0,0,1})) 
				rotate: heading+90 color: #green;
			draw rectangle(0.03,0.02) depth: 0.2*world.percent_time_remaining at: location+({0.07,t_x-0.11,t_z-0.61} rotated_by (heading::{0,0,1})) 
				rotate: heading+90 color: #green;
		}else{
			draw rectangle(0.03,0.02) depth: 0.2*world.percent_time_remaining at: location+({0.07,t_x+0.11,t_z-0.31} rotated_by (heading::{0,0,1})) 
			rotate: heading+90 color: #red;
			draw rectangle(0.03,0.02) depth: 0.2*world.percent_time_remaining at: location+({0.07,t_x-0.11,t_z-0.31} rotated_by (heading::{0,0,1})) 
			rotate: heading+90 color: #red;
		}
	
		draw triangle(0.15,0.2) rotated_by(-90,{1,0,0}) at: location+({0.08,t_x,t_z-0.55} rotated_by (heading::{0,0,1})) 
			rotate: heading+90 color: world.schedule_step = 1?#green:rgb(100,100,100);
		draw circle(0.05) rotated_by(-90,{1,0,0}) at: location+({0.08,t_x,t_z-0.45} rotated_by (heading::{0,0,1})) 
			rotate: heading+90 color: world.schedule_step = 1?#green:rgb(100,100,100);
			
			
//		draw sphere(0.1#m) at: location+{0.6#m,0.15,5#m} color: is_green?#green:#darkgrey;
//		draw sphere(0.1#m) at: location+{1.1#m,0.15,5#m} color: is_green?#darkgrey:#red;
	}
}


experiment ShibuyaCrossing type: gui  {
	float minimum_cycle_duration <- 0.001#s;
	output {
		display map type: 3d axes: false background: #darkgray{
			//camera 'default' location: {98.4788,143.3489,64.7132} target: {98.6933,81.909,0.0};
			camera 'default' location: {98.4788,143.3489,64.7132} target: {98.6933,81.909,0.0};
//			camera #default dynamic: true location: {int(first(people).location.x), int(first(people).location.y), 5/factor} target:
//			{cos(first(people).heading) * first(people).speed + int(first(people).location.x), sin(first(people).heading) * first(people).speed + int(first(people).location.y), 5/factor};
			species fake_building transparency: 0.9;			
			image photo refresh: false transparency: 0 ;	
			species traffic_light_3d;
	//		species walking_area transparency: 0.6;
		species pedestrian_path aspect: default;
			 	species people aspect: 3d;
			species building transparency: 0.4;
			species car transparency: 0.6;
			
			//species pedestrian_path aspect: free_area_aspect transparency: 0.4;
	
		}
	}
}


experiment "First person view" type: gui  {
	float minimum_cycle_duration <- 0.001#s;
	output {
		display map type: 3d axes: false background: #darkgray{
			//camera 'default' location: {98.4788,143.3489,64.7132} target: {98.6933,81.909,0.0};
	//		camera 'default' location: {98.4788,143.3489,64.7132} target: {98.6933,81.909,0.0};
			camera #default dynamic: true location: {int(first(people).location.x), int(first(people).location.y), 1#m} target:
			{cos(first(people).heading) * first(people).speed + int(first(people).location.x), sin(first(people).heading) * first(people).speed + int(first(people).location.y), 1#m};
			species fake_building transparency: 0.9;			
			image photo refresh: false transparency: 0 ;	
			species traffic_light_3d;
		 	species people aspect: 3d;
			species building transparency: 0.4;
			species car transparency: 0.6;
			
			//species pedestrian_path aspect: free_area_aspect transparency: 0.4;
	
		}
	}
}

experiment "Car view" type: gui  {
	float minimum_cycle_duration <- 0.001#s;
	output {
		display map type: 3d axes: false background: #darkgray{
			//camera 'default' location: {98.4788,143.3489,64.7132} target: {98.6933,81.909,0.0};
	//		camera 'default' location: {98.4788,143.3489,64.7132} target: {98.6933,81.909,0.0};
			camera #default dynamic: true location: {int(first(car).location.x), int(first(car).location.y), 0.8#m} target:
			{cos(first(car).heading) + int(first(car).location.x), sin(first(car).heading)  + int(first(car).location.y), 0.8#m};
			species fake_building transparency: 0.9;			
			image photo refresh: false transparency: 0 ;	
			species traffic_light_3d;

		 	species people aspect: 3d;
			species building transparency: 0.4;
			species car transparency: 0.6;
			
	
		}
	}
}