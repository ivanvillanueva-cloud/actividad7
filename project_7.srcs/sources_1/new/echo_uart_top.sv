`timescale 1ns / 1ps

module echo_uart_top #(
    parameter integer CLOCK_FREQ = 100_000_000,
    parameter integer BAUD_RATE  = 115200
)(
    input  logic        clk,
    input  logic        reset,
    input  logic        RxD,        // entrada serial desde PC
    output logic        TxD,        // salida serial hacia PC
    output logic [7:0]  led         // muestra el último dato recibido
);

    // ---------------------------
    // Señales del receptor
    // ---------------------------
    logic [7:0] received_data;
    logic       rx_valid;

    // ---------------------------
    // Señales del transmisor
    // ---------------------------
    logic [7:0] tx_data;
    logic       tx_ready;   // señal que le dice al TX "aquí hay dato"
    logic       tx_free;    // tdre: 1 = transmisor libre

    // ===========================
    // INSTANCIAS
    // ===========================
    // Receptor UART
    Rx #(
        .clk_freq  (CLOCK_FREQ),
        .baud_rate (BAUD_RATE)
    ) uart_rx (
        .clk_fpga   (clk),
        .reset      (reset),
        .RxD        (RxD),
        .RxData     (received_data),
        .data_valid (rx_valid)
    );

    // Transmisor UART
    Tx #(
        .CLOCK_FREQ (CLOCK_FREQ),
        .BAUD_RATE  (BAUD_RATE)
    ) uart_tx (
        .clk    (clk),
        .reset  (reset),
        .ready  (tx_ready),     // pulso/nivel de envío
        .tx_data(tx_data),
        .TxD    (TxD),
        .tdre   (tx_free)
    );

    // ===========================
    // FSM de eco
    // ===========================
    typedef enum logic [1:0] {
        IDLE,
        SEND_ECHO,
        WAIT_TX
    } state_t;

    state_t state;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state    <= IDLE;
            tx_data  <= 8'd0;
            tx_ready <= 1'b0;
        end else begin
            case (state)
                // --------------------------
                // Esperamos un byte válido
                // --------------------------
                IDLE: begin
                    tx_ready <= 1'b0;  // por si acaso
                    if (rx_valid && tx_free) begin
                        // ya llegó un byte y el TX está libre
                        tx_data  <= received_data;
                        tx_ready <= 1'b1;   // levantamos para que el TX lo tome
                        state    <= SEND_ECHO;
                    end
                end

                // --------------------------
                // Esperamos a que el TX capture el dato
                // --------------------------
                SEND_ECHO: begin
                    // Tu Tx baja tdre cuando ya agarró el dato
                    if (!tx_free) begin
                        tx_ready <= 1'b0;   // ya lo tomó, podemos bajar
                        state    <= WAIT_TX;
                    end
                end

                // --------------------------
                // Esperamos a que termine de mandar
                // --------------------------
                WAIT_TX: begin
                    if (tx_free) begin
                        // terminó de enviar, volvemos a escuchar
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Mostrar en LEDs lo último recibido
    assign led = received_data;

endmodule
