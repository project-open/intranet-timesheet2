
ad_page_contract {

    Display one absence as ics file for a user

    @author Malte Sussdorff (malte.sussdorff@cognovis.de)
    @creation-date 2014-04-22
    @cvs-id $Id$
} {
    absence_id
} -properties {
} -validate {
} -errors {
}

set current_user_id [ad_maybe_redirect_for_registration]

callback im_user_absence_perm_check -absence_id $absence_id
im_user_absence_permissions $current_user_id $absence_id view read write admin

if {$view} {
    set cal_ics [im_absence_ics -absence_id $absence_id]

    ad_return_string_as_file -string $cal_ics -filename absence.ics -mime_type text/calendar
} else {
    ad_returnredirect "index"
}