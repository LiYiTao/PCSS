`timescale  1ns / 1ps
`define debug

module tb_pcss_top;

// pcss_top Parameters
parameter PERIOD          = 10;
parameter FW              = 59;
parameter B               = 4 ;
parameter CONNECT         = 2 ;
parameter P_MESH          = 5 ;
parameter P_HIER          = 7 ;
parameter CHIPDATA_WIDTH  = 16;

// localparam
localparam DATA_LEN = 2;

// pcss_top Inputs
reg   clk                                  = 0 ;
reg   rst_n                                = 0 ;
reg   tik                                  = 0 ;
reg   [CHIPDATA_WIDTH-1:0]  recv_data_in_E = 0 ;
reg   recv_data_valid_E                    = 0 ;
reg   recv_data_par_E                      = 0 ;
reg   send_data_ready_E                    = 0 ;
reg   send_data_err_E                      = 0 ;
reg   [CHIPDATA_WIDTH-1:0]  recv_data_in_N = 0 ;
reg   recv_data_valid_N                    = 0 ;
reg   recv_data_par_N                      = 0 ;
reg   send_data_ready_N                    = 0 ;
reg   send_data_err_N                      = 0 ;
reg   [CHIPDATA_WIDTH-1:0]  recv_data_in_W = 0 ;
reg   recv_data_valid_W                    = 0 ;
reg   recv_data_par_W                      = 0 ;
reg   send_data_ready_W                    = 0 ;
reg   send_data_err_W                      = 0 ;
reg   [CHIPDATA_WIDTH-1:0]  recv_data_in_S = 0 ;
reg   recv_data_valid_S                    = 0 ;
reg   recv_data_par_S                      = 0 ;
reg   send_data_ready_S                    = 0 ;
reg   send_data_err_S                      = 0 ;

reg   [14:0] tik_cnt;
reg   [FW+log2(CONNECT)-1:0] recv_data = 0;
reg   [FW+log2(CONNECT)-1:0] cfg_data [DATA_LEN-1:0];

// pcss_top Outputs
wire  recv_data_ready_E                    ;
wire  recv_data_err_E                      ;
wire  [CHIPDATA_WIDTH-1:0]  send_data_out_E ;
wire  send_data_valid_E                    ;
wire  send_data_par_E                      ;
wire  recv_data_ready_N                    ;
wire  recv_data_err_N                      ;
wire  [CHIPDATA_WIDTH-1:0]  send_data_out_N ;
wire  send_data_valid_N                    ;
wire  send_data_par_N                      ;
wire  recv_data_ready_W                    ;
wire  recv_data_err_W                      ;
wire  [CHIPDATA_WIDTH-1:0]  send_data_out_W ;
wire  send_data_valid_W                    ;
wire  send_data_par_W                      ;
wire  recv_data_ready_S                    ;
wire  recv_data_err_S                      ;
wire  [CHIPDATA_WIDTH-1:0]  send_data_out_S ;
wire  send_data_valid_S                    ;
wire  send_data_par_S                      ;

function integer log2;
    input integer number; begin
        log2=0;
        while(2**log2<number) begin    
            log2=log2+1;    
        end
    end
endfunction // log2 

// generate clk
initial begin
    forever #(PERIOD/2)  clk=~clk;
end

// generate reset
initial begin
    #(PERIOD*2) rst_n  =  1;
end

// generate tik
always @(posedge clk or negedge rst_n) begin
    if(~rst_n)begin
        tik <= 1'b0;
        tik_cnt[14:0] <= 15'b0;
    end
    else if(tik_cnt[9] == 1'b1)begin // TODO
        tik_cnt[14:0] <= 15'b0;
        tik <= ~tik;
    end
    else begin
        tik_cnt[14:0] <= tik_cnt[14:0] + 15'b1;
    end
end

// open file
initial begin
    $readmemh("D:/config",cfg_data);
end

// send data
integer i,j;
initial begin
    wait (rst_n == 1'b1);
    for (i=0; i<10; i=i+1) begin
        @(posedge clk);
    end
    // config mode
    $display("Config mode");
    for (j=0; j<DATA_LEN; j=j+1) begin
        pcss_send(cfg_data[j]);
    end

    for (i=0; i<200; i=i+1) begin //wait configure ready
        @(posedge clk);
    end

    #1000;
    $finish;
end

// recv data
always @(posedge clk) begin
    while (1) begin
        pcss_recv;
        $display("Receive Data : %h",recv_data);
    end
end

// PCSS
pcss_top #(
    .FW             ( FW             ),
    .B              ( B              ),
    .CONNECT        ( CONNECT        ),
    .P_MESH         ( P_MESH         ),
    .P_HIER         ( P_HIER         ),
    .CHIPDATA_WIDTH ( CHIPDATA_WIDTH ))
 u_pcss_top (
    .clk                     ( clk                                     ),
    .rst_n                   ( rst_n                                   ),
    .tik                     ( tik                                     ),
    .recv_data_in_E          ( recv_data_in_E     [CHIPDATA_WIDTH-1:0] ),
    .recv_data_valid_E       ( recv_data_valid_E                       ),
    .recv_data_par_E         ( recv_data_par_E                         ),
    .send_data_ready_E       ( send_data_ready_E                       ),
    .send_data_err_E         ( send_data_err_E                         ),
    .recv_data_in_N          ( recv_data_in_N     [CHIPDATA_WIDTH-1:0] ),
    .recv_data_valid_N       ( recv_data_valid_N                       ),
    .recv_data_par_N         ( recv_data_par_N                         ),
    .send_data_ready_N       ( send_data_ready_N                       ),
    .send_data_err_N         ( send_data_err_N                         ),
    .recv_data_in_W          ( recv_data_in_W     [CHIPDATA_WIDTH-1:0] ),
    .recv_data_valid_W       ( recv_data_valid_W                       ),
    .recv_data_par_W         ( recv_data_par_W                         ),
    .send_data_ready_W       ( send_data_ready_W                       ),
    .send_data_err_W         ( send_data_err_W                         ),
    .recv_data_in_S          ( recv_data_in_S     [CHIPDATA_WIDTH-1:0] ),
    .recv_data_valid_S       ( recv_data_valid_S                       ),
    .recv_data_par_S         ( recv_data_par_S                         ),
    .send_data_ready_S       ( send_data_ready_S                       ),
    .send_data_err_S         ( send_data_err_S                         ),

    .recv_data_ready_E       ( recv_data_ready_E                       ),
    .recv_data_err_E         ( recv_data_err_E                         ),
    .send_data_out_E         ( send_data_out_E    [CHIPDATA_WIDTH-1:0] ),
    .send_data_valid_E       ( send_data_valid_E                       ),
    .send_data_par_E         ( send_data_par_E                         ),
    .recv_data_ready_N       ( recv_data_ready_N                       ),
    .recv_data_err_N         ( recv_data_err_N                         ),
    .send_data_out_N         ( send_data_out_N    [CHIPDATA_WIDTH-1:0] ),
    .send_data_valid_N       ( send_data_valid_N                       ),
    .send_data_par_N         ( send_data_par_N                         ),
    .recv_data_ready_W       ( recv_data_ready_W                       ),
    .recv_data_err_W         ( recv_data_err_W                         ),
    .send_data_out_W         ( send_data_out_W    [CHIPDATA_WIDTH-1:0] ),
    .send_data_valid_W       ( send_data_valid_W                       ),
    .send_data_par_W         ( send_data_par_W                         ),
    .recv_data_ready_S       ( recv_data_ready_S                       ),
    .recv_data_err_S         ( recv_data_err_S                         ),
    .send_data_out_S         ( send_data_out_S    [CHIPDATA_WIDTH-1:0] ),
    .send_data_valid_S       ( send_data_valid_S                       ),
    .send_data_par_S         ( send_data_par_S                         )
);


// task
task pcss_send(
    input [FW+log2(CONNECT)-1:0] Data
);
begin
    recv_data_in_E = {CHIPDATA_WIDTH{1'b0}};
    recv_data_valid_E = 1'b0;
    wait(rst_n == 1'b1);
    #100;
    $display ("Send Data:%h,",Data);
    @(posedge clk);
    #1;
    // send 1
    $display ("Send 16 bits .....1");
    while(recv_data_ready_E == 1'b1)begin
        @(posedge clk);
    end
    #1;
    recv_data_in_E    = Data[FW+log2(CONNECT)-1:48];
    recv_data_valid_E = 1'b1;
    recv_data_par_E   = ^recv_data_in_E;
    while(recv_data_ready_E == 1'b0)begin
        @(posedge clk);
    end
    @(posedge clk);
    #1;
    recv_data_valid_E = 1'b0;
    // error
    /*
    while(recv_data_ready_E == 1'b1)begin
        @(posedge clk);
    end
    #1;
    recv_data_in_E = Data[47:32];
    recv_data_valid_E = 1'b1;
    recv_data_par_E = ~(^recv_data_in_E);
    while(recv_data_ready_E == 1'b0)begin
        @(posedge clk);
    end
    @(posedge clk);
    #1;
    recv_data_valid_E = 1'b0;
    */

    // send 2
    $display ("Send 16 bits .....2");
    while(recv_data_ready_E == 1'b1)begin
        @(posedge clk);
    end
    #1;
    recv_data_in_E    = Data[47:32];
    recv_data_valid_E = 1'b1;
    recv_data_par_E   = ^recv_data_in_E;
    while(recv_data_ready_E == 1'b0)begin
        @(posedge clk);
    end
    @(posedge clk);
    #1;
    recv_data_valid_E = 1'b0;

    // send 3
    $display ("Send 16 bits .....3");
    while(recv_data_ready_E == 1'b1)begin
        @(posedge clk);
    end
    #1;
    recv_data_in_E    = Data[31:16];
    recv_data_valid_E = 1'b1;
    recv_data_par_E   = ^recv_data_in_E;
    while(recv_data_ready_E == 1'b0)begin
        @(posedge clk);
    end
    @(posedge clk);
    #1;
    recv_data_valid_E = 1'b0;

    // send 4
    $display ("Send 16 bits .....4");
    while(recv_data_ready_E == 1'b1)begin
        @(posedge clk);
    end
    #1;
    recv_data_in_E    = Data[15:0];
    recv_data_valid_E = 1'b1;
    recv_data_par_E   = ^recv_data_in_E;
    while(recv_data_ready_E == 1'b0)begin
        @(posedge clk);
    end
    @(posedge clk);
    #1;
    recv_data_valid_E = 1'b0;
end
endtask

task pcss_recv;
begin
    send_data_ready_E = 1'b0;
    recv_data = 0;
    // rec 1
    while (send_data_valid_E == 1'b0) begin
        @(posedge clk);
    end
    #1;
    send_data_ready_E = 1'b1;
    send_data_err_E = 1'b0;
    recv_data[FW+log2(CONNECT)-1:48] = send_data_out_E;
    while (send_data_valid_E == 1'b1) begin
        @(posedge clk);
    end
    #1;
    send_data_ready_E = 1'b0;

    // rec 2
    while (send_data_valid_E == 1'b0) begin
        @(posedge clk);
    end
    #1;
    send_data_ready_E = 1'b1;
    send_data_err_E = 1'b0;
    recv_data[47:32] = send_data_out_E;
    while (send_data_valid_E == 1'b1) begin
        @(posedge clk);
    end
    #1;
    send_data_ready_E = 1'b0;

    // rec 3
    while (send_data_valid_E == 1'b0) begin
        @(posedge clk);
    end
    #1;
    send_data_ready_E = 1'b1;
    send_data_err_E = 1'b0;
    recv_data[31:16] = send_data_out_E;
    while (send_data_valid_E == 1'b1) begin
        @(posedge clk);
    end
    #1;
    send_data_ready_E = 1'b0;

    // rec 4
    while (send_data_valid_E == 1'b0) begin
        @(posedge clk);
    end
    #1;
    send_data_ready_E = 1'b1;
    send_data_err_E = 1'b0;
    recv_data[15:0] = send_data_out_E;
    while (send_data_valid_E == 1'b1) begin
        @(posedge clk);
    end
    #1;
    send_data_ready_E = 1'b0;
end
endtask

endmodule