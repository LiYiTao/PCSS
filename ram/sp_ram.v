//-------------------------------------------------------------------------
// 
//
// Filename         : sp_ram.v
// Author           : 
// Release version  : 1.0
// Release date     : 2022-10-20
// Description      :
//
//-------------------------------------------------------------------------

module sp_ram
#(
    //parameter
    parameter RAM_WIDTH = 8 ,       //width of RAM(number of bits)
    parameter ADDR_WIDTH = 4        //number of bits required to represent the RAM address

)
(
    clk             ,
    wr_en           ,
    rd_en           ,
    addr            ,              
    din             ,
    dout        
);

 input                       clk                  ;
 input                       wr_en                ;
 input                       rd_en                ;
 input [ADDR_WIDTH-1:0]      addr                 ;
 input [RAM_WIDTH-1:0 ]      din                  ;
 output[RAM_WIDTH-1:0 ]      dout                 ;

 reg   [RAM_WIDTH-1:0 ]      dout                 ;
 reg   [RAM_WIDTH-1:0 ]      memory[2**ADDR_WIDTH-1:0];  
 
 always @(posedge clk)
    begin
	     if(rd_en)
		     dout         <=  memory[addr]; 
	end
 always @(negedge clk)
    begin
	     if(wr_en)
		     memory[addr] <=  din      ;
	end

endmodule