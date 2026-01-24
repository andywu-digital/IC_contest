module SET ( clk , rst, en, central, radius, mode, busy, valid, candidate );

input clk, rst;
input en;
input [23:0] central;
input [11:0] radius;
input [1:0] mode;
output reg busy;
output reg valid;
output reg [7:0] candidate;

//=================================================================//
// Wire & Reg
//=================================================================//
//sweep counter
reg start_flag;
reg [5:0] counter;
wire [3:0] x_cand, y_cand;

//in circle
wire in_circle_a, in_circle_b, in_circle_c; 	//in flag

//=================================================================//
// Sweep counter
//=================================================================//
always @(posedge clk or posedge rst)begin
	if(rst)
		counter <= 'd0;
	else if(busy)
		counter <= counter + 'd1;
	else
		counter <= 'd0;
end

assign x_cand = {1'd0, counter[2:0]} + 'd1;	//x candidate
assign y_cand = {1'd0, counter[5:3]} + 'd1;	//y candidate

//=================================================================//
// In Circle
//=================================================================//
//Circle A
circle ca(
	.x_cand({1'd0, x_cand}), .y_cand({1'd0, y_cand}),
	.x_cent({1'd0, central[23:20]}), .y_cent({1'd0, central[19:16]}),
	.radius({1'd0, radius[11:8]}),
	.in_circle(in_circle_a)
);	

//Circle B
circle cb(
	.x_cand({1'd0, x_cand}), .y_cand({1'd0, y_cand}),
	.x_cent({1'd0, central[15:12]}), .y_cent({1'd0, central[11:8]}),
	.radius({1'd0, radius[7:4]}),
	.in_circle(in_circle_b)
);	
	
//Circle C
circle cc(
	.x_cand({1'd0, x_cand}), .y_cand({1'd0, y_cand}),
	.x_cent({1'd0, central[7:4]}), .y_cent({1'd0, central[3:0]}),
	.radius({1'd0, radius[3:0]}),
	.in_circle(in_circle_c)
);	

//=================================================================//
// Count set number
//=================================================================//
always @(posedge clk or posedge rst)begin
	if(rst)begin
		candidate <= 'd0;
	end
	else if(en)begin
		candidate <= 'd0;
	end
	else if(busy)begin
		case(mode)
			'd0: begin	//A set
				if(in_circle_a)
					candidate <= candidate + 'd1;
			end
			'd1: begin	//A & B set
				if(in_circle_a && in_circle_b)
					candidate <= candidate + 'd1;
			end
			'd2: begin	//A U B set
				if(in_circle_a != in_circle_b)
					candidate <= candidate + 'd1;
		    	end
			'd3: begin  
				if((in_circle_a && in_circle_b && ~in_circle_c) || (in_circle_a && ~in_circle_b && in_circle_c) || (~in_circle_a && in_circle_b && in_circle_c))
				    candidate <= candidate + 'd1;
			end
            		default: candidate <= candidate;
        	endcase
	end
end

//=================================================================//
// Output
//=================================================================//
//busy
always @(posedge clk or posedge rst)begin
	if(rst)
		busy <= 'd0;
	else if(en)
		busy <= 'd1;
	else if(counter == 'd63)
		busy <= 'd0;
end
//valid
always @(posedge clk or posedge rst)begin
	if(rst)
		valid <= 'd0;
	else if((counter == 'd63) && ~valid)
		valid <= 'd1;
	else
		valid <= 'd0;
end

endmodule

//==================================================================//
// Local function
//==================================================================//
module circle(
	input wire signed [4:0] x_cand, y_cand,
	input wire signed [4:0] x_cent, y_cent,
	input wire signed [4:0] radius,
	output reg in_circle
);
//Wire & Reg
wire signed [4:0] x_diff, y_diff;
wire signed [10:0] x_sqr, y_sqr; 
wire signed [10:0] r_sqr;
wire signed [10:0] cal;

//(x-xc)^2 + (y-yc)^2 <= r^2
assign x_diff = x_cand - x_cent;
assign y_diff = y_cand - y_cent;

assign x_sqr = x_diff*x_diff;
assign y_sqr = y_diff*y_diff;

assign r_sqr = radius*radius;

assign cal = x_sqr + y_sqr - r_sqr;

//in flag
always @(*)begin
	if(cal[10] || (cal == 'd0))	//cal <= 0
		in_circle = 'd1;
	else
		in_circle = 'd0;
end

endmodule
