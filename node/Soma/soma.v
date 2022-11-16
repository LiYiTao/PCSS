//-------------------------------------------------------------------------
// 
//
// Filename         : soma.v
// Author           : 
// Release version  : 1.0
// Release date     : 2022-10-20
// Description      :
//
//-------------------------------------------------------------------------

module soma
#(
    //parameter
    parameter FW         = 59, // flit width
    parameter FTW        =  3, // flit type width
    parameter CDW        = 21, // config data width
    parameter CAW        = 15, // config addres width
    parameter NNW        = 12, // neural number width
    parameter WW         = 16, // weight width
    parameter WD         = 6,  // weight depth (8x8)
    parameter VW         = 20, // Vm width
    parameter SW         = 24, // spk width, (x,y,z)
    parameter CODE_WIDTH = 2 , // spike code width
    parameter DST_WIDTH  = 21, // x+y+r2+r1+flg
    parameter DST_DEPTH  = 4   // dst node depth        
)
(
    clk_soma             ,
    rst_n                ,
    //SD
    sd_soma_vm           ,
    //Spk_out
    soma_spk_out_fire    ,
    //Config
    config_soma_code     ,              
    config_soma_reset    ,
    config_soma_vth      ,
    config_soma_leak     ,
    config_soma_vld      ,
    config_soma_vm_addr  ,
    config_soma_clear    ,
    config_soma_vm_we    ,
    config_soma_vm_waddr ,
    config_soma_vm_wdata ,
    config_soma_vm_re    ,
    config_soma_vm_raddr ,
    config_soma_vm_rdata ,
    config_soma_random_seed,
    config_soma_enable
);

input                       clk_soma             ;
input                       rst_n                ;
//SD
input [VW-1:0]              sd_soma_vm           ;
//Spk_out
output reg                  soma_spk_out_fire    ;
//Config
input [CODE_WIDTH-1:0 ]     config_soma_code     ;   
input                       config_soma_reset    ;
input [VW-1:0]              config_soma_vth      ;
input [VW-1:0]              config_soma_leak     ;
input                       config_soma_vld      ;
input [NNW-1:0]             config_soma_vm_addr  ;
input                       config_soma_clear    ;
input                       config_soma_vm_we    ; 
input [NNW-1:0]             config_soma_vm_waddr ;
input [VW-1:0]              config_soma_vm_wdata ;
input                       config_soma_vm_re    ; 
input [NNW-1:0]             config_soma_vm_raddr ;
input [VW-1:0]              config_soma_vm_rdata ;
input [VW-1:0]              config_soma_random_seed;
input                       config_soma_enable;

reg [NNW-1:0] vm_addr;
reg [VW-1:0 ] vm_wdata;
reg           config_enable_dly;

dp_ram #(
    .RAM_WIDTH   (VW                  ),
    .ADDR_WIDTH  (NNW                 )
) vm_mem (
    .rst_n       (rst_n               ),
    .write_clk   (clk_soma            ),
    .read_clk    (clk_soma            ),
    .write_allow (config_soma_vm_we   ),
    .read_allow  (config_soma_vm_re   ),
    .write_addr  (vm_addr             ),
    .read_addr   (config_soma_vm_raddr),
    .write_data  (vm_wdata            ),
    .read_data   (config_soma_vm_rdata)
);


//config write reset
always @* begin
    if(config_soma_vld && config_soma_clear) begin
        vm_addr  = config_soma_vm_addr;
        vm_wdata = 0;
    end
    else begin
        vm_addr  = config_soma_vm_waddr;
        vm_wdata = config_soma_vm_wdata;
    end
end

reg config_soma_vm_we_r;
//read first
always @(posedge clk or negedge rst_n)
    if(rst_n)
        config_soma_vm_we_r <= 0;
    else if(config_soma_vm_re)
        config_soma_vm_we_r <= config_soma_vm_we;

lfsr #(
    .NUM_BITS   (VW) // TODO
) rand(
    .clk        (clk),
    .rst_n      (rst_n),
    .i_Enable   (1'b1), 
    .i_Seed_DV  (config_soma_enable && !config_enable_dly), 
    .i_Seed_Data(config_soma_random_seed), 
    .o_LFSR_Data(V_rand),
    .o_LFSR_Done()  
);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) config_enable_dly <= 1'b0;
    else config_enable_dly <= config_soma_enable;
end

wire [9:0] n;
wire [9:0] k;

Poisson_code #(

) u_poisson(
    .n         (n    ),
    .k         (k    ),
    .p         (VM_P )
);

reg         [VW-1:0] VM_temp;
wire signed [VW:0  ] V_reset;

assign {n,k} = config_soma_vm_rdata + sd_soma_vm;
//MUX1 VM Select
always @*
    case(config_soma_code)
        2'b00: VM_temp = config_soma_vm_rdata + sd_soma_vm - config_soma_leak; 
        2'b10: begin
            if(soma_spk_out_fire)
                VM_temp = {n,k+1};
            else
                VM_temp = {n,k};
        end
        default: begin
            if(soma_spk_out_fire)
                VM_temp = V_reset;
            else
                VM_temp = config_soma_vm_rdata + sd_soma_vm - config_soma_leak;
        end
    endcase

assign V_reset = config_soma_reset ? 0: -config_soma_vth;

reg [VW-1:0] VM_t;
//MUX2 threshold value select
always @*
    case(config_soma_code)
        2'b00: VM_t = config_soma_vth;
        2'b01: VM_t = V_rand         ;
        2'b10: VM_t = config_soma_vth;
        2'b11: VM_t = config_soma_vth;
    endcase

reg [VW-1:0] VM_out;
//MUX3 compare value select
always @*
    case(config_soma_code)
        2'b00: VM_out = config_soma_vm_rdata + sd_soma_vm;
        2'b01: VM_out = 0;
        2'b10: VM_out = VM_P;               
        2'b11: VM_out = 0;
    endcase

reg config_soma_vm_we_dealy;
always @(posedge clk_soma or negedge rst_n) begin
    if(!rst_n)
        config_soma_vm_we_dealy <= 1'b0;
    else
        config_soma_vm_we_dealy <= config_soma_vm_we;
end


always @* begin
    if(VM_out >= VM_t) begin
        soma_spk_out_fire = 1'b1;
    end
    else
        soma_spk_out_fire = 1'b0;
end

endmodule