; framer.p8 - Miniature frame-based app/task framework.
; by Ben Cox <cox@djehuti.com>
; Released under Creative Commons; see LICENSE for details.
; See README.md for (minimal) documentation, and comments below.

%import syslib
%option ignore_unused

framer {
    ; Call this to initialize the task runner and have it run the given
    ; function with the given arg, on the first iteration. That function
    ; can add other work (like frame tasks) from there.
    sub go(uword kickoff, uword arg) {
        reset()
        void addOneShot(kickoff, arg)
        goto resume
    }

    ; Call this to resume the runner (like calling go without resetting or
    ; adding a task).
    sub resume() {
        ; Check to see if there's anything to actually do first.
        done = frameTaskCount == 0 and oneShotHead == oneShotTail
        while not done {
            runTasks()
            sys.waitvsync()
            done = done or (frameTaskCount == 0 and oneShotHead == oneShotTail)
        }
    }

    ; Call this function to stop the runner (and make go/resume return).
    sub stop() {
        done = true
    }

    ; Initializes the task lists. You only need to call this if you want
    ; to run the loop yourself; it is called first by go().
    sub reset() {
        frameTaskCount = 0
        oneShotHead = 0
        oneShotTail = 0
    }

    ; Add a permanent frame task to the end of the list.
    ; Returns true on success, or false if there's no more room for
    ; frame tasks. These aren't dynamic, so if you need more than a few
    ; of these, you should think about combining some. (You only ever
    ; _really_ need one.)
    ; Also returns false if you pass null, because just why.
    sub addFrameTask(uword newTask) -> bool {
        if newTask == 0 {
            return false
        }
        if frameTaskCount == MAXFRAMETASKS {
            return false
        }
        frameTasks[frameTaskCount] = newTask
        frameTaskCount++
        return true
    }

    ; Adds a new item to the tail of the list and advances it, to
    ; be run on the next frame (the next trip through runTasks).
    ; Returns false if the new task is null (don't do that), or
    ; if there isn't room for this in the task buffer.
    sub addOneShot(uword newTask, uword newTaskArg) -> bool {
        if newTask == 0 {
            return false
        }
        ubyte newWorkTail = (oneShotTail + 1) & ONESHOT_MASK
        if newWorkTail == oneShotHead {
            ; This would fill the last slot in the ringbuffer which we
            ; can't tell from it being empty, so don't let it happen.
            return false
        }
        ; All good; pop it in.
        oneShots[oneShotTail] = newTask
        oneShotArgs[oneShotTail] = newTaskArg
        oneShotTail = newWorkTail
        return true
    }

    ; Call this once per frame (go/resume does that). You only need to call
    ; this directly if you manage your own main loop; not if you use go/resume.
    sub runTasks() {
        runFrameTasks_()
        runOneShots_()
    }

    ; Task work functions can check this (global) value for their argument.
    ; The value that was passed to addOneShot is placed here before the
    ; workFunc is called. For frame tasks, this will be ==workIndex.
    uword @zp workArg = 0

    ; ---------------------------------------------------------------
    ; Everything below this point is private and shouldn't be relied on.

    ; Run through the whole list of frame tasks and call them all.
    sub runFrameTasks_() {
        for workIndex in 0 to frameTaskCount - 1 {
            workFunc = frameTasks[workIndex]
            workArg = workIndex
            dispatch_()
            if done {
                return
            }
        }
    }

    ; Runs through all the one-shot tasks that are currently added. Those that
    ; are added after this routine starts won't happen until the next frame.
    sub runOneShots_() {
        if done {
            return
        }
        ubyte @zp startTail = oneShotTail
        workIndex = oneShotHead
        while workIndex != startTail {
            workFunc = oneShots[workIndex]
            workArg = oneShotArgs[workIndex]
            workIndex = (workIndex + 1) & ONESHOT_MASK
            oneShotHead = workIndex
            dispatch_()
            if done {
                return
            }
        }
    }

    ; Utility function used to JSR to an arbitrary address.
    sub dispatch_() {
        if workFunc != 0 {
            goto workFunc
        }
    }

    ; ---------------------------------------------------------------
    ; Storage

    ; Loop variables.

    bool @requirezp done = false   ; used by stop/go/resume
    ubyte @requirezp workIndex = 0 ; which task are we running
    uword @requirezp workFunc = 0  ; address of the work function

    ; Data for the frame tasks table.
    ubyte frameTaskCount = 0
    const ubyte MAXFRAMETASKS = 32      ; should be way more than enough, can't
    uword[MAXFRAMETASKS] frameTasks = 0 ; be >128 due to prog8 array limit.

    ; Data for the one-shot work functions. This is a ringbuffer.
    ; Each spot in the ringbuffer occupies 2 words; one word is the
    ; address of the work function, and the other is the argument to
    ; be passed (in workArg) to the work function. (That is: we set
    ; the workArg variable, which is global, to the arg value before
    ; calling the work func.)

    const ubyte ONESHOTS = 128 ; must be a power of 2, limited to 128 by prog8.

    ; With ONESHOTS=128 (the max) these tables occupy 512 bytes.
    uword[ONESHOTS] oneShots = 0
    uword[ONESHOTS] oneShotArgs = 0

    ; If head==tail, the ringbuffer is empty. The indices wrap around when
    ; ANDed with the mask (why it has to be a power of 2).
    const ubyte ONESHOT_MASK = ONESHOTS-1
    ubyte oneShotTail = 0  ; Tail is the next slot to be filled
    ubyte oneShotHead = 0  ; Head is the next slot to be executed
}
