`timescale 1ns / 1ps

module ocssd_top #(
    parameter ADDR_WIDTH = 64,
    parameter DATA_WIDTH = 32
)(
    input wire                    clk,
    input wire                    rst,

    // AXI-Lite Slave интерфейс для регистров BAR0 (Регистры)
    input wire [15:0]             s_axil_awaddr, // Используем 16-бит для внутренней адресации регистров
    input wire                    s_axil_awvalid,
    output wire                   s_axil_awready,
    input wire [DATA_WIDTH-1:0]   s_axil_wdata,
    input wire [DATA_WIDTH/8-1:0] s_axil_wstrb,
    input wire                    s_axil_wvalid,
    output wire                   s_axil_wready,
    output wire [1:0]             s_axil_bresp,
    output wire                   s_axil_bvalid,
    input wire                    s_axil_bready,

    // Настройка базовых адресов очередей со стороны хоста
    input wire [ADDR_WIDTH-1:0]   admin_sq_base_addr,
    input wire [ADDR_WIDTH-1:0]   io_sq1_base_addr,

    // Интерфейс запросов DMA Read Descriptor к ядру verilog-pcie
    output wire [ADDR_WIDTH-1:0]  dma_read_desc_addr,
    output wire [11:0]            dma_read_desc_len,
    output wire                   dma_read_desc_valid,
    input wire                    dma_read_desc_ready,
    input wire                    dma_read_desc_status_valid,

    // Входной поток данных от DMA (64 байта команды)
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

    // Внутренние связи между блоками
    wire [15:0] admin_sq_tail;
    wire        admin_sq_tail_update;
    wire [15:0] io_sq1_tail;
    wire        io_sq1_tail_update;

    // 1. Модуль регистров (BAR0 Space)
    // Расширим nvme_regs.v для поддержки звонка IO SQ1 (Адрес 0x1008 по спецификации)
    nvme_regs #(
        .ADDR_WIDTH(16),
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

    // Временная заглушка для второго звонка, пока не расширили nvme_regs
    assign io_sq1_tail = 16'h0; 
    assign io_sq1_tail_update = 1'b0;

    // 2. Модуль арбитра очередей
    queue_arbiter #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_arbiter (
        .clk(clk),
        .rst(rst),
        .admin_sq_tail(admin_sq_tail),
        .admin_sq_tail_update(admin_sq_tail_update),
        .io_sq1_tail(io_sq1_tail),
        .io_sq1_tail_update(io_sq1_tail_update),
        .admin_sq_base_addr(admin_sq_base_addr),
        .io_sq1_base_addr(io_sq1_base_addr),
        .dma_read_desc_addr(dma_read_desc_addr),
        .dma_read_desc_len(dma_read_desc_len),
        .dma_read_desc_valid(dma_read_desc_valid),
        .dma_read_desc_ready(dma_read_desc_ready),
        .dma_read_desc_status_valid(dma_read_desc_status_valid),
        .active_queue_id(),
        .fetch_start()
    );

    // 3. Парсер 64-байтных команд NVMe / OCSSD
    nvme_parser u_parser (
        .clk(clk),
        .rst(rst),
        .cmd_data(dma_cmd_data),
        .cmd_valid(dma_cmd_valid),
        .cmd_ready(dma_cmd_ready),
        .cmd_opcode(),
        .cmd_prp1(),
        .cmd_prp2(),
        .ppa_channel(flash_channel),
        .ppa_lun(flash_lun),
        .ppa_chunk(flash_chunk),
        .ppa_page(flash_page),
        .cmd_parsed_valid(flash_cmd_valid)
    );

endmodule
