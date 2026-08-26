// onfi_chan_ctrl.v
`timescale 1ns / 1ps

module onfi_chan_ctrl #(
    parameter CLK_PER_WE_HALF_CYCLE = 2
)(
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
    input wire            nand_rb_n,

    // --- Интерфейс к SRAM Buffer ---
    output reg  [12:0]    buffer_raddr, // ФИКС: расширено до 13 бит
    input wire  [7:0]     buffer_rdata,
    input wire  [12:0]    tx_byte_count // ФИКС: расширено до 13 бит
);

    localparam STATE_IDLE        = 4'd0;
    localparam STATE_CMD_80H     = 4'd1;
    localparam STATE_ADDR        = 4'd2;
    localparam STATE_DATA_TX     = 4'd3; 
    localparam STATE_CMD_10H     = 4'd4;
    localparam STATE_WAIT_BUSY   = 4'd5;
    localparam STATE_CMD_70H     = 4'd6;
    localparam STATE_READ_STATUS = 4'd7;
    localparam STATE_CHECK_STATUS= 4'd8;

    reg [3:0] current_state;
    reg [2:0] addr_cycle_cnt;
    reg [7:0] nand_io_out;
    reg       nand_io_dir;
    reg [7:0] status_reg;

    reg [12:0] data_byte_cnt; // ФИКС: расширено до 13 бит
    reg        we_cycle; 
    reg [7:0]  wait_counter;

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
            buffer_raddr <= 13'h000;
            data_byte_cnt <= 13'h000;
            we_cycle <= 1'b0;
            wait_counter <= 8'h0;
            current_state <= STATE_IDLE;
        end else begin
            nand_we_n <= 1; nand_re_n <= 1; // Дефолтные значения такта
            
            case (current_state)
                STATE_IDLE: begin
                    flash_engine_ready <= 1;
                    nand_io_dir        <= 1'b1;
                    buffer_raddr       <= 13'h000; // Удерживаем 0
                    data_byte_cnt      <= 13'h000;
                    we_cycle           <= 1'b0;
                    wait_counter       <= 8'h0;
                    if (flash_cmd_valid && nand_rb_n) begin
                        flash_engine_ready <= 0;
                        flash_write_error  <= 0; 
                        current_state      <= STATE_CMD_80H;
                    end
                end

                STATE_CMD_80H: begin
                    nand_cle     <= 1; nand_io_out <= 8'h80; nand_we_n <= 0;
                    buffer_raddr <= 13'h000; // Удерживаем 0
                    current_state <= STATE_ADDR; addr_cycle_cnt <= 0;
                end

                STATE_ADDR: begin
                    nand_cle <= 0; nand_ale <= 1; nand_we_n <= 0;
                    buffer_raddr <= 13'h000; // Удерживаем строго 0
                    
                    if (addr_cycle_cnt == 0)      nand_io_out <= 0;
                    else if (addr_cycle_cnt == 1) nand_io_out <= 0;
                    else if (addr_cycle_cnt == 2) nand_io_out <= flash_page[7:0];
                    else if (addr_cycle_cnt == 3) nand_io_out <= flash_chunk[7:0];
                    else                          nand_io_out <= flash_chunk[15:8];
                    
                    if (addr_cycle_cnt == 4) begin
                        current_state <= STATE_DATA_TX;
                        we_cycle      <= 1'b0;
                        wait_counter  <= 8'h0;
                    end else begin
                        addr_cycle_cnt <= addr_cycle_cnt + 1;
                    end
                end

                STATE_DATA_TX: begin
                    nand_cle    <= 1'b0;
                    nand_ale    <= 1'b0;
                    nand_io_dir <= 1'b1;
                    
                    nand_io_out <= buffer_rdata; 

                    if (!we_cycle) begin
                        nand_we_n <= 1'b0; 
                        if (wait_counter + 1 >= CLK_PER_WE_HALF_CYCLE) begin
                            wait_counter <= 8'h0;
                            we_cycle     <= 1'b1;
                        end else begin
                            wait_counter <= wait_counter + 1;
                        end
                    end else begin
                        nand_we_n <= 1'b1; 
                        if (wait_counter + 1 >= CLK_PER_WE_HALF_CYCLE) begin
                            wait_counter <= 8'h0;
                            we_cycle     <= 1'b0;
                            
                            // Обновляем счетчики только здесь — когда WE# вернулся в 1
                            buffer_raddr  <= (buffer_raddr + 1) & 13'h1FFF;
                            data_byte_cnt <= (data_byte_cnt + 1) & 13'h1FFF;
                            
                            if ((data_byte_cnt + 1) >= tx_byte_count) begin
                                current_state <= STATE_CMD_10H;
                            end
                        end else begin
                            wait_counter <= wait_counter + 1;
                        end
                    end
                end



                STATE_CMD_10H: begin
                    nand_cle <= 1; nand_ale <= 0; nand_io_out <= 8'h10; nand_we_n <= 0;
                    current_state <= STATE_WAIT_BUSY;
                end

                STATE_WAIT_BUSY: begin
                    nand_cle <= 1'b0;
                    if (nand_rb_n == 1'b0) begin
                        current_state <= STATE_CMD_70H;
                    end else begin
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
                    nand_io_dir <= 1'b0; 
                    nand_re_n   <= 1'b0; // Удерживаем спад RE#
                    current_state <= STATE_CHECK_STATUS;
                end

                STATE_CHECK_STATUS: begin
                    nand_io_dir <= 1'b0;
                    nand_re_n   <= 1'b0; // ФИКС: Продолжаем удерживать RE# низким, чтобы mock_status не отключался!
                    
                    status_reg  <= nand_io; 
                    
                    if ((nand_io & 8'h40) == 8'h40) begin
                        if ((nand_io & 8'h01) == 8'h01) begin
                            flash_write_error <= 1'b1;
                        end
                        nand_re_n     <= 1'b1; // Освобождаем чтение только при выходе
                        current_state <= STATE_IDLE;
                    end
                end

                default: current_state <= STATE_IDLE;
            endcase
            
            $strobe("TIME: %t | STATE: %d | IO: %h | STATUS_REG: %h | ERROR_OUT: %b | BUF_ADDR: %d", 
                    $time, current_state, nand_io, status_reg, flash_write_error, buffer_raddr);
        end
    end
endmodule
