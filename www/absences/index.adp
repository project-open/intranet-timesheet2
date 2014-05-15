<master src="../../../intranet-core/www/master">
<property name="title">@page_title@</property>
<property name="context">@context@</property>
<property name="main_navbar_label">timesheet2_absences</property>
<property name="left_navbar">@left_navbar_html;noquote@</property>


<script type="text/javascript">
$(".po_form_element").each(function(index) {
     $(this).children().each(function( index_1 ) {
        if ( $(this).is('input') && $(this).attr('name') == 'start_date') {
            $( $(this) ).parents().each(function() {
                if ($(this).is('tr')){
                    $(this).attr('id', 'start_date_tr');
                    return false;
                };
            });                    
        };
        if ( $(this).is('input') && $(this).attr('name') == 'end_date') {
            $( $(this) ).parents().each(function() {
                if ($(this).is('tr')){
                    $(this).attr('id', 'end_date_tr');
                    return false;
                };
            });                    
        };        
     });
});

// Important for 'refreshs'
$("#timescale").trigger("change");

</script>


<if "" ne @absence_cube_html@>
<%= [im_box_header $page_title] %>
@absence_cube_html;noquote@
<%= [im_box_footer] %>
</if>

<%= [im_box_header $page_title] %>

	<table class='table_list_page'>
	    <%= $table_header_html %>
	    <%= $table_body_html %>
	    <%= $table_continuation_html %>
	</table>

<%= [im_box_footer] %>

