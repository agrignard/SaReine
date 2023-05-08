/**
* Name: Gama Pong. Worst Pong game ever.
* Based on the internal empty template. 
* Author: Tri
* Tags: 
*/


model gama_ping

global{
	int goals_to_score <- 2;
	int width <- 120;
	int height <- 100;
	float ball_radius <- 5.0;
	float cycle_duration_to_start <- 0.6#s;
	float cycle_duration_to_check_goal <- 0.85#s;
	float racket_width <- 3*ball_radius;
	
	int racket_highlight_duration <- 3;

	int score <- 0;
	bool game_paused <- true;
	bool gameover <- false;
	string score_line <- "Move the time slider to the right to start the game.";
	int best_score <- 0;
	
	int racket_highlight <- 0;
	
	
	
	geometry shape <- polygon([{0,0},{0,height},{width,height},{width,0}]);
	
	init{
		create playground;
	}	
	
	action init_game{
		ask ball {
			do die;
		}	
		score <- 0;
		create ball;
		score_line <- "Remaining goals to score: "+score;
		ask first(ball){
			do initialize;
		}
		game_paused <- false;
		gameover <- false;
	}
	
	action game_over {
		experiment.minimum_cycle_duration <- 1 #s;
		ask ball {do die;}
		game_paused <- true;
		gameover <- true;
		if score > best_score{
			best_score <- score;
		}
		score_line <- "Move the slider to the right to start again.";
	}
	
	reflex schedule_game{
		if racket_highlight > 0{
			racket_highlight <- racket_highlight - 1;
		}
		
		if game_paused{
			if experiment.minimum_cycle_duration < cycle_duration_to_start{
				do init_game;
			}
		}
	}
}







species playground{
	rgb color;
	int nb_segments <- 16;
	float racket_position -> -ball_radius + racket_width/2 + experiment.minimum_cycle_duration/1#s*(height+2*ball_radius-racket_width);
	geometry racket <- polygon([{-ball_radius,racket_position-racket_width/2},{-ball_radius,racket_position+racket_width/2},
				{-ball_radius-2,racket_position+racket_width/2},{-ball_radius-2,racket_position-racket_width/2}]);
	
	reflex compute_racket when: !gameover{
		racket <- polygon([{-ball_radius,racket_position-racket_width/2},{-ball_radius,racket_position+racket_width/2},
				{-ball_radius-2,racket_position+racket_width/2},{-ball_radius-2,racket_position-racket_width/2}]);
	}
	
	aspect default{
		draw 0.5 around(polyline([{-ball_radius,-ball_radius},{width+ball_radius,-ball_radius}, {width+ball_radius,height+ball_radius},{-ball_radius,height+ball_radius}])) color: #black;
		draw racket  color: racket_highlight>0?#red:#black;

		draw "Score: "+score+ " (best: "+best_score+")" at: {width/2,height+10} font:font("Helvetica", 20 , #plain) color: #black anchor: #center;
		if gameover {
			draw string("Game over. Score: "+score) at: {width/2,height/2} font:font("Helvetica", 50 , #plain) color: #black anchor: #center;
		}
	}
}






species ball{
	point direction <- {1.2,0.4};
	float speed <- 1.0;
	float radius <- 5.0;
	bool catchable <- true;
	geometry shape <- circle(radius);
	
	action initialize{
		location <- {20,rnd(100)};
	}
	
	bool in_bounds{
		return (location.x > 0) and (location.x < width) 
			and (location.y > 0) and (location.y < height);
	}
	
	bool hit_racket{
		return self overlaps first(playground).racket;
	}

	action compute_new_hor_location{
		loop while: (location.x < 0) or (location.x > width) {
			if location.x < 0{
				location <- {-location.x,location.y};
				direction <- {-direction.x,direction.y};
			}
			if location.x > width{
				location <- {2*width-location.x,location.y};
				direction <- {-direction.x,direction.y};
			}
		}
	}
	
	action compute_new_vert_location{
		loop while: (location.y < 0) or (location.y > height){
			if location.y < 0{
				location <- {location.x,-location.y};
				direction <- {direction.x,-direction.y};
			}
			if location.y > height{
				location <- {location.x,2*height-location.y};
				direction <- {direction.x,-direction.y};
			}
		}
	}
	
	reflex move{
		location <- location + direction*speed;
		do compute_new_vert_location;
		if location.x < 0 {
			if hit_racket(){
				racket_highlight <- racket_highlight_duration;
				score <- score + 1;
				if direction.x <  0 {
					direction <- {-direction.x,-direction.y};
				}
			}
			if location.x < -5 * ball_radius{
				ask world {do game_over;}
			}
		}else{
			do compute_new_hor_location;
		}
		
		
	
	}
	
	aspect default{
		draw shape color: rgb(41, 128, 185);
	}
	
}


experiment "Play Gama Pong" type: gui autorun: true{	
	float minimum_cycle_duration <- 1#s;
	output {
		display "My display" type: opengl { 
			species playground;
			species ball;
		}
	}
}