/**
* Name: bugtest
* Based on the internal empty template. 
* Author: Tri
* Tags: 
*/


model overlapping_bug

global{
	
	geometry shape <- polygon([{0,0},{0,80},{100,80},{100,0}]);
	image_file photo <- (image_file(("../includes/Shibuya.png")));
	matrix<int> im <- matrix<int>(photo);
	
	init{
		
		create disc{
			name <- "purple";
			color <- #purple;
			location <- {30,30};
		}
		create disc{
			name <- "cyan";
			color <- #cyan;
			location <- {50,70};
		}
		create disc{
			name <- "gold";
			color <- #gold;
			location <- {130,30};
		}
		create forme;
		ask disc{
			write "Disc "+name+" is overlapped by the following forms: "+(forme overlapping self);
		} 
	}
	
}

species disc{
	rgb color;
	
	aspect default{
		draw circle(3) color: color;
	}
}

species forme{
	geometry shape <- polygon([{10,10},{170,10},{170,50},{10,50}]);
//	point location <- {50,50};
	
	aspect default{
		draw world.shape color: #pink;
		
		draw shape color: #yellow;
	
	}
}

experiment essai type: gui {	
	output {
	 display "My display" type: opengl axes: true{
	 	//	image im refresh: false transparency: 0 position: {0,0,0}  size: {100,100} color: #blue;	
		 	image im refresh: false transparency: 0;	
			species forme aspect: default transparency: 0.8;
			species disc aspect: default;
	 }
	}
}