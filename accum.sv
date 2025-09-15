/***************************************************/
/* ECE 327: Digital Hardware Systems - Spring 2025 */
/* Lab 4                                           */
/* Accumulator Module                              */
/***************************************************/

module accum #(
    parameter DATAW  = 19,
    parameter ACCUMW = 32
) (
    input clk,
    input rst,
    input signed [DATAW-1:0] data,
    input ivalid,
    input first,
    input last,
    output signed [ACCUMW-1:0] result,
    output ovalid
);

    /******* Your code starts here *******/
    logic signed [ACCUMW-1:0] accum_reg, accum_next;
    logic signed [ACCUMW-1:0] result_reg;

    logic ivalid_reg;
    logic ovalid_reg;

    always_comb begin
            if (first) accum_next = data;
            else accum_next = accum_reg + data;
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            accum_reg  <= '0;
            result_reg <= '0;
            ovalid_reg <= 1'b0;
            ivalid_reg <= 1'b0;
        end else begin
            accum_reg  <= accum_next;
            ivalid_reg <= ivalid;

            if (ivalid_reg && last) begin
                result_reg <= accum_next;
                ovalid_reg <= 1'b1;
            end else begin
                ovalid_reg <= 1'b0;
            end
        end
    end

    assign ovalid = ovalid_reg;
    assign result = $signed(result_reg);
    /******* Your code ends here ********/

endmodule
