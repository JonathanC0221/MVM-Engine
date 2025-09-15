/***************************************************/
/* ECE 327: Digital Hardware Systems - Spring 2025 */
/* Lab 4                                           */
/* Matrix Vector Multiplication (MVM) Module       */
/***************************************************/

module mvm #(
    parameter IWIDTH = 8,
    parameter OWIDTH = 32,
    parameter MEM_DATAW = IWIDTH * 8,
    parameter VEC_MEM_DEPTH = 256,
    parameter VEC_ADDRW = $clog2(VEC_MEM_DEPTH),
    parameter MAT_MEM_DEPTH = 512,
    parameter MAT_ADDRW = $clog2(MAT_MEM_DEPTH),
    parameter NUM_OLANES = 8
) (
    input clk,
    input rst,
    input [MEM_DATAW-1:0] i_vec_wdata,
    input [VEC_ADDRW-1:0] i_vec_waddr,
    input i_vec_wen,
    input [MEM_DATAW-1:0] i_mat_wdata,
    input [MAT_ADDRW-1:0] i_mat_waddr,
    input [NUM_OLANES-1:0] i_mat_wen,
    input i_start,
    input [VEC_ADDRW-1:0] i_vec_start_addr,
    input [VEC_ADDRW:0] i_vec_num_words,
    input [MAT_ADDRW-1:0] i_mat_start_addr,
    input [MAT_ADDRW:0] i_mat_num_rows_per_olane,
    output o_busy,
    output [OWIDTH-1:0] o_result[0:NUM_OLANES-1],
    output o_valid
);

    /******* Your code starts here *******/
    genvar i;
    logic first;
    logic last;
    logic first_pipe[6];
    logic last_pipe[6];
    logic ctrl_valid;
    logic dot_valid[NUM_OLANES];
    logic [NUM_OLANES-1:0] accum_valid;
    logic busy;
    logic [VEC_ADDRW-1:0] vec_raddr;
    logic [MEM_DATAW-1:0] vec_rdata;
    logic [MAT_ADDRW-1:0] mat_raddr;
    logic [MEM_DATAW-1:0] mat_rdata[NUM_OLANES];
    logic signed [OWIDTH-1:0] results[NUM_OLANES];
    logic [OWIDTH-1:0] final_results[NUM_OLANES];

    ctrl #(
        .VEC_ADDRW(VEC_ADDRW),
        .MAT_ADDRW(MAT_ADDRW),
        .VEC_SIZEW(VEC_ADDRW + 1),
        .MAT_SIZEW(MAT_ADDRW + 1)
    ) ctrl_inst (
        .clk(clk),
        .rst(rst),
        .start(i_start),
        .vec_start_addr(i_vec_start_addr),
        .vec_num_words(i_vec_num_words),
        .mat_start_addr(i_mat_start_addr),
        .mat_num_rows_per_olane(i_mat_num_rows_per_olane),
        .vec_raddr(vec_raddr),
        .mat_raddr(mat_raddr),
        .accum_first(first),
        .accum_last(last),
        .ovalid(ctrl_valid),
        .busy(busy)
    );

    mem #(
        .DATAW(MEM_DATAW),
        .DEPTH(VEC_MEM_DEPTH),
        .ADDRW(VEC_ADDRW)
    ) mem_inst (
        .clk  (clk),
        .wdata(i_vec_wdata),
        .waddr(i_vec_waddr),
        .wen  (i_vec_wen),
        .raddr(vec_raddr),
        .rdata(vec_rdata)
    );

    generate
        for (i = 0; i < NUM_OLANES; i = i + 1) begin : lanes
            mem #(
                .DATAW(MEM_DATAW),
                .DEPTH(MAT_MEM_DEPTH),
                .ADDRW(MAT_ADDRW)
            ) mem_insts (
                .clk  (clk),
                .wdata(i_mat_wdata),
                .waddr(i_mat_waddr),
                .wen  (i_mat_wen[i]),
                .raddr(mat_raddr),
                .rdata(mat_rdata[i])
            );

            dot8 #(
                .IWIDTH(IWIDTH),
                .OWIDTH(IWIDTH*2+2)
            ) dot_inst (
                .clk(clk),
                .rst(rst),
                .vec0(vec_rdata),
                .vec1(mat_rdata[i]),
                .ivalid(ctrl_valid),
                .result(results[i]),
                .ovalid(dot_valid[i])
            );

            accum #(
                .DATAW (IWIDTH*2+2),
                .ACCUMW(OWIDTH)
            ) accum_inst (
                .clk(clk),
                .rst(rst),
                .data(results[i]),
                .ivalid(dot_valid[i]),
                .first(first_pipe[5]),
                .last(last_pipe[5]),
                .result(final_results[i]),
                .ovalid(accum_valid[i])
            );
        end
    endgenerate
    
    always_ff @(posedge clk) begin
        if (rst) begin
            for(int i=0; i<6; i++) begin
                first_pipe[i] <= 0;
                last_pipe[i] <= 0;
            end
        end else
            for(int i=1; i<6; i++) begin
                first_pipe[0] <= first;
                last_pipe[0] <= last;
                first_pipe[i] <= first_pipe[i-1];
                last_pipe[i] <= last_pipe[i-1];
            end
        end

    assign o_result = final_results;
    assign o_valid = &accum_valid;
    assign o_busy  = busy;

    /******* Your code ends here ********/

endmodule
