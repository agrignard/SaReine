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
	
	
	// *************************** VARIABLES AGENT MONDE **********************

	float pas_x <-1.0#m; //taille des cases selon x
	float pas_y <-10.0#m; //taille des cases selon y
	
	//critere de déclenchement de l'avalanche
	float chute_neige_3j <-rnd(2.0)#m;
	int topo<-rnd(2);
	float temp<-rnd(-11.0,11.0);
	int vent<-rnd(50);
	float proba_nouveau_skieur<-0.01;
	
	//pour avalanche
	bool fin_avalanche<-false;
	bool declenchement<-false;
	list<parcelle> parcelle_declenchement; //parcelles qui vont faire partie de l'avalanche
	point lieu_fin_avalanche<-{2660,0,0};//direction finale de l'avalanche 
	float longueur_avalanche<-10+rnd(100)#m; //longueur de l'avalanche
	float largeur_avalanche<-10+rnd(40)#m; //largueur de l'avalanche
	
	//données SIG
	file grid_data <- grid_file("../includes/Alpes50.asc");
	geometry shape <- envelope(grid_data);	
	
	bool mode_debug <- false;

//***************** INITIALISATION AGENT MONDE *********************
init {

	step <- 1 # s; //step time of the simulation (pas de 1s)
	
	ask parcelle {parcelles_voisines <- (self neighbors_at 1);}	

	float max_g <- parcelle max_of(each.grid_value);
	
	ask parcelle {
		//définition pente principale de chaque parcelle
		float delta_alt <-(parcelles_voisines with_min_of(each.altitude)).altitude-(parcelles_voisines with_min_of(each.altitude)).altitude;
		float distan<-(parcelles_voisines with_min_of(each.altitude)).altitude-(parcelles_voisines with_min_of(each.altitude)).altitude;
		pente<-atan(delta_alt/shape.width);
			
		//proba  de déclenchement d'avalanche sur la parcelle
		float proba_cn<-0.1;
		float proba_p<-0.1;
		float proba_t<-0.1;
		float proba_v<-0.1;
		float proba_tp<-0.1;
			
		//condition chute de neige
		if chute_neige_3j <0.5 {proba_cn<-0.0;}
		if chute_neige_3j>=0.5 and chute_neige_3j <=1.0 {proba_cn<-0.5;}
		if chute_neige_3j >1.0 {proba_cn<-0.9;}
		
		//condition pente
		if pente <25 {proba_p<-0.1;}
		if pente>=25 {proba_p<-0.9;}
		
		//condition températures
		if temp<=-10.0 {proba_t<-0.05;}
		if temp>=10.0 {proba_t<-0.9;}
		else {proba_t<-0.1;}
		
		//condition vent
		if vent = 1 {proba_v<-1.0;}
		else {proba_v<-0.1;}
		
		//condition topo
      	if topo=0  {proba_tp<-0.3;}
		if topo=1  {proba_tp<-0.5;}
		if topo=2 {proba_tp<-0.9;}
		
		
		//Calcul de la probabilité de déclenchement
	//	
		if (mode_debug) {
			proba_declenchement <- grid_x = 30 ? 1.0 : 0;
		
		} else {
			proba_declenchement<-proba_cn*proba_p*proba_t*proba_v*proba_tp;
		}
		//définition des conditions de neige initiale
		hauteur_neige_couche_inf<-1.5#m;  //couche dure pas avalancheuse
		hauteur_neige_couche_sup<-0.5#m+chute_neige_3j; //couche susceptible dêtre avalancheuse
		
		if (mode_debug) {
			float val <- grid_value / max_g * 255;
			color <- rgb(val,val,val);
		}
	
	}
	

}
		
/**************** Fin du INIT **********************************/


	
//***************** REFLEXES & ACTIONS AGENT MONDE *********************

//pour faire arriver des skieurs en haut de la pente
reflex arrivee_skieur when:cycle in [1,100,1000] {
	create skieur {
		location<-(parcelle with_max_of(each.altitude)).location; 
		niveau_ski<-rnd(1,10);
		ma_couleur<-rnd_color(255);
		vitesse<-niveau_ski*0.5  #m/#s	;		//vitesse initiale
		vitesse_fuite<-niveau_ski  #m/#s	;
		coeff_risque <- niveau_ski/10.0; //entre 0 et 1
		amplitude_courbe <- rnd(4,20)#m;
	}
}

//avancée de l'avalanche
reflex avancee_avalanche{
	ask front_avalanche {   //gère le mouvement de l'avalanche
		do deplacement;
	}
	
}

}
/**************** Fin de AGENT MONDE **********************************/




/***********************************************
 *                   AGENTS Du modèle               * 
 ***********************************************/


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


/**************************************************************************
 ************************************FRONT d AVALANCHE*********************
 *************************************************************************/
 
species front_avalanche skills:[moving]{ 
	float vitesse_init<-10  #m/#s	;		//vitesse initiale
	float vitesse<-vitesse_init #m/#s;		//sa vitesse
	float nu<-0.25 ;			// caractéristique de l'avanlanche
	float ksi <-1000 #m/#s^2 ;			//conditions topographiques
	float ki <- 10+2 #m ;			// perimetre de la surface mouillee dans la section transversale 
	float S <- 20 #m^2 ;				// section transversale 
	float Rh <- S/ki ;			// rayon hydraulique
	float g <- 9.81 #m/#s^2;			// acceleration gravitationelle
	float lambda <-g/(ksi*Rh) ; 		//un truc de méca
	geometry ligne_front;		//pour voir le chemin parcouru en u step
	list<parcelle> parcelles_traversee;	//les parcelles traversées à chaque step
	list<parcelle> parcelle_avalanche_debut; //les parcelles de l'avalanche
	list<parcelle> parcelle_avalanche_fin; //les parcelles de l'avalanche
	parcelle parcelle_depart;		//d'ou elle part au début du step
	parcelle parcelle_fin;			//sur quelle parcelle elle arrive à la fin du step
	int nb_par_trav;					//nombre de parcelles traversées en un step
	point position_initiale;			//poistion de départ de l'avalanche
	point centre_avalanche;  // centre de l'avalanche
	float pente_avant;			//pente de la parcelle en début de mouvement
	float phi;					//angle de frottement
	geometry trajectoire;		//trajectoire suivi par l'avalanche (prédéfinie)
	list<point> points <- [location];	//points de la trajectoire
	float angle_rotation;				//direction de l'avalanche
    list<skieur> skieurs_pris;			//skieurs dans l'avalanche
    
	//equa diff pour calculer la vitesse
	equation eqVit {
		diff(vitesse,phi)=g*cos(pente_avant)*(tan(pente_avant)-nu) / vitesse - g / (ksi*Rh) *vitesse;
	}
	
	//définit la trajectoire lors du déclenchement	
	action definir_trajectoire {	
		points <-[];  //on ajoute les points selon la position initiale
		points << location;
			if (location.x<800 and location.y>1800)   {	points << {712,1837,0};	}
			if (location.x<2000 and location.y>350)    {points << {1912,337,0};}
			points << {2637,12,0};
			points << lieu_fin_avalanche;
			trajectoire <- line(points);  	//on trace la trajectoire passant par ces points
		}
	
	// le front se déplace
	action deplacement  {
		vitesse_init<-vitesse;	//vitesse du pas antérieur (continuité)
		point pos_avant<-location;   //sa position de départ avant déplacement
		parcelle_depart<-one_of(parcelle overlapping pos_avant);   //de quelle parcelle il part
		do follow path: path(trajectoire) speed:vitesse; //il se déplace en direction de lieu fin avalanche à un vitesse donnée		
		point pos_apres<-location;  //sa position d'arivée apres déplacement
		
		if (pos_apres.y-pos_avant.y)!=0{angle_rotation<-90-atan((pos_apres.x-pos_avant.x)/(pos_apres.y-pos_avant.y));}
		else {angle_rotation<-0.0;}
		centre_avalanche<-{(self.location.x+longueur_avalanche/2),self.location.y}; //on recalcule le centre apres son déplacement
	
		parcelle_fin<-one_of(parcelle overlapping pos_apres);  //parcelle d'arrivée
		
		parcelle_avalanche_debut<-parcelle where (each.location.x>=pos_avant.x and each.location.x<(pos_avant.x+longueur_avalanche));  //parcelles couvertes avant mouvement
		parcelle_avalanche_fin<-parcelle where (each.location.x>=pos_apres.x and each.location.x<(pos_apres.x+longueur_avalanche));  //parcelles couvertes apres mouvement
		
		centre_avalanche<-{(self.location.x+longueur_avalanche/2),self.location.y}; //on recalcule le centre apres son déplacement
		
		//les trois trucs qui suivent sont pas encore utilisés mais pourraient servir
		ligne_front <- link(pos_avant,pos_apres); //ligne reliant le départ et l'arrivée 
		parcelles_traversee<-(parcelle overlapping ligne_front); //parcelle traversées lors du step
		nb_par_trav<-length(parcelles_traversee);  //nb de parcelles traversées
		
		float hauteur_neige_deversee;  //hauteur de neige qui passe d'une parcelle à l'autre

		ask parcelle_avalanche_debut {
			hauteur_neige_deversee<-hauteur_neige_couche_sup;   //correspond à la neige supp de la parcelle de départ
			hauteur_neige_couche_sup<-0.0;  //qui du coup se vide
		}
			
			ask parcelle_avalanche_fin {
			hauteur_neige_couche_sup<-hauteur_neige_deversee;  //et la même neige arrive sur la parcelle de fin
		}
		
		pente_avant <- parcelle_avalanche_debut mean_of(each.pente);  //pente moyenne

		float pos <- position_initiale.x-location.x ;

		vitesse<-vitesse_init;  //pour la continuité
	
		if vitesse>0 {
			solve eqVit method:#rk4 step_size:0.001; //résolution équa diff
		}
		
		vitesse <-max([0,vitesse*cos(pente_avant)]); //pour éviter les vitesse <0
		if vitesse=0.0 or self.location=lieu_fin_avalanche{
			fin_avalanche<-true;
		}
		ask skieurs_pris {
			location<-myself.location;
		}
		
	}
	

		//représente le front de niege, juste pour le voir sur la représentation 3D
	aspect basic	{
         draw rectangle(longueur_avalanche,largeur_avalanche) rotate:angle_rotation at:centre_avalanche color:#yellow depth:parcelle_fin.altitude+100#m border:#black ;  // texture:[roof_texture,texture]; 

	}
	
	aspect debug	{
         draw rectangle(longueur_avalanche,largeur_avalanche) rotate:angle_rotation at:centre_avalanche color:#yellow depth:2#m border:#black ;  // texture:[roof_texture,texture]; 

	}
		
}




/***************************************
 * ******SKIEUR******* *
 ***************************************/
species skieur skills:[moving] control: simple_bdi schedules: skieur where each.est_libre{ 
	float vitesse;		//vitesse initiale
	float vitesse_fuite;
	float coeff_risque; //entre 0 et 1
	float amplitude_courbe;
	geometry trajectoire;
	point final_target;
	parcelle ma_parcelle -> parcelle(location);
	bool est_libre <- true;
	rgb ma_couleur;
	int niveau_ski; //1 debutant ; 5 expert
	float coeff_sinus_courbe ; 
	float pente_skieur ;
	float g <- 9.81 #m/#s^2;			// acceleration gravitationelle
	float vitesse_step_precedent ; 
	
//Beginning of the predicates --------------------------------------------------------------------------------
		
	//predicate 'Desire'
	 predicate skier <- new_predicate("skier");
	 predicate fuir <- new_predicate("fuir");
	 predicate aider <- new_predicate("aider") ;

	init
	{
		do add_desire(skier);
		final_target<-lieu_fin_avalanche; 
	}
	
	
//Beginning of the perception of the agent from himself and his environment  --------------------------
	perceive target: front_avalanche when: est_libre	{
		list<mental_state> previous_beliefs <- myself.get_beliefs_with_name("lieu_avalanche");
		previous_beliefs <- previous_beliefs where (each.predicate.values["name"] = name);
		bool change_belief <- false;
		if(empty(previous_beliefs)) {
			change_belief <- true;
			ask myself{
				do add_belief(new_predicate("lieu_avalanche") with_values ["name"::myself.name, "location_value"::myself.location]);
			}
		}
		if (not empty(previous_beliefs) and (first(previous_beliefs).predicate.values["location_value"] != location)) {
			first(previous_beliefs).predicate.values["location_value"] <- location;
			change_belief <- true;
		}
		if (change_belief) {
			ask myself {
				do remove_intention(skier, false);
				trajectoire <- nil;
			}
		}
		
	}
	

	perceive target: (skieur-self)  where (not each.est_libre) when: est_libre{
		list<mental_state> previous_beliefs <- myself.get_beliefs_with_name("lieu_skieur_detresse");
		previous_beliefs <- previous_beliefs where (each.predicate.values["name"] = name);
		bool change_belief <- false;
		if(empty(previous_beliefs)) {
			change_belief <- true;
			ask myself{
				do add_belief(new_predicate("lieu_skieur_detresse") with_values ["name"::myself.name, "location_value"::myself.location]);
			}
		}
		if (not empty(previous_beliefs) and (first(previous_beliefs).predicate.values["location_value"] != location)) {
			first(previous_beliefs).predicate.values["location_value"] <- location;
			change_belief <- true;
		}
		if (change_belief) {
			ask myself {
				do remove_intention(skier, false);
				trajectoire <- nil;
			}
		}
		
	}
	 
//Beginning of the perception of the agent from himself and his environment  --------------------------
	rule belief: new_predicate("lieu_avalanche") new_desire: fuir;
	rule belief: new_predicate("lieu_skieur_detresse") new_desire: aider strength: 2.0;

	

	action definir_trajectoire(point target, float risque_pris,  float amplitude) {
		if (target.x <= location.x) {
			trajectoire <- line([location, target]);
		} else {
			float dist_y <- abs(location.y - target.y);
			float dist_x <- abs(location.x - target.x);
			bool droite <- target.y > location.y;
			list<point> points <- [location];
			float coeff <- 0.1 + 2 * risque_pris;
			float dist <- amplitude / 2.0;
			point current_point <- location + {dist  * coeff ,(droite ? dist : - dist)};
			bool droite_obj <- droite;
			droite <- not droite;
			loop while: current_point != target {
				
				points << current_point;
				//float dist <- amplitude ;
				float new_x <- current_point.x + amplitude  * coeff;
				if ((target.x -new_x  ) < 5#m) {
					current_point <- target;
				}
				else {
					float distH <-  amplitude ;
					float distHy <- amplitude + ((flip(dist_x = 0 ? 0.0 : 0.1) and (droite_obj = droite)) ? rnd(min([100.0,abs(target.y - current_point.y)])): 0.0);
					current_point <- current_point + {distH  * coeff ,droite ? distHy : - distHy};
					if !(current_point overlaps world) {
						current_point <- (world closest_points_with current_point) [0] ;
					}
					droite <- not droite;
						
					
			
				}
				
			}
			points << current_point;
			trajectoire <- line(points);
		}
	
	}



	action skier{
		point current_point <- location ;
		pente_skieur <- ma_parcelle.pente ;
		coeff_sinus_courbe <- 2*3.14/(amplitude_courbe*cos(pente_skieur)) ;
		vitesse_step_precedent <- vitesse ; 
		vitesse <- (abs(sin((500-location.x)*coeff_sinus_courbe))*g*sin(pente_skieur))*niveau_ski/10 + vitesse_step_precedent; // on coefficiente la vitesse par la valeur absolue du sinus représentant la trajectoire et aussi par un coefficient dépendant du niveau du skieur

		do follow path: path(trajectoire) speed:vitesse; 			
	}
	
	
	plan skier_au_pif intention:skier when: est_libre
	{
		if (trajectoire = nil) {do definir_trajectoire(final_target, coeff_risque, amplitude_courbe);}
		do skier;
	}


	plan fuite intention:fuir when: est_libre
	{
		point lieu_avalanche<- one_of(get_beliefs(new_predicate("lieu_avalanche")) collect (point(get_predicate(mental_state (each)).values["location_value"])));
			point target <- ((parcelle where (each.location.x < location.x)) farthest_to(lieu_avalanche)).location;
			if (trajectoire = nil) {do definir_trajectoire(target, coeff_risque * 2.0, amplitude_courbe/2.0);}
			do skier;
			do remove_intention(skier, true);
		}	
	
	
	
	plan sauver intention:aider when: est_libre
	{
		//	write "je vais te sauver Pépito";
		point lieu_skieur_detresse<- one_of(get_beliefs(new_predicate("lieu_skieur_detresse")) collect (point(get_predicate(mental_state (each)).values["location_value"])));
			point target <- lieu_skieur_detresse;
			if (trajectoire = nil) {do definir_trajectoire(target, coeff_risque * 2.0, amplitude_courbe/2.0);}
			do skier;
			do remove_intention(skier, true);
			do remove_intention(fuir, true);
			if location=target {
				write "Creusons !";
				ask world {do pause;}	
			}
				
	}
	
	
	
	
	
	
	reflex ecrabouiller when: est_libre{
	if parcelle_declenchement contains(ma_parcelle) {
	//	write name+" : désolé, c'est moi qui ai déclenché l'avalanche !";
		if flip(0.5) {
			do passer_a_la_lessiveuse;
		}	
	}
	else {
		ask front_avalanche {
		if (parcelle_avalanche_fin contains(myself.ma_parcelle) or parcelles_traversee contains(myself.ma_parcelle) and !fin_avalanche){
			ask myself {do passer_a_la_lessiveuse;}
			
		}
	}
	}
	
	do clear_intentions; 
	}
	
	
	
	action passer_a_la_lessiveuse {
	//		write name+" : je suis pris dans l'avalanche";
			trajectoire <- nil;
			est_libre <- false;		
			(front_avalanche closest_to self).skieurs_pris << self;
	}
	
	
	reflex declenchement_avalanche  when: est_libre{
		parcelle_declenchement<-[]; //parcelle ou débutera l'avalanche
			if !declenchement{		//on ne peut déclecnher qu'une avalanche dans la simu (si c'est déjà fait, on ne peut pas en déclencher d'autres)
				if flip(ma_parcelle.proba_declenchement) {   //on tire si le skieur déclenche l'avalanche par un test par rapport à la proba de déclenchement de la parcelle
			//	write "Go go Avalanche";
				parcelle parcelle_depart;
				parcelle_depart<-self.ma_parcelle;
				parcelle_declenchement<- parcelle where (each.location.x>(parcelle_depart.location.x-longueur_avalanche) and each.location.x<=(parcelle_depart.location.x) and each.location.y>(parcelle_depart.location.y-largeur_avalanche/2) and each.location.y<=(parcelle_depart.location.y+largeur_avalanche/2));

				//je declenche celle u il y a le skieur + x en dessous dépendaemment de la lonhueur de l'avalanche

					declenchement<-true;  //pour pas qu'il y en est deux
				}
			}
		
		
		
		
		if length(parcelle_declenchement)>0 {  //pour éviter les bugs
			 
		 //le déclenchement créé un front d'avalanche
	      	create front_avalanche {
				location<-(parcelle_declenchement with_min_of(each.altitude)).location; //en tete d'avalanche
				position_initiale<-location;	//à une posiiton initiale donnée
				lieu_fin_avalanche<-(parcelle with_min_of(each.altitude)).location;  //direction finale de l'avalanche (point le plus bas)
				vitesse_init<-1.0; //avec une vitesse initiale donnée
				centre_avalanche<-{(self.location.x+longueur_avalanche/2),self.location.y};  //pour la représentation; je prends le milieu
				centre_avalanche<-{parcelle_declenchement mean_of(each.location.x),parcelle_declenchement mean_of(each.location.y)};  //pour la représentation; je prends le milieu
				do definir_trajectoire;	
	}
	}
	
	
}
	
	
	aspect basic	{
        draw triangle(100#m) depth: 10#m rotate:  heading + 90  color:ma_couleur at: location + {0,0,ma_parcelle.altitude+1#m} border:#black ;  
	}

	aspect debug	{
        //juste pour vérifier (faut ajouter l'agent parcelle dans le display si on veut le voir)
        draw triangle(10#m) depth: 10#m color:ma_couleur border:#black rotate: heading + 90; 
        if (trajectoire != nil) {
        	draw trajectoire color: ma_couleur depth: 1.5 ;
        }
	} 
	
}






/***********************************************
 *                  Expérience               * 
 ***********************************************/
experiment demo type: gui {
	output synchronized: true{
		display "carte" type: opengl {
			grid parcelle   elevation:grid_value  	grayscale:true triangulation: true refresh: false;
		//	species parcelle aspect:basic;	//avec ses parcelles (en 3D)
		
			species front_avalanche aspect:basic;	//le front d'avalcnhe
			species skieur aspect:basic;	
		}
			

	} 
}

experiment debug type: gui {
	
	action _init_ {
		create simulation with:[mode_debug::true];
	}
	output {
		display "carte" type: opengl background: #pink {
			grid parcelle  refresh: false;
		//	species parcelle aspect:basic;	//avec ses parcelles (en 3D)
		
			species front_avalanche aspect:debug;	//le front d'avalcnhe
			species skieur aspect:debug;	
		}
			

	} 
}
