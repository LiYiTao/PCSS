`define  START_LOC(port_num,width)                (width*(port_num+1)-1)
`define  END_LOC(port_num,width)                  (width*port_num)
`define  ROUTER2_NUM(x,y)                         ((y * NX) + x)
`define  ROUTER1_NUM(x,y,i)                       ((`ROUTER2_NUM(x,y) * NR2) + i)
`define  NODE_NUM(x,y,i,j)                        ((`ROUTER1_NUM(x,y,i) * NR1) + j)
`define  ROUTER2_SELECT_WIRE(x,y,port,width)      `ROUTER2_NUM(x,y)][`START_LOC(port,width) : `END_LOC(port,width)
`define  ROUTER1_SELECT_WIRE(x,y,i,port,width)    `ROUTER1_NUM(x,y,i)][`START_LOC(port,width) : `END_LOC(port,width)
`define  CONNECT_SELECT_WIRE(connect,port,width)  connect][`START_LOC((port-1),width) : `END_LOC((port-1),width)

module noc #(
    parameter FW = 36, //TODO
    parameter B = 4,
    parameter XW = 4,
    parameter YW = 4,
    parameter CONNECT = 2, // NX,NY
    parameter P_MESH = 5,
    parameter P_HIER = 7
) (
    // system signal
    input  clk,
    input  rst_n,
    // ctrl
    input  tik,
    // noc to chipconnection
    input  [FW*(P_MESH-1)-1:0] flit_in [CONNECT-1:0],
    input  [(P_MESH-1)-1:0] flit_in_wr [CONNECT-1:0],
    output [FW*(P_MESH-1)-1:0] flit_out [CONNECT-1:0],
    output [(P_MESH-1)-1:0] flit_out_wr [CONNECT-1:0],
    input  [(P_MESH-1)-1:0] credit_in [CONNECT-1:0],
    output [(P_MESH-1)-1:0] credit_out [CONNECT-1:0]
);

localparam NX = 2;
localparam NY = 2;
localparam NXY = NX*NY;
localparam NR2 = 6;
localparam NR1 = 6;
localparam NXYR2 = NX*NY*NR2;
localparam NXYR2R1 = NX*NY*NR2*NR1;
// port num
localparam L = 0;
localparam E = 1;
localparam N = 2;
localparam W = 3;
localparam S = 4;
localparam P0 = 0;

// mesh connect: [each port],[each router]
wire [P_MESH-1:0] mesh_flit_in_wr_all [NXY-1:0];
wire [FW*P_MESH-1:0] mesh_flit_in_all [NXY-1:0];
wire [P_MESH-1:0] mesh_flit_out_wr_all [NXY-1:0];
wire [FW*P_MESH-1:0] mesh_flit_out_all [NXY-1:0];
wire [P_MESH-1:0] mesh_credit_in_all [NXY-1:0];
wire [P_MESH-1:0] mesh_credit_out_all [NXY-1:0];

// hier2 connect: [each port],[each router]
wire [P_HIER-1:0] hier2_flit_in_wr_all [NXY-1:0];
wire [FW*P_HIER-1:0] hier2_flit_in_all [NXY-1:0];
wire [P_HIER-1:0] hier2_flit_out_wr_all [NXY-1:0];
wire [FW*P_HIER-1:0] hier2_flit_out_all [NXY-1:0];
wire [P_HIER-1:0] hier2_credit_in_all [NXY-1:0];
wire [P_HIER-1:0] hier2_credit_out_all [NXY-1:0];

// hier1 connect: [each port],[each router]
wire [P_HIER-1:0] hier1_flit_in_wr_all [NXYR2-1:0];
wire [FW*P_HIER-1:0] hier1_flit_in_all [NXYR2-1:0];
wire [P_HIER-1:0] hier1_flit_out_wr_all [NXYR2-1:0];
wire [FW*P_HIER-1:0] hier1_flit_out_all [NXYR2-1:0];
wire [P_HIER-1:0] hier1_credit_in_all [NXYR2-1:0];
wire [P_HIER-1:0] hier1_credit_out_all [NXYR2-1:0];
wire [P_HIER-2:0] current_r1 [P_HIER-2:0]; // exclude P0

// node connect:
wire node_flit_in_wr_all [NXYR2R1-1:0];
wire [FW-1:0] node_flit_in_all [NXYR2R1-1:0];
wire node_flit_out_wr_all [NXYR2R1-1:0];
wire [FW-1:0] node_flit_out_all [NXYR2R1-1:0];
wire node_credit_in_all [NXYR2R1-1:0];
wire node_credit_out_all [NXYR2R1-1:0];

genvar x,y,i,j,k;
generate

    for (x=0; x<NX; x=x+1) begin : x_loop
        for (y=0; y<NY; y=y+1) begin : y_loop

            // router_mesh
            router #(
                .FW(FW),
                .P(P_MESH),
                .B(B),
                .XW(XW),
                .YW(YW),
                .TOPOLOGY("MESH")
            )
            router_mesh
            (
                // system signal
                .clk(clk),
                .rst_n(rst_n),
                // flit
                .flit_in_wr_all(mesh_flit_in_wr_all[`ROUTER2_NUM(x,y)]),
                .flit_in_all(mesh_flit_in_all[`ROUTER2_NUM(x,y)]),
                .flit_out_wr_all(mesh_flit_out_wr_all[`ROUTER2_NUM(x,y)]),
                .flit_out_all(mesh_flit_out_all[`ROUTER2_NUM(x,y)]),
                // credit
                .credit_in_all(mesh_credit_in_all[`ROUTER2_NUM(x,y)]),
                .credit_out_all(mesh_credit_out_all[`ROUTER2_NUM(x,y)]),
                // current node
                .current_r2(1'b0),
                .current_r1({(P_MESH-1){1'b0}})
            );
            // mesh connect
            if (x < NX-1) begin : not_last_x
                assign mesh_flit_in_wr_all [`ROUTER2_SELECT_WIRE(x,y,E,1)] = mesh_flit_out_wr_all [`ROUTER2_SELECT_WIRE((x+1),y,W,1)];
                assign mesh_flit_in_all [`ROUTER2_SELECT_WIRE(x,y,E,FW)] = mesh_flit_out_all [`ROUTER2_SELECT_WIRE((x+1),y,W,FW)];
                assign mesh_credit_in_all [`ROUTER2_SELECT_WIRE(x,y,E,1)] = mesh_credit_out_all [`ROUTER2_SELECT_WIRE((x+1),y,W,1)];
            end
            else begin : last_x
                assign mesh_flit_in_wr_all [`ROUTER2_SELECT_WIRE(x,y,E,1)] = flit_in_wr [`CONNECT_SELECT_WIRE(y,E,1)];
                assign mesh_flit_in_all [`ROUTER2_SELECT_WIRE(x,y,E,FW)] = flit_in [`CONNECT_SELECT_WIRE(y,E,FW)];
                assign mesh_credit_in_all [`ROUTER2_SELECT_WIRE(x,y,E,1)] = credit_in [`CONNECT_SELECT_WIRE(y,E,1)];
                assign flit_out_wr [`CONNECT_SELECT_WIRE(y,E,1)] = mesh_flit_out_wr_all [`ROUTER2_SELECT_WIRE(x,y,E,1)];
                assign flit_out [`CONNECT_SELECT_WIRE(y,E,FW)] = mesh_flit_out_all [`ROUTER2_SELECT_WIRE(x,y,E,FW)];
                assign credit_out [`CONNECT_SELECT_WIRE(y,E,1)] = mesh_credit_out_all [`ROUTER2_SELECT_WIRE(x,y,E,1)];
            end
            
            if (x > 0) begin : not_first_x
                assign mesh_flit_in_wr_all [`ROUTER2_SELECT_WIRE(x,y,W,1)] = mesh_flit_out_wr_all [`ROUTER2_SELECT_WIRE((x-1),y,E,1)];
                assign mesh_flit_in_all [`ROUTER2_SELECT_WIRE(x,y,W,FW)] = mesh_flit_out_all [`ROUTER2_SELECT_WIRE((x-1),y,E,FW)];
                assign mesh_credit_in_all [`ROUTER2_SELECT_WIRE(x,y,W,1)] = mesh_credit_out_all [`ROUTER2_SELECT_WIRE((x-1),y,E,1)];
            end
            else begin : first_x
                assign mesh_flit_in_wr_all [`ROUTER2_SELECT_WIRE(x,y,W,1)] = flit_in_wr [`CONNECT_SELECT_WIRE(y,W,1)];
                assign mesh_flit_in_all [`ROUTER2_SELECT_WIRE(x,y,W,FW)] = flit_in [`CONNECT_SELECT_WIRE(y,W,FW)];
                assign mesh_credit_in_all [`ROUTER2_SELECT_WIRE(x,y,W,1)] = credit_in [`CONNECT_SELECT_WIRE(y,W,1)];
                assign flit_out_wr [`CONNECT_SELECT_WIRE(y,W,1)] = mesh_flit_out_wr_all [`ROUTER2_SELECT_WIRE(x,y,W,1)];
                assign flit_out [`CONNECT_SELECT_WIRE(y,W,FW)] = mesh_flit_out_all [`ROUTER2_SELECT_WIRE(x,y,W,FW)];
                assign credit_out [`CONNECT_SELECT_WIRE(y,W,1)] = mesh_credit_out_all [`ROUTER2_SELECT_WIRE(x,y,W,1)];
            end

            if (y < NY-1) begin : not_last_y
                assign mesh_flit_in_wr_all [`ROUTER2_SELECT_WIRE(x,y,S,1)] = mesh_flit_out_wr_all [`ROUTER2_SELECT_WIRE(x,(y+1),N,1)];
                assign mesh_flit_in_all [`ROUTER2_SELECT_WIRE(x,y,S,FW)] = mesh_flit_out_all [`ROUTER2_SELECT_WIRE(x,(y+1),N,FW)];
                assign mesh_credit_in_all [`ROUTER2_SELECT_WIRE(x,y,S,1)] = mesh_credit_out_all [`ROUTER2_SELECT_WIRE(x,(y+1),N,1)];
            end
            else begin : last_y
                assign mesh_flit_in_wr_all [`ROUTER2_SELECT_WIRE(x,y,S,1)] = flit_in_wr [`CONNECT_SELECT_WIRE(x,S,1)];
                assign mesh_flit_in_all [`ROUTER2_SELECT_WIRE(x,y,S,FW)] = flit_in [`CONNECT_SELECT_WIRE(x,S,FW)];
                assign mesh_credit_in_all [`ROUTER2_SELECT_WIRE(x,y,S,1)] = credit_in [`CONNECT_SELECT_WIRE(x,S,1)];
                assign flit_out_wr [`CONNECT_SELECT_WIRE(x,S,1)] = mesh_flit_out_wr_all [`ROUTER2_SELECT_WIRE(x,y,S,1)];
                assign flit_out [`CONNECT_SELECT_WIRE(x,S,FW)] = mesh_flit_out_all [`ROUTER2_SELECT_WIRE(x,y,S,FW)];
                assign credit_out [`CONNECT_SELECT_WIRE(x,S,1)] = mesh_credit_out_all [`ROUTER2_SELECT_WIRE(x,y,S,1)];
            end
            
            if (y > 0) begin : not_first_y
                assign mesh_flit_in_wr_all [`ROUTER2_SELECT_WIRE(x,y,N,1)] = mesh_flit_out_wr_all [`ROUTER2_SELECT_WIRE(x,(y-1),S,1)];
                assign mesh_flit_in_all [`ROUTER2_SELECT_WIRE(x,y,N,FW)] = mesh_flit_out_all [`ROUTER2_SELECT_WIRE(x,(y-1),S,FW)];
                assign mesh_credit_in_all [`ROUTER2_SELECT_WIRE(x,y,N,1)] = mesh_credit_out_all [`ROUTER2_SELECT_WIRE(x,(y-1),S,1)];
            end
            else begin : first_y
                assign mesh_flit_in_wr_all [`ROUTER2_SELECT_WIRE(x,y,N,1)] = flit_in_wr [`CONNECT_SELECT_WIRE(x,N,1)];
                assign mesh_flit_in_all [`ROUTER2_SELECT_WIRE(x,y,N,FW)] = flit_in [`CONNECT_SELECT_WIRE(x,N,FW)];
                assign mesh_credit_in_all [`ROUTER2_SELECT_WIRE(x,y,N,1)] = credit_in [`CONNECT_SELECT_WIRE(x,N,1)];
                assign flit_out_wr [`CONNECT_SELECT_WIRE(x,N,1)] = mesh_flit_out_wr_all [`ROUTER2_SELECT_WIRE(x,y,N,1)];
                assign flit_out [`CONNECT_SELECT_WIRE(x,N,FW)] = mesh_flit_out_all [`ROUTER2_SELECT_WIRE(x,y,N,FW)];
                assign credit_out [`CONNECT_SELECT_WIRE(x,N,1)] = mesh_credit_out_all [`ROUTER2_SELECT_WIRE(x,y,N,1)];
            end

            // router_hier2
            router #(
                .FW(FW),
                .P(P_HIER),
                .B(B),
                .XW(XW),
                .YW(YW),
                .TOPOLOGY("HIER")
            )
            router_hier2
            (
                // system signal
                .clk(clk),
                .rst_n(rst_n),
                // flit
                .flit_in_wr_all(hier2_flit_in_wr_all[`ROUTER2_NUM(x,y)]),
                .flit_in_all(hier2_flit_in_all[`ROUTER2_NUM(x,y)]),
                .flit_out_wr_all(hier2_flit_out_wr_all[`ROUTER2_NUM(x,y)]),
                .flit_out_all(hier2_flit_out_all[`ROUTER2_NUM(x,y)]),
                // credit
                .credit_in_all(hier2_credit_in_all[`ROUTER2_NUM(x,y)]),
                .credit_out_all(hier2_credit_out_all[`ROUTER2_NUM(x,y)]),
                // current node
                .current_r2(1'b1), // current is r2
                .current_r1({(P_HIER-1){1'b0}})
            );

            // hier2 connect
            assign hier2_flit_in_wr_all[`ROUTER2_SELECT_WIRE(x,y,P0,1)] = mesh_flit_out_wr_all[`ROUTER2_SELECT_WIRE(x,y,L,1)];
            assign hier2_flit_in_all[`ROUTER2_SELECT_WIRE(x,y,P0,FW)] = mesh_flit_out_all[`ROUTER2_SELECT_WIRE(x,y,L,FW)];
            assign mesh_flit_in_wr_all[`ROUTER2_SELECT_WIRE(x,y,L,1)] = hier2_flit_out_wr_all[`ROUTER2_SELECT_WIRE(x,y,P0,1)];
            assign mesh_flit_in_all[`ROUTER2_SELECT_WIRE(x,y,L,FW)] = hier2_flit_out_all[`ROUTER2_SELECT_WIRE(x,y,P0,FW)];
            assign hier2_credit_in_all[`ROUTER2_SELECT_WIRE(x,y,P0,1)] = mesh_credit_out_all[`ROUTER2_SELECT_WIRE(x,y,L,1)];
            assign mesh_credit_in_all[`ROUTER2_SELECT_WIRE(x,y,L,1)] = hier2_credit_out_all[`ROUTER2_SELECT_WIRE(x,y,P0,1)];


            for (i=0; i<NR2; i=i+1) begin : r2_loop

                for (k=0; k<NR2; k=k+1) begin
                    assign current_r1[i][k] = (i == k);
                end

                // router_hier1
                router #(
                .FW(FW),
                .P(P_HIER),
                .B(B),
                .XW(XW),
                .YW(YW),
                .TOPOLOGY("HIER")
                )
                router_hier1
                (
                    // system signal
                    .clk(clk),
                    .rst_n(rst_n),
                    // flit
                    .flit_in_wr_all(hier1_flit_in_wr_all[`ROUTER1_NUM(x,y,i)]),
                    .flit_in_all(hier1_flit_in_all[`ROUTER1_NUM(x,y,i)]),
                    .flit_out_wr_all(hier1_flit_out_wr_all[`ROUTER1_NUM(x,y,i)]),
                    .flit_out_all(hier1_flit_out_all[`ROUTER1_NUM(x,y,i)]),
                    // credit
                    .credit_in_all(hier1_credit_in_all[`ROUTER1_NUM(x,y,i)]),
                    .credit_out_all(hier1_credit_out_all[`ROUTER1_NUM(x,y,i)]),
                    // current node
                    .current_r2(1'b0), // current is not r2
                    .current_r1(current_r1[i])
                );

                // hier1 connect
                assign hier1_flit_in_wr_all[`ROUTER1_SELECT_WIRE(x,y,i,P0,1)] = hier2_flit_out_wr_all[`ROUTER2_SELECT_WIRE(x,y,(i+1),1)];
                assign hier1_flit_in_all[`ROUTER1_SELECT_WIRE(x,y,i,P0,FW)] = hier2_flit_out_all[`ROUTER2_SELECT_WIRE(x,y,(i+1),FW)];
                assign hier2_flit_in_wr_all[`ROUTER2_SELECT_WIRE(x,y,(i+1),1)] = hier1_flit_out_wr_all[`ROUTER1_SELECT_WIRE(x,y,i,P0,1)];
                assign hier2_flit_in_all[`ROUTER2_SELECT_WIRE(x,y,(i+1),FW)] = hier1_flit_out_all[`ROUTER1_SELECT_WIRE(x,y,i,P0,FW)];
                assign hier1_credit_in_all[`ROUTER1_SELECT_WIRE(x,y,i,P0,1)] = hier2_credit_out_all[`ROUTER2_SELECT_WIRE(x,y,(i+1),1)];
                assign hier2_credit_in_all[`ROUTER2_SELECT_WIRE(x,y,(i+1),1)] = hier1_credit_out_all[`ROUTER1_SELECT_WIRE(x,y,i,P0,1)];

                for (j=0; j<NR1; j=j+1) begin : r1_loop

                    // node
                    node #(
                        .FW(FW)
                    )
                    node_top
                    (
                        // system signal
                        .clk(clk),
                        .rst_n(rst_n),
                        // ctrl
                        .tik(tik),
                        // credit
                        .credit_in(node_credit_in_all[`NODE_NUM(x,y,i,j)]),
                        .credit_out(node_credit_out_all[`NODE_NUM(x,y,i,j)]),
                        // flit
                        .flit_in_wr(node_flit_in_wr_all[`NODE_NUM(x,y,i,j)]),
                        .flit_in(node_flit_in_all[`NODE_NUM(x,y,i,j)]),
                        .flit_out_wr(node_flit_out_wr_all[`NODE_NUM(x,y,i,j)]),
                        .flit_out(node_flit_out_all[`NODE_NUM(x,y,i,j)])
                    );

                    // node connect
                    assign node_flit_in_wr_all[`NODE_NUM(x,y,i,j)] = hier1_flit_out_wr_all[`ROUTER1_SELECT_WIRE(x,y,i,(j+1),1)];
                    assign node_flit_in_all[`NODE_NUM(x,y,i,j)] = hier1_flit_out_all[`ROUTER1_SELECT_WIRE(x,y,i,(j+1),FW)];
                    assign hier1_flit_in_wr_all[`ROUTER1_SELECT_WIRE(x,y,i,(j+1),1)] = node_flit_out_wr_all[`NODE_NUM(x,y,i,j)];
                    assign hier1_flit_in_all[`ROUTER1_SELECT_WIRE(x,y,i,(j+1),FW)] = node_flit_out_all[`NODE_NUM(x,y,i,j)];
                    assign node_credit_in_all[`NODE_NUM(x,y,i,j)] = hier1_credit_out_all[`ROUTER1_SELECT_WIRE(x,y,i,(j+1),1)];
                    assign hier1_credit_in_all[`ROUTER1_SELECT_WIRE(x,y,i,(j+1),1)] = node_credit_out_all[`NODE_NUM(x,y,i,j)];

                end // r1

            end // r2

        end // y
    end // x
    
endgenerate

endmodule