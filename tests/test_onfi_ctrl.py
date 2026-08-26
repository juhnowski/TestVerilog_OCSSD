import cocotb
from cocotb.triggers import RisingEdge, ReadOnly
from cocotb.clock import Clock

@cocotb.test()
async def test_onfi_page_program_flow(dut):
    """Проверяем генерацию физических таймингов ONFI для операции Page Program"""

    ctrl = dut.u_onfi_ctrl

    cocotb.start_soon(Clock(ctrl.clk, 10, unit="ns").start())

    # Инициализация сигналов
    ctrl.rst.value = 1
    ctrl.flash_cmd_valid.value = 0
    ctrl.flash_page.value = 0
    ctrl.flash_chunk.value = 0
    ctrl.nand_rb_n.value = 1
    
    await RisingEdge(ctrl.clk)
    ctrl.rst.value = 0
    await RisingEdge(ctrl.clk)

    # Подаем команду записи: Страница 42, Чанк 258 (0x0102)
    ctrl.flash_page.value = 42
    ctrl.flash_chunk.value = 258
    ctrl.flash_cmd_valid.value = 1
    await RisingEdge(ctrl.clk)
    ctrl.flash_cmd_valid.value = 0
    
    # Даем FSM ровно один такт, чтобы перейти из IDLE в CMD_80H
    await RisingEdge(ctrl.clk)
    await ReadOnly() # Синхронизируем дельта-циклы симулятора

    # 1. Проверяем фазу команды CMD_80H
    assert ctrl.nand_cle.value == 1, "Ошибка: CLE должен быть равен 1"
    assert ctrl.nand_io_out.value == 0x80, "Ошибка: Ожидалась команда 80h"
    assert ctrl.nand_we_n.value == 0, "Ошибка: Строб записи WE# должен упасть в 0"

    # 2. Проверяем циклы адреса (STATE_ADDR)
    # Цикл 1: Column Address 1 (00h)
    await RisingEdge(ctrl.clk)
    await ReadOnly()
    assert ctrl.nand_ale.value == 1
    assert ctrl.nand_io_out.value == 0x00
    
    # Цикл 2: Column Address 2 (00h)
    await RisingEdge(ctrl.clk)
    await ReadOnly()
    assert ctrl.nand_io_out.value == 0x00
    
    # Цикл 3: Row Address 1 (Адрес страницы = 42)
    await RisingEdge(ctrl.clk)
    await ReadOnly()
    assert ctrl.nand_io_out.value == 42
    
    # Цикл 4: Row Address 2 (Младший байт чанка = 2)
    await RisingEdge(ctrl.clk)
    await ReadOnly()
    assert ctrl.nand_io_out.value == 2
    
    # Цикл 5: Row Address 3 (Старший байт чанка = 1)
    await RisingEdge(ctrl.clk)
    await ReadOnly()
    assert ctrl.nand_io_out.value == 1

    # 3. Проверяем фазу подтверждения CMD_10H
    await RisingEdge(ctrl.clk)
    await ReadOnly()
    assert ctrl.nand_cle.value == 1
    assert ctrl.nand_io_out.value == 0x10

    ctrl._log.info("🔥 [Успех] Регрессионный тест физических таймингов ONFI пройден!")
