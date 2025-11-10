module Tx #(
    parameter integer CLOCK_FREQ = 100_000_000,
    parameter integer BAUD_RATE  = 115200
) (
    input  logic        clk,
    input  logic        reset,
    input  logic        ready,      // pulso o nivel: "quiero enviar este byte"
    input  logic [7:0]  tx_data,
    output logic        TxD,
    output logic        tdre        // 1 = listo para nuevo dato
);

    // ------------------------------------------------------------
    // Cálculo del divisor de baud (solo enteros)
    // ------------------------------------------------------------
    // ciclos por bit = clk / baud
    localparam integer CYCLES_PER_BIT = (CLOCK_FREQ + BAUD_RATE - 1) / BAUD_RATE; // ceil
    localparam integer BAUD_MAX       = (CYCLES_PER_BIT > 0) ? (CYCLES_PER_BIT - 1) : 0;
    localparam integer BAUD_CNT_WIDTH = $clog2(BAUD_MAX + 1);

    // ------------------------------------------------------------
    // FSM
    // ------------------------------------------------------------
    typedef enum logic [1:0] {
        S_MARK,   // línea en reposo
        S_START,  // bit de inicio
        S_DATA,   // 8 bits
        S_STOP    // bit de parada
    } state_t;

    state_t state, next_state;

    // registros
    logic [7:0] txbuff;
    logic [2:0] bit_count;
    logic [BAUD_CNT_WIDTH-1:0] baud_count;

    // sincronizar ready (por si viene de botón)
    logic ready_sync;
    always_ff @(posedge clk or posedge reset) begin
        if (reset)
            ready_sync <= 1'b0;
        else
            ready_sync <= ready;
    end

    // ------------------------------------------------------------
    // Registro de estado
    // ------------------------------------------------------------
    always_ff @(posedge clk or posedge reset) begin
        if (reset)
            state <= S_MARK;
        else
            state <= next_state;
    end

    // ------------------------------------------------------------
    // Lógica de próximo estado
    // ------------------------------------------------------------
    always_comb begin
        next_state = state;
        case (state)
            S_MARK: begin
                // solo salgo si me piden enviar Y estoy libre
                if (ready_sync && tdre)
                    next_state = S_START;
            end

            S_START: begin
                if (baud_count == BAUD_MAX)
                    next_state = S_DATA;
            end

            S_DATA: begin
                if ((baud_count == BAUD_MAX) && (bit_count == 3'd7))
                    next_state = S_STOP;
            end

            S_STOP: begin
                if (baud_count == BAUD_MAX)
                    next_state = S_MARK;
            end

            default: next_state = S_MARK;
        endcase
    end

    // ------------------------------------------------------------
    // Datapath y salidas
    // ------------------------------------------------------------
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            TxD        <= 1'b1;
            tdre       <= 1'b1;
            baud_count <= '0;
            bit_count  <= '0;
            txbuff     <= '0;
        end else begin
            case (state)
                // ------------------------------------------------
                // Línea en reposo
                // ------------------------------------------------
                S_MARK: begin
                    TxD        <= 1'b1;
                    baud_count <= '0;
                    bit_count  <= '0;

                    // si me están pidiendo enviar y estoy libre...
                    if (ready_sync && tdre) begin
                        txbuff <= tx_data;  // cargo el dato
                        tdre   <= 1'b0;     // ya no estoy libre
                    end else begin
                        tdre   <= 1'b1;     // sigo libre
                    end
                end

                // ------------------------------------------------
                // Bit de inicio
                // ------------------------------------------------
                S_START: begin
                    TxD <= 1'b0; // start bit
                    if (baud_count == BAUD_MAX) begin
                        baud_count <= '0;
                    end else begin
                        baud_count <= baud_count + 1;
                    end
                end

                // ------------------------------------------------
                // Bits de datos (LSB primero)
                // ------------------------------------------------
                S_DATA: begin
                    TxD <= txbuff[0]; // sacar LSB
                    if (baud_count == BAUD_MAX) begin
                        baud_count <= '0;
                        // shift right, metiendo 0 arriba (no importa, ya no se usa)
                        txbuff    <= {1'b0, txbuff[7:1]};
                        bit_count <= bit_count + 1;
                    end else begin
                        baud_count <= baud_count + 1;
                    end
                end

                // ------------------------------------------------
                // Bit de parada
                // ------------------------------------------------
                S_STOP: begin
                    TxD <= 1'b1; // stop bit
                    if (baud_count == BAUD_MAX) begin
                        baud_count <= '0;
                        tdre       <= 1'b1; // ya estoy listo otra vez
                    end else begin
                        baud_count <= baud_count + 1;
                    end
                end

                default: begin
                    TxD        <= 1'b1;
                    tdre       <= 1'b1;
                    baud_count <= '0;
                    bit_count  <= '0;
                end
            endcase
        end
    end

endmodule
