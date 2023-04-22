/***
* Name: generate_pedestrian_path
* Author: Patrick Taillandier
* Description: Show how to create pedestrian path and associated free space
* Tags: * Tags: pedestrian, gis, shapefile, graph, agent_movement, skill, transport
***/

model generate_pedestrian_path

global {
	
	shape_file bounds <- shape_file("../includes/Shibuya.shp");

	shape_file crosswalk_shape_file <- shape_file("../includes/crosswalk.shp");

	
	shape_file walking_area_shape_file <- shape_file("../includes/walking area.shp");

	
	geometry shape <- envelope(bounds);
	bool display_free_space <- false parameter: true;
	float P_shoulder_length <- 0.45 parameter: true;
	
	float simplification_dist <- 0.5; //simplification distance for the final geometries
	
	bool add_points_open_area <- true;//add points to open areas
 	bool random_densification <- false;//random densification (if true, use random points to fill open areas; if false, use uniform points), 
 	float min_dist_open_area <- 0.1;//min distance to considered an area as open area, 
 	float density_open_area <- 0.01; //density of points in the open areas (float)
 	bool clean_network <-  true; 
	float tol_cliping <- 1.0; //tolerance for the cliping in triangulation (float; distance), 
	float tol_triangulation <- 0.1; //tolerance for the triangulation 
	float min_dist_obstacles_filtering <- 0.0;// minimal distance to obstacles to keep a path (float; if 0.0, no filtering), 
	
	
	init {
		create walking_area from:walking_area_shape_file ;
		create walking_area from:crosswalk_shape_file ;
		
		geometry oa <- union(walking_area collect each.shape);
		list<geometry> generated_lines <- generate_pedestrian_network([],[oa],add_points_open_area,random_densification,min_dist_open_area,density_open_area,clean_network,tol_cliping,tol_triangulation,min_dist_obstacles_filtering,simplification_dist);
		
		list<geometry> cc <- walking_area collect each.shape.contour;
		create pedestrian_path from: generated_lines  {
			do initialize bounds:[oa] distance: min(10.0,(cc closest_to self) distance_to self)  distance_extremity: 1.0;
		}
		save pedestrian_path to: "../includes/pedestrian paths.shp" format:shp;
		save (pedestrian_path collect each.free_space) where (each != nil) to: "../includes/free spaces.shp" format:shp;
	}
}

species pedestrian_path skills: [pedestrian_road]{
	rgb color <- rnd_color(255);
	aspect default {
		draw shape  color: color;
	}
	aspect free_area_aspect {
		if(display_free_space and free_space != nil) {
			draw free_space color: #cyan border: #black;
		}
	}
}

species walking_area {
	aspect default {
		draw shape color: #gray border: #black;
	}
}

experiment normal_sim type: gui {
		output {
		display map type: 3d{
			species walking_area refresh: false;
			
			species pedestrian_path aspect:free_area_aspect transparency: 0.5 ;
			species pedestrian_path refresh: false;
		}
	}
}
