import cocotb
from cocotb.triggers import RisingEdge
from cocotb.clock import Clock

@cocotb.test()
async def test_queue_arbitration_and_dma_desc(dut):
    """Тестируем Round-Robin / Приоритетный арбитраж очередей и генерацию DMA-дескриптора"""

    # Переключаем указатель на внутренний блок арбитра внутри топа
    arb = dut.u_arbiter

    cocotb.start_soon(Clock(arb.clk, 10, units="ns").start())

    # Инициализация интерфейсов через префикс 'arb.'
    arb.rst.value = 1
    arb.admin_sq_tail.value = 0
    arb.io_sq1_tail.value = 0
    arb.admin_sq_base_addr.value = 0xAAAA_0000_0000_0000
    arb.io_sq1_base_addr.value   = 0xBBBB_0000_0000_0000
    arb.dma_read_desc_ready.value = 0
    arb.dma_read_desc_status_valid.value = 0
    
    await RisingEdge(arb.clk)
    arb.rst.value = 0
    await RisingEdge(arb.clk)

    # Симулируем: Хост выставляет новые хвосты для ОБОИХ очередей одновременно
    arb.admin_sq_tail.value = 1
    arb.io_sq1_tail.value = 1
    await RisingEdge(arb.clk)

    # Проверяем дескриптор DMA Admin-очереди (ID=0)
    for _ in range(5):
        await RisingEdge(arb.clk)
        if arb.dma_read_desc_valid.value == 1:
            break

    assert arb.active_queue_id.value == 0
    assert arb.dma_read_desc_addr.value == 0xAAAA_0000_0000_0000
    assert arb.dma_read_desc_len.value == 64

    arb.dma_read_desc_ready.value = 1
    await RisingEdge(arb.clk)
    arb.dma_read_desc_ready.value = 0
    
    await RisingEdge(arb.clk)
    arb.dma_read_desc_status_valid.value = 1
    await RisingEdge(arb.clk)
    arb.dma_read_desc_status_valid.value = 0

    # Проверяем переключение на I/O-очередь (ID=1)
    for _ in range(5):
        await RisingEdge(arb.clk)
        if arb.dma_read_desc_valid.value == 1:
            break

    assert arb.active_queue_id.value == 1
    assert arb.dma_read_desc_addr.value == 0xBBBB_0000_0000_0000
    
    arb._log.info("🔥 [Успех] Регрессионный тест интеграции арбитра пройден!")
