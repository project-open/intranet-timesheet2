# /packages/intranet-timesheet2/tcl/test/intranet-timesheet2-test-procs.tcl
#
# Copyright (C) 2024 Frank Bergmann (frank.bergmann@project-open.com)
#

ad_library {
    Test procedures for intranet-timesheet2
    @author frank.bergmann@project-open.com
    @creation-date 2024-11-27
}

aa_register_case \
    -cats { smoke production_safe web } \
    -libraries tclwebtest \
    timesheet_basic_logging_with_costs \
{
    Log hours on two tasks of a project and check that they are booked correctly.
} {
    set user_id [db_nextval acs_object_id_seq]
    set debug 1

    # Do the teardown before the test, so the data are left for manual inspection of the report
    timesheet_test_basic_teardown

    aa_run_with_teardown -test_code {
	
        # Login user
        array set user_info [twt::user::create -admin -user_id $user_id]
	# aa_log "user_info: [array get user_info]"
        twt::user::login $user_info(email) $user_info(password)

	# We need to define the test in a different file because we can't load the test multiple times.
	timesheet_test_basic -user_id $user_id

	# Logout user
	twt::user::logout
	twt::user::delete -user_id $user_id

    } -teardown_code {
	aa_log "before executing twt::user::delete"
	twt::user::delete -user_id $user_id
	# aa_log "before teardown"
	# timesheet_test_basic_teardown
    }
}


aa_register_case \
    -cats { smoke production_safe web } \
    -libraries tclwebtest \
    timesheet_google_form \
{
    Tests ::tclwebtest::form submit, which seems to have issues when run from within NS
} {
    set debug 1

    tclwebtest::user_agent_id "Custom mozilla"

    # get number of found entries for tclwebtest
    tclwebtest::do_request "http://www.google.com/"
    tclwebtest::field fill tclwebtest
    tclwebtest::form submit
    aa_log "user_info: response1_url=[tclwebtest::response url]"
    
    # go directly to the first entry
    tclwebtest::do_request http://www.google.com/
    tclwebtest::field fill tclwebtest
    tclwebtest::form submit {feeling lucky}
    
    aa_log "user_info: response2_url=[tclwebtest::response url]"

}
