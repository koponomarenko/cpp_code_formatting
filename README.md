--------------------------------------------------------------------------------
Description
--------------------------------------------------------------------------------

clang-format is the formatting tool which can be use with intention to automatically
apply formatting rules based on best practices in C++ community.

`dot-clang-format` - is `.clang-format` file.

--------------------------------------------------------------------------------
Prerequisites
--------------------------------------------------------------------------------

clang-format 7.0.1

A pre-built binaries can be get from:
    http://releases.llvm.org/download.html#7.0.1


--------------------------------------------------------------------------------
If you want to format a project using "clang-format"
--------------------------------------------------------------------------------

Put the correct `.clang-format` file into the root directory of a project:

    $ cp dot-clang-format <proj_root_dir>/.clang-format

Run the clang-format with the correct options on all sources in the poject
   directory using this script:

    $ cd <proj_root_dir>
    $ <path_to_this_script>/clang-format-fixer.sh


--------------------------------------------------------------------------------
Other info
--------------------------------------------------------------------------------

You can use "upfind.sh" to check if there are any ".clang-format" files in all
parent directories above:

    $ cd <directory_from_which_you_want_to_check>
    $ <path_to_this_script>/upfind.sh -name '.clang-format'

