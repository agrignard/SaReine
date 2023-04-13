/**
* Name: Complex Object Loading
* Author:  Arnaud Grignard
* Description: Provides a  complex geometry to agents (svg,obj or 3ds are accepted). The geometry becomes that of the agents.
* Tags:  load_file, 3d, skill, obj
*/

model obj_loading   

global {
	
	file shape_file_buildings <- shape_file("../includes/GamaVectorized.shp");
	
	//definition of the geometry of the world agent (environment) as the envelope of the shapefile
	geometry shape <- envelope(shape_file_buildings);

	init { 
		create object from:shape_file_buildings with:[type::string(get("type")), name::string(get("name"))]{
			if (type = "circle"){
			  do die;
		    }
		    color<-#black;
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
		
	}  
	
} 

species object skills:[moving]{
	rgb color;
	string type;
	string name;
	
	reflex move{
		shape <- shape rotated_by (rnd(1),{rnd(-1,1),rnd(-1,1),rnd(-1,1)});
		do wander;
		color <-rnd_color(255);
	}
	aspect obj {
		draw shape depth:1 color:color border: #black;
	}
			
}	

experiment Display  type: gui {
	float minimum_cycle_duration<-0.03#sec;
	output {
		
		display complex  background:#black type: 3d axes:false{
		  species object aspect:obj;				
		}
	}
}