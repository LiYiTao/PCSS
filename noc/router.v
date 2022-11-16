module router #(
    parameter FW = 36, //TODO
    parameter P = 7,
    parameter B = 4,
    parameter XW = 4,
    parameter YW = 4,
    parameter TOPOLOGY = "HIER"
) (
    // System Sginals
    input  clk,
    input  rst_n,
    // flit
    input  [P-1:0] flit_in_wr_all,
    input  [FW*P-1:0] flit_in_all,
    output [P-1:0] flit_out_wr_all,
    output [FW*P-1:0] flit_out_all,
    // credit
    input  [P-1:0] credit_in_all,
    output [P-1:0] credit_out_all,
    // current node
    input  current_r2, // current is r2
    input  [P-1:0] current_r1
);

wire [FW*P-1:0] flit_to_crossbar_all;
wire [P*P-1:0] dest_port_req_all;
wire [P-1:0] outport_available_all;
wire [P*P-1:0] grant_dest_port_all;
wire [P*P-1:0] grant_outport_all;

// inout_port
inout_port #(
    .FW(FW),
    .P(P),
    .B(B),
    .XW(XW),
    .YW(YW),
    .TOPOLOGY(TOPOLOGY)
)
the_inout_port
(
    // system signal
    .clk(clk),
    .rst_n(rst_n),
    // flit
    .flit_in_wr_all(flit_in_wr_all),
    .flit_in_all(flit_in_all),
    .flit_to_crossbar_all(flit_to_crossbar_all),
    // credit
    .credit_in_all(credit_in_all),
    .credit_out_all(credit_out_all),
    // req
    .dest_port_req_all(dest_port_req_all),
    .outport_available_all(outport_available_all),
    // ack
    .grant_dest_port_all(grant_dest_port_all),
    .grant_outport_all(grant_outport_all),
    // current node
    .current_r2(current_r2),
    .current_r1(current_r1)
);

// sw_alloc
sw_alloc #(
    .P(P)
)
the_sw_alloc
(
    // system signals
    .clk(clk),
    .rst_n(rst_n),
    // req
    .dest_port_req_all(dest_port_req_all),
    .outport_available_all(outport_available_all),
    // ack
    .grant_dest_port_all(grant_dest_port_all),
    .grant_outport_all(grant_outport_all)
);

// crossbar
crossbar #(
    .FW(FW),
    .P(P)
)
the_crossbar
(
    // flit
    .flit_to_crossbar_all(flit_to_crossbar_all),
    .flit_out_wr_all(flit_out_wr_all),
    .flit_out_all(flit_out_all),
    // sel
    .grant_outport_all(grant_outport_all)
);

endmodule
