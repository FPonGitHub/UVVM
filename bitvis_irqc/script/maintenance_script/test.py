import sys

try:
    from hdlunit import HDLUnit
except:
    print('Unable to import HDLUnit module. See HDLUnit documentation for installation instructions.')
    sys.exit(1)

    
print('Verify Bitvis IRQC DUT')


hdlunit = HDLUnit()
hdlunit.set_simulator("GHDL")

# Set testcase detection string
hdlunit.set_testcase_id("GC_TESTCASE")

# Add util, fw and VIP Scoreboard
hdlunit.add_files("../../uvvm_util/src/*.vhd", "uvvm_util")
hdlunit.add_files("../../uvvm_vvc_framework/src/*.vhd", "uvvm_vvc_framework")
hdlunit.add_files("../../bitvis_vip_scoreboard/src/*.vhd", "bitvis_vip_scoreboard")
# Add other VIPs in the TB
#  - SBI VIP
hdlunit.add_files("../../bitvis_vip_sbi/src/*.vhd", "bitvis_vip_sbi")
hdlunit.add_files("../../uvvm_vvc_framework/src_target_dependent/*.vhd", "bitvis_vip_sbi")
# Add DUT
hdlunit.add_files("../../bitvis_irqc/src/*.vhd", "bitvis_irqc")
# Add TB/TH
hdlunit.add_files("../../bitvis_irqc/tb/*.vhd", "bitvis_irqc")
hdlunit.add_files("../../bitvis_irqc/tb/maintenance_tb/*.vhd", "bitvis_irqc")
hdlunit.start()


num_failing_tests = hdlunit.get_num_fail_tests()

hdlunit.check_run_results(exp_fail=0)

sys.exit(num_failing_tests)


