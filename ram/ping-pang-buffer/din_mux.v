//-------------------------------------------------------------------------
// 
//
// Filename         : din_mux.v
// Author           : 
// Release version  : 1.0
// Release date     : 2022-10-20
// Description      :
//
//-------------------------------------------------------------------------


module din_mux
#(
    parameter DATA_WIDTH = 8
)
(
    din                        ,
    sl_din                     ,
    dout1                      ,
    dout2
);

input  [DATA_WIDTH-1:0]  din   ;
input                    sl_din;
output [DATA_WIDTH-1:0]  dout1 ;
output [DATA_WIDTH-1:0]  dout2 ;

reg    [DATA_WIDTH-1:0]  dout1 ;
reg    [DATA_WIDTH-1:0]  dout2 ;

//input select:
//sl_din 1: din写入bunit1  0:din写入bunit2;
always @(sl_din or din) begin
    if(sl_din) begin
        dout1 = din;
        dout2 = 'dx;
    end
    else begin
        dout1 = 'dx;
        dout2 = din;
    end
end

endmodule