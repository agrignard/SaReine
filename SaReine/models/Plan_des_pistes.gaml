/***
* Name: Avalanche
* Author: Mog
* Description: 
* Tags: Tag1, Tag2, TagN
***/

model Avalanche




/***********************************************
 *                   AGENT MONDE               * 
 ***********************************************/

global {
	bool show_slopes <- true;
	bool show_triangles <- false;
	int nb_last_positions <- 100;
	float trail_smoothness <- 0.2 min:0.01 max: 1.0;
	
	//données SIG
	string grid_data_file <- "../includes/Alpes250.asc";
	file grid_data <- grid_file(grid_data_file);
	geometry shape <- envelope(grid_data);	
	file shape_file_slopes <- shape_file("../includes/shp/ski_slopes.shp");
	file shape_file_aerial <- shape_file("../includes/shp/aerial_ways.shp");
	file shape_file_buildings <- file("../includes/shp/building.shp");
	file shape_file_roads <- file("../includes/shp/road.shp");
	float offset;
	graph slopes_graph;
	graph aerial_graph;
	
	point dims <- {4.5#m,12.0#m};
	
	
	graph ski_domain;
	
	debug debugger;
	
	list<string> levels <- ["1*","2*","3*","chamois"];
	
	
	map<string, map<string,float>> init_proba_wander <- [
		"1*"::["verte"::100.0,"bleue"::40.0,"rouge"::20.0,"noire"::5.0,
					"freeride"::1.0,"link"::100.0,"acces"::100.0,"liaison"::100.0],
		"2*"::["verte"::60.0,"bleue"::100.0,"rouge"::40.0,"noire"::15.0,
					"freeride"::1.0,"link"::100.0,"acces"::100.0,"liaison"::100],
		"3*"::["verte"::15.0,"bleue"::60.0,"rouge"::100.0,"noire"::50.0,
					"freeride"::5.0,"link"::100.0,"acces"::100.0,"liaison"::100.0],
		"chamois"::["verte"::5.0,"bleue"::25.0,"rouge"::60.0,"noire"::100.0,
					"freeride"::1.0,"link"::100.0,"acces"::100.0,"liaison"::100.0]
	];		
	
	
//	map<string, map<string,float>> init_proba_wander <- [
//		"1*"::["verte"::100.0,"bleue"::1,"rouge"::1,"noire"::1,
//					"freeride"::1.0,"link"::1,"acces"::1,"liaison"::1],
//		"2*"::["verte"::100,"bleue"::100.0,"rouge"::1,"noire"::1,
//					"freeride"::1.0,"link"::1,"acces"::1,"liaison"::1],
//		"3*"::["verte"::1,"bleue"::1,"rouge"::100.0,"noire"::1,
//					"freeride"::1,"link"::1,"acces"::1,"liaison"::1],
//		"chamois"::["verte"::1,"bleue"::1,"rouge"::1,"noire"::100.0,
//					"freeride"::1.0,"link"::100.0,"acces"::100.0,"liaison"::100.0]
//	];	
	
	

	
	map<string, map<generic_edge,float>> proba_wander;
//	map<generic_edge,float> proba_wander;
	
	map<string, map<string, list<float>>> speed_range <-[
		"1*"::["verte"::[1.0,3.0],"bleue"::[1.0,2.2],"rouge"::[1.0,2.0],"noire"::[0.3,0.9],
					"freeride"::[0.3,0.7],"link"::[1.0,2.0],"acces"::[1.0,2.0],"chemin"::[1.0,2.0]],
		"2*"::["verte"::[1.0,2.0],"bleue"::[1.0,4.0],"rouge"::[1.0,3.0],"noire"::[0.5,1.4],
					"freeride"::[0.5,1.0],"link"::[1.0,2.0],"acces"::[1.0,2.0],"chemin"::[2.0,3.0]],
		"3*"::["verte"::[4.0,7.0],"bleue"::[5,8.0],"rouge"::[4.5,8.0],"noire"::[1.5,4.0],
					"freeride"::[1.5,2.5],"link"::[1.0,2.0],"acces"::[1.0,2.0],"chemin"::[3.0,5.0]],
		"chamois"::["verte"::[6.0,11.0],"bleue"::[6.0,11.0],"rouge"::[6.0,10.0],"noire"::[5,9.0],
					"freeride"::[5,9],"link"::[1.0,2.0],"acces"::[1.0,2.0],"chemin"::[3.0,5.0]]		
		];
	
		map<string, map<string, list<float>>> turn_speed_range <-[
		"1*"::["verte"::[1.0,3.0],"bleue"::[1.0,2.2],"rouge"::[1.0,2.0],"noire"::[0.5,1.0],
					"freeride"::[0.3,0.7],"link"::[1.0,2.0],"acces"::[1.0,2.0],"chemin"::[1.0,2.0]],
		"2*"::["verte"::[1.0,2.0],"bleue"::[2.0,5.0],"rouge"::[1.0,3.0],"noire"::[0.8,2.3],
					"freeride"::[0.5,1.0],"link"::[1.0,2.0],"acces"::[1.0,2.0],"chemin"::[2.0,3.0]],
		"3*"::["verte"::[1.5,3],"bleue"::[3,4],"rouge"::[4.5,8.0],"noire"::[1,3],
					"freeride"::[1.5,2.5],"link"::[1.0,2.0],"acces"::[1.0,2.0],"chemin"::[3.0,5.0]],
		"chamois"::["verte"::[1,2],"bleue"::[1,2],"rouge"::[3,6],"noire"::[5,9],
					"freeride"::[5,9],"link"::[1.0,2.0],"acces"::[1.0,2.0],"chemin"::[3.0,5.0]]		
		];
	
	
		
		map<string, map<string, list<float>>> amplitude_range <-[
		"1*"::["verte"::[40,70],"bleue"::[40,70],"rouge"::[40,70],"noire"::[80,120],
					"freeride"::[50,90],"link"::[4,10],"acces"::[3,7],"chemin"::[4,10]],
		"2*"::["verte"::[25,60],"bleue"::[80,90],"rouge"::[20,45],"noire"::[75,90],
					"freeride"::[50,90],"link"::[4,10],"acces"::[3,7],"chemin"::[4,10]],
		"3*"::["verte"::[10,30],"bleue"::[80,90],"rouge"::[20,45],"noire"::[60,85],
					"freeride"::[50,90],"link"::[4,10],"acces"::[3,7],"chemin"::[4,10]],
		"chamois"::["verte"::[5,12],"bleue"::[10,20],"rouge"::[20,45],"noire"::[20,45],
					"freeride"::[40,60],"link"::[4,10],"acces"::[3,7],"chemin"::[4,10]]		
		];
		
		map<string, map<string, int>> angle_range <-[
		"1*"::["verte"::60,"bleue"::70,"rouge"::90,"noire"::90,
					"freeride"::60,"link"::0,"acces"::0,"chemin"::30],
		"2*"::["verte"::60,"bleue"::60,"rouge"::60,"noire"::60,
					"freeride"::60,"link"::0,"acces"::0,"chemin"::20],
		"3*"::["verte"::60,"bleue"::60,"rouge"::60,"noire"::60,
					"freeride"::60,"link"::60,"acces"::0,"chemin"::0],		
		"chamois"::["verte"::60,"bleue"::60,"rouge"::60,"noire"::60,
					"freeride"::0,"link"::0,"acces"::0,"chemin"::0]
		];
		
		map<string, map<string, int>> slidding_coeff <-[
		"1*"::["verte"::0,"bleue"::0,"rouge"::0,"noire"::0,
					"freeride"::0,"link"::0,"acces"::0,"chemin"::0],
		"2*"::["verte"::0,"bleue"::0,"rouge"::30,"noire"::10,
					"freeride"::0,"link"::0,"acces"::0,"chemin"::0],
		"3*"::["verte"::0,"bleue"::0,"rouge"::30,"noire"::60,
					"freeride"::0,"link"::0,"acces"::0,"chemin"::0],		
		"chamois"::["verte"::0,"bleue"::0,"rouge"::0,"noire"::10,
					"freeride"::0,"link"::0,"acces"::0,"chemin"::0]
		];
		

	init {
		create aerial_ways from:shape_file_aerial with:[name::string(get("name")),type::string(get("type")), two_ways::bool(get("two_ways"))]{
			loop i from: 0 to:length(shape.points)-1{	
				float val <- parcelle(shape.points[i]).grid_value;
				shape <- set_z(shape,i,val+50);
			}
			if first(shape.points).z > last(shape.points).z {
				shape <- polyline(reverse(shape.points));
			}
			
			if two_ways = true{
				create aerial_ways {
					shape <- polyline(reverse(myself.shape.points));
					visible <- false;
					name <- myself.name;
					type <- myself.type;
				}
			}
		}
		
		string sens_attribute; 
		write "MNT: "+grid_data_file+" loaded.";		
		string resolution <- first(regex_matches(grid_data_file,'\\d+'));
		if ("sens "+resolution) in first(shape_file_slopes).attributes.keys{
			write "Loading attributes at resolution "+resolution;
			sens_attribute <- "sens "+resolution;
		}else{
			write "*****************************************************************************\nWarning: shapefile not optimized for this resolution MNT: "+
			first(regex_matches(grid_data_file,'Alpes.*'));
			write"The direction of the slopes may be incorrect. Add a new 'sens' field matching \nthis resolution and use the debug interface to locate inverted ski slopes.";
			write "*****************************************************************************";
			sens_attribute <- "sens 250";
		}
	
		
		create slopes from:shape_file_slopes with:[type::string(get("type")), name::string(get("name")), 
			sens::string(get(sens_attribute)),special::string(get("special"))] {
			switch type{
				match "noire"{
					color <- #black;
				}
				match "rouge"{
					color <- rgb(196,60,57);
				}
				match "bleue"{
					color <- rgb(51,87,187);
				}
				match "verte"{
					color <- rgb(16,175,35);
				}
				match "freeride"{
					color <- #grey;
				}
				match "bordercross"{
					color <- #grey;
				}
			}
			loop i from: 0 to:length(shape.points)-1{
				float val <- parcelle(shape.points[i]).grid_value;
				shape <- set_z(shape,i,val+50);
			}
			if first(shape.points).z < last(shape.points).z {
				shape <- polyline(reverse(shape.points));
			}
			switch sens{
				match "inverse"{
					shape <- polyline(reverse(shape.points));
				}
				match "plat"{
					create slopes {
						self.type <- myself.type;
						self.special <- myself.special;
						shape <- polyline(reverse(myself.shape.points));
						visible <- false;
					}
				}
			}
			if type = "acces"{
				if (first(shape.points) in (aerial_ways collect first(each.shape.points))) or (last(shape.points) in (aerial_ways collect last(each.shape.points))){
					shape <- polyline(reverse(shape.points));
				}
			}		
		}
		
		ask union(slopes,aerial_ways){
			do compute_segment;
		}
		
		
		map<generic_edge,float> tmp;
		loop l over: levels{
			tmp <- union(slopes,aerial_ways) as_map (each::float(init_proba_wander[l][each.type]));
			put tmp at: l in: proba_wander;
		}


		create people number:800{
			//location<-any_location_in(one_of(union(slopes, aerial_ways)));
			location<-any_location_in(one_of(slopes));
			last_positions <- [location];//list_with(nb_last_positions,location);
		}
		
		slopes_graph <-directed(as_edge_graph(slopes));
		aerial_graph <- directed(as_edge_graph(aerial_ways));
		
		ski_domain <- directed(as_edge_graph(union(slopes, aerial_ways)));

		
		create debug{
			debugger <- self;
		}
		ask debugger {
			do test_graph;
		}
		
		create building from: shape_file_buildings with: [type::string(read ("NATURE"))] {
			loop i from: 0 to:length(shape.points)-1{	
				float val <- parcelle(shape.points[i]).grid_value;
				shape <- set_z(shape,i,val+50);
			}
			if type="Industrial" {
				color <- #blue ;
			}
		}
		create road from: shape_file_roads {
			loop i from: 0 to:length(shape.points)-1{	
				float val <- parcelle(shape.points[i]).grid_value;
				shape <- set_z(shape,i,val+50);
			}
		}
		
	}
	
}

//////////////////////////////////////////


species debug{
	// for graph test
	list<point> dead_end;
	list<point> unreachable;
	list<point> mergeable;
	
	
	action test_graph{
		write "testing graph...";
		list<agent> edges <-union(slopes, aerial_ways);
		// testing slopes geometries
		ask edges{
			if length(shape.points) < 2 {
				write 'Edge '+self+' has only '+length(shape.points)+" vertices.";
			}
		}
		// testing wrong access edges (only telecabin at one extremity)
		list<point> aerial_way_extremities <- aerial_ways accumulate([first(each.shape.points),last(each.shape.points)]);
		ask slopes where (each.type="acces"){
			if (first(shape.points) in aerial_way_extremities) and (last(shape.points) in aerial_way_extremities){
				write "Access slope "+self+" is linked to two gondolas.";
			}
		}
		// testing orphan vertices
		list<point> end_vertices <- remove_duplicates(edges collect (last(each.shape.points)));
		list<point> start_vertices <- remove_duplicates(edges collect (first(each.shape.points)));
		loop v over: end_vertices{
			if not(v in start_vertices){
				//write "Vertice "+v+" is a dead end.";
				dead_end <- dead_end + v;
			}
		}
		write "There are "+length(dead_end)+" dead ends.";
		loop v over: start_vertices{
			if not(v in end_vertices){
		//		write "Vertice "+v+" is unreachable.";
				unreachable <- unreachable + v;
			}
		}
		write "There are "+length(unreachable)+" unreachable points.";
		loop v over: (end_vertices-dead_end-unreachable){
			list<slopes> slopes_with_v <- slopes where (v in [first(each.shape.points),last(each.shape.points)]);
			list<aerial_ways> a_with_v <- aerial_ways where (v in [first(each.shape.points),last(each.shape.points)]);
			if (length(slopes_with_v)+length(a_with_v)<3) {
				bool not_merge <-(
									length(slopes_with_v)=1 and length(a_with_v)=1
									) or ( 
									length(slopes_with_v)=2 and (
										(first(slopes_with_v).special != last(slopes_with_v).special) or 
										(first(slopes_with_v).type != last(slopes_with_v).type)
									)
								 );
				if !not_merge{
						mergeable <- mergeable + v;
				} 
			}
		}
		write "There are "+length(mergeable)+" mergeable points.";
	}
	
	aspect base{
		loop v over: dead_end{
			draw circle(5) at: v color: #red depth: 1000;
		}		
		loop v over: unreachable{
			draw circle(5) at: v color: #orange depth: 1000;
		}		loop v over: mergeable{
			draw circle(5) at: v color: #purple depth: 1000;
		}
	}
	
}

////////////////////////////////////


species generic_edge{
	string type;
	float angleTriangle;
	point triangle_position;
	bool visible <- true;
	
	// to draw a triangle showing the direction at the middle of the polyline
	action compute_segment{
		float l <- shape.perimeter/2;
		int p <- 0;
		point segment;
		float segment_length;
		segment <- {shape.points[1].x-shape.points[0].x,shape.points[1].y-shape.points[0].y,shape.points[1].z-shape.points[0].z};
		segment_length <-norm(segment);
		loop while: segment_length < l {
			l <- l - segment_length;
			p <- p + 1;
			segment <- {shape.points[p+1].x-shape.points[p].x,shape.points[p+1].y-shape.points[p].y,shape.points[p+1].z-shape.points[p].z};
			segment_length <-norm(segment);	
		}
		angleTriangle <- acos(segment.x/segment_length);
		angleTriangle <- segment.y<0 ? - angleTriangle : angleTriangle;
		triangle_position <- shape.points[p]+segment*l/segment_length;
	}
}

////////////////////////////////////


species slopes parent: generic_edge{
	string sens;
	rgb color <- #brown;
	string special;
	
	aspect base{
		if show_slopes{
			if visible{
				if special = "tunnel"{
					draw cube(20#m) at: first(shape.points) color: rgb(47,47,47) rotate: 90+angleTriangle;
					draw cube(20#m) at:last(shape.points) color: rgb(47,47,47) rotate: 90+angleTriangle;
				}else{
					draw shape color: color;
				}
			}		
			if show_triangles {draw triangle(10) at:  triangle_position rotate: 90+angleTriangle  color: color;}
		//	if show_triangles {draw triangle(10) at:  triangle_position color: color;}
		}
	}
}

///////////////////////


species aerial_ways parent: generic_edge{
	bool two_ways;
	list<people> waiting_line;
	int delay <- 60;
	int capacity <- 4;
	float speed <- 3.0;
	
	init{
		if name = "Pic Blanc"{
			delay <- 200;
			capacity <- 40;
			speed <- 10.0;
		}
	}
	
	aspect base{
		if visible{
			draw shape color:#black width:2;
		}
		if show_triangles {draw triangle(40) at: triangle_position rotate: 90+angleTriangle color: #black;}
	}
	
	reflex departure when: mod(cycle,delay) = 0{
		ask first(capacity, waiting_line){
			state <- "climb";
		}
		waiting_line <- waiting_line - first(capacity, waiting_line);
	}
	
}

species people skills:[moving] parallel: true{

	list<point> last_positions <- [];
//	int delay <- rnd(359);
	float turn_speed <- rnd(1.0,10.0);
	float amplitude <- 60.0;
	float angle_amp <- 60.0;
	point shifted_location;
	generic_edge last_edge <- nil;
	string level <- rnd_choice(["1*"::0.2,"2*"::0.3,"3*"::0.3,"chamois"::0.2]);
	rgb color <- #black;
	float slidding<-0.0;
	float angle <- float(rnd(359));
	float speed2;
	point shift;
	
	string state <- "ski";
	
	init{
		switch level{
			match "1*" {color <- #green;}
			match "2*" {color <- #blue;}//slidding <- 80;}
			match "3*" {color <- #red;
		//		slidding <- 60;
			}
			match "chamoix" {color <- #black;}
		}
	}
	
	
	reflex move{
		// change parameters when entering a new edge
		if current_edge != nil and current_edge != last_edge{
			if species(current_edge) = aerial_ways{
				//speed <- 3.0;
				state <- "wait";
				ask aerial_ways(current_edge){
					waiting_line <+ myself;
					myself.speed <- self.speed;
				}
			}else{
				if species(last_edge) = aerial_ways{
					last_positions <- [location];
				} 
				string ty <- (slopes(current_edge).special != "normal")?"chemin":slopes(current_edge).type;
				speed2 <- rnd(first(speed_range[level][ty]),last(speed_range[level][ty]));
				turn_speed <- rnd(first(turn_speed_range[level][ty]),last(turn_speed_range[level][ty]));
				amplitude <- rnd(first(amplitude_range[level][ty]),last(amplitude_range[level][ty]));
				slidding <- (slidding_coeff[level][ty])*rnd(0.7,1.1);
				angle_amp <- float(angle_range[level][ty]);
				state <- "ski";
			} 
			last_edge <- generic_edge(current_edge);
		}
		
		// regular behavor;
		angle <- angle + turn_speed;
		if state = "ski"{
			speed <- speed2 * (1+cos(angle_amp*cos(90+angle)))/2;	
		}
		
		if state != "wait"{
			do wander on:ski_domain proba_edges: proba_wander[level];
		}
		
//		shift <- ({0,1,0} rotated_by (heading::{0,0,1}))*amplitude*cos(angle);

		shift <- shift + (({0,1,0} rotated_by (heading::{0,0,1}))*amplitude*cos(angle)-shift)*trail_smoothness;
		shifted_location <- location + shift;
		//shifted_location <- last(last_positions) + (shifted_location - last(last_positions))*trail_smoothness;
		if species(current_edge) = aerial_ways{
			last_positions <- [];
		}else{
			last_positions <- last(nb_last_positions-1,last_positions)+shifted_location;
		}
		
		
	}
	
	
	aspect base{
		if current_edge != nil and species(current_edge) = slopes{
			shape <- (rectangle(dims.x,dims.y) rotated_by (heading+90+angle_amp*cos(90+angle+slidding)));
			draw shape color: color at: shifted_location;
			draw polyline(last_positions) color: #grey;
			//draw polyline(last_positions) color: slopes(current_edge).color;
		}
		else{
			shape <- rectangle(dims.x,dims.y) rotated_by (heading+90);
			draw shape at: location color:color;
			draw rectangle(dims.x,dims.y) color:color rotate: heading+90;
		}
	}
}

species building {
	string type; 
	rgb color <- #gray  ;
	
	aspect base {
		draw shape color: color ;
	}
}

species road  {
	rgb color <- #black ;
	aspect base {
		draw shape color: color ;
	}
}

/*******************Agent grille de parcelle (montagne)**************************** */
grid parcelle file: grid_data neighbors: 8  frequency:0{
	float altitude<-grid_value;  // altitude d'apres le MNT
	float hauteur_neige_couche_inf; //couche dure
	float hauteur_neige_couche_sup; //couche plus molle au dessus
	float hauteur_neige;	//hauteur de neige totale
 	float pente; //pente (selon le sens le plus important)
   	list<parcelle> parcelles_voisines;  //parcelles voisines
   	float proba_declenchement;	//proba de déclenchement d'une avalanche sur la parcelle (quand un skieur s'y trouve)
   	rgb ma_couleur;	//couleur pour verif
   
   //calcul de la heuteur de neige et définition de la couleur
//	reflex neige_couleur  {
//    	hauteur_neige<-hauteur_neige_couche_sup+hauteur_neige_couche_inf;
//   	
//   		if (hauteur_neige_couche_sup=0) {ma_couleur<-#red;}
// 		else {ma_couleur<-#green;}
//   }

	aspect basic	{
        //juste pour vérifier (faut ajouter l'agent parcelle dans le display si on veut le voir)
        draw rectangle(1#m,1#m) color:ma_couleur depth:altitude border:#black ; 
	}
}



/***********************************************
 *                  Expérience               * 
 ***********************************************/
experiment demo type: gui {
	parameter 'Show slopes' var: show_slopes   category: "Preferences";
	parameter 'Show slopes directions' var: show_triangles   category: "Preferences";
	parameter 'Trail size' var: nb_last_positions min:0 max:200  category: "Preferences";
	parameter 'Trail smoothness' var: trail_smoothness min:0.01 max:1.0  category: "Preferences";
	output synchronized: true{
		display "carte" type: opengl toolbar:false background:#black{
			grid parcelle   elevation:grid_value  	grayscale:true triangulation: true refresh: false;
			species slopes aspect:base position:{0,0,0.0};
			species aerial_ways aspect:base position:{0,0,0.0};
			species people aspect:base;
			//species graph_debug aspect: base;
			species building aspect: base ;
			species road aspect: base ;
		}
			

	} 
}


