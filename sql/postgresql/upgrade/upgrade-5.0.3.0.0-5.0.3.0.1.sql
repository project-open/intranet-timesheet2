-- upgrade-5.0.3.0.0-5.0.3.0.1.sql

SELECT acs_log__debug('/packages/intranet-timesheet2/sql/postgresql/upgrade/upgrade-5.0.3.0.0-5.0.3.0.1.sql','');

-- Fix L10n message
update lang_messages set message = 'Last 3 months' where message = 'last 3 month';


-- New category in order to modify the color for weekend
SELECT im_category_new (5008, 'Weekend', 'Intranet Absence Type'); 
update im_categories set aux_string2 = 'BBBBBB', enabled_p = 'f' where category_id = 5008;

