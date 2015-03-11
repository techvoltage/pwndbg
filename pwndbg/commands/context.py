import gdb
import pwndbg.commands
import pwndbg.color
import pwndbg.vmmap
import pwndbg.symbol
import pwndbg.regs
import pwndbg.ui
import pwndbg.disasm
import pwndbg.chain
import pwndbg.commands.telescope
import pwndbg.events


@pwndbg.commands.ParsedCommand
@pwndbg.commands.OnlyWhenRunning
@pwndbg.events.stop
def context(*args):
    if len(args) == 0:
        args = ['reg','code','stack','backtrace']

    args = [a[0] for a in args]

    result = []

    result.append(pwndbg.color.legend())
    if 'r' in args: result.extend(context_regs())
    if 'c' in args: result.extend(context_code())
    if 's' in args: result.extend(context_stack())
    if 'b' in args: result.extend(context_backtrace())

    print('\n'.join(map(str, result)))

def context_regs():
    result = []
    result.append(pwndbg.color.blue(pwndbg.ui.banner("registers")))
    for reg in pwndbg.regs.gpr + (pwndbg.regs.frame, pwndbg.regs.stack, '$pc'):
        if reg is None:
            continue

        value = pwndbg.regs[reg]

        # Make the register stand out
        regname = pwndbg.color.bold(reg.ljust(4).upper())

        result.append("%s %s" % (regname, pwndbg.chain.format(value)))
    return result

def context_code():
    result = []
    result.append(pwndbg.color.blue(pwndbg.ui.banner("code")))
    pc = pwndbg.regs.pc
    instructions = pwndbg.disasm.near(pwndbg.regs.pc, 5)

    # In case $pc is in a new map we don't know about,
    # this will trigger an exploratory search.
    pwndbg.vmmap.find(pc)

    # Ensure screen data is always at the same spot
    for i in range(11 - len(instructions)):
        result.append('')

    # Find all of the symbols for the addresses
    symbols = []
    for i in instructions:
        symbol = pwndbg.symbol.get(i.address)
        if symbol:
            symbol = '<%s> ' % symbol
        symbols.append(symbol)

    # Find the longest symbol name so we can adjust
    longest_sym = max(map(len, symbols))

    # Pad them all out
    for i,s in enumerate(symbols):
        symbols[i] = s.ljust(longest_sym)

    # Print out each instruction
    for i,s in zip(instructions, symbols):
        asm    = pwndbg.disasm.color(i)
        prefix = ' =>' if i.address == pc else '   '

        line   = ' '.join((prefix, s + hex(i.address), asm))
        result.append(line)
    return result

def context_stack():
    result = []
    result.append(pwndbg.color.blue(pwndbg.ui.banner("stack")))
    telescope = pwndbg.commands.telescope.telescope(pwndbg.regs.sp, to_string=True)
    result.extend(telescope)
    return result

def context_backtrace():
    result = []
    result.append(pwndbg.color.blue(pwndbg.ui.banner("backtrace")))
    frame = gdb.selected_frame()
    for i in range(0,10):
        if frame:
            line = map(str, ('f', i, pwndbg.ui.addrsz(frame.pc()), frame.name() or '???'))
            line = ' '.join(line)
            result.append(line)
            frame = frame.older()
    return result