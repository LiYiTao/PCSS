`timescale  1ns / 1ps
// `define debug
//`define ASIC
//`define SAIF
//`define VCD_DUMP
`define FSDB_DUMP

module tb_inf_top;

// pcss_top Parameters
parameter PERIOD          = 10;
parameter FW              = 59;
parameter B               = 4 ;
parameter CONNECT         = 2 ;
parameter CONNECT_WIDTH   = 5 ;
parameter P_MESH          = 5 ;
parameter P_HIER          = 7 ;
parameter CHIPDATA_WIDTH  = 16;
parameter NNW             = 12; // TODO neural number width
parameter DATA_WIDTH      = 64;

// localparam
localparam CFG_LEN = 68407; //68399;
localparam SPK_LEN = 8;
localparam TIK_LEN = 7;
localparam TIK_CNT = 8; // tik count

// pcss_top port
reg   clk                                  = 0 ;
reg   rst_n                                = 0 ;
wire  [CHIPDATA_WIDTH-1:0]  recv_data_in_E ;
wire  recv_data_valid_E                    ;
wire  recv_data_par_E                      ;
wire  send_data_ready_E                    ;
wire  send_data_err_E                      ;
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

wire  tik;
wire  recv_data_ready_E                    ;
wire  recv_data_err_E                      ;
wire  [CHIPDATA_WIDTH-1:0]  send_data_out_E;
wire  send_data_valid_E                    ;
wire  send_data_par_E                      ;
wire  recv_data_ready_N                    ;
wire  recv_data_err_N                      ;
wire  [CHIPDATA_WIDTH-1:0]  send_data_out_N;
wire  send_data_valid_N                    ;
wire  send_data_par_N                      ;
wire  recv_data_ready_W                    ;
wire  recv_data_err_W                      ;
wire  [CHIPDATA_WIDTH-1:0]  send_data_out_W;
wire  send_data_valid_W                    ;
wire  send_data_par_W                      ;
wire  recv_data_ready_S                    ;
wire  recv_data_err_S                      ;
wire  [CHIPDATA_WIDTH-1:0]  send_data_out_S;
wire  send_data_valid_S                    ;
wire  send_data_par_S                      ;

// inf port
reg   [DATA_WIDTH-1:0]     S_AXIS_send_tdata  = 0;
reg                        S_AXIS_send_tvalid = 0;
reg                        S_AXIS_send_tlast  = 0;
reg   [DATA_WIDTH/8-1:0]   S_AXIS_send_tkeep  = 0;
wire                       S_AXIS_send_tready ;
wire  [DATA_WIDTH-1:0]     M_AXIS_recv_tdata  ;
wire                       M_AXIS_recv_tvalid ;
wire                       M_AXIS_recv_tlast  ;
wire  [DATA_WIDTH/8-1:0]   M_AXIS_recv_tkeep  ;
reg                        M_AXIS_recv_tready = 0;

reg   [DATA_WIDTH-1:0] recv_data = 0;
reg   [DATA_WIDTH-1:0] cfg_data [CFG_LEN-1:0];
reg   [DATA_WIDTH-1:0] spk_data [SPK_LEN-1:0];
reg   [TIK_CNT-1:0] tik_cnt;
reg                 tik_dly;

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


// open file
initial begin
    $readmemh("../PCSS/config.txt",cfg_data);
    // $readmemh("D:/spike.txt",spk_data);
end

// send data
integer i;
initial begin
    wait (rst_n == 1'b1);
    for (i=0; i<10; i=i+1) begin
        @(posedge clk);
    end
    // config mode
    $display("send data");
    S_AXIS_send_tkeep = {(DATA_WIDTH/8){1'b1}};
    pcss_send;

    for (i=0; i<100; i=i+1) begin //wait configure ready
        @(posedge clk);
    end

    wait (M_AXIS_recv_tdata == {DATA_WIDTH{1'b1}});

    `ifdef SAIF
        $toggle_stop;
        $toggle_report("pcss.saif", 1.0e-9,"u_pcss_top");
    `endif

    #1000;
    $finish;
end

// recv data
always @(posedge clk) begin
    pcss_recv;
end

// tik
always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        tik_cnt <= {TIK_CNT{1'b0}};
        tik_dly <= 1'b0;
    end
    else begin
        tik_dly <= tik;
        if (tik_dly && ~tik) begin
            tik_cnt <= tik_cnt + 1'b1;
        end
    end
end

// PCSS
pcss_top #(
    .FW             ( FW             ),
    .B              ( B              ),
    .CONNECT        ( CONNECT        ),
    .P_MESH         ( P_MESH         ),
    .P_HIER         ( P_HIER         ),
    .CHIPDATA_WIDTH ( CHIPDATA_WIDTH ),
    .NNW            ( NNW )
)
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


// pcss_inf
pcss_inf the_pcss_inf
(
    .clk(clk),
    .rst_n(rst_n),
    // AXI-stream send data
    .S_AXIS_send_tdata(S_AXIS_send_tdata),
    .S_AXIS_send_tvalid(S_AXIS_send_tvalid),
    .S_AXIS_send_tlast(S_AXIS_send_tlast),
    .S_AXIS_send_tkeep(S_AXIS_send_tkeep),
    .S_AXIS_send_tready(S_AXIS_send_tready),
    // AXI-stream recv data
    .M_AXIS_recv_tdata(M_AXIS_recv_tdata),
    .M_AXIS_recv_tvalid(M_AXIS_recv_tvalid),
    .M_AXIS_recv_tlast(M_AXIS_recv_tlast),
    .M_AXIS_recv_tkeep(M_AXIS_recv_tkeep),
    .M_AXIS_recv_tready(M_AXIS_recv_tready),
    // signal with chip
    .tik(tik),
    .recv_data_in_E(recv_data_in_E),
    .recv_data_valid_E(recv_data_valid_E),
    .recv_data_par_E(recv_data_par_E),
    .recv_data_ready_E(recv_data_ready_E),
    .recv_data_err_E(recv_data_err_E),
    .send_data_out_E(send_data_out_E),
    .send_data_valid_E(send_data_valid_E),
    .send_data_par_E(send_data_par_E),
    .send_data_ready_E(send_data_ready_E),
    .send_data_err_E(send_data_err_E)
);

initial begin
`ifdef SAIF
    $display("saif dump...");
    $set_toggle_region(u_pcss_top);
    $toggle_start;
`endif

`ifdef FSDB_DUMP
    wait(tik == 1);
    $display("fsdb dump...");
    $fsdbDumpfile("pcss.fsdb");
    $fsdbDumpvars(); // 0,tb_xor_top.x_darwin_top
    $fsdbDumpMDA();
`endif

`ifdef VCD_DUMP
    $display("vcd dump...");
    $dumpfile("pcss.vcd");
    $dumpvars(0);
`endif
end

task pcss_send;
begin
    wait(rst_n == 1'b1);
    #100
    for (i=0; i<CFG_LEN; i=i+1) begin
        @(posedge clk);
        #1
        if ((i%1000)==0) begin
            $display ("Send Data:%d",i);
        end
        // $display ("Send Data:%h,",cfg_data[i]);
        if (S_AXIS_send_tready == 1'b1) begin
            S_AXIS_send_tdata = cfg_data[i];
            S_AXIS_send_tvalid = 1'b1;
        end
        else begin
            S_AXIS_send_tvalid = 1'b0;
            wait(S_AXIS_send_tready == 1'b1);
            #1
            S_AXIS_send_tdata = cfg_data[i];
            S_AXIS_send_tvalid = 1'b1;
        end
    end
    @(posedge clk);
    #1
    S_AXIS_send_tvalid = 1'b0;
end
endtask

task pcss_recv;
begin
    M_AXIS_recv_tready = 1'b1;
    if (M_AXIS_recv_tvalid) begin
        $display ("Recv Data:%h,", M_AXIS_recv_tdata);
    end
end
endtask

endmodule