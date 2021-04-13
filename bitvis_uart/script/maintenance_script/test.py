import sys

try:
    from hdlunit import HDLUnit
except:
    print('Unable to import HDLUnit module. See HDLUnit documentation for installation instructions.')
    sys.exit(1)

    
print('Verify Bitvis UART DUT')

hdlunit = HDLUnit(simulator='modelsim')

# Add util, fw and VIP Scoreboard
hdlunit.add_files("../../uvvm_util/src/*.vhd", "uvvm_util")
hdlunit.add_files("../../uvvm_vvc_framework/src/*.vhd", "uvvm_vvc_framework")
hdlunit.add_files("../../bitvis_vip_scoreboard/src/*.vhd", "bitvis_vip_scoreboard")

# Add other VIPs in the TB
#  - SBI VIP
hdlunit.add_files("../../bitvis_vip_sbi/src/*.vhd", "bitvis_vip_sbi")
hdlunit.add_files("../../uvvm_vvc_framework/src_target_dependent/*.vhd", "bitvis_vip_sbi")
#  - UART VIP
hdlunit.add_files("../../bitvis_vip_uart/src/*.vhd", "bitvis_vip_uart")
hdlunit.add_files("../../uvvm_vvc_framework/src_target_dependent/*.vhd", "bitvis_vip_uart")
#  - Clock Generator VVC
hdlunit.add_files("../../bitvis_vip_clock_generator/src/*.vhd", "bitvis_vip_clock_generator")
hdlunit.add_files("../../uvvm_vvc_framework/src_target_dependent/*.vhd", "bitvis_vip_clock_generator")
# Add DUT
hdlunit.add_files("../../bitvis_uart/src/*.vhd", "bitvis_uart")

# Add TB/TH
hdlunit.add_files("../../bitvis_uart/tb/maintenance_tb/*.vhd", "bitvis_uart")
hdlunit.add_files("../../bitvis_uart/tb/*.vhd", "bitvis_uart")

hdlunit.start(regression_mode=True, gui_mode=False)


num_failing_tests = hdlunit.get_num_fail_tests()

hdlunit.check_run_results(exp_fail=0)

sys.exit(num_failing_tests)
