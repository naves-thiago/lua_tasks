# Lua tasks
Lua library to describe parallel blocks of code inspired by the Céu language (work in progress).
* `task_t` objects hold code that will run in parallel (in a coroutine).
* Events allow tasks to send messages asynchronously or block waiting for them.
  * Tasks can use the `await(<event>)` function to block waiting for the `<event>` event.
  * The `emit(<event>)` function sends and `<event>` event and unblocks all tasks waiting on `await(<event>)`.
    * If no tasks are currently blocked waiting for the event, it's discarded.
    * `<event>` can be any value that can be used as key in a table.
* Tasks can have subtasks that are killed when the outer task finishes or is killed.
* `par_and` and `par_or` functions start subtasks in parallel.
  * `par_and` ends when all subtasks end.
  * `par_or` ends when any subtask end, killing the others.
