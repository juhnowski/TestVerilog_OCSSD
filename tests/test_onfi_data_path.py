# /home/ilya/TestVerilog/tests/test_onfi_data_path.py
import cocotb
from cocotb.triggers import Timer, FallingEdge, RisingEdge, ReadOnly
from cocotb.clock import Clock

async def run_page_write_transaction(dut, page_val, expect_error):
    """
    Вспомогательная функция для прогона транзакции записи страницы.
    """
    # Подготовка параметров команды напрямую в контроллер
    dut.u_onfi_ctrl.flash_page.value = page_val
    dut.u_onfi_ctrl.flash_chunk.value = 10
    dut.u_onfi_ctrl.flash_cmd_valid.value = 1
    
    await RisingEdge(dut.clk)
    dut.u_onfi_ctrl.flash_cmd_valid.value = 0

    # Ожидание переключения FSM в фазу DATA_TX (state 3)
    while int(dut.u_onfi_ctrl.current_state.value) != 3:
        await RisingEdge(dut.clk)

    cocotb.log.info(f"[Page {page_val}] Вход в STATE_DATA_TX зафиксирован.")

    # Генерация эталонного паттерна (0..255)
    expected_data = list(range(256)) * 16

    for i in range(4096):
        # 1. Ждем спада WE# (начало цикла передачи текущего байта)
        await FallingEdge(dut.nand_we_n)
        
        # 2. Даем симулятору пройти ровно 1 такт clk для применения <= присваиваний
        await RisingEdge(dut.clk)
        await ReadOnly() # Переходим в фазу безопасного сэмплинга
        
        # Проверка направления драйвера
        assert dut.u_onfi_ctrl.nand_io_dir.value == 1, f"Ошибка на байте {i}: Направление не OUTPUT!"
        
        # Читаем актуальное значение, когда импульс WE# еще удерживается в нуле
        actual_byte = dut.nand_io.value.to_unsigned()
        expected_byte = expected_data[i]
        
        if actual_byte != expected_byte:
            raise AssertionError(
                f"Рассогласование! Байт {i}: Ожидалось 0x{expected_byte:02X}, "
                f"Извлечено 0x{actual_byte:02X} (ADDR в контроллере: {int(dut.u_onfi_ctrl.buffer_raddr.value)})"
            )
        
        # 3. Дожидаемся фронта WE# (окончание цикла передачи байта)
        await RisingEdge(dut.nand_we_n)

    cocotb.log.info(f"[Page {page_val}] Все 4096 байт успешно верифицированы.")

    # Ожидание возврата в IDLE
    while int(dut.u_onfi_ctrl.current_state.value) != 0:
        await RisingEdge(dut.clk)

    # Финальная проверка статуса ошибки/успеха транзакции
    await RisingEdge(dut.clk)
    await ReadOnly()
    
    # Железобетонный фикс для однобитных сигналов в Cocotb 2.0+
    actual_error = int(dut.u_onfi_ctrl.flash_write_error.value)
    if expect_error:
        assert actual_error == 1, "Ошибка не была зафиксирована!"
        cocotb.log.info(f"✔ Ошибка на Page {page_val} успешно поймана.")
    else:
        assert actual_error == 0, "Ложная фиксация ошибки!"
        cocotb.log.info(f"✔ Запись на Page {page_val} прошла успешно.")

    # КРИТИЧЕСКИЙ ФИКС: Выводим тестбенч из фазы ReadOnly, продвигая время на 1 такт.
    # Это разблокирует планировщик симулятора для записи новых сигналов в следующем тесте!
    await RisingEdge(dut.clk)


@cocotb.test()
async def test_onfi_data_path_full_flow(dut):
    """Регрессионный тест Data Path с прямой загрузкой SRAM."""
    
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    
    dut.rst.value = 1
    dut.nand_rb_n.value = 1 
    dut.pcie_dma_valid.value = 0
    dut.pcie_dma_data.value = 0
    dut.nand_io.value = "ZZZZZZZZ" # Изоляция тестбенча от inout-шины
    
    await Timer(30, unit="ns")
    dut.rst.value = 0
    await RisingEdge(dut.clk)

    # Backdoor загрузка паттерна в data_buffer (ocssd_top)
    cocotb.log.info("Backdoor: Инициализация памяти паттерном...")
    ref_pattern = list(range(256)) * 16
    for idx in range(4096):
        dut.data_buffer[idx].value = ref_pattern[idx]

    await Timer(10, unit="ns")

    # Тест 1: Успех
    await run_page_write_transaction(dut, page_val=0, expect_error=False)

    # Тест 2: Ошибка (Page 5 триггерит mock_status 0x41)
    await run_page_write_transaction(dut, page_val=5, expect_error=True)

    cocotb.log.info("Триумф! Тракт данных Варианта А полностью верифицирован.")
