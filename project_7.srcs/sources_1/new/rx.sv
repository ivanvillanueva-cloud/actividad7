`timescale 1ns / 1ps

module Rx (
    input  logic        clk_fpga,   
    input  logic        reset,      
    input  logic        RxD,       
    output logic [7:0]  RxData,
    output logic        data_valid      
);
    // ----------------------------------------------------------------
    // Parámetros de UART
    // ----------------------------------------------------------------
    parameter int clk_freq    = 100_000_000;
    parameter int baud_rate   = 115200;
    parameter int div_sample  = 4;   // oversampling x4
    // cuántos ciclos de clk por muestra
    parameter int div_counter = clk_freq / (baud_rate * div_sample);
    parameter int mid_sample  = div_sample / 2;
    parameter int div_bit     = 10;  // 1 start + 8 data + 1 stop

    // ----------------------------------------------------------------
    // FSM
    // ----------------------------------------------------------------
    typedef enum logic {IDLE=0, RECEIVING=1} state_t;
    state_t state, nextstate;

    // Contadores
    logic [3:0]  bit_counter;        // cuenta bits recibidos (0..9)
    logic [1:0]  sample_counter;     // cuenta las muestras dentro del bit (0..3)
    logic [13:0] baudrate_counter;   // divide el clk a la frecuencia de muestreo
    logic [9:0]  rxshift_reg;        // start + 8 + stop

    // Control desde la FSM
    logic shift;
    logic clear_bitcounter, inc_bitcounter;
    logic clear_samplecounter, inc_samplecounter;

    // salida de dato
    assign RxData = rxshift_reg[8:1];   // bits de datos


    always_ff @(posedge clk_fpga or posedge reset) begin
        if (reset) begin
            state            <= IDLE;
            bit_counter      <= '0;
            sample_counter   <= '0;
            baudrate_counter <= '0;
            rxshift_reg      <= '0;
            data_valid       <= 1'b0;
        end else begin
            data_valid <= 1'b0;    // por defecto, solo 1 ciclo en alto

            // divisor de baud (a nivel de muestra)
            baudrate_counter <= baudrate_counter + 1;

            if (baudrate_counter >= div_counter - 1) begin
                baudrate_counter <= 0;

                // avanzamos de estado
                state <= nextstate;

                // shift si toca muestrear el bit
                if (shift)
                    rxshift_reg <= {RxD, rxshift_reg[9:1]};

                // control de contadores de muestra
                if (clear_samplecounter)
                    sample_counter <= 0;
                else if (inc_samplecounter)
                    sample_counter <= sample_counter + 1;

                // control del contador de bits
                if (clear_bitcounter)
                    bit_counter <= 0;
                else if (inc_bitcounter)
                    bit_counter <= bit_counter + 1;

                // si terminamos el último bit y vamos a IDLE, levantamos data_valid
                if (state == RECEIVING &&
                    bit_counter == div_bit - 1 &&
                    sample_counter == div_sample - 1) begin
                    data_valid <= 1'b1;
                end
            end
        end
    end

  
    always_comb begin
        // valores por defecto
        shift               = 1'b0;
        clear_samplecounter = 1'b0;
        inc_samplecounter   = 1'b0;
        clear_bitcounter    = 1'b0;
        inc_bitcounter      = 1'b0;
        nextstate           = state;

        case (state)
            IDLE: begin
                // esperamos start bit (línea baja)
                if (!RxD) begin
                    nextstate           = RECEIVING;
                    clear_bitcounter    = 1'b1;
                    clear_samplecounter = 1'b1;
                end
            end

            RECEIVING: begin
                // seguimos recibiendo bits
                nextstate = RECEIVING;

                // en la mitad del bit tomamos el valor y lo pasamos al shift
                if (sample_counter == mid_sample - 1)
                    shift = 1'b1;

                // si ya agotamos las muestras de este bit
                if (sample_counter == div_sample - 1) begin
                    inc_bitcounter     = 1'b1;
                    clear_samplecounter= 1'b1;

                   
                    if (bit_counter == div_bit - 1)
                        nextstate = IDLE;
                end else begin
                    // seguimos contando muestras del mismo bit
                    inc_samplecounter = 1'b1;
                end
            end

            default: nextstate = IDLE;
        endcase
    end

endmodule
