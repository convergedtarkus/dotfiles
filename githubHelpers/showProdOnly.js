// This script will collapse all not production files for easy viewing.
// Also collapses any files in a vendor directory or lock/sum files.
javascript: (function() {
    // Get all the file names.
    let allFileHeaders = document.getElementsByClassName("file-header");

    for (let fileHeader of allFileHeaders) {
        let fileNameElement = fileHeader.getElementsByClassName("Link--primary")[0];

        // Collapse the file if it is test file. Not an exhaustive list (largely Go + Dart specific).
        // Also collapses dependency files.
        let shouldShow = true;
	// TODO Is there a more performant way of running all these checks?
        if (
            // Direct test files/directories.
            fileNameElement.textContent.endsWith("_test.go") ||
            fileNameElement.textContent.endsWith("_test.dart") ||
            fileNameElement.textContent.includes("/test/") ||
            // Test util file matches, not perfect but should work pretty well.
            fileNameElement.textContent.includes("test_utils.") ||
            fileNameElement.textContent.includes("test_util.") ||
            fileNameElement.textContent.includes("/testutil/") ||
            fileNameElement.textContent.includes("testutils.") ||
            // Dependency files/directories.
            fileNameElement.textContent.startsWith("vendor/") ||
            fileNameElement.textContent.endsWith(".sum") ||
            fileNameElement.textContent.endsWith(".lock") ||
	    // Generated files
	    fileNameElement.textContent.endsWith(".sg.g.dart")) {
            shouldShow = false;
        }

        // Correctly check the 'Viewed' button based on shouldShow.
        let viewedDiff = fileHeader.getElementsByClassName("js-reviewed-checkbox")[0];
        if (viewedDiff.checked === shouldShow) {
            viewedDiff.click();
        }

        // Load large diffs that should be shown as well.
        if (shouldShow) {
            let fileContentElement = fileHeader.nextElementSibling;
            let hiddenDiffReasonElement = fileContentElement.getElementsByClassName("hidden-diff-reason")[0];
            if (hiddenDiffReasonElement != null && hiddenDiffReasonElement.textContent.includes("Large diffs are not rendered by default.")) {
                let loadDiffButton = fileContentElement.getElementsByClassName("load-diff-button")[0];
                loadDiffButton.click();
            }
        }
    }
})();
