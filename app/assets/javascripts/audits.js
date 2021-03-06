$(document).ready(function() {
	// ----------------- ajax pagination ---------------
	// will_paginate does not support link attributes yet.
	// See: https://github.com/mislav/will_paginate/pull/100

	$('#audits-table-pagination a').live('ajax:success', function (evt, data, statusStr, xhr) {
		$('.audits-table-container').replaceWith(data);
		fixAuditChangesColumnWidth();
	}).live('ajax:error', function () {
		alert("[ERROR] unable to retrieve audits");
	});

	// -------------- fix td.changes width -------------
	var fixAuditChangesColumnWidth = function () {
		var td = $('#audits-table td.changes').first();
		var table = td.closest('table');
		var width = table.parent().width() - td.position().left + table.position().left - 5;
		$('#audits-table td.changes span').width(width);
	};

	if ($('#audits-table').size() > 0)
		fixAuditChangesColumnWidth();
});
