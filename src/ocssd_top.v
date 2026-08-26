`timescale 1ns / 1ps

module ocssd_top #(
    parameter ADDR_WIDTH = 64,
    parameter DATA_WIDTH = 32
)(
    input wire                    clk,
    input wire                    rst,

    // AXI-Lite Slave интерфейс для регистров BAR0
    input wire [15:0]             s_axil_awaddr,
    input wire                    s_axil_awvalid,
    output wire                   s_axil_awready,
    input wire [DATA_WIDTH-1:0]   s_axil_wdata,
    input wire [DATA_WIDTH/8-1:0] s_axil_wstrb,
    input wire                    s_axil_wvalid,
    output wire                   s_axil_wready,
    output wire [1:0]             s_axil_bresp,
    output wire                   s_axil_bvalid,
    input wire                    s_axil_bready,

    // Настройка базовых адресов очередей
    input wire [ADDR_WIDTH-1:0]   admin_sq_base_addr,
    input wire [ADDR_WIDTH-1:0]   io_sq1_base_addr,

    // Интерфейс запросов DMA Read Descriptor к ядру verilog-pcie
    output wire [ADDR_WIDTH-1:0]  dma_read_desc_addr,
    output wire [11:0]            dma_read_desc_len,
    output wire                   dma_read_desc_valid,
    input wire                    dma_read_desc_ready,
    input wire                    dma_read_desc_status_valid,

    // Входной физический поток данных от шины PCIe DMA (512 бит)
    input wire [511:0]            pcie_dma_data,
    input wire                    pcie_dma_valid,
    output wire                   pcie_dma_ready,

    // Физический интерфейс к выводам микросхемы NAND Flash (стандарт ONFI)
    output wire                   nand_cle,
    output wire                   nand_ale,
    output wire                   nand_we_n,
    output wire                   nand_re_n,
    inout wire [7:0]              nand_io, // ФИКС: Честный inout на самом верху
    input wire                    nand_rb_n
);

    // Внутренние связи конвейера
    wire [15:0] admin_sq_tail;
    wire        admin_sq_tail_update;
    wire [15:0] io_sq1_tail;
    wire        io_sq1_tail_update;
    
    wire [511:0] parsed_cmd_data;
    wire         parsed_cmd_valid;
    wire         parsed_cmd_ready;

    wire [7:0]   flash_channel;
    wire [7:0]   flash_lun;
    wire [15:0]  flash_chunk;
    wire [15:0]  flash_page;
    wire         flash_cmd_valid;

    // 1. Модуль регистров (BAR0 Space)
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

    // 3. DMA Data Mover (Буферизация шины PCIe)
    dma_data_mover #(
        .DATA_WIDTH(512)
    ) u_dma_mover (
        .clk(clk),
        .rst(rst),
        .pcie_dma_data(pcie_dma_data),
        .pcie_dma_valid(pcie_dma_valid),
        .pcie_dma_ready(pcie_dma_ready),
        .out_cmd_data(parsed_cmd_data),
        .out_cmd_valid(parsed_cmd_valid),
        .out_cmd_ready(parsed_cmd_ready)
    );

    // 4. Парсер 64-байтных команд OCSSD
    nvme_parser u_parser (
        .clk(clk),
        .rst(rst),
        .cmd_data(parsed_cmd_data),
        .cmd_valid(parsed_cmd_valid),
        .cmd_ready(parsed_cmd_ready),
        .cmd_opcode(),
        .cmd_prp1(),
        .cmd_prp2(),
        .ppa_channel(flash_channel),
        .ppa_lun(flash_lun),
        .ppa_chunk(flash_chunk),
        .ppa_page(flash_page),
        .cmd_parsed_valid(flash_cmd_valid)
    );

    // 5. Контроллер ONFI NAND Flash с ФИКСИРОВАННЫМ маппингом портов
    onfi_chan_ctrl u_onfi_ctrl (
        .clk(clk),
        .rst(rst),
        .flash_cmd_valid(flash_cmd_valid),
        .flash_lun(flash_lun),
        .flash_chunk(flash_chunk),
        .flash_page(flash_page),
        .flash_engine_ready(),
        .flash_write_error(),
        .nand_cle(nand_cle),
        .nand_ale(nand_ale),
        .nand_we_n(nand_we_n),
        .nand_re_n(nand_re_n),
        .nand_io(nand_io), // Чистое сквозное подключение inout-шины
        .nand_rb_n(nand_rb_n)
    );

endmodule
