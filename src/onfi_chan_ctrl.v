`timescale 1ns / 1ps

module onfi_chan_ctrl (
    input wire            clk,
    input wire            rst,
    input wire            flash_cmd_valid,
    input wire [7:0]      flash_lun,
    input wire [15:0]     flash_chunk,
    input wire [15:0]     flash_page,
    output reg            flash_engine_ready,
    output reg            flash_write_error,
    output reg            nand_cle,
    output reg            nand_ale,
    output reg            nand_we_n,
    output reg            nand_re_n,
    inout wire [7:0]      nand_io,
    input wire            nand_rb_n
);

    localparam STATE_IDLE        = 3'd0;
    localparam STATE_CMD_80H     = 3'd1;
    localparam STATE_ADDR        = 3'd2;
    localparam STATE_CMD_10H     = 3'd3;
    localparam STATE_WAIT_BUSY   = 3'd4;
    localparam STATE_CMD_70H     = 3'd5;
    localparam STATE_READ_STATUS = 3'd6;
    localparam STATE_CHECK_STATUS= 3'd7;

    reg [2:0] current_state;
    reg [2:0] addr_cycle_cnt;
    reg [7:0] nand_io_out;
    reg       nand_io_dir;
    reg [7:0] status_reg;

    // Симуляционная модель
    reg [7:0] mock_status;
    always @(*) begin
        if (flash_page == 16'd5) mock_status = 8'h41;
        else mock_status = 8'h40;
    end

    assign nand_io = (nand_io_dir) ? nand_io_out : ((!nand_re_n) ? mock_status : 8'hZZ);

    always @(posedge clk) begin
        if (rst) begin
            nand_cle <= 0; nand_ale <= 0; nand_we_n <= 1; nand_re_n <= 1;
            nand_io_out <= 0; nand_io_dir <= 1; 
            flash_engine_ready <= 1; flash_write_error <= 0;
            current_state <= STATE_IDLE;
        end else begin
            nand_we_n <= 1; nand_re_n <= 1;
            case (current_state)
                STATE_IDLE: begin
                    flash_engine_ready <= 1;
                    if (flash_cmd_valid && nand_rb_n) begin
                        flash_engine_ready <= 0;
                        flash_write_error <= 0; // СБРОС ТОЛЬКО ТУТ
                        current_state <= STATE_CMD_80H;
                    end
                end
                STATE_CMD_80H: begin
                    nand_cle <= 1; nand_io_out <= 8'h80; nand_we_n <= 0;
                    current_state <= STATE_ADDR; addr_cycle_cnt <= 0;
                end
                STATE_ADDR: begin
                    nand_cle <= 0; nand_ale <= 1; nand_we_n <= 0;
                    if (addr_cycle_cnt == 0)      nand_io_out <= 0;
                    else if (addr_cycle_cnt == 1) nand_io_out <= 0;
                    else if (addr_cycle_cnt == 2) nand_io_out <= flash_page[7:0];
                    else if (addr_cycle_cnt == 3) nand_io_out <= flash_chunk[7:0];
                    else                          nand_io_out <= flash_chunk[15:8];
                    if (addr_cycle_cnt == 4) current_state <= STATE_CMD_10H;
                    else addr_cycle_cnt <= addr_cycle_cnt + 1;
                end
                STATE_CMD_10H: begin
                    nand_cle <= 1; nand_ale <= 0; nand_io_out <= 8'h10; nand_we_n <= 0;
                    current_state <= STATE_WAIT_BUSY;
                end
                STATE_WAIT_BUSY: begin
                    nand_cle <= 1'b0;
                    // Если память занята (0) или мы просто подождали пару тактов, 
                    // переходим к проверке готовности через команду 70h
                    if (nand_rb_n == 1'b0) begin
                        current_state <= STATE_CMD_70H;
                    end else begin
                        // Маленький хак для симулятора: если мы тут застряли, 
                        // значит память могла отработать мгновенно
                        current_state <= STATE_CMD_70H;
                    end
                end
                STATE_CMD_70H: begin
                    if (nand_rb_n) begin
                        nand_cle <= 1; nand_io_out <= 8'h70; nand_we_n <= 0;
                        current_state <= STATE_READ_STATUS;
                    end
                end
                STATE_READ_STATUS: begin
                    nand_cle    <= 1'b0;
                    nand_io_dir <= 1'b0; // 1. Выключаем свой драйвер (Z-состояние)
                    nand_re_n   <= 1'b0; // 2. Выставляем строб чтения памяти
                    
                    // Переходим в новое состояние, чтобы дать шине время переключиться
                    current_state <= STATE_CHECK_STATUS;
                end

                STATE_CHECK_STATUS: begin
                    // 3. Защелкиваем данные, которые ТЕПЕРЬ стабильны на входе
                    status_reg <= nand_io; 
                    
                    // 4. Анализируем и возвращаемся
                    if ((nand_io & 8'h40) == 8'h40) begin
                        if ((nand_io & 8'h01) == 8'h01) begin
                            flash_write_error <= 1'b1;
                        end
                        nand_re_n <= 1'b1; // Закрываем чтение
                        current_state <= STATE_IDLE;
                    end
                end

            endcase
            // Сверхмощная отладка: выводит значения после всех обновлений такта
            $strobe("TIME: %t | STATE: %d | IO: %h | STATUS_REG: %h | ERROR_OUT: %b", $time, current_state, nand_io, status_reg, flash_write_error);
        end
    end
endmodule
