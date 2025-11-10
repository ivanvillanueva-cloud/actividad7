`timescale 1ns / 1ps

module top_cmd_uart #(
    parameter integer CLOCK_FREQ = 100_000_000,
    parameter integer BAUD_RATE  = 115200
)(
    input  logic       clk,
    input  logic       reset,
    input  logic       RxD,
    output logic       TxD,
    output logic [7:0] led
);

    // =======================
    // UART RX
    // =======================
    logic [7:0] rx_byte;
    logic       rx_valid;

    Rx #(
        .clk_freq  (CLOCK_FREQ),
        .baud_rate (BAUD_RATE)
    ) u_rx (
        .clk_fpga   (clk),
        .reset      (reset),
        .RxD        (RxD),
        .RxData     (rx_byte),
        .data_valid (rx_valid)
    );

    // =======================
    // UART TX
    // =======================
    logic [7:0] tx_data;
    logic       tx_start;
    logic       tx_free;

    Tx #(
        .CLOCK_FREQ (CLOCK_FREQ),
        .BAUD_RATE  (BAUD_RATE)
    ) u_tx (
        .clk    (clk),
        .reset  (reset),
        .ready  (tx_start),
        .tx_data(tx_data),
        .TxD    (TxD),
        .tdre   (tx_free)
    );

    // =======================
    // Parser
    // =======================
    logic       cmd_ready;
    logic       seq_sel;     // 0 padovan, 1 moser
    logic [7:0] n_value;

    command_parser u_parser (
        .clk      (clk),
        .reset    (reset),
        .rx_byte  (rx_byte),
        .rx_valid (rx_valid),
        .cmd_ready(cmd_ready),
        .seq_sel  (seq_sel),
        .n_value  (n_value)
    );

    // =======================
    // Unidades de cálculo
    // =======================
    logic        pad_start, pad_done;
    logic [31:0] pad_res;

    padovan_unit u_pad (
        .clk    (clk),
        .reset  (reset),
        .start  (pad_start),
        .n      (n_value),
        .result (pad_res),
        .done   (pad_done)
    );

    logic        mos_start, mos_done;
    logic [31:0] mos_res;

    moser_unit u_mos (
        .clk    (clk),
        .reset  (reset),
        .start  (mos_start),
        .n      (n_value),
        .result (mos_res),
        .done   (mos_done)
    );

    // =======================
    // FSM principal
    // =======================
    typedef enum logic [2:0] {
        S_WAIT_CMD,
        S_START_CALC,
        S_WAIT_CALC,
        S_SEND_B0,
        S_SEND_B1,
        S_SEND_B2,
        S_SEND_B3
    } main_state_t;

    main_state_t state;

    logic [31:0] result_reg;

    // selecciones de start
    assign pad_start = (state == S_START_CALC) && (cmd_ready) && (seq_sel == 1'b0);
    assign mos_start = (state == S_START_CALC) && (cmd_ready) && (seq_sel == 1'b1);

    // LEDs muestran el último byte recibido
    assign led = rx_byte;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state    <= S_WAIT_CMD;
            tx_data  <= 8'd0;
            tx_start <= 1'b0;
            result_reg <= 32'd0;
        end else begin
            tx_start <= 1'b0; // default

            case (state)
                S_WAIT_CMD: begin
                    if (cmd_ready) begin
                        // pasamos al cálculo
                        state <= S_START_CALC;
                    end
                end

                S_START_CALC: begin
                    // en este ciclo se activan pad_start / mos_start
                    state <= S_WAIT_CALC;
                end

                S_WAIT_CALC: begin
                    if (!seq_sel && pad_done) begin
                        result_reg <= pad_res;
                        state      <= S_SEND_B0;
                    end else if (seq_sel && mos_done) begin
                        result_reg <= mos_res;
                        state      <= S_SEND_B0;
                    end
                end

                // mandamos 4 bytes MSB -> LSB
                S_SEND_B0: begin
                    if (tx_free) begin
                        tx_data  <= result_reg[31:24];
                        tx_start <= 1'b1;
                        state    <= S_SEND_B1;
                    end
                end
                S_SEND_B1: begin
                    if (tx_free) begin
                        tx_data  <= result_reg[23:16];
                        tx_start <= 1'b1;
                        state    <= S_SEND_B2;
                    end
                end
                S_SEND_B2: begin
                    if (tx_free) begin
                        tx_data  <= result_reg[15:8];
                        tx_start <= 1'b1;
                        state    <= S_SEND_B3;
                    end
                end
                S_SEND_B3: begin
                    if (tx_free) begin
                        tx_data  <= result_reg[7:0];
                        tx_start <= 1'b1;
                        state    <= S_WAIT_CMD; // listo para otro comando
                    end
                end

                default: state <= S_WAIT_CMD;
            endcase
        end
    end

endmodule
