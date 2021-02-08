-- upgrade-5.0.4.0.0-5.0.4.0.1.sql

SELECT acs_log__debug('/packages/intranet-timesheet2/sql/postgresql/upgrade/upgrade-5.0.4.0.0-5.0.4.0.1.sql','');




-- Add missing columns to acs_datatype
--
create or replace function inline_0 () 
returns integer as $body$
DECLARE
	row			RECORD;
	v_count			integer;
BEGIN

	FOR row IN
		select 	absence_id
		from 	im_user_absences
		where 	not exists (select * from acs_objects where object_id = absence_id);
	LOOP
		IF row.absence_id < 5000 THEN
			delete from im_user_absences where absence_id = row.absence_id
		ELSE
			insert into acs_objects (object_id, object_type) values (row.absence_id, 'im_user_absence');
		END IF;
	END LOOP;

	-- Check if there is already a foreign key constraint on the
	-- primary key of im_user_absences
	SELECT count(*)
	INTO v_count
	FROM (
		SELECT
			tc.table_schema, 
			tc.constraint_name, 
			tc.table_name, 
			kcu.column_name, 
			ccu.table_schema AS foreign_table_schema,
			ccu.table_name AS foreign_table_name,
			ccu.column_name AS foreign_column_name 
		FROM 
			information_schema.table_constraints AS tc 
			JOIN information_schema.key_column_usage AS kcu
			  ON tc.constraint_name = kcu.constraint_name
			  AND tc.table_schema = kcu.table_schema
			JOIN information_schema.constraint_column_usage AS ccu
			  ON ccu.constraint_name = tc.constraint_name
			  AND ccu.table_schema = tc.table_schema
		WHERE tc.constraint_type = 'FOREIGN KEY'
		) t
	WHERE
		table_name = 'im_user_absences' and
		column_name = 'absence_id';

	IF v_count > 0 THEN return 1; END IF;
	
	ALTER TABLE im_user_absences
	ADD CONSTRAINT im_user_absences_fk
	FOREIGN KEY (absence_id)
	REFERENCES acs_objects (object_id);

	return 0;
END;$body$ language 'plpgsql';
SELECT inline_0 ();
DROP FUNCTION inline_0 ();















-- insert into acs_objects (object_id, object_type) values (       9877 , 'im_user_absence');
-- insert into acs_objects (object_id, object_type) values (       9878 , 'im_user_absence');
-- insert into acs_objects (object_id, object_type) values (       9879 , 'im_user_absence');
-- insert into acs_objects (object_id, object_type) values (       9880 , 'im_user_absence');
-- insert into acs_objects (object_id, object_type) values (       9881 , 'im_user_absence');
-- insert into acs_objects (object_id, object_type) values (      11729 , 'im_user_absence');
-- insert into acs_objects (object_id, object_type) values (      13549 , 'im_user_absence');
-- insert into acs_objects (object_id, object_type) values (      14326 , 'im_user_absence');
-- insert into acs_objects (object_id, object_type) values (      16171 , 'im_user_absence');
-- insert into acs_objects (object_id, object_type) values (      16954 , 'im_user_absence');
-- insert into acs_objects (object_id, object_type) values (      16973 , 'im_user_absence');
-- insert into acs_objects (object_id, object_type) values (      17039 , 'im_user_absence');
-- insert into acs_objects (object_id, object_type) values (      17043 , 'im_user_absence');
-- insert into acs_objects (object_id, object_type) values (      20746 , 'im_user_absence');

