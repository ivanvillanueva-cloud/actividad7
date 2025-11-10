`timescale 1ns / 1ps

module command_parser (
    input  logic clk,
    input  logic reset,
    // desde UART RX
    input  logic [7:0] rx_byte,
    input  logic       rx_valid,
    // salida comando listo
    output logic       cmd_ready,
    output logic       seq_sel,   // 0 = Padovan, 1 = Moser
    output logic [7:0] n_value
);

    // estados del parser
    typedef enum logic [2:0] {
        S_WAIT_LETTER,
        S_WAIT_COMMA,
        S_WAIT_NUM1,
        S_WAIT_LF,
        S_DONE
    } pstate_t;

    pstate_t state;

    logic [7:0] tens;
    logic       got_two_digits;

    assign cmd_ready = (state == S_DONE);

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state          <= S_WAIT_LETTER;
            seq_sel        <= 1'b0;
            n_value        <= 8'd0;
            tens           <= 8'd0;
            got_two_digits <= 1'b0;
        end else begin
            if (rx_valid) begin
                unique case (state)
                    // esperamos 'P' o 'M'
                    S_WAIT_LETTER: begin
                        if (rx_byte == "P") begin
                            seq_sel <= 1'b0;
                            state   <= S_WAIT_COMMA;
                        end else if (rx_byte == "M") begin
                            seq_sel <= 1'b1;
                            state   <= S_WAIT_COMMA;
                        end else begin
                            state <= S_WAIT_LETTER; // ignorar basura
                        end
                    end

                    // esperamos coma
                    S_WAIT_COMMA: begin
                        if (rx_byte == ",")
                            state <= S_WAIT_NUM1;
                        else
                            state <= S_WAIT_LETTER; // reinicia si algo raro
                    end

                    // primero dígito del número
                    S_WAIT_NUM1: begin
                        if (rx_byte >= "0" && rx_byte <= "9") begin
                            tens           <= rx_byte - "0";
                            got_two_digits <= 1'b0;
                            state          <= S_WAIT_LF;
                        end else begin
                            state <= S_WAIT_LETTER;
                        end
                    end

                    // aquí aceptamos o bien:
                    // - un segundo dígito y luego \n
                    // - directamente \n
                    S_WAIT_LF: begin
                        if (rx_byte >= "0" && rx_byte <= "9") begin
                            // segundo dígito
                            n_value        <= (tens * 10) + (rx_byte - "0");
                            got_two_digits <= 1'b1;
                            // nos falta el \n
                        end else if (rx_byte == "\n" || rx_byte == 8'h0D) begin
                            // si solo había un dígito
                            if (!got_two_digits)
                                n_value <= tens;
                            state <= S_DONE;
                        end
                        // si entró el segundo dígito, nos quedamos esperando el \n
                    end

                    S_DONE: begin
                        // esperamos a que de afuera nos reseteen el parser
                        // (lo hará la FSM principal)
                        state <= S_DONE;
                    end

                    default: state <= S_WAIT_LETTER;
                endcase
            end
        end
    end

    // truco sencillo: el top puede resetear este módulo con el reset general
    // o puedes agregar una entrada "clear" si quieres reutilizarlo muchas veces

endmodule

