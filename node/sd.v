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
    tik                         ,
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
input                         tik                         ;
//Axon
input     [NNW -1:0   ]       axon_sd_vm_addr             ;
input     [NNW -1:0   ]       axon_sd_wgt_addr            ;
input     [LAN_num-1:0]       axon_sd_lans                ;
input                         axon_sd_vld                 ;
//Soma
output    [VW-1:0     ]       sd_soma_vm                  ;
//Config
input     [NNW -1:0   ]       config_sd_vm_addr           ;
input                         config_sd_vld               ;
input                         config_sd_clear             ;
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




reg [NNW -1:0   ] wgt_raddr;

dp_ram #(
    .RAM_WIDTH   (WD                  ),
    .ADDR_WIDTH  (WW                  )
) weight_mem (
    .rst_n       (rst_n               ),
    .write_clk   (clk_SD              ),
    .read_clk    (clk_SD              ),
    .write_allow (config_sd_wgt_we    ),
    .read_allow  (config_sd_wgt_re || axon_sd_vld   ),
    .write_addr  (config_sd_wgt_waddr ),
    .read_addr   (wgt_raddr           ),
    .write_data  (config_sd_wgt_wdata ),
    .read_data   (config_sd_wgt_rdata )
);

reg [NNW -1:0   ] vm_raddr;
reg [NNW -1:0   ] vm_waddr;
reg [VW-1:0     ] vm_wdata;

pq_buffer #(
    .DATA_WIDTH  (NNW                 ),
    .ADDR_WIDTH  (VW                  )
) vm_buffer (
    .clk         (clk_SD),
    .rst_n       (rst_n),
    .wr_en       (config_sd_vm_we || axon_sd_vld || config_sd_vld),
    .rd_en       (config_sd_vm_re || axon_sd_vld || config_sd_vld),
    .ctrl        (tik),
    .rd_addr     (vm_raddr          ),
    .wr_addr     (vm_waddr          ),
    .din         (vm_wdata          ),
    .dout        (config_sd_vm_rdata)
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
//axon first;
always @* begin
    if(axon_sd_vld) begin
        vm_raddr  = axon_sd_vm_addr;
        vm_wdata  = config_sd_vm_rdata + config_sd_wgt_rdata;
    end
    else if(config_sd_vld && config_sd_clear) begin
        vm_raddr  = config_sd_vm_addr;
        vm_wdata  = 0;
    end
    else
        vm_raddr  = config_sd_vm_raddr;
        vm_wdata  = config_sd_vm_wdata;
        
end

//read first
always @(posedge clk_SD or negedge rst_n) begin
    if(rst_n) begin
        vm_waddr  <= 0;
    end
    else if(axon_sd_vld) begin
        vm_waddr   <= axon_sd_vm_addr ;
    end
    else
        vm_waddr   <= config_sd_vm_waddr ;
end

assign sd_soma_vm = config_sd_vm_rdata;



endmodule
