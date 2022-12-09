//-------------------------------------------------------------------------
// 
//
// Filename         : pq_buffer.v
// Author           : 
// Release version  : 1.0
// Release date     : 2020-08-08
// Description      :
//
//-------------------------------------------------------------------------

module pq_buffer
#(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4
)
(
    clk                     ,
    rd_en1                  ,
    rd_en2                  ,
    wr_en1                  ,
    wr_en2                  ,
    ctrl                    ,       //buffer select
    clear                   ,
    din1                    ,
    din2                    ,
    rd_addr1                ,
    rd_addr2                ,
    wr_addr1                ,
    wr_addr2                ,
    dout1                   ,
    dout2
);

input                  clk     ;
input                  rd_en1  ;
input                  rd_en2  ;
input                  wr_en1  ;
input                  wr_en2  ;
input                  ctrl    ;
input                  clear   ;
input [ADDR_WIDTH-1:0] rd_addr1;
input [ADDR_WIDTH-1:0] rd_addr2;
input [ADDR_WIDTH-1:0] wr_addr1;
input [ADDR_WIDTH-1:0] wr_addr2;
input [DATA_WIDTH-1:0] din1    ;
input [DATA_WIDTH-1:0] din2    ;
output[DATA_WIDTH-1:0] dout1   ;
output[DATA_WIDTH-1:0] dout2   ;

wire                 bunit1_re;
wire                 bunit2_re;
wire                 bunit1_we;
wire                 bunit2_we;
//bunit_sl 1: bunit1写 bunit1读1;  
//bunit_sl 0: bunit2写 bunit2读1;
reg                  bunit_sl ;   

assign bunit1_re = bunit_sl  ? rd_en1 : rd_en2;
assign bunit2_re = !bunit_sl ? rd_en1 : rd_en2;
assign bunit1_we = clear | (bunit_sl  ? wr_en1 : wr_en2);
assign bunit2_we = clear | (!bunit_sl ? wr_en1 : wr_en2);

// 其实bunit_sl就是ctrl，可以直接用ctrl;
always@(*) begin
    if(ctrl)  
        bunit_sl = 1;
    else      
        bunit_sl = 0;
end

// addr
wire [ADDR_WIDTH-1:0] waddr_b1;
wire [ADDR_WIDTH-1:0] raddr_b1; 
wire [ADDR_WIDTH-1:0] waddr_b2;
wire [ADDR_WIDTH-1:0] raddr_b2; 

assign waddr_b1 = (clear | bunit_sl)  ? wr_addr1 : wr_addr2;
assign waddr_b2 = (clear | !bunit_sl) ? wr_addr1 : wr_addr2;
assign raddr_b1 = bunit_sl  ? rd_addr1 : rd_addr2;
assign raddr_b2 = !bunit_sl ? rd_addr1 : rd_addr2;

// data
wire [DATA_WIDTH-1:0] din_b1 ;
wire [DATA_WIDTH-1:0] din_b2 ;
wire [DATA_WIDTH-1:0] dout_b1;
wire [DATA_WIDTH-1:0] dout_b2;

assign din_b1 = bunit_sl  ? din1 : din2;
assign din_b2 = !bunit_sl ? din1 : din2;

`ifdef FPGA

dp_ram #(
    .RAM_WIDTH   (DATA_WIDTH         ),
    .ADDR_WIDTH  (ADDR_WIDTH         )
) bunit1(
    .write_clk   (clk                ),
    .read_clk    (clk                ),
    .write_allow (bunit1_we          ),
    .read_allow  (bunit1_re          ),
    .write_addr  (waddr_b1           ),
    .read_addr   (raddr_b1           ),
    .write_data  (din_b1             ),
    .read_data   (dout_b1            )
);

dp_ram #(
    .RAM_WIDTH   (DATA_WIDTH         ),
    .ADDR_WIDTH  (ADDR_WIDTH         )
) bunit2(
    .write_clk   (clk                ),
    .read_clk    (clk                ),
    .write_allow (bunit2_we          ),
    .read_allow  (bunit2_re          ),
    .write_addr  (waddr_b2           ),
    .read_addr   (raddr_b2           ),
    .write_data  (din_b2             ),
    .read_data   (dout_b2            )
);
`endif 

`ifdef ASIC
S55DRAM_W32D4096 bunit1(
    QA    (  ),
    QB    (dout_b1  ),
	CLKA  (clk ),
	CLKB  (clk ),
	CENA  (1'b1),
	CENB  (1'b1),
	WENA  (bunit1_we),
	WENB  (~bunit1_re),
	AA    (waddr_b1),
	AB    (raddr_b1),
	DA    (din_b1  ),
	DB    (  )
);

S55DRAM_W32D4096 bunit2(
    QA    (  ),
    QB    (dout_b2  ),
	CLKA  (clk ),
	CLKB  (clk ),
	CENA  (1'b1),
	CENB  (1'b1),
	WENA  (bunit2_we),
	WENB  (~bunit2_re),
	AA    (waddr_b2),
	AB    (raddr_b2),
	DA    (din_b2  ),
	DB    (  )
);
`endif 

assign dout1 = bunit_sl  ? dout_b1 : dout_b2;
assign dout2 = !bunit_sl ? dout_b1 : dout_b2;

endmodule
