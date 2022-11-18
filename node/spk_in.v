//-------------------------------------------------------------------------
// 
//
// Filename         : Spk_in.v
// Author           : 
// Release version  : 1.0
// Release date     : 2022-10-18
// Description      :
//
//-------------------------------------------------------------------------

module spk_in
#(
    parameter B = 4,
    parameter FW = 59,          // flit width
    parameter FTW = 3,          // flit type width
    parameter SW = 24           // spk width, (x,y,z)
) (
    // port list
    input 	                   clk_spk_in,
    input 	                   rst_n,
    // node top
    input   [FW-1:0]           flit_in,
    input                      flit_in_wr,
    output                     credit_out,
    // config
    input 	                   config_spk_in_credit,
    output 	                   spk_in_config_we,
    output 	[FW-1:0]           spk_in_config_wdata,
    // axon
    input 	                   axon_busy,
    output 	                   spk_in_axon_vld,
    output 	[SW -1:0]          spk_in_axon_data,
    output 	[FTW -1:0]         spk_in_axon_type
);

wire spk_in_push;
wire [FW-1:0] spk_in_push_data;
wire spk_in_pop;
wire [FW-1:0] spk_in_pop_data;
wire spk_in_fifo_empty;

flit_Recv
#(
    // parameter
    .FW                         ( FW          ), 
    .FTW                        ( FTW         )
)
the_flit_recv
(
    // port list
    .clk                        ( clk_spk_in            ),          
    .rst_n                      ( rst_n                 ),         
    // aer_in,       
    .flit_in_wr                 ( flit_in_wr            ),       
    .flit_in                    ( flit_in               ),
    .credit_out                 ( credit_out            ), 
    // spk_in_fifo               
    .spk_in_push                ( spk_in_push           ),          
    .spk_in_push_data           ( spk_in_push_data      ),          
    .spk_in_pop                 ( spk_in_pop            )
);



data_fifo
#(
    //parameter
    .DATA_WIDTH                  ( FW ),
    .ADDR_WIDTH                  ( B )
)
spk_in_fifo
(
    .clk                         ( clk_spk_in           ),
    .rst_n                       ( rst_n                ),
    .wr_en                       ( spk_in_push          ),
    .rd_en                       ( spk_in_pop           ),
    .din                         ( spk_in_push_data     ),
    .dout                        ( spk_in_pop_data      ),
    .almost_full                 (     ),
    .empty                       ( spk_in_fifo_empty    )
);

flit_Anls
#(
    // parameter
    .FW                          ( FW ),
    .FTW                         ( FTW ),
    .SW                          ( SW )
)
the_flit_Anls
(
    // port list
    .clk                         ( clk_spk_in            ),
    .rst_n                       ( rst_n                 ),
    // Axon
    .axon_busy                   ( axon_busy             ),
    .spk_in_axon_vld             ( spk_in_axon_vld       ),
    .spk_in_axon_data            ( spk_in_axon_data      ),
    .spk_in_axon_type            ( spk_in_axon_type      ),
    // config
    .config_spk_in_credit        ( config_spk_in_credit  ),
    .spk_in_config_we            ( spk_in_config_we      ),
    .spk_in_config_wdata         ( spk_in_config_wdata   ),
    // flit_fifo
    .spk_in_pop                  ( spk_in_pop            ),
    .spk_in_pop_data             ( spk_in_pop_data       ),
    .spk_in_fifo_empty           ( spk_in_fifo_empty     )
);

endmodule

// flit in recv
module flit_Recv #(
    parameter FW = 37 , // flit width
    parameter FTW = 2   // flit type width
) (
    // port list
    input  clk ,
    input  rst_n ,
    // aer_in
    input  flit_in_wr ,
    input  [FW-1:0] flit_in ,
    output credit_out ,
    // spk_in_fifo
    output spk_in_push,
    output [FW-1:0] spk_in_push_data,
    input  spk_in_pop
);

// push
assign spk_in_push       = flit_in_wr;
assign spk_in_push_data  = flit_in[FW-1:0];

// credit
assign credit_out = spk_in_pop;

endmodule


// flit in anls
module flit_Anls #(
    // parameter
    parameter FW = 59 , // flit width
    parameter FTW = 3 , // flit type width
    parameter SW = 24   // spk width, (x,y,z), data
) (
    // port list
    input  clk ,
    input  rst_n ,
    // Axon
    input  axon_busy ,
    output spk_in_axon_vld ,
    output reg [SW-1:0] spk_in_axon_data ,
    output reg [FTW-1:0] spk_in_axon_type,
    // config
    input  config_spk_in_credit ,
    output spk_in_config_we ,
    output reg [FW-1:0] spk_in_config_wdata ,
    // flit_fifo
    output spk_in_pop ,
    input  [FW-1:0] spk_in_pop_data ,
    input  spk_in_fifo_empty
);

// flit type
localparam      SPIKE         = 3'b000;
localparam      DATA          = 3'b001;
localparam      DATA_END      = 3'b010;
localparam      WRITE         = 3'b110;
localparam      READ          = 3'b111;


// FSM
localparam      IDLE          = 3'd0;
localparam      S_WAIT        = 3'd1;
localparam      S_AXON        = 3'd2;
localparam      S_CONFIG      = 3'd3;

reg  credit_cnt;
wire send_axon;
wire send_config;

// current and next state
reg     [2:0]   cs;
reg     [2:0]   ns;

// generate current state
always @(posedge clk or negedge rst_n) begin
    if (rst_n == 1'b0) begin
        cs <= IDLE;
    end
    else begin
        cs <= ns;
    end
end

// generate next state
always @(*) begin
    case(cs)
        IDLE : begin
            if (!spk_in_fifo_empty) begin
                ns = S_WAIT;
            end
            else begin
                ns = IDLE;
            end
        end
        S_WAIT : begin
            if (send_axon && !axon_busy) begin
                ns = S_AXON;
            end
            else if (send_config && credit_cnt) begin
                ns = S_CONFIG;
            end
            else begin
                ns = S_WAIT;
            end
        end
        S_AXON : begin
            if (spk_in_fifo_empty) begin
                ns = IDLE;
            end
            else begin
                ns = S_WAIT;
            end
        end
        S_CONFIG : begin
            if (spk_in_fifo_empty) begin
                ns = IDLE;
            end
            else begin
                ns = S_WAIT;
            end
        end
        default : begin // IDLE
            ns = IDLE;
        end
    endcase
end
//generate output
assign spk_in_pop = (ns == S_WAIT) && (cs != S_WAIT);
assign spk_in_axon_vld  = (cs == S_AXON);
assign spk_in_config_we = (cs == S_CONFIG);

assign send_axon   = ((spk_in_pop_data[FW-1:FW-FTW] == SPIKE) 
                   || (spk_in_pop_data[FW-1:FW-FTW] == DATA)
                   || (spk_in_pop_data[FW-1:FW-FTW] == DATA_END));
assign send_config = ((spk_in_pop_data[FW-1:FW-FTW] == WRITE) 
                   || (spk_in_pop_data[FW-1:FW-FTW] == READ));

always @(posedge clk or negedge rst_n) begin
    if (rst_n == 1'b0) begin
        spk_in_axon_type    <= {FTW{1'b0}};
        spk_in_axon_data    <= {SW{1'b0}};
        spk_in_config_wdata <= {FW{1'b0}};
    end
    else begin
        case (cs)
            IDLE : begin
                // free
            end
            S_WAIT : begin
                if (ns == S_AXON) begin
                    spk_in_axon_type    <= spk_in_pop_data[FW-1:FW-FTW];
                    spk_in_axon_data    <= spk_in_pop_data[SW-1:0];
                end
                else if (ns == S_CONFIG) begin
                    spk_in_config_wdata <= spk_in_pop_data[FW-1:0];
                end
            end
            S_AXON : begin
                // free
            end
            S_CONFIG : begin
                // free
            end
            default : begin
                spk_in_axon_type    <= {FTW{1'b0}};
                spk_in_axon_data    <= {SW{1'b0}};
                spk_in_config_wdata <= {FW{1'b0}};
            end
        endcase
    end
end

// credit cnt
always @(posedge clk or negedge rst_n) begin
    if (rst_n == 1'b0) begin
        credit_cnt <= 1'b1;
    end
    else if (config_spk_in_credit) begin
        credit_cnt <= 1'b1; 
    end
    else if (spk_in_config_we) begin
        credit_cnt <= 1'b0;
    end
end

endmodule
