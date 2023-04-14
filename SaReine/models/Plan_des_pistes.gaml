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

	init {
		create slopes from:shape_file_slopes {
			loop i from: 0 to:length(shape.points)-1{
				float val <- parcelle(shape.points[i]).grid_value;
				shape <- set_z(shape,i,val+50);
				
			}
		}
		create aerial_ways from:shape_file_aerial {
			loop i from: 0 to:length(shape.points)-1{
				float val <- parcelle(shape.points[i]).grid_value;
				shape <- set_z(shape,i,val+50);
				
			}
		}
		
		create people number:100{
			location<-any_location_in(one_of(slopes));
		}
		create people number:50{
			location<-any_location_in(one_of(aerial_ways));
			ski<-false;
		}
		
		slopes_graph <- as_edge_graph(slopes);
		aerial_graph <- as_edge_graph(aerial_ways);
		
	}
}

species slopes{
	aspect base{
		draw shape color:#blue;
	}
}

species aerial_ways{
	aspect base{
		draw shape color:#black width:5;
	}
}

species people skills:[moving]{
	
	bool ski<-true;
	
	reflex move{
		do wander on:ski ? slopes_graph:aerial_graph ;
	}
	aspect base{
		draw circle(50#m) color:ski?#black:#red;
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


