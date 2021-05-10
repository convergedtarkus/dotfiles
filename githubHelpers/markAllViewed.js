// This script will collapse (click 'Viewed') all files in a Github pull request.
javascript: (function (collapse) {
	let viewForms = document.getElementsByClassName("js-reviewed-checkbox");

	for (let viewForm of viewForms) {
		if (viewForm.checked===!collapse) {
			viewForm.click();
		}
	}
})(true);
