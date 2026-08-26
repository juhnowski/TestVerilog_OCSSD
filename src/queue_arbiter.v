`timescale 1ns / 1ps

module queue_arbiter #(
    parameter ADDR_WIDTH = 64,
    parameter DATA_WIDTH = 32
)(
    input wire                    clk,
    input wire                    rst,

    // Сигналы от регистровой карты дверных звонков
    input wire [15:0]             admin_sq_tail,
    input wire                    admin_sq_tail_update,
    input wire [15:0]             io_sq1_tail,
    input wire                    io_sq1_tail_update,

    // Базовые адреса очередей в памяти хоста (обычно настраиваются Admin-командами)
    input wire [ADDR_WIDTH-1:0]   admin_sq_base_addr,
    input wire [ADDR_WIDTH-1:0]   io_sq1_base_addr,

    // Интерфейс запросов DMA Read Descriptor (к ядру verilog-pcie)
    output reg [ADDR_WIDTH-1:0]   dma_read_desc_addr,
    output reg [11:0]             dma_read_desc_len,
    output reg                    dma_read_desc_valid,
    input wire                    dma_read_desc_ready,
    input wire                    dma_read_desc_status_valid, // Сигнал успешного завершения чтения

    // Сигналы управления для парсера команд
    output reg [1:0]              active_queue_id,
    output reg                    fetch_start
);

    // Локальные регистры для отслеживания обработанных индексов (Head) внутри железа
    reg [15:0] admin_sq_head;
    reg [15:0] io_sq1_head;

    // Состояния FSM
    localparam STATE_IDLE      = 2'b00;
    localparam STATE_ARBITRATE = 2'b01;
    localparam STATE_FETCH     = 2'b10;
    localparam STATE_WAIT_DMA  = 2'b11;

    reg [1:0] current_state;

    // Флаги наличия необработанных команд в очередях
    wire admin_has_cmds = (admin_sq_tail != admin_sq_head);
    wire io1_has_cmds   = (io_sq1_tail   != io_sq1_head);

    always @(posedge clk) begin
        if (rst) begin
            admin_sq_head              <= 16'h0;
            io_sq1_head                <= 16'h0;
            dma_read_desc_addr         <= {ADDR_WIDTH{1'b0}};
            dma_read_desc_len          <= 12'h0;
            dma_read_desc_valid        <= 1'b0;
            active_queue_id            <= 2'b00;
            fetch_start                <= 1'b0;
            current_state              <= STATE_IDLE;
        end else begin
            fetch_start <= 1'b0;

            case (current_state)
                STATE_IDLE: begin
                    if (admin_has_cmds || io1_has_cmds) begin
                        current_state <= STATE_ARBITRATE;
                    end
                end

                STATE_ARBITRATE: begin
                    // Приоритетный арбитраж: сначала всегда обрабатываем системную Admin-очередь
                    if (admin_has_cmds) begin
                        active_queue_id    <= 2'b00; // Admin Queue ID
                        // Считаем адрес команды в ОЗУ хоста: Base + (Head * 64 байта)
                        dma_read_desc_addr <= admin_sq_base_addr + (admin_sq_head * 64);
                        current_state      <= STATE_FETCH;
                    end else if (io1_has_cmds) begin
                        active_queue_id    <= 2'b01; // I/O Queue 1 ID
                        dma_read_desc_addr <= io_sq1_base_addr + (io_sq1_head * 64);
                        current_state      <= STATE_FETCH;
                    end else begin
                        current_state <= STATE_IDLE;
                    end
                end

                STATE_FETCH: begin
                    dma_read_desc_len   <= 12'd64; // Каждая NVMe команда строго 64 байта
                    dma_read_desc_valid <= 1'b1;

                    if (dma_read_desc_ready) begin
                        dma_read_desc_valid <= 1'b0;
                        fetch_start         <= 1'b1; // Сигнализируем парсеру о начале вычитки
                        current_state       <= STATE_WAIT_DMA;
                    end
                end

                STATE_WAIT_DMA: begin
                    if (dma_read_desc_status_valid) begin
                        // Обновляем аппаратный указатель Head после успешного чтения
                        if (active_queue_id == 2'b00) begin
                            admin_sq_head <= admin_sq_head + 1;
                        end else begin
                            io_sq1_head <= io_sq1_head + 1;
                        end
                        current_state <= STATE_IDLE;
                    end
                end
            endcase
        end
    end

endmodule
