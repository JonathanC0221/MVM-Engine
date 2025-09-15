/***************************************************/
/* ECE 327: Digital Hardware Systems - Spring 2025 */
/* Lab 4                                           */
/* 8-Lane Dot Product Module                       */
/***************************************************/

module dot8 #(
    parameter IWIDTH = 8,
    parameter OWIDTH = 32
) (
    input clk,
    input rst,
    input signed [8*IWIDTH-1:0] vec0,
    input signed [8*IWIDTH-1:0] vec1,
    input ivalid,
    output signed [OWIDTH-1:0] result,
    output ovalid
);

    /******* Your code starts here *******/
    logic signed [IWIDTH-1:0] a[8], b[8], aa[8], bb[8];
    logic signed [2*IWIDTH-1:0] y1[8];
    logic signed [2*IWIDTH:0] y2[4];
    logic signed [2*IWIDTH+1:0] y3[2];
    logic signed [2*IWIDTH+2:0] y;

    logic r_valid[6];

    always_comb begin
        for (int i = 0; i < 8; i = i + 1) begin : unpack
            aa[i] = vec0[(i+1)*IWIDTH-1-:IWIDTH];
            bb[i] = vec1[(i+1)*IWIDTH-1-:IWIDTH];
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < 8; i = i + 1) begin
                a[i] <= '0;
                b[i] <= '0;
            end
        end else begin
            for (int i = 0; i < 8; i = i + 1) begin
                a[i] <= aa[i];
                b[i] <= bb[i];
            end
        end
    end

    //Stage 1
    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < 8; i = i + 1) begin
                y1[i] <= '0;
            end
        end else begin
            for (int i = 0; i < 8; i = i + 1) begin
                y1[i] <= a[i] * b[i];
            end
        end
    end

    //Stage 2
    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < 4; i = i + 1) begin
                y2[i] <= '0;
            end
        end else begin
            for (int i = 0; i < 4; i = i + 1) begin
                y2[i] <= y1[i*2] + y1[i*2+1];
            end
        end
    end

    //Stage 3
    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < 2; i = i + 1) begin
                y3[i] <= '0;
            end
        end else begin
            for (int i = 0; i < 2; i = i + 1) begin
                y3[i] <= y2[i*2] + y2[i*2+1];
            end
        end
    end

    //Stage 4
    always_ff @(posedge clk) begin
        if (rst) begin
            y <= '0;
        end else begin
            y <= y3[0] + y3[1];
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < 6; i = i + 1) begin
                r_valid[i] <= '0;
            end
        end else begin
             r_valid[0] <= ivalid;
            for (int i = 1; i < 6; i = i + 1) begin
                r_valid[i] <= r_valid[i-1];
            end
        end
    end

    assign result = $signed(y);
    assign ovalid = r_valid[5];

    /******* Your code ends here ********/

endmodule
