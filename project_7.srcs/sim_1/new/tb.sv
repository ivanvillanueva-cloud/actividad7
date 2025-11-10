`timescale 1ns / 1ps

module tb_top_cmd_uart;

    // ======================
    // Señales del testbench
    // ======================
    logic clk;
    logic reset;
    logic RxD;
    logic TxD;
    logic [7:0] led;

    // ======================
    // Instancia del DUT
    // ======================
    top_cmd_uart #(
        .CLOCK_FREQ(100_000_000),
        .BAUD_RATE (115200)
    ) DUT (
        .clk   (clk),
        .reset (reset),
        .RxD   (RxD),
        .TxD   (TxD),
        .led   (led)
    );

    // ======================
    // Generador de reloj
    // ======================
    initial begin
        clk = 0;
        forever #5 clk = ~clk;   // periodo = 10 ns → 100 MHz
    end

    // ======================
    // Proceso de estímulo
    // ======================
    initial begin
        // UART idle
        RxD   = 1'b1;
        reset = 1;
        #100;
        reset = 0;

        // Espera inicial después del reset
        #(1000 * 10); // 10 us

        // ---------- PRUEBA 1: Padovan(5) ----------
        send_uart_byte("P");
        send_uart_byte(",");
        send_uart_byte("5");
        send_uart_byte("\n");

        // Espera para que termine TX
        #(200000 * 10); // 2 ms

        // ---------- PRUEBA 2: Moser(8) ----------
        send_uart_byte("M");
        send_uart_byte(",");
        send_uart_byte("8");
        send_uart_byte("\n");

        // Espera para ver resultado final
        #(200000 * 10); // 2 ms

        $stop;
    end

    // ======================
    // Tarea: enviar 1 byte UART (8N1)
    // ======================
    task send_uart_byte(input [7:0] data);
        integer i;
        // 115200 baudios → 8680 ns por bit ≈ 868 ticks de 10 ns
        integer bit_ticks = 868;
        begin
            // start bit
            RxD = 1'b0;
            repeat (bit_ticks) @(posedge clk);

            // 8 bits LSB primero
            for (i = 0; i < 8; i = i + 1) begin
                RxD = data[i];
                repeat (bit_ticks) @(posedge clk);
            end

            // stop bit
            RxD = 1'b1;
            repeat (bit_ticks) @(posedge clk);
        end
    endtask

endmodule
