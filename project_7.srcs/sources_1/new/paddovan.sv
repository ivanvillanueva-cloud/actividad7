`timescale 1ns / 1ps

module padovan_unit (
    input  logic        clk,
    input  logic        reset,
    input  logic        start,
    input  logic [7:0]  n,
    output logic [31:0] result,
    output logic        done
);
    typedef enum logic [1:0] {IDLE, INIT, LOOP, FINISH} state_t;
    state_t state;

    logic [31:0] p0, p1, p2;
    logic [7:0]  i;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state  <= IDLE;
            result <= 32'd0;
            done   <= 1'b0;
        end else begin
            done <= 1'b0;
            case (state)
                IDLE: begin
                    if (start)
                        state <= INIT;
                end

                INIT: begin
                    p0 <= 32'd1;
                    p1 <= 32'd1;
                    p2 <= 32'd1;
                    i  <= 8'd3;
                    if (n == 0 || n == 1 || n == 2) begin
                        result <= 32'd1;
                        state  <= FINISH;
                    end else begin
                        state <= LOOP;
                    end
                end

                LOOP: begin
                    if (i <= n) begin
                        logic [31:0] new_p;
                        new_p = p0 + p1;
                        p0 <= p1;
                        p1 <= p2;
                        p2 <= new_p;
                        i  <= i + 1;
                        if (i == n) begin
                            result <= new_p;
                            state  <= FINISH;
                        end
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
