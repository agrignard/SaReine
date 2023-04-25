/**
* Name: bugtest
* Based on the internal empty template. 
* Author: Tri
* Tags: 
*/


model points_as_geometry

global{
	
	list liste <- [{20,30},{3,2},{30,44},{5,6},{12,4}, {105,30}];
	list<geometry> liste2 <- [{20,30},{3,2},{30,44},{5,6},{12,4}, {105,30}];
	list<geometry> liste3 <- [geometry({20,30}),{3,2},{30,44},{5,6},{12,4}, {105,30}];	
	
	init{
		create forme;
		write liste inside first(forme).shape;
		write liste2 inside first(forme).shape;
		write liste3 inside first(forme).shape;
		write (liste collect(geometry(each))) inside first(forme).shape;
	}
	
}

species forme{
	geometry shape <- square(100);
	point location <- {50,50};
	
	aspect default{
		draw shape color: #pink;
		loop l over: liste{
			draw circle(1) at: l color: #purple;
		}
	}
}

experiment essai type: gui {	
	output {
	 display "My display" { 
			species forme aspect: default;
	 }
	}
}