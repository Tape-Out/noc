# noc

Network on chip.

![maturity](https://img.shields.io/badge/maturity-simulated-yellow) ![license](https://img.shields.io/badge/license-MulanPSL--2.0-blue)

Part of the [Tape-Out](https://github.com/Tape-Out) IP library: Bluespec IP over the
bus-neutral contracts in [`hwcore`](https://github.com/Tape-Out/hwcore), assembled by
[`xirang`](https://github.com/Tape-Out/xirang). Maturity runs `planned` -> `simulated` ->
`fpga-proven` -> `asic-ready` -> `silicon-proven`.

## Status

Simulated. A library in Bluespec Haskell that builds a packet network from a topology:

- `class Topology t` answers three questions: how many nodes there are, which port a packet at one node takes towards a destination, and which node sits behind a given port.
- `Mesh w h` is a mesh whose width and height are numeric types, routed dimension-order (X, then Y). `P2P` is a single link between two nodes.
- `mkRouter` computes each router's routing table at compile time from the class and looks it up by destination at run time. It has two-deep buffers per port and a round-robin choice per output port.
- `mkNetwork` instantiates one router per node and connects every port the topology says has a neighbour. If the topology's node count differs from the network's type, the build stops.

Dimension-order routing on a mesh never turns from Y back to X, so the channel dependency graph has no cycle, and by Dally and Seitz (1987) the network cannot deadlock. A ring without virtual channels does have such a cycle, which is why no ring topology is offered yet.

The testbench sends an all-to-all pattern across a 2x2 mesh with a sequence number per source and destination. It holds two receivers back for 300 cycles so every buffer fills, then checks that all packets arrive, in order, at the right node. A point-to-point link carries traffic both ways.

Packets are a single flit (8-bit destination and source, a payload of any width). Wormhole switching, multi-flit packets, virtual channels and carrying bus transactions over the network are not implemented.

## Specification sources

The specifications this IP is implemented against, with their links, digests and the clause-by-clause comparison, are kept on the [`spec` branch](https://github.com/Tape-Out/noc/tree/spec).

## License

Mulan PSL v2.
