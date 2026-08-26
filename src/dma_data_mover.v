`timescale 1ns / 1ps

module dma_data_mover #(
    parameter DATA_WIDTH = 512
)(
    input wire                    clk,
    input wire                    rst,

    // Интерфейс данных от DMA-интерфейса ядра PCIe
    input wire [DATA_WIDTH-1:0]   pcie_dma_data,
    input wire                    pcie_dma_valid,
    output wire                   pcie_dma_ready,

    // Интерфейс к нашему парсеру команд (nvme_parser)
    output reg [DATA_WIDTH-1:0]   out_cmd_data,
    output reg                    out_cmd_valid,
    input wire                    out_cmd_ready
);

    // Буферная логика управления потоком (Handshake)
    assign pcie_dma_ready = out_cmd_ready || !out_cmd_valid;

    always @(posedge clk) begin
        if (rst) begin
            out_cmd_data  <= {DATA_WIDTH{1'b0}};
            out_cmd_valid <= 1'b0;
        end else begin
            // Принимаем данные с шины PCIe, если готовы передать их дальше или буфер пуст
            if (pcie_dma_valid && pcie_dma_ready) begin
                out_cmd_data  <= pcie_dma_data;
                out_cmd_valid <= 1'b1;
            end else if (out_cmd_ready) begin
                out_cmd_valid <= 1'b0;
            end
        end
    end

endmodule
