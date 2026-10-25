package org.dartpilot.spike;

/** The native measurement (engine/android/spike): streams the cameras behind the given USB file descriptors. */
public final class NativeSpike {
    static {
        System.loadLibrary("dartpilot_spike");
    }

    private NativeSpike() {}

    /** Blocks for {@code seconds}; returns the result as JSON. */
    public static native String run(int[] fds, int seconds);
}
