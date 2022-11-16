module inout_port #(
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
    input  [P-1:0] flit_in_wr_all,
    input  [FW*P-1:0] flit_in_all,
    output [FW*P-1:0] flit_to_crossbar_all,
    // credit
    input  [P-1:0] credit_in_all,
    output [P-1:0] credit_out_all,
    // req
    output [P*P-1:0] dest_port_req_all,
    output [P-1:0] outport_available_all,
    // ack
    input  [P*P-1:0] grant_dest_port_all,
    input  [P*P-1:0] grant_outport_all,
    // current node
    input  current_r2,
    input  [P-2:0] current_r1
);

wire [P-1:0] flit_rel_all;
wire [P-1:0] input_port [P-1:0];

genvar i,j;
generate
    
    for (i=0; i<P; i=i+1) begin : inport_loop
        
        for (j=0; j<P; j=j+1) begin
            assign input_port[i][j] = (i == j);
        end

        input_queue #(
            .FW(FW),
            .P(P),
            .B(B),
            .XW(XW),
            .YW(YW),
            .TOPOLOGY(TOPOLOGY)
        )
        the_input_queue
        (
            // system signal
            .clk(clk),
            .rst_n(rst_n),
            // flit
            .flit_in_wr(flit_in_wr_all[i]),
            .flit_in(flit_in_all[(i+1)*FW-1:i*FW]),
            .flit_to_crossbar(flit_to_crossbar_all[(i+1)*FW-1:i*FW]),
            //credit
            .flit_rel(flit_rel_all[i]),
            // req
            .dest_port_req(dest_port_req_all[(i+1)*P-1:i*P]),
            // ack
            .grant_dest_port(grant_dest_port_all[(i+1)*P-1:i*P]),
            // current node
            .current_r2(current_r2),
            .current_r1(current_r1),
            .input_port(input_port[i])
        );

    end

endgenerate

credit_counter #(
    .P(P),
    .B(B)
)
the_credit_counter
(
    // system signal
    .clk(clk),
    .rst_n(rst_n),
    // credit
    .credit_in_all(credit_in_all),
    .credit_out_all(credit_out_all),
    .flit_rel_all(flit_rel_all),
    // req
    .outport_available_all(outport_available_all),
    // ack
    .grant_outport_all(grant_outport_all)
);


endmodule