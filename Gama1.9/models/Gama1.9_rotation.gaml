/**
* Name: Gama 1.9
* Author:  Arnaud Grignard - Tri Nguyen-Huu
* Description: A toy model demonstrating "morphing" technologies in GAMA
* Tags:  load_file, 3d, skill, obj
*/

model obj_loading   

global {
	point origin <- {490,490,0};
	file shape_file_buildings <- shape_file("../includes/GamaVectorized.shp");
	
	//definition of the geometry of the world agent (environment) as the envelope of the shapefile
	geometry shape <- envelope(shape_file_buildings);

	init { 
		create object from:shape_file_buildings with:[type::string(get("type")), name::string(get("name")),level::int(get("level"))]{
			if (type = "circle"){
			  do die;
		    }
		   color<-rgb(#white,0);
		    if (name = "gamablue"){
		    	color<-#gamablue;
		    	location<-{location.x,location.y,1};
		    }
		    if (name = "gamaorange"){
		    	color<-#gamared;
		    }
		    if (name = "gamayellow"){
		    	color<-#gamaorange;
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
		    if (name = "donut2" or name = "donut4"){
		 //   	do die;
		    }
		    if (name = "rond"){
		    	color<-rgb(#gamared,25);
		    }
		}
		

		ask object{
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
				}
				match 1 {
					axe <- {1,1,0};
				}
			}
			//shape <- shape + 5 around(polyline([origin - axe*500, origin +  axe*500]));
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
//
//		ask object{
//			shift <- location-origin;
//			write "Objet "+int(self)+" location: "+location;
//
//		}
	
	}  
	
	
	
} 


species object skills:[moving]{
	rgb color;
	string type;
	string name;
	point axe <- {0,1,0};
	float rotation_speed <- 1.0;
	int level;
	list<object> linked_objects <- [];
	
	point shift;

	action propagate_rotation(float angle,point ax){
		shape <- shape rotated_by (angle,ax);
	    shift <-  shift rotated_by (angle::ax);
	    axe <-  axe rotated_by (angle::ax);
	   	ask linked_objects{
	    	do propagate_rotation(angle, ax);
	    }
	}

	reflex rotate{
		shape <- shape rotated_by (rotation_speed,axe);
	    shift <-  shift rotated_by (rotation_speed::axe);
	    ask linked_objects{
	    	do propagate_rotation(myself.rotation_speed, myself.axe);
	    }
	}
	aspect obj {
		draw shape depth:0 color:color border: color at: origin +shift;
		//draw sphere(5) at: origin color: #green;
	}
			
}	

experiment Dark_Mode  type: gui autorun:false{
	float minimum_cycle_duration<-1#sec;
	output {
		display complex  background:#black type: 3d axes:false autosave:false fullscreen:false toolbar:false{
		  species object aspect:obj;			
		}
	}
}
