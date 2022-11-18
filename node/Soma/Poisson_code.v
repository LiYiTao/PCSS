module Poisson_code #(
    parameter FMW = 12, // TODO
    parameter CNTW = 8,
    parameter VW = 20
) (
    input  [FMW-1:0] n,
    input  [CNTW-1:0] k,
    output [VW-1:0] p
);

assign p = {n,k}; // LUT

endmodule