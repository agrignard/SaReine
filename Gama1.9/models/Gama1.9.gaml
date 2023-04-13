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
		create object from:shape_file_buildings with:[id::int(get("id")),type::string(get("type")), name::string(get("name"))]{
			location<-{location.x,location.y,1000};
			if (type = "circle"){
			  do die;
		    }
		    color<-#white;
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
		    	color<-rgb(#gamablue,25);
		    }
		    if (name = "donut3"){
		    	color<-rgb(#gamared,25);
		    }
		    if (name = "donut5"){
		    	color<-rgb(#gamaorange,25);
		    }
		    if (name = "donut2" or name = "donut4"){
		    	do die;
		    }
		    if (name = "rond"){
		    	color<-rgb(#gamared,25);
		    }
		    
	   
		}
		
	}  
	
} 

species object skills:[moving]{
	rgb color;
	int id;
	string type;
	string name;
	
	reflex move{
		//shape <- shape rotated_by (rnd(1),{rnd(-1,1),rnd(-1,1),rnd(-1,1)});
		location<-{location.x,location.y,location.z>0 ? (1000-cycle*id*10):0};
		//color <-rnd_color(255);
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