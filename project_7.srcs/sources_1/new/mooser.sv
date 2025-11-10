`timescale 1ns / 1ps

module moser_unit (
    input  logic        clk,
    input  logic        reset,
    input  logic        start,
    input  logic [7:0]  n,
    output logic [31:0] result,
    output logic        done
);
    // a(0)=0
    // n impar: a(n)=4*a(n/2)+1
    // n par  : a(n)=4*a(n/2)
    typedef enum logic [1:0] {IDLE, RUN, FINISH} state_t;
    state_t state;

    logic [7:0]  n_work;
    logic [31:0] acc;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state  <= IDLE;
            result <= 32'd0;
            done   <= 1'b0;
        end else begin
            done <= 1'b0;
            case (state)
                IDLE: begin
                    if (start) begin
                        if (n == 0) begin
                            result <= 32'd0;
                            state  <= FINISH;
                        end else begin
                            n_work <= n;
                            acc    <= 32'd0;
                            state  <= RUN;
                        end
                    end
                end
                RUN: begin
                    if (n_work != 0) begin
                        acc    <= (acc << 2) + (n_work[0] ? 32'd1 : 32'd0);
                        n_work <= n_work >> 1;
                    end else begin
                        result <= acc;
                        state  <= FINISH;
                    end
                end
                FINISH: begin
                    done  <= 1'b1;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
