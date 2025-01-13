# Dotfiles
There are my dotfiles. You are welcome to use them as a whole, or just take any parts that are helpful to you.

# Bash
`.bash_profile` source `.bashrc` so `.bashrc` loads for all interactive shells.
This will load bash-it and in turn source `./bash/combinedBash.bash` which then sources everything under parts. In addition, any files (other than .keep) under `./custom` will be sourced as well allowing sourcing custom files.

`MYDOTFILES` is exported from .bashrc as the root of the project (when the .bashrc is), this is used to find other files.

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
bash-it enable plugin alias-completion man
bash-it enable completion bash-it brew defaults git makefile system tmux
```
7. Restart the terminal again.
8. Run `myconfig config --local status.showUntrackedFiles no` to not show untracked files. Otherwise all files in your home directory will report when running `git status`. You will need to manually add new files to commit them to the repo.
    - Verify by running `myconfig status` and it doesn't report a ton of files.

# Working with
Edit a tracked file and then use the `myconfig` alias to commit and push. If you need to integrate remote changes, you'll need to reclone unfortunately (if you've have a better solution I would love to hear it!).

# Updating Bash-It submodule
1. Checkout my [Bash-It fork](https://github.com/convergedtarkus/bash-it)
2. Pull in upstream master (that is https://github.com/Bash-it/bash-it)
3. Push that up.
4. cd into .bash-it
5. git pull master
6. cd to root
7. Commit the .bash-it folder

# Common Issues/Gotcha
## Auth issues with submodules
- If you are me and use the kind of setup from clonePersonalRepo in bash/parts/git.bash, you'll need to change all the 'git@github.com' urls to be 'git@github.com-personal'.

## Bash-It Not Loading Personal Files
- Add a symlink under .bash-it/enabled/ to .bash-it/aliases/available/personal.bash and name it '150--personal.bash'.
  - This is how bash-it enables things and will enable loading the personal.bash file.
  - `ln -s $HOME/.bash-it/aliases/available/personal.bash $HOME/.bash-it/enabled/150--personal.bash`
    - The `$HOME` is very important as the symlink does not get created correctly otherwise.


# License
This project uses the https://unlicense.org license. Basically no copyright, you can copy, modify, use, sell etc any code here without giving me credit (though if this is helpful to you, I'd love a shout out!). I give no warranty of any kind on this code.
