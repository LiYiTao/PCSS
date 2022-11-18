`timescale  1ns/1ps
/*********************************

    multiplexer
    
********************************/
module one_hot_mux #(
        parameter   IN_WIDTH  = 20,
        parameter   SEL_WIDTH = 5, 
        parameter   OUT_WIDTH = IN_WIDTH/SEL_WIDTH

    )
    (
        input [IN_WIDTH-1   :0] mux_in,
        output[OUT_WIDTH-1  :0] mux_out,
        input [SEL_WIDTH-1  :0] sel

    );

    wire [IN_WIDTH-1 :0] mask;
    wire [IN_WIDTH-1 :0] masked_mux_in;
    wire [SEL_WIDTH-1:0] mux_out_gen [OUT_WIDTH-1:0]; 
    
    genvar i,j;
    
    //first selector masking
    generate    // first_mask = {sel[0],sel[0],sel[0],....,sel[n],sel[n],sel[n]}
        for(i=0; i<SEL_WIDTH; i=i+1) begin : mask_loop
            assign mask[(i+1)*OUT_WIDTH-1 : (i)*OUT_WIDTH]  =   {OUT_WIDTH{sel[i]} };
        end
        
        assign masked_mux_in    = mux_in & mask;
        
        for(i=0; i<OUT_WIDTH; i=i+1) begin : lp1
            for(j=0; j<SEL_WIDTH; j=j+1) begin : lp2
                assign mux_out_gen [i][j]   =   masked_mux_in[i+OUT_WIDTH*j];
            end
            assign mux_out[i] = | mux_out_gen [i];
        end
    endgenerate
    
endmodule


/***********************************

    module bin_to_one_hot     

************************************/

module bin_to_one_hot #(
    parameter BIN_WIDTH     =   2,
    parameter ONE_HOT_WIDTH =   2**BIN_WIDTH
    
)
(
    input   [BIN_WIDTH-1            :   0]  bin_code,
    output  [ONE_HOT_WIDTH-1        :   0] one_hot_code
 );

    genvar i;
    generate 
        for(i=0; i<ONE_HOT_WIDTH; i=i+1) begin :one_hot_gen_loop
                assign one_hot_code[i] = (bin_code == i[BIN_WIDTH-1         :   0]);
        end
    endgenerate
 
endmodule

/***********************************

    one_hot_to_binary

************************************/

module one_hot_to_bin #(
    parameter ONE_HOT_WIDTH =   4,
    parameter BIN_WIDTH     =  (ONE_HOT_WIDTH>1)? log2(ONE_HOT_WIDTH):1
)
(
    input   [ONE_HOT_WIDTH-1        :   0] one_hot_code,
    output  [BIN_WIDTH-1            :   0] bin_code

);

    function integer log2;
      input integer number; begin   
         log2=0;    
         while(2**log2<number) begin    
            log2=log2+1;    
         end    
      end   
   endfunction // log2 

localparam MUX_IN_WIDTH =   BIN_WIDTH* ONE_HOT_WIDTH;

wire [MUX_IN_WIDTH-1        :   0]  bin_temp ;

genvar i;
generate 
    if(ONE_HOT_WIDTH>1)begin :if1
        for(i=0; i<ONE_HOT_WIDTH; i=i+1) begin :mux_in_gen_loop
            assign bin_temp[(i+1)*BIN_WIDTH-1 : i*BIN_WIDTH] =  i[BIN_WIDTH-1:0];
        end


        one_hot_mux #(
            .IN_WIDTH   (MUX_IN_WIDTH),
            .SEL_WIDTH  (ONE_HOT_WIDTH)
            
        )
        one_hot_to_bcd_mux
        (
            .mux_in     (bin_temp),
            .mux_out        (bin_code),
            .sel            (one_hot_code)
    
        );
     end else begin :els
        assign  bin_code = one_hot_code;
     
     end

endgenerate

endmodule


