## linting

before finalising changes and reporting to the user that you're done,
ALWAYS run `odin check hollie -vet` to ensure that your changes produce valid code.

## style

NEVER USE COMMENTS, DO NOT EVER PUT COMMENTS IN THE CODE

## architecture

raylib bindings should never be used directly from application code and should instead be
wrapped with a function that uses standard odin types.

any code that can be completely self-contained without interdepencies should be put in a submodule,
otherwise it should be an aptly named virtual submodule in the main module such as scene.odin

## naming conventions

- submodules are one word
- functions in submodules do not namespacing on functions like module_do_thing
- functions in the main module (bar main.odin) require namespacing like filename_do_thing (unless private to that file)

## commands

- use `fd` and `rg` if you must use bash to acquire more information about the project. 
- NEVER use `odin run` or `odin build`

