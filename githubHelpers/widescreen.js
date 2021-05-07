// This script will expand Github pages to use a larger width.
// The width is controlled by `maxWidth`. Smaller values may be helpful for ultra wide monitors.
// The default `maxWidth` (98) leaves some buffer space while still being much wider than Github's default.
javascript: var maxWidth = 98;
var style = document.createElement('style');
var padding = (100 - maxWidth) / 2;
style.innerText = `   .container-lg,   .container-xl {     max-width: ${maxWidth}% !important;     padding-right: ${padding}% !important;     padding-left: ${padding}% !important;   }`;
var head = document.getElementsByTagName('head')[0];
head.appendChild(style);