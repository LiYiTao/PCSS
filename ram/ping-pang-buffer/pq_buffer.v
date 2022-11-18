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
    rst_n                   ,
    rd_en                   ,      
    wr_en                   ,      
    ctrl                    ,       //buffer select
    din                     ,
    rd_addr                 ,
    wr_addr                 ,
    dout
);

input                  clk    ;
input                  rst_n  ;
input                  rd_en  ;
input                  wr_en  ;
input                  ctrl   ;
input [ADDR_WIDTH-1:0] rd_addr;
input [ADDR_WIDTH-1:0] wr_addr;
input [DATA_WIDTH-1:0] din    ;
output[DATA_WIDTH-1:0] dout   ;

wire                 bunit1_re;
wire                 bunit2_re;
wire                 bunit1_we;
wire                 bunit2_we;
//bunit_sl 1: bunit1写 bunit2读;  
//bunit_sl 0: bunit1读 bunit2写;
reg                  bunit_sl ;   

assign bunit1_re = rd_en & (!bunit_sl);
assign bunit2_re = rd_en & (bunit_sl );
assign bunit1_we = wr_en & (bunit_sl );
assign bunit2_we = wr_en & (!bunit_sl);

// 其实bunit_sl就是ctrl，可以直接用ctrl;
always@(*) begin
    if(ctrl)  
        bunit_sl = 1;
    else      
        bunit_sl = 0;
end

reg                   bunit_sl_lat1;
reg                   bunit_sl_lat2;
always@(posedge clk or negedge rst_n) begin
    if(!rst_n)  begin 
        bunit_sl_lat1 <= 1'b0;
        bunit_sl_lat2 <= 1'b0;
    end
    else       begin
        bunit_sl_lat1 <= bunit_sl     ;
        bunit_sl_lat2 <= bunit_sl_lat1;
    end
end

// addr
wire [ADDR_WIDTH-1:0] addr_b1; 
wire [ADDR_WIDTH-1:0] addr_b2;

assign addr_b1 = bunit_sl ? wr_addr : rd_addr;
assign addr_b2 = bunit_sl ? rd_addr : wr_addr;

//
wire [DATA_WIDTH-1:0] din_b1 ;
wire [DATA_WIDTH-1:0] din_b2 ;
wire [DATA_WIDTH-1:0] dout_b1;
wire [DATA_WIDTH-1:0] dout_b2;

din_mux #(
    .DATA_WIDTH(DATA_WIDTH)
)
dinmux
(
    .din       (din                ),
    .sl_din    (bunit_sl           ),
    .dout1     (din_b1             ),
    .dout2     (din_b2             )
); 

sp_ram #(
    .RAM_WIDTH  (DATA_WIDTH         ),
    .ADDR_WIDTH (ADDR_WIDTH         )
) bunit1(
    .clk       (clk                ),
    .wr_en     (bunit1_we          ),
    .rd_en     (bunit1_re          ),
    .addr      (addr_b1            ),
    .din       (din_b1             ),
    .dout      (dout_b1            )
);

sp_ram #(
    .RAM_WIDTH (DATA_WIDTH         ),
    .ADDR_WIDTH(ADDR_WIDTH         )
) bunit2(
    .clk       (clk                ),
    .wr_en     (bunit2_we          ),
    .rd_en     (bunit2_re          ),
    .addr      (addr_b2            ),
    .din       (din_b2             ),
    .dout      (dout_b2            )
);

dout_mux #(
    .DATA_WIDTH(DATA_WIDTH)
)
doutmux
(
    .din1      (dout_b1            ),
    .din2      (dout_b2            ),
    .sl_dout   (bunit_sl_lat2      ),
    .dout      (dout               )
);

endmodule