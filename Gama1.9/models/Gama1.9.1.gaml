/**
* Name: Gama 1.9
* Author:  Arnaud Grignard - Tri Nguyen-Huu
* Description: A toy model demonstrating "morphing" technologies in GAMA
* Tags:  load_file, 3d, skill, obj
*/

model gamablob  

global {
	file Gama_shape_file <- shape_file("../includes/GamaVectorized.shp");
	string mode <- "Dark" among: ["Light to dark", "Dark to light", "Light", "Dark"];

	//definition of the geometry of the world agent (environment) as the envelope of the shapefile
	geometry shape <- envelope(Gama_shape_file);
//	field blob_field <- field(100,100,0.0); 
	blob the_blob;
	
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
		create object from:Gama_shape_file with:[type::string(get("type")), name::string(get("name"))]{
		    color<-#white;
		    if (name = "gamablue"){
		    	color<-#gamablue;
		    	depth <- 60.0;
		    }
		    if (name = "gamared"){
		    	color<-#gamared;
		    	depth <- 70.0;
		    }
		    if (name = "gamaorange"){
		    	color<-#gamaorange;
		    	depth <- 100.0;
		    }
		    if (name = "donut1"){
		    	color<-rgb(#gamablue,25);
		    	depth <- 30.0;
		    }
		    if (name = "donut3"){
		    	color<-rgb(#gamared,25);
		    			    	depth <- 50.0;
		    }
		    if (name = "donut5"){
		    	color<-rgb(#gamaorange,25);
		    	depth <- 80.0;
		    }
		    if (name = "circle"){
		    	color<-rgb(#gamared,70);
		    	color<-#gamared;
		    }
		    if (name = "donut4" or name ="donut2"){
		    	do die;
		    }
		}

		create blob{
			the_blob <- self;
		}
		ask the_blob {
			do blob_seed({50,50},10.0,500.0);
			location <- {50,50};
		}
		ask object{
			ask inside(blob_field, self.shape){
				height <- max(height, myself.depth);
			//	grid_value <- height;
			}
		}
	}
	
	
	reflex stats{
	//	write "cycle "+cycle+" : "+sum(blob_field collect(each.grid_value));
	}
	
	
	
	
	reflex truc when: cycle = 20{
		ask the_blob {do blob_seed({50,50},10.0,10.0);}
	}
} 



species blob{
	float total_blob_weight;
	
	action blob_seed(point centre, float radius, float quantity){
	//	write "seeding";
		ask blob_field{
			float dist <- sqrt((grid_x-centre.x)^2+(grid_y-centre.y)^2);
			if dist < radius {
				grid_value <- grid_value + quantity*cos(asin(dist/radius));
			}
		}
	}

	
	reflex coordinate_blobs{
		total_blob_weight <- sum(blob_field collect(each.grid_value));
		ask blob_field{
			old_value <- grid_value;
		}
	}
		
}


grid blob_field width: 100 height: 100 use_regular_agents: false neighbors: 8 parallel:false {	
	float old_value;
	float dif <- 0.8;
	float cohesion <- 0.0002;
	float height <- 0.0;
		
	reflex diffusion{
	//	float quantity <- dif * grid_value/8;
		float quantity <- old_value/8;
		point vec <- {the_blob.location.x - grid_x, the_blob.location.y - grid_y};
	//	grid_value <- grid_value - nb * quantity;
		ask neighbors{
			float scal <-  (self.grid_x - myself.grid_x) * vec.x+ (self.grid_y - myself.grid_y) * vec.y;
			float dif2 <- scal > 0 ? dif:max(0,dif + scal*cohesion/the_blob.total_blob_weight*norm(vec)^2);
			//float dif2 <- min(2*dif,max(0,dif - scal*cohesion*norm(vec)));
			self.grid_value <- self.grid_value + dif2*quantity;
			myself.grid_value <- myself.grid_value - dif2 * quantity;
		}
	}	
	

	
	
}

species object skills:[moving]{
	rgb color;
	string type;
	string name;
	float depth <- 0.0;	

	aspect obj {
		if name = "gamared" or name = "gamaorange" or name = "gamablue"{
			draw 1 around(shape) depth: depth color:color;	    	
		}
			draw shape depth: depth color:color;	    	
	}			
}	

experiment Dark_Mode  type: gui autorun:false{
	//float minimum_cycle_duration<-0.016#sec;
float minimum_cycle_duration<-0.025#sec;
	parameter 'Mode' var: mode   category: "Preferences";
	output {
		display complex  background: world.changeColor(cycle) type: 3d axes:false autosave:false fullscreen:false toolbar:false{
			//mesh blob_field grayscale:true scale: 0.05 triangulation: true smooth: true refresh: false;
			grid blob_field elevation: true grayscale: true triangulation: true;
	//		mesh env grayscale:true scale: 0.05 triangulation: true smooth: true refresh: false;
		 	species object aspect:obj;		
		  	
		}
	}
}
