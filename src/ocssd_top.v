`timescale 1ns / 1ps

module ocssd_top #(
    parameter ADDR_WIDTH = 16,
    parameter DATA_WIDTH = 32
)(
    input wire                    clk,
    input wire                    rst,

    // AXI-Lite Slave интерфейс для регистров BAR0
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

    // Интерфейс данных от DMA-движка (симуляция шины)
    input wire [511:0]            dma_cmd_data,
    input wire                    dma_cmd_valid,
    output wire                   dma_cmd_ready,

    // Выходы физической геометрии NAND для Flash Translation Layer (FTL)
    output wire [7:0]             flash_channel,
    output wire [7:0]             flash_lun,
    output wire [15:0]            flash_chunk,
    output wire [15:0]            flash_page,
    output wire                   flash_cmd_valid
);

    wire [15:0] admin_sq_tail;
    wire        admin_sq_tail_update;

    // 1. Инстанцируем регистровую карту NVMe
    nvme_regs #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_regs (
        .clk(clk),
        .rst(rst),
        .s_axil_awaddr(s_axil_awaddr),
        .s_axil_awvalid(s_axil_awvalid),
        .s_axil_awready(s_axil_awready),
        .s_axil_wdata(s_axil_wdata),
        .s_axil_wstrb(s_axil_wstrb),
        .s_axil_wvalid(s_axil_wvalid),
        .s_axil_wready(s_axil_wready),
        .s_axil_bresp(s_axil_bresp),
        .s_axil_bvalid(s_axil_bvalid),
        .s_axil_bready(s_axil_bready),
        .admin_sq_tail(admin_sq_tail),
        .admin_sq_tail_update(admin_sq_tail_update)
    );

    // 2. Инстанцируем парсер команд
    nvme_parser u_parser (
        .clk(clk),
        .rst(rst),
        .cmd_data(dma_cmd_data),
        .cmd_valid(dma_cmd_valid),
        .cmd_ready(dma_cmd_ready),
        .cmd_opcode(), // Нам интересна только геометрия NAND
        .cmd_prp1(),
        .cmd_prp2(),
        .ppa_channel(flash_channel),
        .ppa_lun(flash_lun),
        .ppa_chunk(flash_chunk),
        .ppa_page(flash_page),
        .cmd_parsed_valid(flash_cmd_valid)
    );

endmodule
