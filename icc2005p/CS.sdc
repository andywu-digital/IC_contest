# operating conditions and boundary conditions #

current_design CS

set cycle 0;		#clock period defined by designer
set t_in  0;		#input delay defined by designer
set t_out 0;		#output delay defined by designer

create_clock -period $cycle [get_ports clk]
set_dont_touch_network [get_clocks clk]
set_clock_uncertainty -setup 0.1 [get_clocks clk]
set_clock_latency 0.5 [get_clocks clk]

set_input_delay $t_in -clock clk [get_ports X[7]]
set_input_delay $t_in -clock clk [get_ports X[6]]
set_input_delay $t_in -clock clk [get_ports X[5]]
set_input_delay $t_in -clock clk [get_ports X[4]]
set_input_delay $t_in -clock clk [get_ports X[3]]
set_input_delay $t_in -clock clk [get_ports X[2]]
set_input_delay $t_in -clock clk [get_ports X[1]]
set_input_delay $t_in -clock clk [get_ports X[0]]
set_input_delay $t_in -clock clk [get_ports reset]
set_output_delay $t_out -clock clk [get_ports Y[9]]
set_output_delay $t_out -clock clk [get_ports Y[8]]
set_output_delay $t_out -clock clk [get_ports Y[7]]
set_output_delay $t_out -clock clk [get_ports Y[6]]
set_output_delay $t_out -clock clk [get_ports Y[5]]
set_output_delay $t_out -clock clk [get_ports Y[4]]
set_output_delay $t_out -clock clk [get_ports Y[3]]
set_output_delay $t_out -clock clk [get_ports Y[2]]
set_output_delay $t_out -clock clk [get_ports Y[1]]
set_output_delay $t_out -clock clk [get_ports Y[0]]              
 
set_load -pin_load 1 [get_ports Y[9]]    
set_load -pin_load 1 [get_ports Y[8]]    
set_load -pin_load 1 [get_ports Y[7]]    
set_load -pin_load 1 [get_ports Y[6]]    
set_load -pin_load 1 [get_ports Y[5]]    
set_load -pin_load 1 [get_ports Y[4]]    
set_load -pin_load 1 [get_ports Y[3]]    
set_load -pin_load 1 [get_ports Y[2]]    
set_load -pin_load 1 [get_ports Y[1]]
set_load -pin_load 1 [get_ports Y[0]]
set_drive 1 [get_ports X[7]]
set_drive 1 [get_ports X[6]]
set_drive 1 [get_ports X[5]]
set_drive 1 [get_ports X[4]]
set_drive 1 [get_ports X[3]]
set_drive 1 [get_ports X[2]]
set_drive 1 [get_ports X[1]]
set_drive 1 [get_ports X[0]]
set_drive 1 [get_ports reset]
set_drive 1 [get_ports clk]
                       
set_operating_conditions -min_library fast -min fast  -max_library slow -max slow
set_wire_load_model -name umc18_wl10 -library slow 
                       
