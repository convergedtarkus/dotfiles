# Dotfiles
There are my dotfiles. You are welcome to use them as a whole, or just take any parts that are helpful to you.

# How to setup
I'm using the setup from https://www.atlassian.com/git/tutorials/dotfiles which allows cloning this repo into $HOME to automatically sync all files. I've included how to do this below (and to help me remember without having to re-read the article).

1. [combinedBash.bash](https://github.com/convergedtarkus/dotfiles/blob/master/bash/combinedBash.bash) defines the alias to interact with the repo. It is also here for setup ease `alias myconfig="/usr/bin/git --git-dir=$HOME/.myconfig/ --work-tree=$HOME"`. This assumes you clone into `$HOME/.myconfig`.
2. `git clone --bare https://github.com/convergedtarkus/dotfiles.git $HOME/.myconfig`
3. `myconfig checkout`
    - This will warn you about overwritting any files in this repo that are in your home directory. You should manually back these up.
    - `myconfig checkout -f` will overwrite everything.
4. This repo uses submodules for bash-it and vim plugins
    - `myconfig submodule update --init`
5. At this point restart you terminal
6. If using bash-it, enable the following things
```
bash-it enable alias personal
bash-it enable plugin alias-completion
bash-it enable completion bash-it brew defaults git makefile system tmux
```
7. Restart the terminal again.
8. Run `myconfig config --local status.showUntrackedFiles no` to not show untracked files. Otherwise all files in your home directory will report when running `git status`. You will need to manually add new files to commit them to the repo.
    - Verify by running `myconfig status` and it doesn't report a ton of files.

# Working with
Edit a tracked file and then use the `myconfig` alias to commit and push. If you need to integrate remote changes, you'll need to reclone unfortunately (if you've have a better solution I would love to hear it!).

# Liscense
This project uses the https://unlicense.org liscense. Basically no copywrite, you can copy, modify, use, sell etc any code here without giving me credit (though if this is helpful to you, I'd love a shout out!). I give no warranty of any kind on this code.
