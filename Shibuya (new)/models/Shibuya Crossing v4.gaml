/**
* Name: ShibuyaCrossing
* Based on the internal skeleton template. 
* Author: Patrick Taillandier
* Tags: 
*/

model ShibuyaCrossing

global {
	int nb_people <- 1800;
	bool can_cross <- false;
	int timing <- 500;
	float precision <- 0.001;
	float factor <- 1.0;
	
	shape_file bounds <- shape_file("../includes/Shibuya.shp");
	image_file photo <- (image_file(("../includes/Shibuya.png")));

	shape_file highway_line_shape_file <- shape_file("../includes/highway_line.shp");
	shape_file building_polygon_shape_file <- shape_file("../includes/building_polygon.shp");
	shape_file crosswalk_shape_file <- shape_file("../includes/crosswalk.shp");
	shape_file walking_area_shape_file <- shape_file("../includes/walking area.shp");
	shape_file free_spaces_shape_file <- shape_file("../includes/free spaces.shp");
	shape_file pedestrian_paths_shape_file <- shape_file("../includes/pedestrian paths.shp");
	
	geometry shape <- envelope(bounds) ;
	
	
	float P_shoulder_length <- 1.0 parameter: true;
	float P_proba_detour <- 0.5 parameter: true ;
	bool P_avoid_other <- true parameter: true ;
	float P_obstacle_consideration_distance <- 3.0 parameter: true ;
	float P_pedestrian_consideration_distance <- 3.0 parameter: true ;
	float P_tolerance_target <- 0.1 parameter: true;
	bool P_use_geometry_target <- true parameter: true;
	
	
	string P_model_type <- "simple" among: ["simple", "advanced"] parameter: true ; 
	
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
	
	float step <- 0.1;
	
	
	people the_people;
	point endpoint;
	
	geometry open_area;
	geometry bounds_shape;
	
	init {
		create road from: highway_line_shape_file;
		create building from: building_polygon_shape_file with:[height::float(get("height"))];
		
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
//				if self overlaps myself{
//					put intersection(self.shape,myself.shape) at: first(self.ends - myself) 
//						in: myself.waiting_areas;
//				}
			}
		}
		
		loop c over: crosswalk{
			loop w over: c.waiting_areas{
				w.opposite <- first(c.waiting_areas - w);
			}
		}
		
//		ask walking_area{
//			write ""+int(self)+" "+waiting_areas;
//		}
//		ask waiting_area{
//			write ""+int(self)+" "+self.opposite;
//		}
		
		open_area <- union(walking_area collect each.shape);
		bounds_shape <- union(open_area,union(crosswalk collect each.shape));
	//	bounds_shape <- bounds_shape - union(building collect each.shape);
		
	//	create pedestrian_path from: union(pedestrian_paths_shape_file,waiting_area)  {
	
		float ml <- 3.0;
		int i <-  0;

//		loop  while: (i+1) * ml < shape.width{
//			int j <-  0;
//			loop  while: (j+1) * ml < shape.height{
//				create pedestrian_path{
//					shape <- polyline([{i*ml,j*ml},{(i+1)*ml,j*ml}]);
//				}
//				create pedestrian_path{
//					shape <- polyline([{i*ml,j*ml},{i*ml,(j+1)*ml}]);
//				}
////				create pedestrian_path{
////					shape <- polyline([{i*ml,j*ml},{(i+1)*ml,(j+1)*ml}]);
////				}
////				create pedestrian_path{
////					shape <- polyline([{i*ml,(j+1)*ml},{(i+1)*ml,j*ml}]);
////				}
//				j <- j +1;
//			}
//			i <- i + 1;
//		}
		
//		ask pedestrian_path{
//			if  !(bounds_shape covers self.shape){
//				do die;
//			}
//		}
//		
//		ask pedestrian_path   {
//			list<geometry> fs <- free_spaces_shape_file overlapping self;
//			free_space <- fs first_with (each covers shape); 
//			if free_space = nil {
//				free_space <- shape + P_shoulder_length;
//			}
//		}
		
		ask waiting_area{
			loop k from: 0 to: length(shape.points)-2 step: 1{
				create pedestrian_path{
					shape <- polyline([myself.shape.points[k],myself.shape.points[k+1]]);
					list<geometry> fs <- free_spaces_shape_file overlapping self;
			free_space <- fs first_with (each covers shape); 
			if free_space = nil {
				free_space <- shape + P_shoulder_length;
			}
				}
			}
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
			final_dest <- location;// any_location_in(open_area);	
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
		
	}
	

	reflex switch_traffic_light when: mod(cycle,timing)=200{
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
}

/*******************************************
 * 
 * 
 *     species definition
 * 
 * 
 * ***************************************** */



species pedestrian_path skills: [pedestrian_road]{
	
	
	aspect default { 
		draw shape  color: #gray;
	}
	aspect free_area_aspect {
		draw free_space color: #lightpink border: #black;
		
		
	}
}


species building {
	float height;
	
	aspect default {
		draw shape color: #gray depth: height;		
	}
}

species walking_area {
	list<waiting_area> waiting_areas;
	aspect default {
		draw shape color: #green border: #black;
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

species road {
	aspect default {
		draw shape color: #red depth: 1;
	}
}

species people skills: [pedestrian] control: fsm{
	rgb color <- rnd_color(255);
	float speed <- gauss(5,1.5) #km/#h min: 2 #km/#h;
	point dest;
	point final_dest;
	walking_area final_area;
	walking_area current_area;
	waiting_area current_waiting_area;
	waiting_area last_waiting_area;
	bool going_to_cross <- false;
	bool waiting <- false;
	point wait_location;
	
	state find_new_destination initial: true{
		final_dest <- any_location_in(open_area);
		final_area <- walking_area closest_to final_dest;
		current_waiting_area <- nil;
		current_area <- walking_area closest_to self.location;	
		transition to: go_to_final_destination when: current_area = final_area;
		transition to: go_to_crosswalk when: current_area != final_area;
	}
	
	state go_to_final_destination{
		enter{
			dest <- final_dest;
		}
		do walk_to target: dest;
		transition to: find_new_destination when: norm(location - dest) < precision;
	}
	
	state go_to_crosswalk{
		enter{
			current_waiting_area <- 
				first(current_area.waiting_areas where (each.opposite.my_walking_area = final_area));
			if current_waiting_area = nil{
				current_waiting_area <- one_of(current_area.waiting_areas);
			}				
			dest <- any_location_in(current_waiting_area);
		}
				
		do walk_to target: dest;
		transition to: waiting_to_cross when: (norm(location - dest) < precision) or (distance_to(self,current_waiting_area)< precision);
	}
	
	state waiting_to_cross{
		enter{
			dest <- first(point(intersection(polyline(current_waiting_area.shape.points),polyline([location, location+current_waiting_area.direction]))));
		}	
		do walk_to target: dest;
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
			current_area <- walking_area closest_to current_waiting_area.opposite;
		}
		do walk_to target: dest;
		bool other_side_reached <- self.location distance_to current_area < 1#m;
		transition to: go_to_crosswalk when: other_side_reached and (current_area != final_area);
		transition to: go_to_final_destination when: other_side_reached and (current_area = final_area);
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
		draw pyramid(shoulder_length/2) color: color;
		draw sphere(shoulder_length/4) at: location + {0,0,shoulder_length/2} color: #black;
		draw sphere(shoulder_length*7/32) at: location + ({shoulder_length/16,0,0} rotated_by (heading::{0,0,1}))+ {0,0,shoulder_length*15/32} color: rgb(191,181,164);
	}
}

species debug{
	aspect default{
			draw bounds_shape color: can_cross?#green:#red;	
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
			
			image photo refresh: false transparency: 0 ;
		 	species people aspect: 3d;
			species building transparency: 0.4;
		//	species walking_area;
		//	species waiting_area transparency: 0.9;
		//	species crosswalk;
		//	species pedestrian_path aspect: default;
			species debug transparency: 0.9;
			//species pedestrian_path aspect: free_area_aspect transparency: 0.4;
	
		}
	}
}
