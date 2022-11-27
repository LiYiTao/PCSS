`timescale  1ns / 1ps
`define debug
//`define VCD_DUMP

module tb_node_top;

// pcss_top Parameters
parameter PERIOD          = 10;
parameter FW              = 59;
parameter B               = 4 ;
parameter CONNECT         = 2 ;
parameter CONNECT_WIDTH   = 5 ;
parameter P_MESH          = 5 ;
parameter P_HIER          = 7 ;
parameter CHIPDATA_WIDTH  = 16;

// localparam
localparam CFG_LEN = 45;
localparam SPK_LEN = 8;
localparam TIK_LEN = 7;
localparam TIK_CNT = 8; // tik count

// pcss_top Inputs
reg   clk                                  = 0 ;
reg   rst_n                                = 0 ;
reg   tik                                  = 0 ;

reg   [FW+CONNECT_WIDTH+TIK_CNT-1:0] cfg_data [CFG_LEN-1:0];
reg   [FW+CONNECT_WIDTH+TIK_CNT-1:0] spk_data [SPK_LEN-1:0];

reg   flit_in_wr;
reg   [FW-1:0] flit_in;
reg   credit_in;
wire  flit_out_wr;
wire  [FW-1:0] flit_out;
wire  credit_out;

reg   [TIK_LEN+TIK_CNT-1:0] tik_gen;
reg   [TIK_CNT-1:0] tik_cnt;
reg   enable;

function integer log2;
    input integer number; begin
        log2=0;
        while(2**log2<number) begin    
            log2=log2+1;    
        end
    end
endfunction // log2 

// generate clk & rst
initial begin
    forever #(PERIOD/2)  clk=~clk;
end

initial begin
    #(PERIOD*2) rst_n  =  1;
end

// generate tik
always @(posedge clk or negedge rst_n) begin
    if(~rst_n)begin
        tik <= 1'b0;
        tik_cnt <= {TIK_CNT{1'b0}};
        tik_gen <= {(TIK_LEN+TIK_CNT){1'b0}};
    end
    else if(tik_gen[TIK_LEN] == 1'b1)begin // TODO
        tik_gen <= {(TIK_LEN+TIK_CNT){1'b0}};
        tik <= ~tik;
        if (tik) begin
            tik_cnt <= tik_cnt + 1'b1;
        end
    end
    else if(enable)begin
        tik_gen <= tik_gen + 1'b1;
    end
end

// open file
initial begin
    $readmemh("D:/config.txt",cfg_data);
    $readmemh("D:/spike.txt",spk_data);
end

// send data
integer i,j,time_step;
initial begin
    enable = 1'b0;
    flit_in_wr = 1'b0;
    credit_in = 1'b0;
    wait (rst_n == 1'b1);
    for (i=0; i<10; i=i+1) begin
        @(posedge clk);
    end
    // config mode
    $display("Config mode");
    for (j=0; j<CFG_LEN; j=j+1) begin
        flit_in = cfg_data[j][FW-1:0];
        flit_in_wr = 1'b1;
        @(posedge clk);
        flit_in_wr = 1'b0;
    end

    for (i=0; i<100; i=i+1) begin //wait configure ready
        @(posedge clk);
    end

    // work mode
    enable = 1;
    $display("Work mode");
    for (j=0; j<SPK_LEN; j=j+1) begin
        time_step = spk_data[j][FW+CONNECT_WIDTH+TIK_CNT-1 : FW+CONNECT_WIDTH];
        wait (tik_cnt == time_step);
        flit_in = spk_data[j][FW-1:0];
        flit_in_wr = 1'b1;
        @(posedge clk);
        flit_in_wr = 1'b0;
    end

    for (i=0; i<100; i=i+1) begin //wait spk out
        @(posedge clk);
    end

    #1000;
    $finish;
end

node #(
    .FW(FW)
)
the_node
(
    .clk(clk),
    .rst_n(rst_n),
    .tik(tik),
    .credit_in(credit_in),
    .credit_out(credit_out),
    .flit_in_wr(flit_in_wr),
    .flit_in(flit_in),
    .flit_out_wr(flit_out_wr),
    .flit_out(flit_out)
);


endmodule