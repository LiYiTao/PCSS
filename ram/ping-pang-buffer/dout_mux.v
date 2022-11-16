//-------------------------------------------------------------------------
// 
//
// Filename         : dout_mux.v
// Author           : huyn
// Release version  : 1.0
// Release date     : 2022-10-20
// Description      :
//
//-------------------------------------------------------------------------
module dout_mux
#(
    parameter DATA_WIDTH = 8
)
(
    din1                      ,
    din2                      ,
    sl_dout                   ,
    dout
);

input [DATA_WIDTH-1:0] din1   ;
input [DATA_WIDTH-1:0] din2   ;
input                  sl_dout;
output[DATA_WIDTH-1:0] dout   ;

reg   [DATA_WIDTH-1:0] dout   ;

//output selsct
//sl_dout 0: din1, 1: din2
always@(sl_dout or din1 or din2) begin
    if(!sl_dout)        
        dout = din1;
    else 
        dout = din2;
end

endmodule