module crossbar #(
    parameter FW = 64, //TODO
    parameter P = 7
) (
    // flit
    input  [FW*P-1:0] flit_to_crossbar_all,
    output [P-1:0] flit_out_wr_all,
    output [FW*P-1:0] flit_out_all,
    // sel
    input  [P*P-1:0] grant_outport_all
);

genvar i;
generate
    
    for (i=0; i<P; i=i+1) begin : outport_loop
        
        one_hot_mux #(
            .IN_WIDTH(FW*P),
            .SEL_WIDTH(P)
        )
        crossbar_mux
        (
            .mux_in(flit_to_crossbar_all),
            .mux_out(flit_out_all[(i+1)*FW-1:i*FW]),
            .sel(grant_outport_all[(i+1)*P-1:i*P])
        );

        assign flit_out_wr_all[i] = |grant_outport_all[(i+1)*P-1:i*P];

    end

endgenerate

endmodule