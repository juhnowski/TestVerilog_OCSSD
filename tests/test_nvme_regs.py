import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock

@cocotb.test()
async def test_doorbell_write(dut):
    """Тестируем запись хостом значения в Admin Doorbell регистр"""

    # Добавляем указание на иерархию подмодуля u_regs внутри ocssd_top
    regs = dut.u_regs

    # Инициализация тактового сигнала
    cocotb.start_soon(Clock(regs.clk, 10, units="ns").start())

    # Сброс аппаратуры
    regs.rst.value = 1
    regs.s_axil_awvalid.value = 0
    regs.s_axil_wvalid.value = 0
    regs.s_axil_bready.value = 1
    await RisingEdge(regs.clk)
    await RisingEdge(regs.clk)
    regs.rst.value = 0
    await RisingEdge(regs.clk)

    # Симулируем запись хоста по AXI-Lite: Адрес 0x1000, Данные = 5
    regs.s_axil_awaddr.value = 0x1000
    regs.s_axil_wdata.value = 5
    regs.s_axil_awvalid.value = 1
    regs.s_axil_wvalid.value = 1

    # Ждем пока модуль выставит флаг обновления
    for _ in range(5):
        await RisingEdge(regs.clk)
        if regs.admin_sq_tail_update.value == 1:
            break

    # Проверяем корректность логики
    assert regs.admin_sq_tail.value == 5, f"Ошибка: ожидалось 5, получили {regs.admin_sq_tail.value}"
    regs._log.info("🔥 [Успех] Регрессионный тест регистров пройден!")
