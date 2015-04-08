
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

set cal_ics [im_absence_ics -absence_id $absence_id]

ad_return_string_as_file -string $cal_ics -filename absence.ics -mime_type text/calendar