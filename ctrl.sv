/***************************************************/
/* ECE 327: Digital Hardware Systems - Spring 2025 */
/* Lab 4                                           */
/* MVM Control FSM                                 */
/***************************************************/

module ctrl #(
    parameter VEC_ADDRW = 8,
    parameter MAT_ADDRW = 9,
    parameter VEC_SIZEW = VEC_ADDRW + 1,
    parameter MAT_SIZEW = MAT_ADDRW + 1
) (
    input clk,
    input rst,
    input start,
    input [VEC_ADDRW-1:0] vec_start_addr,
    input [VEC_SIZEW-1:0] vec_num_words,
    input [MAT_ADDRW-1:0] mat_start_addr,
    input [MAT_SIZEW-1:0] mat_num_rows_per_olane,
    output [VEC_ADDRW-1:0] vec_raddr,
    output [MAT_ADDRW-1:0] mat_raddr,
    output accum_first,
    output accum_last,
    output ovalid,
    output busy
);

    // FSM states
    typedef enum logic [1:0] {
        IDLE,
        WAIT,
        COMPUTE
    } state_t;
    state_t state, next_state;

    // Latched input parameters
    logic [VEC_ADDRW-1:0] vec_start_addr_r;
    logic [VEC_SIZEW-1:0] vec_num_words_r;
    logic [MAT_ADDRW-1:0] mat_start_addr_r;
    logic [MAT_SIZEW-1:0] mat_num_rows_per_olane_r;

    // Counters
    logic [VEC_SIZEW-1:0] vec_idx, next_vec_idx;
    logic [MAT_SIZEW-1:0] mat_row_idx, next_mat_row_idx;

    // Wait counter for two-cycle memory latency
    logic [1:0] wait_counter, next_wait_counter;

    // Three-stage pipeline registers for address and control signal pipelining
    logic [VEC_SIZEW-1:0] vec_idx_pipe1, vec_idx_pipe2, vec_idx_pipe3;
    logic [MAT_SIZEW-1:0] mat_row_idx_pipe1, mat_row_idx_pipe2, mat_row_idx_pipe3;
    logic [MAT_ADDRW-1:0] mat_row_base_pipe1, mat_row_base_pipe2, mat_row_base_pipe3;
    logic accum_first_pipe1, accum_first_pipe2, accum_first_pipe3;
    logic accum_last_pipe1, accum_last_pipe2, accum_last_pipe3;
    logic ovalid_pipe1, ovalid_pipe2, ovalid_pipe3;

    // Output registers
    logic [VEC_ADDRW-1:0] vec_raddr_reg;
    logic [MAT_ADDRW-1:0] mat_raddr_reg;
    logic accum_first_reg;
    logic accum_last_reg;
    logic ovalid_reg;
    logic busy_reg;

    // FSM and pipeline registers
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            vec_start_addr_r <= '0;
            vec_num_words_r <= '0;
            mat_start_addr_r <= '0;
            mat_num_rows_per_olane_r <= '0;
            vec_idx <= '0;
            mat_row_idx <= '0;
            wait_counter <= 2'b00;
            vec_idx_pipe1 <= '0;
            vec_idx_pipe2 <= '0;
            vec_idx_pipe3 <= '0;
            mat_row_idx_pipe1 <= '0;
            mat_row_idx_pipe2 <= '0;
            mat_row_idx_pipe3 <= '0;
            mat_row_base_pipe1 <= '0;
            mat_row_base_pipe2 <= '0;
            mat_row_base_pipe3 <= '0;
            accum_first_pipe1 <= 1'b0;
            accum_first_pipe2 <= 1'b0;
            accum_first_pipe3 <= 1'b0;
            accum_last_pipe1 <= 1'b0;
            accum_last_pipe2 <= 1'b0;
            accum_last_pipe3 <= 1'b0;
            ovalid_pipe1 <= 1'b0;
            ovalid_pipe2 <= 1'b0;
            ovalid_pipe3 <= 1'b0;
        end else begin
            state <= next_state;
            vec_idx <= next_vec_idx;
            mat_row_idx <= next_mat_row_idx;
            wait_counter <= next_wait_counter;

            // Latch input parameters at start
            if (state == IDLE) begin
                vec_start_addr_r <= vec_start_addr;
                vec_num_words_r <= vec_num_words;
                mat_start_addr_r <= mat_start_addr;
                mat_num_rows_per_olane_r <= mat_num_rows_per_olane;
            end

            // Three-stage pipelining for all relevant signals

            // Stage 1
            vec_idx_pipe1      <= vec_idx;
            mat_row_idx_pipe1  <= mat_row_idx;
            mat_row_base_pipe1 <= mat_row_idx * vec_num_words_r;
            accum_first_pipe1  <= (state == COMPUTE) && (vec_idx == 0);
            accum_last_pipe1   <= (state == COMPUTE) && (vec_idx == vec_num_words_r - 1);
            ovalid_pipe1       <= (state == COMPUTE);

            // Stage 2
            vec_idx_pipe2      <= vec_idx_pipe1;
            mat_row_idx_pipe2  <= mat_row_idx_pipe1;
            mat_row_base_pipe2 <= mat_start_addr_r + mat_row_base_pipe1;
            accum_first_pipe2  <= accum_first_pipe1;
            accum_last_pipe2   <= accum_last_pipe1;
            ovalid_pipe2       <= ovalid_pipe1;

            // Stage 3
            vec_idx_pipe3      <= vec_idx_pipe2;
            mat_row_idx_pipe3  <= mat_row_idx_pipe2;
            mat_row_base_pipe3 <= mat_row_base_pipe2;
            accum_first_pipe3  <= accum_first_pipe2;
            accum_last_pipe3   <= accum_last_pipe2;
            ovalid_pipe3       <= ovalid_pipe2;
        end
    end

    // State transition logic
    always_comb begin
        case (state)
            IDLE: next_state = (start) ? WAIT : IDLE;
            WAIT: next_state = (wait_counter == 2) ? COMPUTE : WAIT;
            COMPUTE:
            next_state = ((vec_idx == vec_num_words_r - 1) && (mat_row_idx == mat_num_rows_per_olane_r - 1)) ? IDLE : COMPUTE;
            default: next_state = IDLE;
        endcase
    end

    // Counter and output logic
    always_comb begin
        // Default assignments
        next_vec_idx = vec_idx;
        next_mat_row_idx = mat_row_idx;
        next_wait_counter = wait_counter;
        busy_reg = 1'b0;

        case (state)
            WAIT: begin
                busy_reg = 1'b1;
                next_wait_counter = wait_counter + 1;
            end
            COMPUTE: begin
                busy_reg = 1'b1;
                next_wait_counter = 0;

                // Counter update logic
                if (vec_idx == vec_num_words_r - 1) begin
                    if (mat_row_idx == mat_num_rows_per_olane_r - 1) begin
                        next_vec_idx = 0;
                        next_mat_row_idx = 0;
                    end else begin
                        next_vec_idx = 0;
                        next_mat_row_idx = mat_row_idx + 1;
                    end
                end else begin
                    next_vec_idx = vec_idx + 1;
                    next_mat_row_idx = mat_row_idx;
                end
            end
            default: begin
                next_vec_idx = 0;
                next_mat_row_idx = 0;
                next_wait_counter = 0;
            end
        endcase
    end

    // Address generation (pipelined)
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            vec_raddr_reg   <= '0;
            mat_raddr_reg   <= '0;
            accum_first_reg <= 1'b0;
            accum_last_reg  <= 1'b0;
            ovalid_reg      <= 1'b0;
        end else begin
            // Use pipelined indices for address calculation
            vec_raddr_reg   <= vec_start_addr_r + vec_idx_pipe3;
            mat_raddr_reg   <= mat_row_base_pipe3 + vec_idx_pipe3;
            accum_first_reg <= accum_first_pipe3;
            accum_last_reg  <= accum_last_pipe3;
            ovalid_reg      <= ovalid_pipe3;
        end
    end

    // Output assignments
    assign vec_raddr   = vec_raddr_reg;
    assign mat_raddr   = mat_raddr_reg;
    assign accum_first = accum_first_reg;
    assign accum_last  = accum_last_reg;
    assign ovalid      = ovalid_reg;
    assign busy        = busy_reg;

    /******* Your code ends here ********/

endmodule
