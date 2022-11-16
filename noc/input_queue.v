module input_queue #(
    parameter FW = 64, //TODO
    parameter P = 7,
    parameter B = 4, // buffer space: flit per port
    parameter XW = 4,
    parameter YW = 4,
    parameter TOPOLOGY = "HIER"
) (
    // system signals
    input  clk,
    input  rst_n,
    // flit
    input  flit_in_wr,
    input  [FW-1:0] flit_in,
    output [FW-1:0] flit_to_crossbar,
    // credit
    output flit_rel,
    // req
    output [P-1:0] dest_port_req,
    // ack
    input  [P-1:0] grant_dest_port,
    // current node
    input  current_r2, // current is r2
    input  [P-2:0] current_r1,
    input  [P-1:0] input_port
);

// TODO start of router bit in flit
localparam R_FLG = 36;
localparam X_FLG = R_FLG + 12;

wire inport_not_empty;
wire rd_en;
wire [XW-1:0] delta_x;
wire [YW-1:0] delta_y;
wire [XW-1:0] delta_x_next;
wire [YW-1:0] delta_y_next;
wire [P-2:0] dest_port_r1;
wire [P-2:0] dest_port_r2;
wire [P-1:0] dest_from_fifo;
wire [P-1:0] dest_from_engine;
wire [P-1:0] dest_port_cand;
wire [FW-1:0] flit_from_buffer;
wire [FW-1:0] flit_to_buffer;

assign rd_en = inport_not_empty && (!hold);
assign flit_rel = rd_en;
// TODO
assign delta_x = flit_in[XW+X_FLG-1:X_FLG];
assign delta_y = flit_in[XW+YW+X_FLG-1:XW+X_FLG];
assign dest_port_r1 = flit_in[R_FLG+P-2:R_FLG];
assign dest_port_r2 = flit_in[R_FLG+2*(P-1)-1:R_FLG+P-1];

generate
    if (TOPOLOGY == "MESH") begin
        assign flit_to_buffer = {flit_in[FW-1:X_FLG+XW+YW], delta_y_next, delta_x_next, flit_in[X_FLG-1:0]};
    end
    else begin
        assign flit_to_buffer = flit_in;
    end
endgenerate

// route_engine
route_engine #(
    .P(P),
    .XW(XW),
    .YW(YW),
    .TOPOLOGY(TOPOLOGY)
)
the_route_engine
(
    // current node
    .current_r2(current_r2),
    .current_r1(current_r1),
    .input_port(input_port),
    // dest node
    .delta_x(delta_x),
    .delta_y(delta_y),
    .delta_x_next(delta_x_next),
    .delta_y_next(delta_y_next),
    .dest_r1(dest_port_r1),
    .dest_r2(dest_port_r2),
    .dest_port(dest_from_engine)
);

// flit_buffer
flit_buffer #(
    .DATA_WIDTH(FW),
    .ADDR_WIDTH(B)
)
the_flit_buffer
(
    .clk(clk),
    .rst_n(rst_n),
    .in(flit_to_buffer),
    .out(flit_from_buffer),
    .wr_en(flit_in_wr),
    .rd_en(rd_en),
    .buffer_not_empty(inport_not_empty)
);

// dest_fifo
flit_buffer #(
    .DATA_WIDTH(FW),
    .ADDR_WIDTH(B)
)
dest_fifo
(
    .clk(clk),
    .rst_n(rst_n),
    .in(dest_from_engine),
    .out(dest_from_fifo),
    .wr_en(flit_in_wr),
    .rd_en(rd_en),
    .buffer_not_empty() // control in flit buffer
);

// release generate
rel_gen #(
    .FW(FW),
    .P(P),
    .X_FLG(X_FLG),
    .TOPOLOGY(TOPOLOGY)
)
the_rel_gen
(
    .clk(clk),
    .rst_n(rst_n),
    .inport_not_empty(inport_not_empty),
    .grant_dest_port(grant_dest_port),
    .dest_port(dest_from_fifo),
    .dest_port_cand(dest_port_cand),
    .hold(hold), // flit release signal
    .flit_from_buffer(flit_from_buffer),
    .flit_to_crossbar(flit_to_crossbar)
);

// request generate
req_gen #(
    .P(P)
)
the_req_gen
(
    .clk(clk),
    .rst_n(rst_n),
    .hold(hold),
    .dest_port_cand(dest_port_cand),
    .dest_port_req(dest_port_req)
);

endmodule

module req_gen #(
    parameter P = 7
) (
    input  clk,
    input  rst_n,
    input  hold, // flit hold, wait all outport
    input  [P-1:0] dest_port_cand, // dest_port need request
    output [P-1:0] dest_port_req
);

assign dest_port_req = hold ? dest_port_cand : {P{1'b0}};
    
endmodule

module rel_gen #(
    parameter FW = 64,
    parameter P = 7,
    parameter X_FLG = 44,
    parameter TOPOLOGY = "HIER"
) (
    input  clk,
    input  rst_n,
    input  inport_not_empty,
    input  [P-1:0] grant_dest_port, // the outport granted to this inport
    input  [P-1:0] dest_port,
    output reg [P-1:0] dest_port_cand,
    output reg hold, // flit hold
    input  [FW-1:0] flit_from_buffer, // from flit buffer
    output reg [FW-1:0] flit_to_crossbar
);

reg hold_dly;
reg [P-1:0] dest_cand;
reg [FW-1:0] flit_hold;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        hold <= 1'b0;
        hold_dly <= 1'b0;
        dest_cand <= {P{1'b0}};
        flit_hold <= {FW{1'b0}};
    end
    else if (inport_not_empty && !hold) begin // rd_en
        hold <= 1'b1;
    end
    else if (hold && !hold_dly) begin // get dest_port and flit, gen req
        dest_cand <= dest_port;
        // flit update
        flit_hold <= flit_from_buffer;
    end
    else if (|grant_dest_port) begin
        dest_cand <= dest_cand ^ grant_dest_port;
        if (dest_cand ^ grant_dest_port == {P{1'b0}}) begin
            hold <= 1'b0;
        end
    end

    hold_dly <= hold;
end

always @(*) begin
    if (hold && !hold_dly) begin
        dest_port_cand = dest_port;
        // flit update
        flit_to_crossbar = flit_from_buffer;
    end
    else if (|grant_dest_port) begin
        dest_port_cand = dest_cand ^ grant_dest_port;
        flit_to_crossbar = flit_hold;
    end
    else begin
        dest_port_cand = dest_cand;
        flit_to_crossbar = flit_hold;
    end
end

endmodule

