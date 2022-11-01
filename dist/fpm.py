#!/usr/bin/env python3
from pathlib import Path
from pynq import Overlay
import struct
import logging
import argparse
import enum
import sys


class Flags(enum.IntFlag):
  NUMBER_A = 0b1
  NUMBER_B = 0b10
  RESULT = 0b100


class Ports(enum.IntEnum):
  INPUT = 0x0
  IN_FLAGS = 0x4
  RESULT = 0x8
  OUT_FLAGS = 0xC


def float_to_bytes(num):
  return struct.pack('!f', num)


def u32_to_float(num):
  return struct.unpack('!f', struct.pack('!I', num))[0]


def float_to_bitstring(num):
  return ''.join('{:0>8b}'.format(c) for c in struct.pack('!f', num))


def multiply_float(overlay, a, b):
  logging.info(f"Multipling {a} and {b}")
  # wait A_READY
  while not overlay.fpm_ip_AXI_0.read(Ports.OUT_FLAGS) & Flags.NUMBER_A:
    pass

  logging.info(f"Writing {a} as first number")
  logging.debug(f"As binary: {float_to_bitstring(a)}")
  # write A, A_VALID
  overlay.fpm_ip_AXI_0.write(Ports.INPUT, float_to_bytes(a))
  overlay.fpm_ip_AXI_0.write(Ports.IN_FLAGS, Flags.NUMBER_A.value)

  # wait B_READY & flags
  while not overlay.fpm_ip_AXI_0.read(Ports.OUT_FLAGS) & Flags.NUMBER_B:
    pass

  logging.info(f"Writing {b} as second number")
  logging.debug(f"As binary: {float_to_bitstring(b)}")
  # wait b, flags = READ_B
  overlay.fpm_ip_AXI_0.write(Ports.INPUT, float_to_bytes(b))
  overlay.fpm_ip_AXI_0.write(Ports.IN_FLAGS, Flags.NUMBER_B.value)

  # wait DONE & flags
  while not overlay.fpm_ip_AXI_0.read(Ports.OUT_FLAGS) & Flags.RESULT:
    pass

  # read result
  result = u32_to_float(overlay.fpm_ip_AXI_0.read(Ports.RESULT))
  logging.info(f"Result of {a}*{b}")
  logging.debug(f"As binary: {float_to_bitstring(result)}")

  return result


def main(args):
  path = args.bitstream
  if not (path.is_file() and path.with_suffix('.tcl').is_file()):
    print("Bitstream file and/or Block Diagram file not found",
          file=sys.stderr)
    return -1

  overlay = Overlay(str(path))

  result = multiply_float(overlay, args.a, args.b)

  print(result)
  return 0


if __name__ == "__main__":
  parser = argparse.ArgumentParser(
    formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    description="Multiply a pair of floating point numers")
  parser.add_argument("a", help="multiplicand", type=float)
  parser.add_argument("b", help="multiplier", type=float)
  parser.add_argument("-v",
                      "--verbose",
                      help="increase output verbosity",
                      action="store_true")
  parser.add_argument("--bitstream",
                      help="path of the bitstream file",
                      default="system.bit",
                      type=Path)
  args = parser.parse_args()

  if args.verbose:
    logging.basicConfig(level=logging.DEBUG, format='%(message)s')

  sys.exit(main(args))
