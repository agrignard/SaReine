/**
* Name: Complex Object Loading
* Author:  Arnaud Grignard
* Description: Provides a  complex geometry to agents (svg,obj or 3ds are accepted). The geometry becomes that of the agents.
* Tags:  load_file, 3d, skill, obj
*/

model obj_loading   

global {
	point origin <- {490,490,0};
	file shape_file_buildings <- shape_file("../includes/GamaVectorized.shp");
	
	//definition of the geometry of the world agent (environment) as the envelope of the shapefile
	geometry shape <- envelope(shape_file_buildings);

	init { 
		create object from:shape_file_buildings with:[type::string(get("type")), name::string(get("name"))]{
			if (type = "circle"){
			  do die;
		    }
		    color<-#grey;
		    if (name = "gamablue"){
		    	color<-#gamablue;
		    }
		    if (name = "gamaorange"){
		    	color<-#gamared;
		    }
		    if (name = "gamayellow"){
		    	color<-#gamaorange;
		    }
		    if (name = "donut1"){
		    	color<-#gamablue+100;
		    }
		    if (name = "donut3"){
		    	color<-#gamared+100;
		    }
		    if (name = "donut5"){
		    	color<-#gamaorange+100;
		    }   
		}
		
		
//		create test{
//			x <- 490;
//		}
//		
//				create test{
//			x <- 300;
//		}
		ask object{
			shift <- location-origin;
			write "Objet "+int(self)+" location: "+location;

		}
	
	}  
	
	
	
} 

species test{
	int x;
	aspect obj {
		draw 10 around(polyline([{x,0}, {x,1000}])) depth:1 color: #green;
	}
}



species object skills:[moving]{
	rgb color;
	string type;
	string name;
	point axe <- {0,1,0};
	float rotation_speed <- 1.0;
	point original_location;
	int level;
	
	point shift;

	reflex move{
	
		shape <- shape rotated_by (rotation_speed,axe);
	    shift <-  shift rotated_by (rotation_speed::axe);
	  //  write shift;
	//	new <- origin +shift; 
		//location <-origin + point(shift rotated_by (rotation_speed,axe));
		//shape <- shape rotated_by (rnd(1),{rnd(-1,1),rnd(-1,1),rnd(-1,1)});
		//do wander;
		//color <-rnd_color(255);
		
	}
	aspect obj {
//		draw 5 around(polyline([location, location+{0,1000,0}])) depth:1 color: color;
//		draw 5 around(polyline([origin, origin+{0,1000,0}])) depth:1 color: #green;
		draw shape depth:1 color:color border: #black at: origin +shift;
		draw sphere(5) at: origin color: #green;
	}
			
}	

experiment Display  type: gui {
	float minimum_cycle_duration<-0.1#sec;
	output {
		
		display complex  background:#black type: 3d axes:false{
		  species object aspect:obj;			
		  species test aspect: obj;
		}
	}
}