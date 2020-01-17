<if @enable_master_p@>
<master src="../../../intranet-core/www/master">
<property name="doc(title)">@page_title;literal@</property>
<property name="@context@">@context;literal@</property>
<property name="main_navbar_label">timesheet2_absences</property>
</if>

<if @message@ not nil>
  <div class="general-message">@message@</div>
</if>

<table width="100%">
  <tr valign="top">
    <td width="50%">
      <%= [im_box_header $page_title] %>
      <formtemplate id="absence"></formtemplate></font>
      <%= [im_box_footer] %>

<if @form_mode@ eq "display" >
      <%= [im_component_bay left] %>
</if>

    </td>
    <td width="50%">

<if @form_mode@ eq "display" >
      <%= [im_component_bay right] %>
</if>


    </td>
  </tr>
</table>

<if @form_mode@ eq "display" >
      <%= [im_component_bay bottom] %>
</if>


<script type="text/javascript">
function calculateAbsenceDuration() {
	var debug = 1;
	if (debug) console.log('intranet-timesheet2/www/absences/new: Calculating absence duration: Started');

	var start_day = document.getElementById("start_date.day").value;
	if (1 == start_day.length) start_day = '0'+start_day;
	var start_month = document.getElementById("start_date.month").value;
	if (1 == start_month.length) start_month = '0'+start_month;
	var start_year = document.getElementById("start_date.year").value;
	var start_date = start_year + '-' + start_month + '-' + start_day;

	var end_day = document.getElementById("end_date.day").value;
	if (1 == end_day.length) end_day = '0'+end_day;
	var end_month = document.getElementById("end_date.month").value;
	if (1 == end_month.length) end_month = '0'+end_month;
	var end_year = document.getElementById("end_date.year").value;
	var end_date = end_year + '-' + end_month + '-' + end_day;

	var owner_id = document.getElementById("absence:absence_owner_id:0").value;

	var xmlHttp = new XMLHttpRequest();
	xmlHttp.onreadystatechange = function() {
		if (debug) console.log('absences/new: readyState='+xmlHttp.readyState+', status='+xmlHttp.status+', responseText='+xmlHttp.responseText);
		if (xmlHttp.readyState != 4) return;		// 4 = Request finished and response is ready
		if (xmlHttp.status == 200) {
			document.getElementById("duration_days").value = xmlHttp.responseText;
		} else {
			var errorQuoted = xmlHttp.responseText.split('<blockquote><pre>').pop().split('</pre></blockquote>')[0];
			var tmp = document.createElement("DIV");
			tmp.innerHTML = errorQuoted;
			var error = tmp.textContent || tmp.innerText || "";
			alert('Error processing server response from /intranet-timesheet2/absences/absence-duration:\n\n '+error);
		}
        }
	xmlHttp.open("GET","/intranet-timesheet2/absences/absence-duration?user_id="+owner_id+"&start_date="+start_date+"&end_date="+end_date);
	xmlHttp.send(null);

	if (debug) console.log('absences/new: Calculating absence duration: Finished');
};

// Trigger the automatic calculation of duration with the change
// of any date field
document.getElementById("start_date.day").addEventListener("change", calculateAbsenceDuration, false);
document.getElementById("start_date.month").addEventListener("change", calculateAbsenceDuration, false);
document.getElementById("start_date.year").addEventListener("change", calculateAbsenceDuration, false);

document.getElementById("end_date.day").addEventListener("change", calculateAbsenceDuration, false);
document.getElementById("end_date.month").addEventListener("change", calculateAbsenceDuration, false);
document.getElementById("end_date.year").addEventListener("change", calculateAbsenceDuration, false);
</script>
