/***
* Name: ShapefileCleaner
* Author: Tri
* Description: 
* Tags: Tag1, Tag2, TagN
***/

model networkCleaner

global {
//	string intersections_file <- "../../includes/GIS/nodes_OSM_test.shp";
	string roads_file <- "../../includes/shp/ski_slopes.shp";
//	string intersections_output_file <- copy_between(intersections_file,0,length(intersections_file)-4)+"_out.shp";
	string roads_output_file <- copy_between(roads_file,0,length(roads_file)-4)+"_out.shp";

	float seed <- 0.05854642306653;
	float NORMAL_THICKNESS <- 0.5;
	float MEDIUM_THICKNESS <- 1.5;
	float HIGH_THICKNESS <- 2.5;
	float tolerance <- 0.0001 parameter: true on_change: refresh_tolerance;
	bool override_null_values_roads <- false parameter: true on_change: refresh_merge;
//	bool override_null_values_intersections <- true parameter: true on_change: refresh_intersections;
	list road_parameters_to_match <- roads_shapefile.attributes - ['the_geom','id','test_id'] parameter: true on_change: refresh_merge;
	//list intersection_parameters_to_match <- intersections_shapefile.attributes - ['the_geom','id','test_id'] parameter: true;

	list<list<road>> to_merge <- [];
	list<intersection> orphan_intersections <- [];
	list<road> orphan_roads <- [];
	list<list<intersection>> duplicate_intersections <- [];
	list<string> roads_attributes;
	list<string> intersections_attributes;
	list<point> end_vertices;
	list<point> all_vertices;
	

	shape_file roads_shapefile <- shape_file(roads_file);
	//shape_file intersections_shapefile <- shape_file(intersections_file);
	geometry shape <- envelope(roads_file);
	
	//list<string> excluded_attributes <- ["shape","id_gis","id","name","color"];
		
	init {
		loop geom over: roads_shapefile.contents {
			create road with:(shape:geom);
		}		
//		loop geom over: intersections_shapefile.contents {
//			create intersection with:(shape:geom);
//		}
		
		end_vertices <- remove_duplicates(road accumulate (each.extremities));
		all_vertices <- remove_duplicates(road accumulate (each.shape.points));
	
		
		ask road{
			initial_shape <- shape.points;
			do compute_extremities;
		}
		
		ask intersection{
			old_location <- location;
		}
		
		roads_attributes <- roads_shapefile.attributes - 'the_geom';
	//	intersections_attributes <- intersections_shapefile.attributes - 'the_geom';
		
		

		do find_orphans_and_duplicate_intersections;
		do find_mergeable_and_orphan_roads;
	}
	
	action refresh_merge{
		if length(road_parameters_to_match - roads_attributes)>0{
			write "Invalid parameter list for roads. Parameters "+(road_parameters_to_match - roads_attributes)+" do not exist.";
			write "The parameters should be in "+roads_attributes;
		}else{
			do find_mergeable_and_orphan_roads;
			do refresh_display;
		}
	}
	
//	action refresh_intersections{
//		if length(intersection_parameters_to_match - intersections_attributes)>0{
//			write "Invalid parameter list for intersections. Parameters "
//				+(intersection_parameters_to_match - intersections_attributes)+" do not exist.";
//			write "The parameters should be in "+intersections_attributes;
//		}else{
//			do find_orphans_and_duplicate_intersections;
//			do refresh_display;
//		}
//	}
	
	action refresh_tolerance{
		ask intersection where (each.created){
			do die;
		}
		ask road where each.splitted{
			do die;
		}
		ask road where each.to_split{
			to_split <- false;
		}
		ask orphan_intersections{
			do try_to_snap;
		}
		ask orphan_roads{
			do try_to_snap;
		}
		do refresh_display;
	}
	
	action refresh_display {
		ask experiment {
			do update_outputs(true);
		}
	}
	
	reflex clean_and_save when: cycle>0{
		write "\n\n Start cleaning.";
		do merge_duplicate_intersections;
		do merge_roads;

		ask road where (each.to_kill or each.to_split){
			do die;
		}
		//do fix_orphan_roads;
		
		write "Cleaning done, savinf output to files: "+roads_output_file;
	
		save road collect each.shape to: roads_output_file format: "shp" attributes: roads_attributes;	
//		save intersection collect each.shape to: intersections_output_file format: "shp" attributes: intersections_attributes;
		do pause;
	}
	
	action find_mergeable_and_orphan_roads{
		write "\n***********************************\nSearching mergeable roads...";
		
		ask road{do reset;}
		int next_merge_index <- 1;
		list<road> road_list <- road where (length(each.free_extremities)>0);// find road with free extremities
		list<point> extr <-road_list accumulate(each.free_extremities);
		loop e over: extr{
			list<road> connected_roads <- road where (e in each.free_extremities);
			if length(connected_roads)=2{
				list<int> associated_groups <- remove_duplicates(connected_roads collect(each.merge_group)) - 0;
				if empty(associated_groups){
					ask connected_roads{
						merge_group <- next_merge_index;
					}
					next_merge_index <- next_merge_index + 1;
				}else{
					int index <- min(associated_groups);
					ask road where (each.merge_group in associated_groups){
						merge_group <- index;
					}
					ask connected_roads{
						merge_group <- index;
					}
				}
			}
		}
		loop g over: remove_duplicates(road collect(each.merge_group))-0{
			rgb new_color <- rnd_color(255);
//			write 'Roads '+(road where(each.merge_group = g)) collect(int(each))+' are candidate for merging.' color: new_color;
			list<road> current_group <- road where(each.merge_group = g);
			ask current_group{
				color <- new_color;
			}
			list<string> unmatchable_attributes <- road_parameters_to_match 
					where (!same_value(current_group, each, override_null_values_roads));
			if empty(unmatchable_attributes){
				write 'Merging roads '+current_group collect(int(each))+'.' color: new_color;
				ask road where(each.merge_group = g){
					color <- new_color;
					mergeable <- true;
				}
			}else{
				write 'Cannot merge roads '+current_group collect(int(each))+', intersections will be added.' color: new_color;
				string text <- "";
				loop a over: unmatchable_attributes{
					text <- text +"'"+a+"': "+remove_duplicates(current_group collect(string(each get a)));
				}
				write 'Conflicting attributes values: '+text color: new_color;			
				ask current_group{
					mergeable <- false;
				}
			}	
		}
		do find_orphan_roads;	
	}
	
	
	action find_orphan_roads{
		ask intersection where (each.created){
			do die;
		}
		write "\n***********************************\nLooking for orphan roads (roads with missing intersection at extremities)...";
		orphan_roads <- (road where (each.merge_group = 0)) where (length(each.free_extremities)>0);
		if length(orphan_roads)=0{
			write "No orphan road found.";
		}else{
			write "Found "+length(orphan_roads)+" orphan roads: "+(orphan_roads collect(int(each)));
			ask orphan_roads{
				color <- rnd_color(255);
				do try_to_snap;
			}
			ask orphan_roads{
				do add_intersections;
			}
		}
	}
	
	
	action merge_roads{
		write "Merging roads...";
		loop g over: remove_duplicates(road collect(each.merge_group))-0{
			list<road> lr <- road where(each.merge_group = g);
			if first(lr).mergeable{
				road r1 <- lr[0];
				lr <- lr - r1;
				loop while: length(lr)>0{
					road r2 <- first(lr overlapping r1);
//					write "merging "+r1+" and "+r2;
					lr <- lr - r2;
					ask r2 {to_kill <- true;}
					if last(r1.shape.points)=first(r2.shape.points) {
							r1.shape <- polyline(first(length(r1.shape.points)-1,r1.shape.points)  + r2.shape.points);
					}else{
						r1.shape <- polyline(first(length(r2.shape.points)-1,r2.shape.points)  + r1.shape.points);					
					}
					ask r1 {do compute_extremities;}
				}
			}
		}
	}
	

	bool all_equals(list L, bool ignore_null){  //returns true if all the elements of a list are equal
												// if ignore_null = true, NULL values are not counted
		if ignore_null{
			return length(remove_duplicates(L)-'')<=1;
		}else{
			return length(remove_duplicates(L))=1;
		}	
	}
	
	bool same_value(list<geometry> L, string a, bool ignore_null){//returns true if all the elements of a list are equal
																  // if ignore_null = true, NULL values are not counted
		return all_equals(L collect (each get a), ignore_null);
	}
	


	action find_orphans_and_duplicate_intersections{
		orphan_intersections <- [];
		duplicate_intersections <- [];
		ask intersection {do reset;}
		
		write "\n***********************************\nSearching orphan intersections...";
		end_vertices <- remove_duplicates(road accumulate (each.extremities));
		all_vertices <- remove_duplicates(road accumulate (each.shape.points));
		
		ask intersection{
			if not(self.location in end_vertices){
				orphan_intersections << self;
			}
		}
		if empty(orphan_intersections){
			write "No orphan intersection found.";
		}else{
			write "Found "+length(orphan_intersections)+" orphan intersection(s).";
			ask orphan_intersections {do try_to_snap;}
		}
		
		
		write "\n***********************************\nSearching duplicate intersections...";
		
		loop i over: intersection{
			list<intersection> tmp <- (intersection - i -(duplicate_intersections accumulate (each))) where(each.location = i.location);
			if not empty(tmp) {duplicate_intersections << [i]+tmp;}
		}
		if length(duplicate_intersections) = 0 {
			write "No duplicates found.";
		}else{
			write "Found "+length(duplicate_intersections)+" duplicated nodes. List:";
			loop i from: 0 to: length(duplicate_intersections)-1{
				rgb new_color <- rnd_color(255);
				ask duplicate_intersections[i]{
					color <- new_color;
				}
//				list<string> unmatchable_attributes <- intersection_parameters_to_match 
//					where (!same_value(duplicate_intersections[i], each, override_null_values_intersections));
//				if empty(unmatchable_attributes){
//					write "intersections "+(duplicate_intersections[i] collect int(each))+" will be merged." color: new_color;
//					ask duplicate_intersections[i]{fixed <- true;}
//				}else{
//					write "intersections "+(duplicate_intersections[i] collect int(each))+" cannot be merged." color: new_color;// (different values found for attributes "
//				//		+unmatchable_attributes+")." color: new_color;
//					string text <- "";
//					loop a over: unmatchable_attributes{
//						text <- text +"'"+a+"': "+remove_duplicates(duplicate_intersections[i] collect(string(each get a)));
//					}
//					write 'Conflicting attributes values: '+text color: new_color;
//		
//					ask duplicate_intersections[i]{unfixable <- true;}
//				}				
			}
		}
	}


	action merge_duplicate_intersections{
		loop L over: duplicate_intersections{
			if !first(L).unfixable{
				loop a over: intersections_attributes{
					list possible_values <- remove_duplicates(L collect (each get a))-'';
					if !empty(possible_values){
						ask first(L){ set a value: first(possible_values);}
					}
				}
				write L;
				write L-first(L);
				ask L - first(L){
						do die;
				}
			}
		}
		
	}
		
}



species road{
	int merge_group <- 0;
	list<point> extremities;
	list<point> free_extremities;
	bool mergeable;
	bool to_kill <- false;
	bool to_create <- false;
	bool splitted <- false;
	bool to_split <- false;
	list<point> initial_shape;
	map<point,intersection> intersections_to_snap <- [];
	
//	float thickness <- NORMAL_THICKNESS;	
//	float after_thickness <- NORMAL_THICKNESS;
	rgb color <- #lightgrey;
	//rgb after_color <- color;
	
	action split_at(point p){
		if not(p in shape.points){
			write 'Error, cannot split road since vertex '+p+'is not in the shape' color: #red;
		}else{
			to_split <- true;
			int i <- shape.points index_of p;
			create road{
				shape <- myself.shape;
				shape <- polyline(copy_between(myself.shape.points,0,i+1));
				splitted <- true;
			}
			create road{
				shape <- myself.shape;
				shape <- polyline(copy_between(myself.shape.points,i,length(myself.shape.points)));
				splitted <- true;
			}
		}
	}


	action compute_extremities{
		extremities <-[first(shape.points),last(shape.points)];
		free_extremities <- extremities - (intersection collect each.location);
	}
	
	action reset{
		color <- #lightgrey;
		mergeable <- false;
		merge_group <- 0;
		to_kill <- false;
		to_create <- false;
		do compute_extremities;
	}
	
	action try_to_snap {
		shape <- polyline(initial_shape);
		intersections_to_snap <- [];
		if length(free_extremities)>0{
			loop e over: free_extremities{
				intersection i1 <- intersection closest_to e;
				if distance_to(i1.location, e)< tolerance{
					put i1 key: e in: intersections_to_snap;
				}
			}
		}
		if length(intersections_to_snap)>0{
			write "Snapped road "+int(self)+" to intersection(s) "+intersections_to_snap.values collect(each);
			loop e over: intersections_to_snap.keys{
				shape.points[shape.points index_of e] <- intersections_to_snap[e].location;
			}
		}
	}
	
	action add_intersections{		
			loop e over: extremities - (intersection collect each.location) {//loop over orphan extremities 
				create intersection{
					location <- e.location;
					created <- true;
				}
			}
		}

	
	aspect base{
		if not(to_create){
			draw shape+NORMAL_THICKNESS  color: color ;		
			loop p over: shape.points{
				draw circle(NORMAL_THICKNESS*1.5) at: p color: #green;
			}		
		}
	}
	
	aspect clean{
		if not(to_kill or to_split){
			draw shape+NORMAL_THICKNESS color: #lightgrey;
			if not(empty(intersections_to_snap.keys)){
				draw shape+NORMAL_THICKNESS color: #green;
				ask intersections_to_snap.values {
					draw circle(3)+1 wireframe: true color: #green;		
				}
			}
			if merge_group > 0{
				draw shape+HIGH_THICKNESS color: mergeable?#green:#orange;
			}
			if (to_create or splitted){
				draw shape+HIGH_THICKNESS color: #blue;
			}
		}

	}

}



species intersection {
	bool fixed <- false;
	bool created <- false;
	bool unfixable <- false;
	point old_location;
	rgb color <- #darkgrey;
	
	action reset{
		fixed <- false;
		created <- false;
		unfixable <- false;	
		location <- old_location;	
		color <- #darkgrey;
	}
	
	action try_to_snap{
		do reset;
		color <- rnd_color(255);
		point closest_vertex <- all_vertices closest_to self;
		if old_location distance_to closest_vertex < tolerance{
			list<road> lr <- road where(closest_vertex in each.shape.points);
			if closest_vertex in (lr accumulate (each.extremities)){
				write 'Moving '+int(self)+' to nearest road end/start vertex.' color: color;
				fixed <- true;
				location <- closest_vertex;
			}else{
				write 'Moving '+int(self)+' to nearest road vertex and split roads.' color: color;
				fixed <- true;
				location <- closest_vertex;
				ask lr{do split_at(closest_vertex);}
			}
		}else{
			write 'Removing '+int(self)+' (too far from any vertex, change tolerance to keep it).' color: color;
			unfixable <- true;
		}
	}

	aspect base{
		if !created{
			draw circle(3) color: color wireframe: color = #darkgrey?true:false;
		}	
	}
	
	aspect clean{
		draw circle(3) color: #darkgrey wireframe: true;
		if created{
			draw circle(5) color: #blue;
		}
		if fixed{
			draw circle(5) color: #green;
		}
		if unfixable{
			draw circle(5) color: #red;
		}
	}
}


experiment clean type: gui {
	text "Click 'run' to save the results in output files." category: "Save to files";
	parameter "Road shapefile" var: roads_output_file  category: "Save to files";
//	parameter "Intersection shapefile" var: intersections_output_file  category: "Save to files";
	text "If roads have different values for the parameters that are listed bellow, they will not be merged (click on the 'edit' button for a friendlier interface)." category: "Clean intersections";
//	parameter inter name:"" var: intersection_parameters_to_match category: "Clean intersections";
//	parameter "Override null values for intersections" var: override_null_values_intersections category: "Null values";
	
	text "Adjust tolerance to snap orphan roads to closest intersections" category: "Orphan roads";
	parameter "Tolerance" var: tolerance category: "Orphan roads";
	text "If roads have different values for the parameters that are listed bellow, they will not be merged (click on the 'edit' button for a friendlier interface)." category: "Merge roads";
	parameter road_params name:" " var: road_parameters_to_match category: "Merge roads";
	parameter "Override NULL values for road merge" var: override_null_values_roads category: "Null values";
	
	output {
		layout #split;//#vertical;	
		display Identification background:#black {
			species road aspect:base;	
			species intersection aspect:base;						
		}
		display Cleanable name:"After cleaning" background:#black {
			species road aspect:clean;	
			species intersection aspect:clean;						
		}
	}
}