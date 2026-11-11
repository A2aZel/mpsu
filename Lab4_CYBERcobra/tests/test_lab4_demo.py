"""Exercise the GUI demo with Icarus Verilog, when installed on PATH."""
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest


PROJECT = Path(__file__).resolve().parents[1]
SOURCES = (
    "memory_pkg.sv", "alu_opcodes_pkg.sv", "fulladder.sv", "fulladder4.sv",
    "fulladder32.sv", "alu.sv", "instr_mem.sv", "register_file.sv",
    "CYBERcobra.sv",
)
IVERILOG = shutil.which("iverilog")
VVP = shutil.which("vvp")
PASS = re.compile(
    r"DEMO_PASS SW=([0-9a-fA-F]+) OUT=([0-9a-fA-F]+) "
    r"PC=([0-9a-fA-F]+) after (\d+) ordinary steps; "
    r"J0 stable for 2 extra steps; checks=(\d+)"
)


@unittest.skipUnless(IVERILOG and VVP, "iverilog and vvp are required on PATH")
class DemoTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.build = tempfile.TemporaryDirectory()
        cls.addClassCleanup(cls.build.cleanup)
        cls.build_dir = Path(cls.build.name)
        cls.demo_source = (PROJECT / "walkthrough/tb_lab4_demo.sv").read_text()
        cls.image = cls.compile_demo(cls.demo_source, cls.build_dir)

    @staticmethod
    def compile_demo(source, directory):
        testbench = directory / "tb_lab4_demo.sv"
        image = directory / "demo.vvp"
        testbench.write_text(source, encoding="utf-8")
        result = subprocess.run(
            [IVERILOG, "-g2012", "-s", "tb_lab4_demo", "-o", str(image),
             *(str(PROJECT / name) for name in SOURCES), str(testbench)],
            cwd=directory, capture_output=True, text=True, timeout=30,
        )
        if result.returncode:
            raise AssertionError(result.stdout + result.stderr)
        return image

    def setUp(self):
        self.run_dir = tempfile.TemporaryDirectory()
        self.addCleanup(self.run_dir.cleanup)
        self.directory = Path(self.run_dir.name)
        # instr_mem reads a relative filename; never mutate the supplied image.
        shutil.copyfile(PROJECT / "program.mem", self.directory / "program.mem")

    def simulate(self, image=None, sw=None):
        args = [VVP, str(image or self.image)]
        if sw is not None:
            args.append(f"+SW={sw:04x}")
        return subprocess.run(
            args, cwd=self.directory, capture_output=True, text=True, timeout=10,
        )

    def assert_pass(self, result, sw):
        output = result.stdout + result.stderr
        self.assertEqual(result.returncode, 0, output)
        self.assertNotIn("DEMO_FAIL", output)
        matches = PASS.findall(output)
        self.assertEqual(len(matches), 1, output)
        actual_sw, actual_out, actual_pc, steps, checks = matches[0]
        # The input is sign-extended by hardware before its even bits are packed.
        operand = sw | (0xFFFF0000 if sw & 0x8000 else 0)
        expected = sum(((operand >> (2 * bit)) & 1) << bit for bit in range(16))
        iterations = max(1, (operand.bit_length() + 1) // 2)
        self.assertEqual(int(actual_sw, 16), sw, output)
        self.assertEqual(int(actual_out, 16), expected, output)
        self.assertEqual(int(actual_pc, 16), 0x2C, output)
        self.assertEqual(int(steps), 5 + 6 * iterations, output)
        self.assertEqual(int(checks), 18 + 5 * iterations, output)

    def test_input_values_and_every_single_bit(self):
        values = [0, 1, 0x0055, 0x00AA, 0x03B8, 0x5555, 0x7FFF,
                  0x8000, 0xAAAA, 0xFFFF, *(1 << bit for bit in range(16))]
        for sw in dict.fromkeys(values):
            with self.subTest(sw=f"{sw:04x}"):
                self.assert_pass(self.simulate(sw=sw), sw)

    def test_editing_only_initial_sw_value(self):
        original = "logic [15:0] sw = 16'h03b8;"
        self.assertEqual(self.demo_source.count(original), 1)
        edited = self.demo_source.replace(original, "logic [15:0] sw = 16'h0055;")
        image = self.compile_demo(edited, self.directory)
        self.assert_pass(self.simulate(image=image), 0x0055)

    def test_wrong_program_is_rejected(self):
        memory = self.directory / "program.mem"
        words = memory.read_text().splitlines()
        self.assertEqual(words[0].lower(), "20000002")
        words[0] = "00000002"  # LI r2, 0 instead of IN r2.
        memory.write_text("\n".join(words) + "\n", encoding="ascii")
        result = self.simulate(sw=0x03B8)
        output = result.stdout + result.stderr
        self.assertNotEqual(result.returncode, 0, output)
        self.assertIn("DEMO_FAIL step=1 input loaded into r2", output)
        self.assertNotIn("DEMO_PASS", output)

    def test_resuming_after_finish_does_not_fail_or_run_forever(self):
        self.assertEqual(self.demo_source.count("$finish;"), 1)
        # Model a GUI simulator continuing past its first $finish stop.
        resumed = self.demo_source.replace("$finish;", ";")
        image = self.compile_demo(resumed, self.directory)
        self.assert_pass(self.simulate(image=image, sw=0x03B8), 0x03B8)


if __name__ == "__main__":
    unittest.main()
