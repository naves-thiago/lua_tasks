# Example summary
These are some usage examples written in [Löve](https://love2d.org).
* **blink1**:
	* Blink a LED once a second. Stop when the space bar is pressed.
	* **blink1_par**: Implementation using the parallel blocks API (`par_and` / `par_or`).
	* **blink1_cb**: Implementation using the callback API.
* **blink2**:
	* Blink a LED once a second. Pressing the 1 key speeds up the blinking, pressing the 2 key slows it down. Pressing both together in a 500ms window stops the blink.
 	* **blink2_par**: Implementation using the parallel blocks API (`par_and` / `par_or`).
	* **blink2_cb**: Implementation using the callback API.
* **independent_tasks**:
	* Starts 2 tasks, each blinking a LED in a different speed.
* **sub_tasks_1**:
	* Starts a main task that writes "Press either 1 or 2". Creates a sub-task to wait for either button using `par_or`. Writes "Press 3 and 4 in any order". Creates a sub-task to wait for both buttons using `par_and`. Writes "Done".
* **sub_tasks_2**:
	* Starts a main task that waits for the space bar. Once pressed, starts 10 sub-tasks, each blinking a LED in a different speed. The main task then waits for the space bar again. Pressing the it finishes the main task, killing the sub-tasks and stopping the blink.
* **future_1**:
	* Simulates a task requesting some data from an asynchronous API
