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
	int nb_last_positions <- 50;
	
	//données SIG
	file grid_data <- grid_file("../includes/Alpes250.asc");
	geometry shape <- envelope(grid_data);	
	file shape_file_slopes <- shape_file("../includes/shp/ski_slopes.shp");
	file shape_file_aerial <- shape_file("../includes/shp/aerial_ways.shp");
	float offset;
	graph slopes_graph;
	graph aerial_graph;
	
	
	graph ski_domain;
	
	graph_debug debugger;

	init {
		create aerial_ways from:shape_file_aerial with:[two_ways:bool(get("two_ways"))]{
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
				}
			}
		}
		
		create slopes from:shape_file_slopes with:[type::string(get("type")), name::string(get("name")), sens::string(get("sens"))] {
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
						self.type <- "link";
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
		
		
		create people number:400{
			location<-any_location_in(one_of(union(slopes, aerial_ways)));
			last_positions <- list_with(nb_last_positions,location);
		}
		
		slopes_graph <-directed(as_edge_graph(slopes));
		aerial_graph <- directed(as_edge_graph(aerial_ways));
		
		ski_domain <- directed(as_edge_graph(union(slopes, aerial_ways)));
		
		create graph_debug{
			debugger <- self;
		}
		ask debugger {do test_graph;}
		
	}
	
}

//////////////////////////////////////////


species generic_edge{
	point segment;
	float segment_length;
	float angleTriangle;
	bool visible <- true;
	
	action compute_segment{
		segment <- {shape.points[1].x-shape.points[0].x,shape.points[1].y-shape.points[0].y,shape.points[1].z-shape.points[0].z};
		segment_length <-norm(segment);
		angleTriangle <- acos(segment.x/segment_length);
		angleTriangle <- segment.y<0 ? - angleTriangle : angleTriangle;
	}
}

species graph_debug{
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
			if (length(slopes_with_v)+length(a_with_v)<3) and !(length(slopes_with_v)=1 and length(a_with_v)=1) {
		//		write "Vertice "+v+" is mergeable.";
				mergeable <- mergeable + v;
			}	
		}
		list<point> truc <- (slopes where (each.type = "tunnel")) accumulate ([first(each.shape.points), last(each.shape.points)]);
		mergeable <- mergeable - (slopes where (each.type = "tunnel")) accumulate ([first(each.shape.points), last(each.shape.points)]);
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


species slopes parent: generic_edge{
	string type;
	string sens;
	rgb color <- #brown;
	
	aspect base{
		if show_slopes{
			if visible{
				if type = "tunnel"{
					draw cube(20#m) at: first(shape.points) color: rgb(47,47,47) rotate: 90+angleTriangle;
					draw cube(20#m) at:last(shape.points) color: rgb(47,47,47) rotate: 90+angleTriangle;
				}else{
					draw shape color: color;
				}
			}		
			draw triangle(10) at:  first(shape.points)+ segment*0.5 rotate: 90+angleTriangle color: #blue;
		}
	}
}

///////////////////////


species aerial_ways parent: generic_edge{
	bool two_ways;
	
	aspect base{
		if visible{
			draw shape color:#black width:2;
		}
		draw triangle(40) at:  first(shape.points)+ segment*0.5 rotate: 90+angleTriangle color: #black;
	}
}

species people skills:[moving]{
	list<point> last_positions;
	int delay <- rnd(359);
	float turn_speed <- rnd(1.0,10.0);
	float amplitude <- 60#m;
	point shifted_location;
	float base_speed <- rnd(2.0,9.0);
	
	reflex move{
		if current_edge != nil and species(current_edge) = aerial_ways{
			speed <- 3.0;
		}else{
			speed <- base_speed;
		}
		
		do wander on:ski_domain ;
		shifted_location <- location + ({0,1,0} rotated_by (heading::{0,0,1}))*amplitude*cos(turn_speed*cycle+delay);
		last_positions <- last(nb_last_positions-1,last_positions)+shifted_location;
	}
	
	
	aspect base{
		if current_edge != nil and species(current_edge) = slopes{
			draw rectangle(15#m,40#m) color: #black at: shifted_location rotate: heading+90+60*cos(90+turn_speed*cycle+delay);
			draw polyline(last_positions) color: #grey;
			//draw polyline(last_positions) color: slopes(current_edge).color;
		}
		else{
			draw rectangle(15#m,40#m) color:#black rotate: heading+90;
		}
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
	parameter 'Trail size' var: nb_last_positions min:0 max:200  category: "Preferences";
	output synchronized: true{
		display "carte" type: opengl {
			grid parcelle   elevation:grid_value  	grayscale:true triangulation: true refresh: false;
			species slopes aspect:base position:{0,0,0.0};
			species aerial_ways aspect:base position:{0,0,0.0};
			species people aspect:base;
			species graph_debug aspect: base;
		}
			

	} 
}


