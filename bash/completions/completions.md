# Arguments
These arguments are passed into a completion function by Bash.
* \$1
  * The name of the command whose arguments are being completed
* \$2
  * Is the word being completed
* \$3
  * The word preceding the word being completed on the current command line

# Environment Variables
* \$COMP_LINE
  * The current command line.
* \$COMP_POINT
  * The index of the current cursor position relative to the beginning of the current command.
  * If the current cursor position is at the end of the current command, the value of this variable is equal to ${#COMP_LINE}.
* \$COMP_KEY
  * The key (or final key of a key sequence) used to invoke the current completion function.
* \$COMP_TYPE
    * Set to an integer value corresponding to the type of completion attempted that caused a completion function to be called.
    * TAB for normal completion.
    * ‘?’ for listing completions after successive tabs.
    * ‘!’ for listing alternatives on partial word completion.
    * ‘@’ to list completions if the word is not unmodified/
    * ‘%’ for menu completion.
* \$COMP_WORDS
  * An array variable consisting of the individual words in the current command line.
      * Includes the command name as well. So `git diff` is `git` and `diff`.
      * Keep in mind that `git diff ` would be three words, `git`, `diff`, and an empty string.
  * The line is split into words as Readline would split it, using COMP_WORDBREAKS as described above.
* \$COMP_CWORD
  * An index into ${COMP_WORDS} of the word containing the current cursor position.
* \$COMP_WORDBREAKS
  * The set of characters that the Readline library treats as word separators when performing word completion.
  * If COMP_WORDBREAKS is unset, it loses its special properties, even if it is subsequently reset.

# Guidelines
* Completion logic generally only handles completion, nothing more.
  * It allows inserting duplicated arguments or completions in the middle of a word which creates an invalid argument/command.
  * So there is no need to try and read the whole command and validate it, just complete the current argument.