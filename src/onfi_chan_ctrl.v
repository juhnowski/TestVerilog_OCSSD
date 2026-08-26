`timescale 1ns / 1ps

module onfi_chan_ctrl (
    input wire            clk,
    input wire            rst,

    // Интерфейс от Топ-модуля (Распарсенная команда)
    input wire            flash_cmd_valid,
    input wire [7:0]      flash_lun,
    input wire [15:0]     flash_chunk,
    input wire [15:0]     flash_page,
    output reg            flash_engine_ready,

    // Физический интерфейс к выводам микросхемы NAND Flash
    output reg            nand_cle,
    output reg            nand_ale,
    output reg            nand_we_n,
    output reg            nand_re_n,
    output reg [7:0]      nand_io_out,
    output reg            nand_io_dir, // 1 - выход (запись), 0 - вход (чтение)
    input wire            nand_rb_n    // Ready/Busy# от микросхемы (0 - занята)
);

    // Состояния автомата ONFI
    localparam STATE_IDLE      = 3'b000;
    localparam STATE_CMD_80H   = 3'b001;
    localparam STATE_ADDR      = 3'b010;
    localparam STATE_CMD_10H   = 3'b011;
    localparam STATE_WAIT_BUSY = 3'b100;

    reg [2:0] current_state;
    reg [2:0] addr_cycle_cnt;

    always @(posedge clk) begin
        if (rst) begin
            nand_cle           <= 1'b0;
            nand_ale           <= 1'b0;
            nand_we_n          <= 1'b1;
            nand_re_n          <= 1'b1;
            nand_io_out        <= 8'h0;
            nand_io_dir        <= 1'b1;
            flash_engine_ready <= 1'b1;
            addr_cycle_cnt     <= 3'd0;
            current_state      <= STATE_IDLE;
        end else begin
            nand_we_n <= 1'b1; // По умолчанию строб записи неактивен (высокий уровень)

            case (current_state)
                STATE_IDLE: begin
                    flash_engine_ready <= 1'b1;
                    nand_cle           <= 1'b0;
                    nand_ale           <= 1'b0;
                    if (flash_cmd_valid && nand_rb_n) begin
                        flash_engine_ready <= 1'b0;
                        current_state      <= STATE_CMD_80H;
                    end
                end

                STATE_CMD_80H: begin
                    nand_cle    <= 1'b1;
                    nand_ale    <= 1'b0;
                    nand_io_out <= 8'h80; // Команда записи Serial Data Input
                    nand_we_n   <= 1'b0;  // Строб записи вниз
                    current_state <= STATE_ADDR;
                    addr_cycle_cnt <= 3'd0;
                end

                STATE_ADDR: begin
                    nand_cle <= 1'b0;
                    nand_ale <= 1'b1;
                    nand_we_n <= 1'b0;

                    // 5-цикловый адресный конвейер ONFI
                    case (addr_cycle_cnt)
                        3'd0: nand_io_out <= 8'h00; // Column Address 1 (Начало страницы)
                        3'd1: nand_io_out <= 8'h00; // Column Address 2
                        3'd2: nand_io_out <= flash_page[7:0];   // Row Address 1 (Страница)
                        3'd3: nand_io_out <= flash_chunk[7:0];  // Row Address 2 (Блок/Чанк)
                        3'd4: nand_io_out <= flash_chunk[15:8]; // Row Address 3
                    endcase

                    if (addr_cycle_cnt == 3'd4) begin
                        current_state <= STATE_CMD_10H;
                    end else begin
                        addr_cycle_cnt <= addr_cycle_cnt + 1;
                    end
                end

                STATE_CMD_10H: begin
                    nand_cle    <= 1'b1;
                    nand_ale    <= 1'b0;
                    nand_io_out <= 8'h10; // Команда подтверждения записи Program Confirm
                    nand_we_n   <= 1'b0;
                    current_state <= STATE_WAIT_BUSY;
                end

                STATE_WAIT_BUSY: begin
                    nand_cle <= 1'b0;
                    nand_ale <= 1'b0;
                    // Ждем, пока реальный кристалл Flash просадит RB# в ноль и вернет в единицу
                    if (nand_rb_n) begin
                        current_state <= STATE_IDLE;
                    end
                end
            endcase
        end
    end

endmodule
