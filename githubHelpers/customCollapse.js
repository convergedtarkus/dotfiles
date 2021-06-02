// This script will collapse all not production files for easy viewing.
// Also collapses any files in a vendor directory or lock/sum files.
javascript: (function() {
    let matchRegex = prompt("Please regex to collapse by", "");
    
    if (matchRegex == null) {
      console.log("Must enter a match regex");
    }
    
    // Get all the file names.
    let allFileHeaders = document.getElementsByClassName("file-header");

    for (let fileHeader of allFileHeaders) {
        let fileNameElement = fileHeader.getElementsByClassName("Link--primary")[0];

        // Collapse the file if it is test file. Not an exhaustive list (largely Go + Dart specific).
        // Also collapses dependency files.
        let shouldShow = true;
        if (fileNameElement.textContent.match(matchRegex)) {
            shouldShow = false;
        }

        // Correctly check the 'Viewed' button based on shouldShow.
        let viewedDiff = fileHeader.getElementsByClassName("js-reviewed-checkbox")[0];
        if (viewedDiff.checked === shouldShow) {
            viewedDiff.click();
        }
    }
})();
