#include <jni.h>

#include <vector>

#include "spike.hpp"

// org.dartpilot.spike.NativeSpike.run(int[] fds, int seconds): the measurements as JSON
extern "C" JNIEXPORT jstring JNICALL Java_org_dartpilot_spike_NativeSpike_run (JNIEnv* env, jclass, jintArray fds, jint seconds)
{
    const jsize count = env->GetArrayLength(fds);
    std::vector<int> descriptors(static_cast<size_t>(count));
    env->GetIntArrayRegion(fds, 0, count, descriptors.data());
    const std::string result = dartpilot::android_spike::run(descriptors, seconds);
    return env->NewStringUTF(result.c_str());
}
