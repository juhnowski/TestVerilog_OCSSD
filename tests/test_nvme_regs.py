import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock

@cocotb.test()
async def test_doorbell_write(dut):
    """Тестируем запись хостом значения в Admin Doorbell регистр"""

    # Инициализация тактового сигнала (период 10нс = 100 МГц)
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    # Сброс аппаратуры
    dut.rst.value = 1
    dut.s_axil_awvalid.value = 0
    dut.s_axil_wvalid.value = 0
    dut.s_axil_bready.value = 1
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)

    # Симулируем запись хоста по AXI-Lite: Адрес 0x1000, Данные = 5
    dut.s_axil_awaddr.value = 0x1000
    dut.s_axil_wdata.value = 5
    dut.s_axil_awvalid.value = 1
    dut.s_axil_wvalid.value = 1

    # Ждем пока модуль выставит флаг обновления
    for _ in range(5):
        await RisingEdge(dut.clk)
        if dut.admin_sq_tail_update.value == 1:
            break

    # Проверяем корректность логики утверждениями (asserts)
    assert dut.admin_sq_tail.value == 5, f"Ошибка: ожидалось 5, получили {dut.admin_sq_tail.value}"
    dut._log.info("🔥 [Успех] Драйвер Linux нажал на звонок, железо зафиксировало хвост очереди SQ = 5!")
