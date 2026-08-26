import cocotb
from cocotb.triggers import RisingEdge, ReadOnly
from cocotb.clock import Clock

@cocotb.test()
async def test_onfi_page_program_success(dut):
    """Тестируем успешный цикл ONFI Page Program с чтением статуса 0x40 (OK)"""
    ctrl = dut.u_onfi_ctrl
    cocotb.start_soon(Clock(ctrl.clk, 10, unit="ns").start())

    # Инициализация сигналов
    ctrl.rst.value = 1
    ctrl.flash_cmd_valid.value = 0
    ctrl.nand_rb_n.value = 1
    await RisingEdge(ctrl.clk)
    ctrl.rst.value = 0
    await RisingEdge(ctrl.clk)

    # Запуск транзакции на "хорошую" страницу (не 5)
    ctrl.flash_page.value = 12
    ctrl.flash_chunk.value = 100
    ctrl.flash_cmd_valid.value = 1
    await RisingEdge(ctrl.clk)
    ctrl.flash_cmd_valid.value = 0
    
    # Пролетаем фазы выдачи команды и адреса
    for _ in range(7):
        await RisingEdge(ctrl.clk)

    # Имитируем физический Busy от микросхемы
    ctrl.nand_rb_n.value = 0
    await RisingEdge(ctrl.clk)
    ctrl.nand_rb_n.value = 1
    
    # Ждем, пока FSM пройдет фазы захвата и анализа статуса (до возврата в IDLE)
    # Используем мониторинг готовности движка
    timeout = 50
    while ctrl.flash_engine_ready.value == 0 and timeout > 0:
        await RisingEdge(ctrl.clk)
        timeout -= 1

    # Синхронизируемся с завершением такта для надежной проверки ассерта
    await ReadOnly()
    assert ctrl.flash_write_error.value == 0, f"Ошибка: Ожидался статус успеха (0), получили {ctrl.flash_write_error.value}"
    ctrl._log.info("🔥 [Успех] Логика ONFI верифицирована. Статус памяти OK (0x40).")

@cocotb.test()
async def test_onfi_page_program_fault(dut):
    """Тестируем цикл ONFI Page Program с фиксацией аппаратной ошибки флеш-матрицы 0x41"""
    ctrl = dut.u_onfi_ctrl
    cocotb.start_soon(Clock(ctrl.clk, 10, unit="ns").start())

    # Инициализация
    ctrl.rst.value = 1
    ctrl.flash_cmd_valid.value = 0
    ctrl.nand_rb_n.value = 1
    await RisingEdge(ctrl.clk)
    ctrl.rst.value = 0
    await RisingEdge(ctrl.clk)

    # Страница 5 в нашей mock-модели жестко выдает статус 0x41 (ошибка)
    ctrl.flash_page.value = 5
    ctrl.flash_chunk.value = 5
    ctrl.flash_cmd_valid.value = 1
    await RisingEdge(ctrl.clk)
    ctrl.flash_cmd_valid.value = 0
    
    for _ in range(7):
        await RisingEdge(ctrl.clk)

    # Имитируем цикл Busy
    ctrl.nand_rb_n.value = 0
    await RisingEdge(ctrl.clk)
    ctrl.nand_rb_n.value = 1
    
    # Ждем, пока FSM закончит чтение 70h и вернется в IDLE
    timeout = 50
    while ctrl.flash_engine_ready.value == 0 and timeout > 0:
        await RisingEdge(ctrl.clk)
        timeout -= 1

    # Финальная проверка взведенного флага ошибки
    await ReadOnly()
    assert ctrl.flash_write_error.value == 1, f"FAIL: Ошибка не зафиксирована. Регистр статуса в Verilog: {ctrl.status_reg.value}"
    ctrl._log.info("🔥 [Успех] Контроллер успешно зафиксировал аппаратный сбой ячейки памяти (0x41).")
