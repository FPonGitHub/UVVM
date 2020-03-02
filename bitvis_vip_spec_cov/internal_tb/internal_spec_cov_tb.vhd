--========================================================================================================================
-- Copyright (c) 2018 by Bitvis AS.  All rights reserved.
-- You should have received a copy of the license file containing the MIT License (see LICENSE.TXT), if not,
-- contact Bitvis AS <support@bitvis.no>.
--
-- UVVM AND ANY PART THEREOF ARE PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
-- WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS
-- OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
-- OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH UVVM OR THE USE OR OTHER DEALINGS IN UVVM.
--========================================================================================================================

------------------------------------------------------------------------------------------
-- Description   : See library quick reference (under 'doc') and README-file(s)
------------------------------------------------------------------------------------------


library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

library bitvis_vip_spec_cov;
use bitvis_vip_spec_cov.spec_cov_pkg.all;
use bitvis_vip_spec_cov.local_adaptations_pkg.all;


entity spec_cov_tb is
  generic (
    GC_TEST : string := "UVVM"
    );
end entity spec_cov_tb;


architecture func of spec_cov_tb is

begin

  ------------------------------------------------
  -- PROCESS: p_main
  ------------------------------------------------
  p_main : process
    constant C_SCOPE            : string  := "UVVM TB";
    constant C_DEFAULT_TESTCASE : string  := "T_DEFAULT";


    -- helper procedures
    procedure provoke_uvvm_status_error(alert_level : t_alert_level) is
    begin
      check_value(true = false, alert_level, "triggering alert");
    end procedure;


  begin

    -- To avoid that log files from different test cases (run in separate
    -- simulations) overwrite each other.
    set_log_file_name(GC_TEST & "_Log.txt");
    set_alert_file_name(GC_TEST & "_Alert.txt");

    shared_spec_cov_config := C_SPEC_COV_CONFIG_DEFAULT;
    set_alert_stop_limit(TB_ERROR, 2);



    if GC_TEST = "test_init_with_no_requirement_file" then
      --
      -- This test will test initialize_req_cov() without a 
      -- requirement input file
      --
      log(ID_LOG_HDR, "Testing initialize_req_cov() with no requirement file.", C_SCOPE);
      -- Run testcase
      initialize_req_cov("TC_1", "pc_1.csv");
      register_req_cov("REQ_1");
      -- End testcase
      finalize_req_cov(VOID);



    elsif GC_TEST = "test_init_with_requirement_file" then
      --
      -- This test will test initialize_req_cov() with a requirement input file
      --
      log(ID_LOG_HDR, "Testing initialize_req_cov() with a requirement file.", C_SCOPE);
      -- Run testcase
      initialize_req_cov("TC_2", "../internal_tb/internal_req_file.csv", "pc_2.csv");
      register_req_cov("REQ_2");
      -- End testcase      
      finalize_req_cov(VOID);



    elsif GC_TEST = "test_log_default_testcase_and_not_listed" then
      --
      -- This test will test register_req_cov() with default and unknown testcase, and with 
      -- unknown requirement label.
      --
      log(ID_LOG_HDR, "Testing register_req_cov() with default testcase, unknown testcase and unknown requirement label.", C_SCOPE);
      -- Run testcase
      initialize_req_cov("TC_3", "../internal_tb/internal_req_file.csv", "pc_3.csv");
      -- 1: testing default testcase
      register_req_cov("REQ_3");
      -- 2: testing unknown testcase
      register_req_cov("REQ_3", "TC_50", NA, "logging unknown testcase.", C_SCOPE);
      -- 3: testing unknown requirement
      -- Increment expected alerts so test will pass with missing requirement
      increment_expected_alerts(TB_WARNING, 1);      
      register_req_cov("REQ_10", "TC_1", NA, "logging unknown requirement.", C_SCOPE);
      -- End testcase
      finalize_req_cov(VOID);
      


    elsif GC_TEST = "test_log_testcase_pass_and_fail" then
      --
      -- This test will test register_req_cov() with default (NA, i.e. PASS) and explicit FAIL.
      --
      log(ID_LOG_HDR, "Testing register_req_cov() with no test_status (i.e. PASS) and test_status=FAIL.", C_SCOPE);
      -- Run testcase
      initialize_req_cov("TC_4", "../internal_tb/internal_req_file.csv", "pc_4.csv");
      register_req_cov("REQ_4", "TC_4_FAIL", FAIL);
      register_req_cov("REQ_4", "TC_4");
      -- End testcase
      finalize_req_cov(VOID);



    elsif GC_TEST = "test_uvvm_status_error_before_log" then
      --
      -- This test will test Spec Cov with an UVVM status error set prior to testcase.
      --
      log(ID_LOG_HDR, "Testing register_req_cov() with UVVM status error triggered prior to initialize_req_cov().", C_SCOPE);
      -- Provoking tb_error and incrementing alert stop limit
      provoke_uvvm_status_error(TB_ERROR);
      -- Run testcase
      initialize_req_cov("TC_5", "../internal_tb/internal_req_file.csv", "pc_5.csv");   
      register_req_cov("REQ_5");  
      -- End testcase
      finalize_req_cov(VOID);
      -- Increment expected alerts so test will pass with provoked UVVM TB_ERROR
      increment_expected_alerts(TB_ERROR, 1);


        
    elsif GC_TEST = "test_uvvm_status_error_after_log" then
      --
      -- This test will test Spec Cov with an UVVM status error set during testcase.
      --
      log(ID_LOG_HDR, "Testing register_req_cov() with UVVM status error triggered after register_req_cov() and prior to finalize_req_cov().", C_SCOPE);
      -- Run testcase
      initialize_req_cov("TC_6", "../internal_tb/internal_req_file.csv", "pc_6.csv");   
      register_req_cov("REQ_6", PASS);
      -- Provoking tb_error and incrementing alert stop limit
      provoke_uvvm_status_error(TB_ERROR);
      -- End testcase
      finalize_req_cov(VOID);
      -- Increment expected alerts so test will pass with provoked UVVM TB_ERROR
      increment_expected_alerts(TB_ERROR, 1);



    elsif GC_TEST = "test_open_no_existing_req_file" then
      --
      -- This test will test Spec Cov with an non-existing requirement file.
      --
      log(ID_LOG_HDR, "Testing initialize_req_cov() with non-existing requirement file.", C_SCOPE);
      increment_expected_alerts(TB_ERROR, 1);
      -- Run testcase
      initialize_req_cov("TC_7", "../internal_tb/non_existing_req_file.csv", "pc_7.csv");   
      -- End testcase
      finalize_req_cov(VOID);         



    ---==========================================================================
    --
    -- The following tests are intended for verifying the run_spec_cov.py post 
    -- processing script, and will not explicitly test the spec_cov_pkg.
    --
    ---==========================================================================
    elsif GC_TEST = "test_sub_requirement_pass" then
      --
      -- This test will run requirements for testing sub-requirement processing with run_spec_cov.py
      --
      log(ID_LOG_HDR, "Testing passing sub-requirement with test_status=NA, msg and SCOPE.", C_SCOPE);  
      -- Run testcase
      initialize_req_cov("TC_SUB_REQ", "../internal_tb/internal_sub_req_file.csv", "pc_8.csv");   
      register_req_cov("UART_REQ_BR_A", NA);
      register_req_cov("UART_REQ_BR_B", NA, "testing UART_REQ_BR_B without scope");
      register_req_cov("UART_REQ_ODD", PASS, "testing UART_REQ_BR_B with scope", C_SCOPE);
      register_req_cov("UART_REQ_EVEN", PASS, "testing UART_REQ_EVEN with scope", C_SCOPE);
      -- End testcase
      finalize_req_cov(VOID);

      
    elsif GC_TEST = "test_sub_requirement_fail" then
      --
      -- This test will run requirements for testing sub-requirement processing with run_spec_cov.py
      --
      log(ID_LOG_HDR, "Testing failing sub-requirement with test_status=NA, msg and SCOPE.", C_SCOPE);  
      -- Run testcase
      initialize_req_cov("TC_SUB_REQ", "../internal_tb/internal_sub_req_file.csv", "pc_9.csv");   
      register_req_cov("UART_REQ_BR_A", NA);
      register_req_cov("UART_REQ_BR_B", NA, "testing UART_REQ_BR_B without scope");
      register_req_cov("UART_REQ_ODD", FAIL, "testing UART_REQ_ODD with scope", C_SCOPE);
      register_req_cov("UART_REQ_EVEN", PASS, "testing UART_REQ_EVEN with scope", C_SCOPE);
      -- End testcase
      finalize_req_cov(VOID);



    elsif GC_TEST = "test_incomplete_testcase" then
      --
      -- This test will run requirements for testing incomplete testcase with run_spec_cov.py
      --
      log(ID_LOG_HDR, "Testing failing simulations with incomplete testcase.", C_SCOPE);  
      -- Run testcase
      initialize_req_cov("TC_1", "../internal_tb/internal_req_file.csv", "pc_10.csv");   
      register_req_cov("REQ_1");  
      log(ID_SEQUENCER, "\nProvoking 2 TB_ERRORs to stop simulations.", C_SCOPE);
      -- Provoking tb_error 2 times to make testcase fail and simulation abort
      provoke_uvvm_status_error(TB_ERROR);
      provoke_uvvm_status_error(TB_ERROR); 
      -- End testcase
      finalize_req_cov(VOID);


    else
      --
      -- The Generic Test is unknown.
      --
      alert(tb_error, "Unsupported test");
    end if;


    -----------------------------------------------------------------------------
    -- Ending the simulation
    -----------------------------------------------------------------------------
    wait for 1000 ns;             -- to allow some time for completion
    report_alert_counters(FINAL); -- Report final counters and print conclusion for simulation (Success/Fail)
    log(ID_LOG_HDR, "SIMULATION COMPLETED", C_SCOPE);

    -- Finish the simulation
    std.env.stop;
    wait;  -- to stop completely

  end process p_main;

end func;