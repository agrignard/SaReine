/**
* Name: Gama Ping
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
	float goal_scale <- 1.4;
	float cycle_duration_to_start <- 0.6#s;
	float cycle_duration_to_check_goal <- 0.85#s;

	int score;
	float start_date;
	float last_score <- -1.0;
	list<float> time_scores <- [];
	bool game_paused <- true;
	string score_line <- "Move the time slider to the right to start the game.";
	float best_score <- 10000000.0;
	int percent <- 50;
	float best_percent <- 10000000.0;
	
	
	geometry shape <- polygon([{0,0},{0,height},{width,height},{width,0}]);
	
	init{
		create playground;
		score <- goals_to_score;
	}	
	
	action init_game{
		ask ball {
			do die;
		}
		
		score <- goals_to_score;
		start_date <- machine_time;
		create ball;
		score_line <- "Remaining goals to score: "+score;
		ask first(ball){
			do initialize;
		}
		game_paused <- false;
	}
	
	action end_game{
		game_paused <- true;
		float end_date <- machine_time;
		last_score <- (end_date - start_date)/1000;
		time_scores << last_score;
		time_scores <- time_scores sort_by(each);
		best_percent <- mean(first(ceil(length(time_scores)*percent/100),time_scores));
		best_percent <- round(best_percent*1000)/1000;
		if last_score < best_score{
			best_score <- last_score;
		}
		score_line <- "Move the slider to the right to start again.";
	}
	

	
	reflex schedule_game{
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


	bool check_goal{
		return length(ball)> 0 and first(ball).in_goal() and first(ball).catchable;
	}

	reflex referee{
		if experiment.minimum_cycle_duration > cycle_duration_to_check_goal{
			if check_goal(){
				first(ball).catchable <- false;
				score <- score - 1;
				score_line <- "Goal !!! Remaining goals to score: "+score;
			}
		}
		if score = 0 and !game_paused{
			ask world{
				do end_game;
			}
		}
	}
	
	aspect default{
		draw 0.5 around(polyline([{-ball_radius,-ball_radius},{width+ball_radius,-ball_radius},
				{width+ball_radius,height+ball_radius},{-ball_radius,height+ball_radius},
				{-ball_radius,-ball_radius}])) color: #black;
		
		if first(ball).in_goal(){
			draw rectangle({width - goal_scale*ball_radius, -ball_radius},{width+ball_radius, height + ball_radius}) color: rgb(52, 152, 219,100);		
		}
		
		if !first(ball).catchable{
			draw rectangle({width - goal_scale*ball_radius, -ball_radius},{width+ball_radius, height + ball_radius}) color: rgb(231, 76, 60);
		}
		
				
		loop i from: 0 to:nb_segments step:2{
			draw polyline(points_along(polyline([{width - goal_scale*ball_radius, -ball_radius},{width - goal_scale*ball_radius, height + ball_radius}]),
						[i/(nb_segments+1),(i+1)/(nb_segments+1)]))+ 0.5 color: #black;
		}
		
		draw score_line at: {width/2,height+10} font:font("Helvetica", 20 , #plain) color: #black anchor: #center;
		
		if game_paused and last_score > 0{
			draw string("Your score: "+last_score+"s") at: {width/2,height/2} font:font("Helvetica", 50 , #plain) color: #black anchor: #center;
		}
		
		if last_score > 0{
			draw string("Last score: "+last_score+"s") at: {-ball_radius,-10} font:font("Helvetica", 20 , #plain) color: #black anchor: #left_center;
			draw string("Best score: "+best_score+"s (Average best "+percent+"%: "+best_percent+"s)") at: {-ball_radius,-7} font:font("Helvetica", 20 , #plain) color: #black anchor: #left_center;
			
		}
	}
}



species ball{
	point direction <- {1.2,0.4};
	float speed <- 1.0;
	float radius <- 5.0;
	bool catchable <- true;
	
	action initialize{
		location <- {20,rnd(100)};
	}
	
	bool in_bounds{
		return (location.x > 0) and (location.x < width) 
			and (location.y > 0) and (location.y < height);
	}
	
	bool in_goal{
		return (location.x > width - (goal_scale - 1) * ball_radius) and (location.x < width) 
			and (location.y > 0) and (location.y < height);
	}
	
	reflex move{
		location <- location + direction*speed;
		loop while: !in_bounds(){
			if location.x < 0{
				location <- {-location.x,location.y};
				direction <- {-direction.x,direction.y};
			}
			if location.x > width{
				location <- {2*width-location.x,location.y};
				direction <- {-direction.x,direction.y};
			}
			if location.y < 0{
				location <- {location.x,-location.y};
				direction <- {direction.x,-direction.y};
			}
			if location.y > height{
				location <- {location.x,2*height-location.y};
				direction <- {direction.x,-direction.y};
			}
		}
		if location.x < width - (3+goal_scale)*ball_radius {
			catchable <- true;
			score_line <- "Remaining goals to score: "+score;
		}
	}
	
	aspect default{
		draw circle(radius) color: rgb(41, 128, 185);
	}
	
}


experiment "Play Gama Ping" type: gui autorun: true{	
	float minimum_cycle_duration <- 1#s;
	output {
		display "My display" type: opengl { 
			species playground;
			species ball;
		}
	}
}