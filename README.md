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
6. If using bash-it, run the `make enableBashItScripts` command.
7. Restart the terminal again.
8. Run `myconfig config --local status.showUntrackedFiles no` to not show untracked files. Otherwise all files in your home directory will report when running `git status`. You will need to manually add new files to commit them to the repo.
    - Verify by running `myconfig status` and it doesn't report a ton of files.

# Working with
Use the `myconfig` alias to perform git operations.

# Custom Bash-it setup
# The .bashrc file will copy the custom alias and completion files to the bash-it custom directories when running. This ensures that everything loads properly without having to use a custom fork of bash-it.

# Common Issues/Gotcha
## Auth issues with submodules
- Errors like
```
Cloning into '<PATH>/.vim/pack/convergedtarkus/start/vim-gitgutter'...
git@github.com: Permission denied (publickey).
fatal: Could not read from remote repository.

Please make sure you have the correct access rights
and the repository exists.
fatal: clone of 'git@github.com:airblade/vim-gitgutter.git' into submodule path '<PATH>/.vim/pack/convergedtarkus/start/vim-gitgutter' failed
```
- If you are me and use the kind of setup from clonePersonalRepo in bash/parts/git.bash, you'll need to change all the 'git@github.com' urls to be 'git@github.com-personal'.
- Make sure to add a SSH key
    - [Generate A New SSH Key](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent)

## Bash-It Not Loading Custom Files
- Make ensure alias custom and completion custom are enabled in bash-it.


# DefaultKeyBinding.dict
- This file is used to set up custom keybindings on MacOS.
- Copy this to `~/Library/KeyBindings/DefaultKeyBinding.dict`.
- Currently this only overrides CMD+Control+Left/Right arrow to be a noop to prevent MacOS from making a noise when this combination is used.

# License
This project uses the https://unlicense.org license. Basically no copyright, you can copy, modify, use, sell etc any code here without giving me credit (though if this is helpful to you, I'd love a shout out!). I give no warranty of any kind on this code.
