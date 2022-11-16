module chip_connection #(
    parameter FW = 64, // TODO
    parameter B = 4,
    parameter CONNECT = 2
) (
    // system signal
    input  clk,
    input  rst_n,
    // noc
    input  [CONNECT-1:0] flit_in_wr_noc,
    input  [FW*CONNECT-1:0] flit_in_noc,
    output [CONNECT-1:0] flit_out_wr_noc,
    output [FW*CONNECT-1:0] flit_out_noc,
    input  [CONNECT-1:0] credit_in_noc,
    output [CONNECT-1:0] credit_out_noc,
    // chip
    input  data_in_wr,
    input  [FW+log2(CONNECT)-1:0] data_in,
    output data_out_wr,
    output [FW+log2(CONNECT)-1:0] data_out,
    // inf full
    input  send_fifo_full,
    output [CONNECT-1:0] connect_available
);

function integer log2;
    input integer number; begin
        log2=0;
        while(2**log2<number) begin    
            log2=log2+1;    
        end
    end
endfunction // log2 

mux_in #(
    .FW(FW),
    .B(B),
    .CONNECT(CONNECT)
)
the_mux_in
(
    // system signal
    .clk(clk),
    .rst_n(rst_n),
    // noc
    .flit_in_wr_noc(flit_in_wr_noc),
    .flit_in_noc(flit_in_noc),
    .credit_out_noc(credit_out_noc),
    // chip
    .data_in_wr(data_in_wr),
    .data_in(data_in),
    .connect_available(connect_available)
);

mux_out #(
    .FW(FW),
    .B(B),
    .CONNECT(CONNECT)
)
the_mux_out
(
    // system signal
    .clk(clk),
    .rst_n(rst_n),
    // noc
    .flit_out_wr_noc(flit_out_wr_noc),
    .flit_out_noc(flit_out_noc),
    .credit_in_noc(credit_in_noc),
    // chip
    .data_out_wr(data_out_wr),
    .data_out(data_out),
    .send_fifo_full(send_fifo_full)
);

endmodule //chip_connection

module mux_out #(
    parameter FW = 64,
    parameter B = 4,
    parameter CONNECT = 2
) (
    // system signal
    input  clk,
    input  rst_n,
    // noc
    input  [CONNECT-1:0] flit_out_wr_noc,
    input  [FW*CONNECT-1:0] flit_out_noc,
    output [CONNECT-1:0] credit_in_noc,
    // chip
    output reg data_out_wr,
    output [FW+log2(CONNECT)-1:0] data_out,
    input  send_fifo_full
);

function integer log2;
    input integer number; begin
        log2=0;
        while(2**log2<number) begin    
            log2=log2+1;    
        end
    end
endfunction // log2 

wire [CONNECT-1:0] buffer_not_empty;
wire [CONNECT-1:0] mux_out_buffer_grant;
wire [FW-1:0] mux_out_buffer_data [CONNECT-1:0];
wire [log2(CONNECT)-1:0] sel;

genvar i;
generate
    
    for (i=0; i<CONNECT; i=i+1) begin : out_connect
        
        // flit_buffer
        flit_buffer #(
            .DATA_WIDTH(FW),
            .ADDR_WIDTH(B)
        )
        mux_out_buffer
        (
            .clk(clk),
            .rst_n(rst_n),
            .in(flit_out_noc[FW*(i+1)-1:FW*i]),
            .out(mux_out_buffer_data[i]),
            .wr_en(flit_out_wr_noc[i]),
            .rd_en(mux_out_buffer_grant[i] & ~send_fifo_full),
            .buffer_not_empty(buffer_not_empty[i])
        );

        // credit
        assign credit_in_noc[i] = mux_out_buffer_grant[i] & ~send_fifo_full;
    end

endgenerate

// data out
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        data_out_wr <= 1'b0;
    end
    else begin
        data_out_wr <= |mux_out_buffer_grant & ~send_fifo_full;
    end
end
assign data_out = {sel, mux_out_buffer_data[sel]};

// arbiter
arbiter #(
    .ARBITER_WIDTH(CONNECT)
)
connect_arbiter
(
    .clk(clk),
    .reset(!rst_n),
    .request(buffer_not_empty),
    .grant(mux_out_buffer_grant),
    .any_grant()
);

// select
one_hot_to_bin #(
    .ONE_HOT_WIDTH(CONNECT)
)
connect_sel
(
    .one_hot_code(mux_out_buffer_grant),
    .bin_code(sel)
);
    
endmodule

module mux_in #(
    parameter FW = 64,
    parameter B = 4,
    parameter CONNECT = 2
) (
    // system signal
    input  clk,
    input  rst_n,
    // noc
    output reg [CONNECT-1:0] flit_in_wr_noc,
    output [FW*CONNECT-1:0] flit_in_noc,
    input  [CONNECT-1:0] credit_out_noc,
    // chip
    input  data_in_wr,
    input  [FW+log2(CONNECT)-1:0] data_in,
    output [CONNECT-1:0] connect_available
);
    
function integer log2;
    input integer number; begin
        log2=0;
        while(2**log2<number) begin    
            log2=log2+1;    
        end
    end
endfunction // log2 

wire [CONNECT-1:0] buffer_not_empty;
wire [log2(CONNECT)-1:0] sel;
wire [CONNECT-1:0] sel_one_hot;
reg  [B-1:0] credit_counter_reg [CONNECT-1:0];
wire [CONNECT-1:0] increase;
wire [CONNECT-1:0] decrease;

// credit noc ctrl
assign increase = credit_out_noc;
assign decrease = flit_in_wr_noc;

genvar i;
generate
    
    assign sel = data_in[FW+log2(CONNECT)-1:FW-1];

    for (i=0; i<CONNECT; i=i+1) begin : in_connect
        
        // flit_buffer
        flit_buffer #(
            .DATA_WIDTH(FW),
            .ADDR_WIDTH(B)
        )
        mux_in_buffer
        (
            .clk(clk),
            .rst_n(rst_n),
            .in(data_in[FW-1:0]),
            .out(flit_in_noc[FW*(i+1)-1:FW*i]),
            .wr_en(data_in_wr & sel_one_hot[i]),
            .rd_en(buffer_not_empty[i] & connect_available[i]),
            .buffer_not_empty(buffer_not_empty[i])
        );

        // credit noc
        assign connect_available[i] = credit_counter_reg[i] > 0;
        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                credit_counter_reg[i] <= {B{1'b1}};
            end
            else if (increase[i] && ~decrease[i]) begin
                credit_counter_reg[i] <= credit_counter_reg[i] + 1'b1;
            end
            else if (~increase[i] && decrease[i]) begin
                credit_counter_reg[i] <= credit_counter_reg[i] - 1'b1;
            end
        end

        `ifdef debug

            always @(posedge clk) begin
                if (rst_n) begin
                    if ((credit_counter_reg[i] == {B{1'b0}}) && ~increase[i] && decrease[i]) begin
                        $display("%t: ERROR: Attempt to send flit to full mux_in_buffer[%d]: %m",$time,i);
                    end
                    if ((credit_counter_reg[i] == {B{1'b1}}) && increase[i] && ~decrease[i]) begin
                        $display("%t: ERROR: unexpected credit recived for empty mux_in_buffer[%d]: %m",$time,i);
                    end
                end
            end

        `endif
    end

endgenerate

// flit in
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        flit_in_wr_noc <= {CONNECT{1'b0}};
    end
    else begin
        flit_in_wr_noc <= buffer_not_empty & connect_available;
    end
end

// select
bin_to_one_hot #(
    .BIN_WIDTH(log2(CONNECT))
)
connect_sel
(
    .bin_code(sel),
    .one_hot_code(sel_one_hot)
);

endmodule

