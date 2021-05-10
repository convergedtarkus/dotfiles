// This script will expand any diffs that Github has collapsed because
// github thinks the diff is too large.
// Other collapsed diffs will not be expanded.
javascript: (function () {
	// Get all the collapsed diffs.
	let loadDiffs = document.getElementsByClassName("load-diff-button");

	let alertMessage = "";
	let idx = 0;

	for (let loadDiff of loadDiffs) {
		// Get the div children of the collapsed diff element.
		let divChildren = [];
		for (let child of loadDiff.parentElement.children) {
			if (child.tagName === "DIV") {
				divChildren.push(child);
			}
		}

		// There should be one div child and if that text is the large diff text then
		// click it to expand the diff.
		const expectedDivChildren = 1;
		if (divChildren.length === expectedDivChildren) {
			if (divChildren[0].textContent.match("Large diffs are not rendered by default.")) {
				loadDiff.click();
			}
		} else {
			// Build up an alert in case something about Github's dom setup has changed.
			alertMessage += "Has wrong number of divChildren: " + divChildren.length + " but expected: " + expectedDivChildren + " at index: " + idx + "\n";
		}
		idx++;
	}

	if (alertMessage !== "") {
		alert(alertMessage);
	}
})();
