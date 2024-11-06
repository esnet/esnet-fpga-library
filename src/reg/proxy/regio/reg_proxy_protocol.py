#---------------------------------------------------------------------------------------------------
__all__ = (
    'Protocol',
)

import time

from regio.regmap.io import methods

#---------------------------------------------------------------------------------------------------
class Protocol(methods.Protocol):
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
        addr = offset << 2 # Register offset given in words, not bytes.
        do_write = value is not None
        if do_write:
            err_msg = f'writing value 0x{value:x} to register address 0x{addr:x}'
        else:
            err_msg = f'reading from register address 0x{addr:x}'

        # Setup for the transaction.
        status = self._wait_status(proxy, lambda st: st.ready)
        if status is None:
            raise TimeoutError('Controller not ready for ' + err_msg)

        proxy.address = addr
        if do_write:
            proxy.wr_data = value

        # Trigger the transaction.
        cmd = proxy.command(0).proxy
        cmd.wr_rd_n = int(do_write)
        proxy.command = int(cmd)

        # Wait for the transaction to complete.
        status = self._wait_status(proxy, lambda st: st.done or st.error)
        if status is None:
            raise TimeoutError('Controller timeout when ' + err_msg)
        if status.error:
            raise IOError('Transaction error ' + err_msg)

        # Read the data fetched by the transaction.
        if not do_write:
            return int(proxy.rd_data)

    def start(self, proxy):
        proxy.wr_byte_en = 0xf # Enable all byte lanes for writing.
        super().start(proxy)

    def read(self, proxy, offset, size):
        return self._transact(proxy, offset, None)

    def write(self, proxy, offset, size, value):
        self._transact(proxy, offset, int(value))
