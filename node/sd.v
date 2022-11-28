//-------------------------------------------------------------------------
// 
//
// Filename         : SD.v
// Author           : 
// Release version  : 1.0
// Release date     : 2020-08-06
// Description      :
//
//-------------------------------------------------------------------------

module sd
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
    parameter LAN_num    = 2   // lans
)
(
    // port list
    clk_SD                      ,
    rst_n                       ,
    //Axon
    axon_sd_vm_addr             ,
    axon_sd_wgt_addr            ,
    axon_sd_lans                ,
    axon_sd_vld                 ,
    //Soma
    sd_soma_vm                  ,
    //Config
    config_sd_vm_addr           ,
    config_sd_vld               ,
    config_sd_clear             ,
    config_sd_start             ,
    config_sd_vm_we             ,
    config_sd_vm_waddr          ,
    config_sd_vm_wdata          ,
    config_sd_wgt_we            ,
    config_sd_wgt_waddr         ,
    config_sd_wgt_wdata         ,
    config_sd_vm_re             ,
    config_sd_vm_raddr          ,
    config_sd_vm_rdata          ,
    config_sd_wgt_re            ,
    config_sd_wgt_raddr         ,
    config_sd_wgt_rdata         
);
// input/output declare
input                         clk_SD                      ;
input                         rst_n                       ;
//Axon
input     [NNW -1:0   ]       axon_sd_vm_addr             ;
input     [WD -1:0   ]        axon_sd_wgt_addr            ;
input     [LAN_num-1:0]       axon_sd_lans                ;
input                         axon_sd_vld                 ;
//Soma
output    [VW-1:0     ]       sd_soma_vm                  ;
//Config
input     [NNW -1:0   ]       config_sd_vm_addr           ;
input                         config_sd_vld               ;
input                         config_sd_clear             ;
input                         config_sd_start             ;
input                         config_sd_vm_we             ;
input     [NNW -1:0   ]       config_sd_vm_waddr          ;
input     [VW-1:0     ]       config_sd_vm_wdata          ;
input                         config_sd_wgt_we            ;
input     [WD -1:0    ]       config_sd_wgt_waddr         ;
input     [WW-1:0     ]       config_sd_wgt_wdata         ;
input                         config_sd_vm_re             ;
input     [NNW -1:0   ]       config_sd_vm_raddr          ;
output    [VW-1:0     ]       config_sd_vm_rdata          ;
input                         config_sd_wgt_re            ;
input     [WD -1:0    ]       config_sd_wgt_raddr         ;
output    [WW-1:0     ]       config_sd_wgt_rdata         ;




reg [WD-1:0] wgt_raddr;

dp_ram #(
    .RAM_WIDTH   (WW                  ),
    .ADDR_WIDTH  (WD                  )
) weight_mem (
    .write_clk   (clk_SD              ),
    .read_clk    (clk_SD              ),
    .write_allow (config_sd_wgt_we    ),
    .read_allow  (config_sd_wgt_re || axon_sd_vld),
    .write_addr  (config_sd_wgt_waddr ),
    .read_addr   (wgt_raddr           ),
    .write_data  (config_sd_wgt_wdata ),
    .read_data   (config_sd_wgt_rdata )
);

reg [NNW -1:0   ] vm_raddr;
reg [NNW -1:0   ] vm_waddr;
reg [VW-1:0     ] vm_wdata;
reg               pq_sel;
reg               axon_sd_vld_dly;
reg [NNW -1:0   ] axon_sd_vm_addr_dly;
reg               config_sd_clear_dly;

always @(posedge clk_SD or negedge rst_n) begin
    if (!rst_n) begin
        pq_sel <= 1'b0;
    end
    else if (config_sd_start) begin
        pq_sel <= ~pq_sel;
    end
end

pq_buffer #(
    .DATA_WIDTH  (VW                 ),
    .ADDR_WIDTH  (NNW                )
) vm_buffer (
    .clk         (clk_SD),
    .wr_en1      (config_sd_vld),
    .wr_en2      (config_sd_vm_we || axon_sd_vld_dly),
    .rd_en1      (config_sd_vld & !config_sd_clear  ),
    .rd_en2      (config_sd_vm_re || axon_sd_vld    ),
    .ctrl        (pq_sel            ),
    .clear       (config_sd_clear   ),
    .rd_addr1    (config_sd_vm_addr ),
    .rd_addr2    (vm_raddr          ),
    .wr_addr1    (config_sd_vm_addr ), // clear addr
    .wr_addr2    (vm_waddr          ),
    .din1        ({VW{1'b0}}        ), // clear each tik
    .din2        (vm_wdata          ),
    .dout1       (sd_soma_vm        ),
    .dout2       (config_sd_vm_rdata)
);

//weight mem read
//axon first;
always @* begin
    if(axon_sd_vld) begin
        wgt_raddr  = axon_sd_wgt_addr;
    end
    else begin
        wgt_raddr  = config_sd_wgt_raddr;
    end
end

//vm buffer read/write
// delay
always @(posedge clk_SD or negedge rst_n) begin
    if (!rst_n) begin
        axon_sd_vld_dly <= 1'b0;
        axon_sd_vm_addr_dly  <= {NNW{1'b0}};
    end
    else begin
        axon_sd_vld_dly <= axon_sd_vld;
        axon_sd_vm_addr_dly  <= axon_sd_vm_addr;
    end
end

//vm buffer write
always @(*) begin
    if (axon_sd_vld_dly) begin
        vm_waddr = axon_sd_vm_addr_dly;
        vm_wdata = config_sd_vm_rdata + config_sd_wgt_rdata;
    end
    else begin
        vm_waddr = config_sd_vm_waddr;
        vm_wdata = config_sd_vm_wdata;
    end
end

//vm buffer read
always @(*) begin
    if(axon_sd_vld) begin
        vm_raddr   = axon_sd_vm_addr ;
    end
    else
        vm_raddr   = config_sd_vm_raddr ;
end


endmodule
