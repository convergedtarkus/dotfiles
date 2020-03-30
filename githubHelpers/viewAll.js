// This script will expand any diffs that github has collapsed becuase
// github thinks the diff is too large.
// Other collapsed diffs will not be expanded.
javascript: (function (collapse) {
	let viewForms = document.getElementsByClassName("js-reviewed-checkbox");

	for (let viewForm of viewForms) {
		if (viewForm.checked===!collapse) {
			viewForm.click();
		}
	}
})(true);
