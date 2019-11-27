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


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

library uvvm_vvc_framework;
use uvvm_vvc_framework.ti_vvc_framework_support_pkg.all;

library bitvis_vip_scoreboard;
use bitvis_vip_scoreboard.generic_sb_support_pkg.all;
use bitvis_vip_scoreboard.slv_sb_pkg.all;

use work.gmii_bfm_pkg.all;
use work.vvc_cmd_pkg.all;
use work.td_target_support_pkg.all;

--========================================================================================================================
--========================================================================================================================
package vvc_methods_pkg is

  --========================================================================================================================
  -- Types and constants for the GMII VVC
  --========================================================================================================================
  constant C_VVC_NAME     : string := "GMII_VVC";

  signal GMII_VVCT         : t_vvc_target_record := set_vvc_target_defaults(C_VVC_NAME);
  alias  THIS_VVCT         : t_vvc_target_record is GMII_VVCT;
  alias  t_bfm_config is t_gmii_bfm_config;

  -- Type found in UVVM-Util types_pkg
  constant C_GMII_INTER_BFM_DELAY_DEFAULT : t_inter_bfm_delay := (
    delay_type                          => NO_DELAY,
    delay_in_time                       => 0 ns,
    inter_bfm_delay_violation_severity  => WARNING
  );

  type t_vvc_config is
  record
    inter_bfm_delay                       : t_inter_bfm_delay;-- Minimum delay between BFM accesses from the VVC. If parameter delay_type is set to NO_DELAY, BFM accesses will be back to back, i.e. no delay.
    cmd_queue_count_max                   : natural;          -- Maximum pending number in command executor before executor is full. Adding additional commands will result in an ERROR.
    cmd_queue_count_threshold             : natural;          -- An alert with severity 'cmd_queue_count_threshold_severity' will be issued if command executor exceeds this count. Used for early warning if command executor is almost full. Will be ignored if set to 0.
    cmd_queue_count_threshold_severity    : t_alert_level;    -- Severity of alert to be initiated if exceeding cmd_queue_count_threshold
    result_queue_count_max                : natural;
    result_queue_count_threshold_severity : t_alert_level;
    result_queue_count_threshold          : natural;
    bfm_config                            : t_gmii_bfm_config; -- Configuration for the BFM. See BFM quick reference
    msg_id_panel                          : t_msg_id_panel;   -- VVC dedicated message ID panel
  end record;

  type t_vvc_config_array is array (t_channel range <>, natural range <>) of t_vvc_config;

  constant C_GMII_VVC_CONFIG_DEFAULT : t_vvc_config := (
    inter_bfm_delay                       => C_GMII_INTER_BFM_DELAY_DEFAULT,
    cmd_queue_count_max                   => C_CMD_QUEUE_COUNT_MAX, --  from adaptation package
    cmd_queue_count_threshold             => C_CMD_QUEUE_COUNT_THRESHOLD,
    cmd_queue_count_threshold_severity    => C_CMD_QUEUE_COUNT_THRESHOLD_SEVERITY,
    result_queue_count_max                => C_RESULT_QUEUE_COUNT_MAX,
    result_queue_count_threshold_severity => C_RESULT_QUEUE_COUNT_THRESHOLD_SEVERITY,
    result_queue_count_threshold          => C_RESULT_QUEUE_COUNT_THRESHOLD,
    bfm_config                            => C_GMII_BFM_CONFIG_DEFAULT,
    msg_id_panel                          => C_VVC_MSG_ID_PANEL_DEFAULT
  );

  type t_vvc_status is
  record
    current_cmd_idx       : natural;
    previous_cmd_idx      : natural;
    pending_cmd_cnt       : natural;
  end record;

  type t_vvc_status_array is array (t_channel range <>, natural range <>) of t_vvc_status;

  constant C_VVC_STATUS_DEFAULT : t_vvc_status := (
    current_cmd_idx      => 0,
    previous_cmd_idx     => 0,
    pending_cmd_cnt      => 0
  );

  -- Transaction information to include in the wave view during simulation
  type t_transaction_info is
  record
    operation       : t_operation;
    msg             : string(1 to C_VVC_CMD_STRING_MAX_LENGTH);
    num_bytes       : natural;
    data            : t_byte_array(0 to C_VVC_CMD_DATA_MAX_BYTES-1);
  end record;

  type t_transaction_info_array is array (t_channel range <>, natural range <>) of t_transaction_info;

  constant C_TRANSACTION_INFO_DEFAULT : t_transaction_info := (
    operation           =>  NO_OPERATION,
    msg                 => (others => ' '),
    num_bytes           => 0,
    data                => (others => (others => '0'))
  );


  shared variable shared_gmii_vvc_config       : t_vvc_config_array(      t_channel'left to t_channel'right, 0 to C_MAX_VVC_INSTANCE_NUM-1) := (others => (others => C_GMII_VVC_CONFIG_DEFAULT));
  shared variable shared_gmii_vvc_status       : t_vvc_status_array(      t_channel'left to t_channel'right, 0 to C_MAX_VVC_INSTANCE_NUM-1) := (others => (others => C_VVC_STATUS_DEFAULT));
  shared variable shared_gmii_transaction_info : t_transaction_info_array(t_channel'left to t_channel'right, 0 to C_MAX_VVC_INSTANCE_NUM-1) := (others => (others => C_TRANSACTION_INFO_DEFAULT));

  
  -- Scoreboard
  shared variable shared_gmii_sb : t_generic_sb;


  --========================================================================================================================
  -- Methods dedicated to this VVC
  -- - These procedures are called from the testbench in order to executor BFM calls
  --   in the VVC command executor. The VVC will store and forward these calls to the
  --   GMII BFM when the command is at the from of the VVC command executor.
  --========================================================================================================================

  procedure gmii_write(
    signal   VVCT                      : inout t_vvc_target_record;
    constant vvc_instance_idx          : in    integer;
    constant channel                   : in    t_channel;
    constant data                      : in    t_byte_array;
    constant msg                       : in    string;
    constant scope                     : in    string                      := C_VVC_CMD_SCOPE_DEFAULT;
    constant use_provided_msg_id_panel : in    t_use_provided_msg_id_panel := DO_NOT_USE_PROVIDED_MSG_ID_PANEL;
    constant msg_id_panel              : in    t_msg_id_panel              := shared_msg_id_panel
  );

  procedure gmii_read(
    signal   VVCT                      : inout t_vvc_target_record;
    constant vvc_instance_idx          : in    integer;
    constant channel                   : in    t_channel;
    constant num_bytes                 : in    positive;
    constant msg                       : in    string;
    constant scope                     : in    string                      := C_VVC_CMD_SCOPE_DEFAULT;
    constant use_provided_msg_id_panel : in    t_use_provided_msg_id_panel := DO_NOT_USE_PROVIDED_MSG_ID_PANEL;
    constant msg_id_panel              : in    t_msg_id_panel              := shared_msg_id_panel
  );


  --==============================================================================
  -- Activity Watchdog
  --==============================================================================
  procedure activity_watchdog_register_vvc_state( signal global_trigger_testcase_inactivity_watchdog : inout std_logic;
                                                  constant busy                                      : in    boolean;
                                                  constant vvc_idx_for_activity_watchdog             : in    integer;
                                                  constant last_cmd_idx_executed                     : in    natural;
                                                  constant scope                                     : in    string := "vvc_register");
                                                  
                                                  
end package vvc_methods_pkg;


package body vvc_methods_pkg is


  --========================================================================================================================
  -- Methods dedicated to this VVC
  --========================================================================================================================

  procedure gmii_write(
    signal   VVCT                      : inout t_vvc_target_record;
    constant vvc_instance_idx          : in    integer;
    constant channel                   : in    t_channel;
    constant data                      : in    t_byte_array;
    constant msg                       : in    string;
    constant scope                     : in    string                      := C_VVC_CMD_SCOPE_DEFAULT;
    constant use_provided_msg_id_panel : in    t_use_provided_msg_id_panel := DO_NOT_USE_PROVIDED_MSG_ID_PANEL;
    constant msg_id_panel              : in    t_msg_id_panel              := shared_msg_id_panel
  ) is
    constant proc_name : string := "gmii_write";
    constant proc_call : string := proc_name & "(" & to_string(VVCT, vvc_instance_idx, channel) & ")";
  begin
  -- Create command by setting common global 'VVCT' signal record and dedicated VVC 'shared_vvc_cmd' record
  -- locking semaphore in set_general_target_and_command_fields to gain exclusive right to VVCT and shared_vvc_cmd
  -- semaphore gets unlocked in await_cmd_from_sequencer of the targeted VVC
    set_general_target_and_command_fields(VVCT, vvc_instance_idx, channel, proc_call, msg, QUEUED, WRITE);
    shared_vvc_cmd.num_bytes                 := data'length;
    shared_vvc_cmd.data                      := (others => (others => 'U'));
    shared_vvc_cmd.data(0 to data'length-1)  := data;
    shared_vvc_cmd.use_provided_msg_id_panel := use_provided_msg_id_panel;
    shared_vvc_cmd.msg_id_panel              := msg_id_panel;
    send_command_to_vvc(VVCT, std.env.resolution_limit, scope, msg_id_panel);
  end procedure gmii_write;


  procedure gmii_read(
    signal   VVCT                      : inout t_vvc_target_record;
    constant vvc_instance_idx          : in    integer;
    constant channel                   : in    t_channel;
    constant num_bytes                 : in    positive;
    constant msg                       : in    string;
    constant scope                     : in    string                      := C_VVC_CMD_SCOPE_DEFAULT;
    constant use_provided_msg_id_panel : in    t_use_provided_msg_id_panel := DO_NOT_USE_PROVIDED_MSG_ID_PANEL;
    constant msg_id_panel              : in    t_msg_id_panel              := shared_msg_id_panel
  ) is
    constant proc_name : string := "gmii_read";
    constant proc_call : string := proc_name & "(" & to_string(VVCT, vvc_instance_idx, channel) & ")";
  begin
  -- Create command by setting common global 'VVCT' signal record and dedicated VVC 'shared_vvc_cmd' record
  -- locking semaphore in set_general_target_and_command_fields to gain exclusive right to VVCT and shared_vvc_cmd
  -- semaphore gets unlocked in await_cmd_from_sequencer of the targeted VVC
    set_general_target_and_command_fields(VVCT, vvc_instance_idx, channel, proc_call, msg, QUEUED, READ);
    shared_vvc_cmd.num_bytes                 := num_bytes;
    shared_vvc_cmd.use_provided_msg_id_panel := use_provided_msg_id_panel;
    shared_vvc_cmd.msg_id_panel              := msg_id_panel;
    send_command_to_vvc(VVCT, std.env.resolution_limit, scope, msg_id_panel);
  end procedure gmii_read;


  --==============================================================================
  -- Activity Watchdog
  --==============================================================================
  procedure activity_watchdog_register_vvc_state( signal global_trigger_testcase_inactivity_watchdog : inout std_logic;
                                                  constant busy                                      : in    boolean;
                                                  constant vvc_idx_for_activity_watchdog             : in    integer;
                                                  constant last_cmd_idx_executed                     : in    natural;
                                                  constant scope                                     : in    string := "vvc_register") is
  begin
    shared_inactivity_watchdog.priv_report_vvc_activity(vvc_idx               => vvc_idx_for_activity_watchdog,
                                                        busy                  => busy,
                                                        last_cmd_idx_executed => last_cmd_idx_executed);
    gen_pulse(global_trigger_testcase_inactivity_watchdog, 0 ns, "pulsing global trigger for inactivity watchdog", scope, ID_NEVER);
  end procedure;
  
end package body vvc_methods_pkg;