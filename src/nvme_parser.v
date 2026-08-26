`timescale 1ns / 1ps

module nvme_parser (
    input wire          clk,
    input wire          rst,

    // Входной интерфейс: 64 байта команды, пришедшие по DMA
    input wire [511:0]  cmd_data,
    input wire          cmd_valid,
    output wire         cmd_ready,

    // Распарсенные поля команды для логики флеш-контроллера
    output reg [7:0]    cmd_opcode,
    output reg [63:0]   cmd_prp1,
    output reg [63:0]   cmd_prp2,
    
    // Выходы Physical Page Address (Специфика Open-Channel SSD)
    output reg [7:0]    ppa_channel,
    output reg [7:0]    ppa_lun,
    output reg [15:0]   ppa_chunk,
    output reg [15:0]   ppa_page,
    
    output reg          cmd_parsed_valid
);

    assign cmd_ready = 1'b1; // Всегда готовы принять, так как это чистый парсер

    always @(posedge clk) begin
        if (rst) begin
            cmd_opcode       <= 8'h0;
            cmd_prp1         <= 64'h0;
            cmd_prp2         <= 64'h0;
            ppa_channel      <= 8'h0;
            ppa_lun          <= 8'h0;
            ppa_chunk        <= 16'h0;
            ppa_page         <= 16'h0;
            cmd_parsed_valid <= 1'b0;
        end else begin
            if (cmd_valid) begin
                // Спецификация NVMe / Open-Channel: извлекаем поля по смещениям бит
                cmd_opcode   <= cmd_data[7:0];        // Byte 0: Opcode
                cmd_prp1     <= cmd_data[255:192];    // Bytes 24-31: PRP1
                cmd_prp2     <= cmd_data[319:256];    // Bytes 32-39: PRP2
                
                // В Open-Channel NVMe командах поля адреса NAND мапятся в Dword 14-15
                // Bytes 56-63 (Dword 14 и 15)
                ppa_page     <= cmd_data[463:448];    // 16 бит - Страница
                ppa_chunk    <= cmd_data[479:464];    // 16 бит - Чанк (Блок)
                ppa_lun      <= cmd_data[487:480];    // 8 бит  - Кристалл (Die)
                ppa_channel  <= cmd_data[495:488];    // 8 бит  - Физический канал
                
                cmd_parsed_valid <= 1'b1;
            end else begin
                cmd_parsed_valid <= 1'b0;
            end
        end
    end

endmodule
