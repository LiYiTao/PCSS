//---------------------------clk_spk_out----------------------------------------------
// 
//
// Filename         : Spk_out.v
// Author           : 
// Release version  : 1.0
// Release date     : 2022-10-18
// Description      :
//
//-------------------------------------------------------------------------

module spk_out #(
    parameter B = 4,
    parameter FW  = 59, // flit width
    parameter FTW =  3, // flit type width
    parameter SW = 24,  // spk width, (x,y,z)
    parameter DST_WIDTH = 21, // x+y+r2+r1+flg
    parameter DST_DEPTH = 4   // dst node depth
) (
    // port list
    input  clk_spk_out,
    input  rst_n,
    // node top
    input  credit_in,
    output flit_out_wr,
    output [FW-1:0] flit_out,
    // soma
    input  soma_spk_out_fire,
    // config
    input  config_spk_out_we,
    input  [FW-1:0] config_spk_out_wdata,
    input  [SW-1:0] config_spk_out_neuid,
    output spk_out_config_full,
    input  config_spk_out_dst_we,
    input  [DST_DEPTH-1:0] config_spk_out_dst_waddr,
    input  [DST_WIDTH-1:0] config_spk_out_dst_wdata,
    input  config_spk_out_dst_re,
    input  [DST_DEPTH-1:0] config_spk_out_dst_raddr,
    input  [DST_WIDTH-1:0] config_spk_out_dst_rdata
);

wire spk_out_push;
wire [FW-1:0] spk_out_push_data;
wire spk_out_fifo_full;
wire spk_out_pop;
wire [FW-1:0] spk_out_pop_data;

data_Recv #(
    .FW                     (FW),
    .SW                     (SW)
)
u_data_Recv
(
    // config
    .config_spk_out_we       (config_spk_out_we   ),
    .config_spk_out_wdata    (config_spk_out_wdata),
    .config_spk_out_neuid    (config_spk_out_neuid),
    .spk_out_config_full     (spk_out_config_full ),
    // soma
    .soma_spk_out_fire       (soma_spk_out_fire),
    // spk_out_fifo
    .spk_out_push            (spk_out_push),
    .spk_out_push_data       (spk_out_push_data),
    .spk_out_fifo_full       (spk_out_fifo_full)
);

flit_send
#(
   // parameter
    .B                      (B), 
    .FW                     (FW),
    .FTW                    (FTW),
    .DST_WIDTH              (DST_WIDTH),
    .DST_DEPTH              (DST_DEPTH)
)
u_flit_send
(
    // port list
    .clk                    (clk_spk_out),
    .rst_n                  (rst_n),
    // ni
    .credit_in              (credit_in     ),
    .flit_out_wr            (flit_out_wr   ),
    .flit_out               (flit_out      ),
    // config
    .config_spk_out_dst_we   (config_spk_out_dst_we),
    .config_spk_out_dst_waddr(config_spk_out_dst_waddr),
    .config_spk_out_dst_wdata(config_spk_out_dst_wdata),
    .config_spk_out_dst_re   (config_spk_out_dst_re),
    .config_spk_out_dst_raddr(config_spk_out_dst_raddr),
    .config_spk_out_dst_rdata(config_spk_out_dst_rdata),
    // aer_out_fifo
    .spk_out_pop            (spk_out_pop),
    .spk_out_pop_data       (spk_out_pop_data),
    .spk_out_fifo_empty     (spk_out_fifo_empty)
);

data_fifo
#(
    //parameter
    .DATA_WIDTH                  ( FW ),
    .ADDR_WIDTH                  ( B ) // TODO
)
spk_out_fifo
(
    .clk                         ( clk_spk_out          ),
    .rst_n                       ( rst_n                ),
    .wr_en                       ( spk_out_push         ),
    .rd_en                       ( spk_out_pop          ),
    .din                         ( spk_out_push_data    ),
    .dout                        ( spk_out_pop_data     ),
    .almost_full                 ( spk_out_fifo_full    ),
    .empty                       ( spk_out_fifo_empty   )
);

endmodule

// data recv
module data_Recv #(
    parameter FW  = 59, // flit width
    parameter FTW = 3, // flit type width
    parameter SW = 24  // spk width, (x,y,z)
) (
    // config 
    input  config_spk_out_we,
    input  [FW-1:0] config_spk_out_wdata,
    input  [SW-1:0] config_spk_out_neuid,
    output spk_out_config_full,
    // soma
    input  soma_spk_out_fire,
    // spk_out_fifo
    input  spk_out_fifo_full,
    output spk_out_push,
    output [FW-1:0] spk_out_push_data
);

// flit type
localparam      SPIKE         = 3'b000;
localparam      DATA          = 3'b001;
localparam      DATA_END      = 3'b010;
localparam      WRITE         = 3'b110;
localparam      READ          = 3'b111;

//generate output
assign spk_out_push        = soma_spk_out_fire | config_spk_out_we;
assign spk_out_push_data   = soma_spk_out_fire ? {SPIKE,{(FW-SW-FTW){1'b0}}, config_spk_out_neuid} : config_spk_out_wdata;
assign spk_out_config_full = spk_out_fifo_full;


endmodule


// filt send
module flit_send
#(
    parameter B = 4,
    parameter FW  = 59, // flit width
    parameter FTW =  3, // flit type width
    parameter DST_WIDTH = 21, // x+y+r2+r1+flg
    parameter DST_DEPTH = 4 // dst node depth
)
(
    // port list
    input  clk,
    input  rst_n,
    // node top
    input  credit_in,
    output flit_out_wr,
    output reg [FW-1:0] flit_out,
    // config
    input  config_spk_out_dst_we,
    input  [DST_DEPTH-1:0] config_spk_out_dst_waddr,
    input  [DST_WIDTH-1:0] config_spk_out_dst_wdata,
    input  config_spk_out_dst_re,
    input  [DST_DEPTH-1:0] config_spk_out_dst_raddr,
    input  [DST_WIDTH-1:0] config_spk_out_dst_rdata,
    // spk_out_fifo
    output spk_out_pop,
    input  [FW-1:0] spk_out_pop_data,
    input  spk_out_fifo_empty
);

// TODO start of router bit in flit
localparam      R_FLG         = 36;

// flit type
localparam      SPIKE         = 3'b000;
localparam      DATA          = 3'b001;
localparam      DATA_END      = 3'b010;
localparam      WRITE         = 3'b110;
localparam      READ          = 3'b111;

// send FSM
localparam     S_IDLE         = 2'd0;
localparam     S_WAIT         = 2'd1;
localparam     S_SEND         = 2'd2;

wire dst_mem_re;
reg  [DST_DEPTH-1:0] dst_mem_raddr;
wire [DST_WIDTH-1:0] dst_mem_rdata;
wire dst_flag;
wire router_available;

// current and next state
reg [1:0]  cs;
reg [1:0]  ns;

// generate current state
always @(posedge clk or negedge rst_n) begin
    if (rst_n == 1'b0) begin
        cs <= S_IDLE;
    end
    else begin
        cs <= ns;
    end
end

// generate next state
always @(*) begin
    case(cs)
        S_IDLE : begin
            if (!spk_out_fifo_empty) begin
                ns = S_WAIT;
            end
            else begin
                ns = S_IDLE;
            end
        end
        S_WAIT : begin
            if (router_available) begin
                ns = S_SEND;
            end
            else begin
                ns = S_WAIT;
            end
        end
        S_SEND : begin
            if(!dst_flag && spk_out_fifo_empty) begin
                ns = S_IDLE;
            end
            else begin
                ns = S_WAIT;
            end
        end
        default : begin
            ns = S_IDLE;
        end
    endcase
end

//generate output
assign spk_out_pop = ((cs == S_IDLE) && (ns == S_WAIT)) || 
                     ((cs == S_SEND) && (!dst_flag && !spk_out_fifo_empty));

assign dst_mem_re  = (cs != S_WAIT) && (ns == S_WAIT);
assign dst_flag = dst_mem_rdata[0];
assign config_spk_out_dst_rdata = dst_mem_rdata;
assign flit_out_wr = (cs == S_SEND);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        flit_out <= {FW{1'b0}};
        dst_mem_raddr <= {(DST_DEPTH){1'b0}};
    end
    else begin
        case (cs)
            S_IDLE : begin
                if (ns == S_WAIT) begin
                    dst_mem_raddr <= {(DST_DEPTH){1'b0}};
                end
            end
            S_WAIT : begin
                if (ns != S_WAIT) begin
                    if (spk_out_pop_data[FW-1:FW-FTW] == READ) begin
                        flit_out <= spk_out_pop_data;
                    end
                    else begin
                        flit_out[FW-1:FW-FTW] <= spk_out_pop_data[FW-1:FW-FTW]; // type
                        flit_out[FW-FTW-1:R_FLG] <= dst_mem_rdata; // dst
                        flit_out[R_FLG-1:0] <= spk_out_pop_data[R_FLG-1:0]; // data
                    end
                    dst_mem_raddr <= dst_mem_raddr + 1'b1;
                end
            end
            S_SEND : begin
                if (!dst_flag && !spk_out_fifo_empty) begin
                    dst_mem_raddr <= {(DST_DEPTH){1'b0}};
                end
            end
            default : begin
                flit_out <= {FW{1'b0}};
                dst_mem_raddr <= {(DST_DEPTH){1'b0}};
            end
        endcase
    end
end

// dst ram
fifo_ram #(
    .DATA_WIDTH(DST_WIDTH),
    .ADDR_WIDTH(DST_DEPTH)
)
dst_mem
(
    .clk(clk),
    .wr_en(config_spk_out_dst_we),
    .rd_en((dst_mem_re || config_spk_out_dst_re)),
    .wr_data(config_spk_out_dst_wdata),
    .wr_addr(config_spk_out_dst_waddr),
    .rd_addr((dst_mem_re ? dst_mem_raddr : config_spk_out_dst_raddr)),
    .rd_data(dst_mem_rdata)
);

// credit count
reg  [B-1:0] credit_counter_reg;
wire increase;
wire decrease;

assign increase = credit_in;
assign decrease = flit_out_wr; // TODO
assign router_available = credit_counter_reg > 0;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        credit_counter_reg <= {B{1'b1}};
    end
    else if (increase && ~decrease) begin
        credit_counter_reg <= credit_counter_reg + 1'b1;
    end
    else if (~increase && decrease) begin
        credit_counter_reg <= credit_counter_reg - 1'b1;
    end
end

`ifdef debug

    always @(posedge clk) begin
        if (rst_n) begin
            if ((credit_counter_reg == {B{1'b0}}) && ~increase[i] && decrease) begin
                $display("%t: ERROR: Attempt to send flit to full ni: %m",$time);
            end
            if ((credit_counter_reg == {B{1'b1}}) && increase[i] && ~decrease) begin
                $display("%t: ERROR: unexpected credit recived for empty ni: %m",$time);
            end
        end
    end

`endif

endmodule