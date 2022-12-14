

module dp_ram
#(
     parameter RAM_WIDTH = 8,         //width of RAM(number of bits)
     parameter ADDR_WIDTH = 4        //number of bits required to represent the RAM address
)
(
     write_clk,
	 read_clk,                    //读写时钟
	 
	 write_allow,
	 read_allow,                  //读写使能
	 
	 write_addr,
	 read_addr,                   //读写地址
	 
	 write_data,
	 read_data                    //读写数据
	);

 input                      write_clk;
 input                      read_clk;
 
 input                      write_allow;
 input                      read_allow;
 
 input [ADDR_WIDTH-1:0]     write_addr;
 input [ADDR_WIDTH-1:0]     read_addr;
 
 input [RAM_WIDTH-1:0]      write_data;
 
 output[RAM_WIDTH-1:0]      read_data;
 
 reg   [RAM_WIDTH-1:0]      read_data;
 

 (* ram_style="block" *) reg [RAM_WIDTH-1:0] memory [2**ADDR_WIDTH-1:0];
 
 integer i;
 always @(posedge write_clk)
    begin
	    if(write_allow) begin
		    memory[write_addr] <=  write_data;
		end 
	end

 always @(posedge read_clk)
     begin
	    if(read_allow)
		    read_data <= memory[read_addr]; 
	end

endmodule
 