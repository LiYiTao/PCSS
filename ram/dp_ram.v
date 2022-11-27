

module dp_ram
#(
     parameter RAM_WIDTH = 8,         //width of RAM(number of bits)
     parameter ADDR_WIDTH = 4        //number of bits required to represent the RAM address
)
(
     rst_n,

     write_clk,
	 read_clk,                    //读写时钟
	 
	 write_allow,
	 read_allow,                  //读写使能
	 
	 write_addr,
	 read_addr,                   //读写地址
	 
	 write_data,
	 read_data                    //读写数据
	);
	
 input                      rst_n;

 input                      write_clk;
 input                      read_clk;
 
 input                      write_allow;
 input                      read_allow;
 
 input [ADDR_WIDTH-1:0]     write_addr;
 input [ADDR_WIDTH-1:0]     read_addr;
 
 input [RAM_WIDTH-1:0]      write_data;
 
 output[RAM_WIDTH-1:0]      read_data;
 
 reg   [RAM_WIDTH-1:0]      read_data;
 

 (* RAM_STYLE="{AUTO | BLOCK |  BLOCK_POWER1 | BLOCK_POWER2}" *)
 reg   [RAM_WIDTH-1:0]      memory[2**ADDR_WIDTH-1:0];  
 
 integer i;
 always @(posedge write_clk or negedge rst_n)
     begin
		 if(!rst_n) begin
             for(i=1;i<2**ADDR_WIDTH;i=i+1)
             memory[i] <= 0;
		 end
	     else if(write_allow) begin
		     memory[write_addr] <=  write_data;
		 end 
	end

 always @(posedge read_clk)
     begin
	     if(read_allow)
		     read_data <= memory[read_addr]; 
	end

endmodule
 