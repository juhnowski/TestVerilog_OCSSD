import cocotb
from cocotb.triggers import RisingEdge
from cocotb.clock import Clock

def make_nvme_vector(opcode, prp1, prp2, channel, lun, chunk, page):
    cmd = bytearray(64)
    cmd[0] = opcode
    for i in range(8):
        cmd[24 + i] = (prp1 >> (8 * i)) & 0xFF
    for i in range(8):
        cmd[32 + i] = (prp2 >> (8 * i)) & 0xFF
    cmd[56] = page & 0xFF
    cmd[57] = (page >> 8) & 0xFF
    cmd[58] = chunk & 0xFF
    cmd[59] = (chunk >> 8) & 0xFF
    cmd[60] = lun
    cmd[61] = channel

    value = 0
    for i, b in enumerate(cmd):
        value |= b << (8 * i)
    return value

@cocotb.test()
async def test_parser_ocssd_command(dut):
    """Проверяем, что парсер верно извлекает PPA адреса Open-Channel"""

    # Обращаемся к парсеру через иерархию топа
    parser = dut.u_parser

    cocotb.start_soon(Clock(parser.clk, 10, units="ns").start())

    # Сброс
    parser.rst.value = 1
    parser.cmd_valid.value = 0
    await RisingEdge(parser.clk)
    parser.rst.value = 0
    await RisingEdge(parser.clk)

    # Формируем тестовую команду
    test_vector = make_nvme_vector(
        opcode=0x01, prp1=0xCAFE0000, prp2=0x0, channel=3, lun=1, chunk=512, page=64
    )

    # Подаем на вход парсера
    parser.cmd_data.value = test_vector
    parser.cmd_valid.value = 1
    await RisingEdge(parser.clk)
    parser.cmd_valid.value = 0
    await RisingEdge(parser.clk)

    # Проверяем распаковку
    assert parser.cmd_opcode.value == 0x01
    assert parser.cmd_prp1.value == 0xCAFE0000
    assert parser.ppa_channel.value == 3
    assert parser.ppa_lun.value == 1
    assert parser.ppa_chunk.value == 512
    assert parser.ppa_page.value == 64
    
    parser._log.info("🔥 [Успех] Регрессионный тест парсера пройден!")
