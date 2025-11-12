# Mem Infra

Memory infrastructure library. `mem` is a base library, included by many other low-level libraries, including `fifo`.

As a result, no infrastructure for memory interfaces making use of `fifo`, `reg`, etc. can be included directly
within `mem` without introducing circular dependencies. By including these components in `mem.infra` instead the
circular dependencies are avoided.
