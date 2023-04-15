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
	
	//données SIG
	file grid_data <- grid_file("../includes/Alpes250.asc");
	geometry shape <- envelope(grid_data);	
	file shape_file_slopes <- shape_file("../includes/shp/ski_slopes.shp");
	file shape_file_aerial <- shape_file("../includes/shp/aerial_ways.shp");
	float offset;
	graph slopes_graph;
	graph aerial_graph;
	
	graph ski_domain;

	init {
		create slopes from:shape_file_slopes with:[type::string(get("type")), name::string(get("name"))] {
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
			if type = "link"{
				create slopes {
					self.type <- "link";
					shape <- polyline(reverse(myself.shape.points));
				}
			}else{
				if first(shape.points).z < last(shape.points).z {
					shape <- polyline(reverse(shape.points));
				}
			}
			
			segment <- {shape.points[1].x-shape.points[0].x,shape.points[1].y-shape.points[0].y,shape.points[1].z-shape.points[0].z};
			segment_length <-norm(segment);
		}
		create aerial_ways from:shape_file_aerial {
			loop i from: 0 to:length(shape.points)-1{	
				float val <- parcelle(shape.points[i]).grid_value;
				shape <- set_z(shape,i,val+50);
			}
			if first(shape.points).z > last(shape.points).z {
				shape <- polyline(reverse(shape.points));
			}
			segment <- {shape.points[1].x-shape.points[0].x,shape.points[1].y-shape.points[0].y,shape.points[1].z-shape.points[0].z};
			segment_length <-norm(segment);
		}
		
		create people number:100{
			location<-any_location_in(one_of(slopes));
		}
		create people number:50{
			location<-any_location_in(one_of(aerial_ways));
			ski<-false;
		}
		
		slopes_graph <-directed(as_edge_graph(slopes));
		aerial_graph <- directed(as_edge_graph(aerial_ways));
		
		ski_domain <- directed(as_edge_graph(union(slopes, aerial_ways)));
		
	}
}

species slopes{
	point segment;
	float segment_length;
	string type;
	//bool tunnel;
	rgb color <- #blue;
	
	aspect base{
		if type = "tunnel"{
			draw cube(20#m) at: first(shape.points) color: #black;
			draw cube(20#m) at:last(shape.points) color: #black;
		}else{
			draw shape color: color;
		}
		
		
			float angleTriangle <- acos(segment.x/segment_length);
		 	angleTriangle <- segment.y<0 ? - angleTriangle : angleTriangle;
			draw triangle(40) at:  first(shape.points)+ segment*0.5 rotate: 90+angleTriangle color: #blue;
	}
}

species aerial_ways{
	point segment;
	float segment_length;
	
	aspect base{
		draw shape color:#black width:3;
		
		//loop i from: 0 to: segments_number-1{
		 	 		
// --------		pour afficher des petits triangles pour indiquer le sens de circulation sur chaque route 
	

		 			float angleTriangle <- acos(segment.x/segment_length);
		 			angleTriangle <- segment.y<0 ? - angleTriangle : angleTriangle;
//					draw triangle(10) at:  first(shape.points)+ {0.5*segment.x,0.5*segment.y,shape.} rotate: 90+angleTriangle color: #black;
					draw triangle(40) at:  first(shape.points)+ segment*0.5 rotate: 90+angleTriangle color: #black;
//		 		}
	//	}
		
	}
}

species people skills:[moving]{
	
	bool ski<-true;
	
	reflex move{
		speed <- 10.0;
		//do wander on:ski ? slopes_graph:aerial_graph ;
		do wander on:ski_domain ;
	}
	
	reflex test when: int(self)=0 {
		//write species(current_edge);
	}
	
	
	aspect base{
		if current_edge != nil and species(current_edge) = slopes{
			draw circle(50#m) color:#black;
		}
		else{
			draw circle(50#m) color:#red;
		}
//		draw circle(50#m) color:ski?#black:#red;
	}
}

/*******************Agent grille de parcelle (montagne)**************************** */
grid parcelle file: grid_data neighbors: 8  {
	float altitude<-grid_value;  // altitude d'apres le MNT
	float hauteur_neige_couche_inf; //couche dure
	float hauteur_neige_couche_sup; //couche plus molle au dessus
	float hauteur_neige;	//hauteur de neige totale
 	float pente; //pente (selon le sens le plus important)
   	list<parcelle> parcelles_voisines;  //parcelles voisines
   	float proba_declenchement;	//proba de déclenchement d'une avalanche sur la parcelle (quand un skieur s'y trouve)
   	rgb ma_couleur;	//couleur pour verif
   
   //calcul de la heuteur de neige et définition de la couleur
	reflex neige_couleur  {
    	hauteur_neige<-hauteur_neige_couche_sup+hauteur_neige_couche_inf;
   	
   		if (hauteur_neige_couche_sup=0) {ma_couleur<-#red;}
 		else {ma_couleur<-#green;}
   }

	aspect basic	{
        //juste pour vérifier (faut ajouter l'agent parcelle dans le display si on veut le voir)
        draw rectangle(1#m,1#m) color:ma_couleur depth:altitude border:#black ; 
	}
}



/***********************************************
 *                  Expérience               * 
 ***********************************************/
experiment demo type: gui {
	output synchronized: true{
		display "carte" type: opengl {
			grid parcelle   elevation:grid_value  	grayscale:true triangulation: true refresh: false;
			species slopes aspect:base position:{0,0,0.0};
			species aerial_ways aspect:base position:{0,0,0.0};
			species people aspect:base;
		}
			

	} 
}


