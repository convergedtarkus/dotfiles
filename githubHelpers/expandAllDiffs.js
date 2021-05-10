// This script will expand all diffs that Github is hiding for any reason (too
// large, auto generated, vendor/dependency code tec).
javascript: (function () {
	// Get all the collapsed diffs.
	let loadDiffs = document.getElementsByClassName("load-diff-button");

	for (let loadDiff of loadDiffs) {
    loadDiff.click();
	}
})();
