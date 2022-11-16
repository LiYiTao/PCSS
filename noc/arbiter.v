/*****************************************
		
	round robin arbiter

******************************************/

module arbiter #(
    parameter ARBITER_WIDTH = 8
) (
   input  clk, 
   input  reset, 
   input  [ARBITER_WIDTH-1:0] request, 
   output [ARBITER_WIDTH-1:0] grant,
   output any_grant
);

generate 
if(ARBITER_WIDTH==1)  begin: w1
    assign grant = request;
    assign any_grant = request;
end else if(ARBITER_WIDTH<=4) begin: w4
    //my own arbiter 
    my_one_hot_arbiter #(
        .ARBITER_WIDTH	(ARBITER_WIDTH)
    )
    one_hot_arb
    (	
        .clk		(clk), 
        .reset 		(reset), 
        .request	(request), 
        .grant		(grant),
        .any_grant	(any_grant)
    );

end else begin : wb4
    
    thermo_arbiter #(
        .ARBITER_WIDTH	(ARBITER_WIDTH)
    )
    one_hot_arb
    (	
        .clk		(clk), 
        .reset 		(reset), 
        .request	(request), 
        .grant		(grant),
        .any_grant	(any_grant)
    );
end
endgenerate

endmodule
	

module my_one_hot_arbiter #(
	parameter ARBITER_WIDTH	=4
) (
	input	[ARBITER_WIDTH-1 			:	0]	request,
	output	[ARBITER_WIDTH-1			:	0]	grant,
	output										any_grant,
	input										clk,
	input										reset
);
	function integer log2;
      input integer number;	begin	
         log2=0;	
         while(2**log2<number) begin	
            log2=log2+1;	
         end	
      end	
    endfunction // log2 
	
	localparam ARBITER_BIN_WIDTH= log2(ARBITER_WIDTH);
	reg 	[ARBITER_BIN_WIDTH-1		:	0] 	low_pr;
	wire 	[ARBITER_BIN_WIDTH-1		:	0] 	grant_bcd;
	
	one_hot_to_bin #(
		.ONE_HOT_WIDTH	(ARBITER_WIDTH)
	)conv
	(
	.one_hot_code(grant),
	.bin_code(grant_bcd)
	);
	
	always@(posedge clk or posedge reset) begin
		if(reset) begin
			low_pr	<=	{ARBITER_BIN_WIDTH{1'b0}};
		end else begin
			if(any_grant) low_pr <= grant_bcd;
		end
	end
	
	assign any_grant = | request;

	generate 
		if(ARBITER_WIDTH	==2) begin: w2		arbiter_2_one_hot arb( .in(request) , .out(grant), .low_pr(low_pr)); end
		if(ARBITER_WIDTH	==3) begin: w3		arbiter_3_one_hot arb( .in(request) , .out(grant), .low_pr(low_pr)); end
		if(ARBITER_WIDTH	==4) begin: w4		arbiter_4_one_hot arb( .in(request) , .out(grant), .low_pr(low_pr)); end
	endgenerate

endmodule


module arbiter_2_one_hot(
	 input      [1 			:	0]	in,
	 output	reg [1			:	0]	out,
	 input 	   						low_pr
);
always @(*) begin
	 out=2'b00;
 	 case(low_pr)
		1'd0:
			 if(in[1]) 				out=2'b10;
			 else if(in[0]) 		out=2'b01;
		1'd1:
			 if(in[0]) 				out=2'b01;
			 else if(in[1]) 		out=2'b10;
		default: out=2'b00;
	 endcase 
end
endmodule 


module arbiter_3_one_hot(
	 input      [2 			:	0]	in,
	 output	reg [2			:	0]	out,
	 input 	    [1			:	0]	low_pr
);
always @(*) begin
  out=3'b000;
 	 case(low_pr)
		 2'd0:
			 if(in[1]) 				out=3'b010;
			 else if(in[2]) 		out=3'b100;
			 else if(in[0]) 		out=3'b001;
		 2'd1:
			 if(in[2]) 				out=3'b100;
			 else if(in[0]) 		out=3'b001;
			 else if(in[1]) 		out=3'b010;
		 2'd2:
			 if(in[0]) 				out=3'b001;
			 else if(in[1]) 		out=3'b010;
			 else if(in[2]) 		out=3'b100;
		 default: out=3'b000;
	 endcase 
end
endmodule 


module arbiter_4_one_hot(
	 input      [3 			:	0]	in,
	 output	reg [3			:	0]	out,
	 input 	    [1			:	0]	low_pr
);
always @(*) begin
  out=4'b0000;
 	 case(low_pr)
		 2'd0:
			 if(in[1]) 				out=4'b0010;
			 else if(in[2]) 		out=4'b0100;
			 else if(in[3]) 		out=4'b1000;
			 else if(in[0]) 		out=4'b0001;
		 2'd1:
			 if(in[2]) 				out=4'b0100;
			 else if(in[3]) 		out=4'b1000;
			 else if(in[0]) 		out=4'b0001;
			 else if(in[1]) 		out=4'b0010;
		 2'd2:
			 if(in[3]) 				out=4'b1000;
			 else if(in[0]) 		out=4'b0001;
			 else if(in[1]) 		out=4'b0010;
			 else if(in[2]) 		out=4'b0100;
		 2'd3:
			 if(in[0]) 				out=4'b0001;
			 else if(in[1]) 		out=4'b0010;
			 else if(in[2]) 		out=4'b0100;
			 else if(in[3]) 		out=4'b1000;
		 default: out=4'b0000;
	 endcase 
end
endmodule 



/*******************

	thermo_arbiter

********************/

module thermo_gen #(
	parameter WIDTH=16


)(
	input  [WIDTH-1	:	0]in,
	output [WIDTH-1	:	0]out
);
	genvar i;
	generate
	for(i=0;i<WIDTH;i=i+1)begin :lp
		assign out[i]= | in[i	:0];	
	end
	endgenerate

endmodule

 
 
module thermo_arbiter #(
    parameter	ARBITER_WIDTH	=4
)
(	
   clk, 
   reset, 
   request, 
   grant,
   any_grant
);

	input	[ARBITER_WIDTH-1 			:	0]	request;
	output	[ARBITER_WIDTH-1			:	0]	grant;
	output										any_grant;
	input										reset,clk;
	
	
	wire	[ARBITER_WIDTH-1 			:	0]	termo1,termo2,mux_out,masked_request,edge_mask;
	reg		[ARBITER_WIDTH-1 			:	0]	pr;


	thermo_gen #(
		.WIDTH(ARBITER_WIDTH)
	) tm1
	(
		.in(request),
		.out(termo1)
	);


	thermo_gen #(
		.WIDTH(ARBITER_WIDTH)
	) tm2
	(
		.in(masked_request),
		.out(termo2)
	);

	
assign mux_out=(termo2[ARBITER_WIDTH-1])? termo2 : termo1;
assign masked_request= request & pr;
assign any_grant=termo1[ARBITER_WIDTH-1];

always @(posedge clk or posedge reset)begin 
	if(reset) pr<= {ARBITER_WIDTH{1'b1}};
	else begin 
		if(any_grant) pr<= edge_mask;
	end

end

assign edge_mask= {mux_out[ARBITER_WIDTH-2:0],1'b0};
assign grant= mux_out ^ edge_mask;

endmodule
	
