/**
* Name: bugtest
* Based on the internal empty template. 
* Author: Tri
* Tags: 
*/


model width_polyline_bug

global{
	
	geometry shape <- polygon([{0,0},{0,100},{100,100},{100,0}]);
	
	init{
		create dessin{
		}
	}	
}

species dessin{
	rgb color;
	
	aspect default{
		draw world.shape color: rgb(#pink,0.9);
		draw polyline([{10,10},{90,10}]) color: #purple;
		draw polyline([{10,30},{90,30}]) width: 200 color: #cyan;
		draw polyline([{10,60},{90,60}]) depth: 10 color: #yellow;
		draw polyline([{10,90},{90,90}]) width: 200 depth: 10 color: #green;
	}
}



experiment essai type: gui {	
	output {
	 display "My display" type: opengl { 
		species dessin aspect: default;
	 }
	}
}