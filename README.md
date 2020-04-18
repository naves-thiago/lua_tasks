# Lua tasks
Lua library to describe parallel blocks of code inspired by the Céu language (work in progress).  
Refer to the comments in tasks.lua for more (and possibly more up to date) info.
* `task_t` objects hold code that will run in parallel (in a coroutine).
* Events allow tasks to send messages asynchronously or block waiting for them.
  * Tasks can use the `await(<event>)` function to block waiting for the `<event>` event. `await` returns parameters sent to `emit` (minus `<event>`).
  * The `emit(<event>, ...)` function sends an `<event>` event and unblocks all tasks waiting on `await(<event>)`.
    * If no tasks are currently blocked waiting for the event, it's discarded.
    * `<event>` can be any value that can be used as key in a table.
* Tasks can have subtasks that are killed when the outer task finishes or is killed.
* `par_and` and `par_or` functions return a task that start subtasks in parallel.
  * `par_and` ends when all subtasks end.
  * `par_or` ends when any subtask end, killing the others.
* `listen(<event>, callback, [once])` adds a `callback` function as a listener of `<event>`.
  * The `callback` will be executed on `emit(<event>, ...)`.
  * The parameters sent to the `emit` will be sent to the `callback`, including the event object corresponding to the `<event>` identifier (unlike the return of `await`).
  * If `once` is `true`, the callback will be executed only on the next time the event occurs, otherwise it will execute every time.
* `stop_listening(<event>, callback)` removes the `callback` from the listeners.
* `future_t` objects represent a *future* event return value.
  * `future_t:new(<event>)` creates a future object for `<event>`.
  * `:get()` returns the `<event>` result if avaliable (i.e. `emit(<event>, ...)` was executed already) or behaves as `await(<event>)` otherwise.
  * `:cancel()` stops waiting for `<event>`. Unblocks all `:get()`s, returning `nil`. All `:get()` calls from now on return `nil` immediately.
  * `:is_canceled()` returns true if the future was cancelled.
  * `:is_done()` returns true if the `<event>` was emitted. If the future is done, `:get()` return immediately.
* `timer_t` allows callbacks to be executed based on time passage.
  * `timer_t:new(interval, callback, [cyclic])` creates a timer that will execute the `callback` after `interval` milliseconds.
    * If `cyclic` is `true`, the callback will be executed every `interval` interval (instead of only once).
  * `:start()` schedules the timer: Starts counting the interval.
  * `:stop()` stops the timer.
* `now_ms()` retuns the current timestamp in milliseconds (this is an internal counter in this lib, not the OS time)
* `in_ms(interval, callback)` executes `callback` once in `interval` milliseconds from now. Returns the timer object controlling this.
* `every_ms(interval, callback)` executes `callback` every `interval` milliseconds, starting now. Returns the timer object controlling this.
* `await_ms(interval)` blocks the current task for `interval` milliseconds.
* `update_time(dt)` tells the lib that `dt` milliseconds have passed. This will unblock tasks and execute timer callbacks if needed.
