#---------------------------------------------------------------------------------------------------
__all__ = (
    'Protocol',
)

import enum
import time
import types

from regio.regmap.io import methods

#---------------------------------------------------------------------------------------------------
class Protocol(methods.Protocol):
    # TODO: Remove once enums are auto-generated for the Python library.
    class CommandCode(enum.IntEnum):
        NOP = 0
        READ = 1
        WRITE = 2
        CLEAR = 3

    class StatusCode(enum.IntEnum):
        RESET = 0
        READY = 1
        BUSY = 2

    def __init__(self, spec, if_name, timeout=100e-3, delay=1e-3):
        super().__init__(spec, if_name)

        if timeout is None:
            self.wait_count = None
        elif timeout < delay:
            raise ValueError(f'Timeout {timeout} must be greater than the delay of {delay}')
        elif delay > 0:
            self.wait_delay = delay
            self.wait_count = int(timeout / delay)
        else:
            self.wait_delay = 0
            self.wait_count = 0

    def _wait_status(self, proxy, test):
        count = self.wait_count
        while True:
            status = proxy.status().proxy
            if test(status):
                return status

            if count is None: # Loop infinitely for condition...
                continue

            if count <= 0:
                return None
            count -= 1
            time.sleep(self.wait_delay)

    def _transact(self, proxy, offset, value):
        do_write = value is not None
        if do_write:
            cmd_code = self.CommandCode.WRITE
            err_msg = f'writing value 0x{value:x} to memory word 0x{offset:x}'
        else:
            cmd_code = self.CommandCode.READ
            err_msg = f'reading from memory word 0x{offset:x}'

        # Setup for the transaction.
        status = self._wait_status(proxy, lambda st: st.code == self.StatusCode.READY)
        if status is None:
            raise TimeoutError('Controller not ready for ' + err_msg)

        proxy.addr = offset # Memory address expected in words, not bytes.
        if do_write:
            for data in proxy.wr_data[:self._ctx.data_count]:
                data._r = value & self._ctx.data_mask
                value >>= self._ctx.data_width

        # Trigger the transaction.
        cmd = proxy.command(0).proxy
        cmd.code = int(cmd_code)
        proxy.command = int(cmd)

        # Wait for the transaction to complete.
        status = self._wait_status(proxy, lambda st: st.done or st.timeout or st.error)
        if status is None:
            raise TimeoutError('Controller timeout when ' + err_msg)
        if status.timeout:
            raise TimeoutError('Transaction timeout when ' + err_msg)
        if status.error:
            raise IOError('Transaction error ' + err_msg)
        if status.burst_size != self._ctx.data_size:
            raise IOError('Transaction size mismatch ' + err_msg +
                          f' [expected {self._ctx.data_size}, got {int(status.burst_size)}]')

        # Read the data fetched by the transaction.
        if not do_write:
            value = 0
            for data in reversed(proxy.rd_data[:self._ctx.data_count]):
                value <<= self._ctx.data_width
                value |= int(data._r) & self._ctx.data_mask
            return value

    def start(self, proxy):
        # TODO: Get data_width from controller proxy's spec region info. Add property to variable to
        #       get the spec? Something like:
        # from regio.regmap.spec import info
        # ctx.data_width = info.data_width_of(proxy().spec)
        ctx = types.SimpleNamespace()
        ctx.data_width = 32
        ctx.data_mask = (1 << ctx.data_width) - 1
        ctx.data_size = int(proxy.info_burst.min)
        ctx.data_count = ctx.data_size // (ctx.data_width // 8)
        self._ctx = ctx

        proxy.burst.len = 1 # Restrict burst operations to a single word.
        super().start(proxy)

    def stop(self, proxy):
        super().start(proxy)
        del self._ctx

    def read(self, proxy, offset, size):
        return self._transact(proxy, offset, None)

    def write(self, proxy, offset, size, value):
        self._transact(proxy, offset, int(value))
