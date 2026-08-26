`timescale 1ns / 1ps

module nvme_regs #(
    parameter ADDR_WIDTH = 16,
    parameter DATA_WIDTH = 32
)(
    input wire                    clk,
    input wire                    rst,

    // AXI-Lite Slave интерфейс от ядра verilog-pcie
    input wire [ADDR_WIDTH-1:0]   s_axil_awaddr,
    input wire                    s_axil_awvalid,
    output wire                   s_axil_awready,
    
    input wire [DATA_WIDTH-1:0]   s_axil_wdata,
    input wire [DATA_WIDTH/8-1:0] s_axil_wstrb,
    input wire                    s_axil_wvalid,
    output wire                   s_axil_wready,
    
    output wire [1:0]             s_axil_bresp,
    output wire                   s_axil_bvalid,
    input wire                    s_axil_bready,

    // Выходные сигналы прерываний / событий для вашего DMA-движка
    output reg [15:0]             admin_sq_tail,
    output reg                    admin_sq_tail_update
);

    // Логика управления AXI-Lite (простейший стейт-машина)
    reg awready_reg, wready_reg, bvalid_reg;
    assign s_axil_awready = awready_reg;
    assign s_axil_wready  = wready_reg;
    assign s_axil_bvalid  = bvalid_reg;
    assign s_axil_bresp   = 2'b00; // OKAY

    // Адреса Doorbell регистров по спецификации NVMe
    // BAR0 + 0x1000: Admin Submission Queue Tail Doorbell
    localparam ADDR_ADMIN_SQ_TAIL = 16'h1000;

    always @(posedge clk) begin
        if (rst) begin
            awready_reg          <= 1'b0;
            wready_reg           <= 1'b0;
            bvalid_reg           <= 1'b0;
            admin_sq_tail        <= 16'h0;
            admin_sq_tail_update <= 1'b0;
        end else begin
            admin_sq_tail_update <= 1'b0;

            // Готовность принять адрес записи
            if (s_axil_awvalid && !awready_reg) begin
                awready_reg <= 1'b1;
            end else begin
                awready_reg <= 1'b0;
            end

            // Готовность принять данные записи
            if (s_axil_wvalid && !wready_reg) begin
                wready_reg <= 1'b1;
            end else begin
                wready_reg <= 1'b0;
            end

            // Запись в регистр при совпадении адреса и валидности данных
            if (s_axil_awvalid && s_axil_wvalid && !bvalid_reg) begin
                bvalid_reg <= 1'b1;
                
                if (s_axil_awaddr == ADDR_ADMIN_SQ_TAIL) begin
                    admin_sq_tail        <= s_axil_wdata[15:0];
                    admin_sq_tail_update <= 1'b1;
                end
            end

            if (s_axil_bvalid && s_axil_bready) begin
                bvalid_reg <= 1'b0;
            end
        end
    end

endmodule

