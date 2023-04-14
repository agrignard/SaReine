/**
* Name: Gama 1.9
* Author:  Arnaud Grignard - Tri Nguyen-Huu
* Description: A toy model demonstrating "morphing" technologies in GAMA
* Tags:  load_file, 3d, skill, obj
*/

model obj_loading   

global {
	point origin <- {490,490,0};
	float color_speed <- 2.0;
	file Gama_shape_file <- shape_file("../includes/GamaVectorized_cut.shp");
	string sound_file <-"../includes/sound.mp3";
	string mode <- "Light to dark" among: ["Light to dark", "Dark to light", "Light", "Dark"];
	bool inner_rings <- false;
	bool cut_shapes <- true;

	
	//definition of the geometry of the world agent (environment) as the envelope of the shapefile
	geometry shape <- envelope(Gama_shape_file);
	
	// auxiliary sigmoid function
	float sigmoid(int t, int midCourse, float speed){
		return 1/(1+exp(-speed*(t-midCourse)));
	}
	
	// color change
	rgb changeColor(int t){
		int midCourse <- 400;
		float lambda <- 0.04;
		float sig;
		switch mode{
			match "Light to dark"{
				sig <- 1 - sigmoid(cycle,midCourse,lambda);
			}			
			match "Dark to light"{
				sig <- sigmoid(cycle,midCourse,lambda);
			}
			match "Light"{
				sig <- 1.0;
			}
			match "Dark"{
				sig <- 0.0;
			}
		}
		return rgb(255*sig,255*sig,255*sig);
	}

	init { 
		if cut_shapes{
			Gama_shape_file <- shape_file("../includes/GamaVectorized_cut.shp");
		}else{
			Gama_shape_file <- shape_file("../includes/GamaVectorized.shp");
		}
		create object from:Gama_shape_file with:[type::string(get("type")), name::string(get("name")),level::int(get("level"))]{
			if (type = "circle"){
			  do die;
		    }
		    origin <- myself.origin;
		    color<-#white;
		    if (name = "gamablue"){
		    	color<-#gamablue;
		    	depth <- 0.0001;
		    }
		    if (name = "gamaorange"){
		    	color<-#gamared;
		    	depth <- 0.0001;
		    }
		    if (name = "gamayellow"){
		    	color<-#gamaorange;
		    	depth <- 0.0001;
		    }
		    if (name = "donut1"){
		    	color<-rgb(#gamablue,25);
		    }
		    if (name = "donut3"){
		    	color<-rgb(#gamared,25);
		    }
		    if (name = "donut5"){
		    	color<-rgb(#gamaorange,25);
		    }
		    if (name = "rond"){
		    	color<-rgb(#gamared,70);
		    	color<-#gamared;
		    	rotation_speed <- -2 * rotation_speed;
		    	axe <- {1,-1,0};
		    }
		    location<-location  - {0,0,depth/2};
		}
		

		

		ask object{
			 if (name = "un" or  name = "point" or name = "neuf"){
			 	rotation_speed <- - 4 * rotation_speed;
		    	origin <- first(object where (each.name="rond")).location;
		    	depth <- 1.0;
		    	 location<-location  + {0,0,depth/2};
		    	// if name="neuf"{
		    	 	rotation_speed <- 0.0;
		    	// }
		    }
			switch level {
				match 5 {
					axe <- {1,0,0};
				}
				match 4 {
					axe <- {0,1,0};
				}
				match 3 {
					axe <- {1,0,0};
				}
				match 2 {
					axe <- {0,1,0};
					rotation_speed <- 3 * rotation_speed;
				}
				match 1 {
					axe <- {1,0,0};
					rotation_speed <- -2* rotation_speed;
				}
			}
			shift <- location - origin;
			if level =0 {
				do die;
			}
		}
		
		loop i over: remove_duplicates(object collect each.level){
			ask first(object where (each.level = i)){
				linked_objects <- object where (each.level = i-1);
			}
		}
	}  
	
//	reflex play_sound when: cycle = 1{
//			start_sound source: sound_file;
//	}

} 


species object skills:[moving]{
	rgb color;
	string type;
	string name;
	point axe <- {0,1,0};
	float rotation_speed <- 1.0;
	int level;
	list<object> linked_objects <- [];
	float depth <- 0.0;
	point origin;
	point shift;		

	action propagate_rotation(float angle,point ax, point centre){
		origin <- centre + (( origin - centre) rotated_by (angle::ax));
		shape <- shape rotated_by (angle,ax);
	    shift <-  shift rotated_by (angle::ax);
	    axe <-  axe rotated_by (angle::ax);
	   	ask linked_objects{
	    	do propagate_rotation(angle, ax, centre);
	    }
	}

	reflex rotate{
		if cycle > 293 {
			rotation_speed <- rotation_speed / 1.015;
		}
		if cycle = 600{
			rotation_speed <- 0.0;
		}
		shape <- shape rotated_by (rotation_speed,axe);
	    shift <-  shift rotated_by (rotation_speed::axe);
	    ask linked_objects{
	    	do propagate_rotation(myself.rotation_speed, myself.axe, myself.origin);
	    }
	}
	
	aspect obj {
		if name = "donut2" or name = "donut4"{
			if inner_rings{
				if mode = "Dark"{
					color <- rgb(20,20,20);
				}else{
					color <- world.changeColor(cycle);				
				}
			}else{
				color <- rgb(#white,0);
			}
		}
		switch name{
			match "un"{
		 		color <- rgb(#white,2*(cycle-350));
		 		if cycle < 320 {
		 			color <- rgb(#white,0);
		 		}else{
		 			color <- #white;
		 		}
		 		if cycle > 500{
		    		color <- blend(#white,#gamared,(cycle-500)/150);
		    	} else {
		    		color <- rgb(#white,0);
		    	}
		    } 
		    match "point"{
		    	color <- rgb(#white,2*(cycle-350));
		    	if cycle < 320 {
		 			color <- rgb(#white,0);
		 		}else{
		 			color <- #white;
		 		}
		 		if cycle > 500{
		    		color <- blend(#white,#gamared,(cycle-500)/150);
		    	} else {
		    		color <- rgb(#white,0);
		    	}
		    }
		     match "neuf"{
		    	color <- rgb(#white,cycle-300);
		    	color <- rgb(#white,cycle-500);
		    	int start_cycle <- 500;
		    	if cycle > start_cycle{
		    		color <- blend(#white,#gamared,(cycle-start_cycle)/150);
		    	} else {
		    		color <- rgb(#white,0);
		    	}
		    }
		   match "rond"{
		    	color <- rgb(#gamared,255*world.sigmoid(cycle, 380, 0.04));
		    }
		}
		draw shape depth: depth color:color at: origin +shift;	    	
	}
			
}	

experiment Dark_Mode  type: gui autorun:false{
	float minimum_cycle_duration<-0.016#sec;
//	float minimum_cycle_duration<-0.025#sec;
	parameter 'Mode' var: mode   category: "Preferences";
	parameter 'Inner rings' var: inner_rings   category: "Preferences";
	parameter 'Cut Shapes' var: cut_shapes   category: "Preferences";
	output {
		display complex  background: world.changeColor(cycle) type: 3d axes:false autosave:false fullscreen:false toolbar:false{
		  species object aspect:obj;			
		}
	}
}
