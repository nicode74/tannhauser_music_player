#if __has_include(<jni.h>)
#include <jni.h>
#else
// Fallback for IDE language server when Android NDK sysroot is not explicitly loaded
#ifndef JNIEXPORT
#define JNIEXPORT
#endif
#ifndef JNICALL
#define JNICALL
#endif
typedef unsigned char jboolean;
typedef signed char jbyte;
typedef unsigned short jchar;
typedef short jshort;
typedef int jint;
typedef long long jlong;
typedef float jfloat;
typedef double jdouble;
typedef void* jobject;
typedef void* jclass;
typedef void* jstring;
typedef void* jarray;
struct _JNIEnv {
    const char* GetStringUTFChars(jstring, jboolean*) { return ""; }
    void ReleaseStringUTFChars(jstring, const char*) {}
};
typedef struct _JNIEnv JNIEnv;
#define JNI_TRUE 1
#define JNI_FALSE 0
#endif

#include <string>

#if __has_include(<android/log.h>)
#include <android/log.h>
#define LOG_TAG "Tannhauser_JniBridge"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)
#else
#include <cstdio>
#define LOG_TAG "Tannhauser_JniBridge"
#define LOGI(...) printf(__VA_ARGS__)
#define LOGE(...) fprintf(stderr, __VA_ARGS__)
#endif

#include "../engine/audio_engine.h"

using namespace tannhauser;

extern "C" {

JNIEXPORT jboolean JNICALL
Java_com_example_tannhauser_1music_1player_bridge_NativeAudioBridge_nativeSetUsbFileDescriptor(
        JNIEnv* env, jobject /* this */, jint fd) {
    LOGI("JNI: nativeSetUsbFileDescriptor - START: FD=%d", fd);
    bool res = AudioEngine::getInstance().setUsbFileDescriptor(fd);
    LOGI("JNI: nativeSetUsbFileDescriptor - END: result=%d", res ? 1 : 0);
    return res ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT jboolean JNICALL
Java_com_example_tannhauser_1music_1player_bridge_NativeAudioBridge_nativeLoadFile(
        JNIEnv* env, jobject /* this */, jstring filePath) {
    LOGI("JNI: nativeLoadFile - START");
    if (!filePath) {
        LOGE("JNI: nativeLoadFile - filePath is null!");
        return JNI_FALSE;
    }
    const char* nativePath = env->GetStringUTFChars(filePath, nullptr);
    if (!nativePath) {
        LOGE("JNI: nativeLoadFile - Failed to get native UTF chars!");
        return JNI_FALSE;
    }
    std::string pathStr(nativePath);
    env->ReleaseStringUTFChars(filePath, nativePath);

    LOGI("JNI: nativeLoadFile - Path: %s", pathStr.c_str());
    bool res = AudioEngine::getInstance().loadFile(pathStr);
    LOGI("JNI: nativeLoadFile - END: result=%d", res ? 1 : 0);
    return res ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT jboolean JNICALL
Java_com_example_tannhauser_1music_1player_bridge_NativeAudioBridge_nativePlay(
        JNIEnv* env, jobject /* this */) {
    LOGI("JNI: nativePlay - START");
    bool res = AudioEngine::getInstance().play();
    LOGI("JNI: nativePlay - END: result=%d", res ? 1 : 0);
    return res ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT jboolean JNICALL
Java_com_example_tannhauser_1music_1player_bridge_NativeAudioBridge_nativePause(
        JNIEnv* env, jobject /* this */) {
    LOGI("JNI: nativePause - START");
    bool res = AudioEngine::getInstance().pause();
    LOGI("JNI: nativePause - END: result=%d", res ? 1 : 0);
    return res ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT jboolean JNICALL
Java_com_example_tannhauser_1music_1player_bridge_NativeAudioBridge_nativeResume(
        JNIEnv* env, jobject /* this */) {
    LOGI("JNI: nativeResume - START");
    bool res = AudioEngine::getInstance().resume();
    LOGI("JNI: nativeResume - END: result=%d", res ? 1 : 0);
    return res ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT jboolean JNICALL
Java_com_example_tannhauser_1music_1player_bridge_NativeAudioBridge_nativeStop(
        JNIEnv* env, jobject /* this */) {
    LOGI("JNI: nativeStop - START");
    bool res = AudioEngine::getInstance().stop();
    LOGI("JNI: nativeStop - END: result=%d", res ? 1 : 0);
    return res ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT jboolean JNICALL
Java_com_example_tannhauser_1music_1player_bridge_NativeAudioBridge_nativeSeek(
        JNIEnv* env, jobject /* this */, jlong positionMs) {
    LOGI("JNI: nativeSeek - START: positionMs=%lld", (long long)positionMs);
    bool res = AudioEngine::getInstance().seek(positionMs);
    LOGI("JNI: nativeSeek - END: result=%d", res ? 1 : 0);
    return res ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT jint JNICALL
Java_com_example_tannhauser_1music_1player_bridge_NativeAudioBridge_nativeGetPlaybackState(
        JNIEnv* env, jobject /* this */) {
    return static_cast<jint>(AudioEngine::getInstance().getState());
}

JNIEXPORT jint JNICALL
Java_com_example_tannhauser_1music_1player_bridge_NativeAudioBridge_nativeGetSampleRate(
        JNIEnv* env, jobject /* this */) {
    return AudioEngine::getInstance().getPlaybackInfo().format.sampleRate;
}

JNIEXPORT jint JNICALL
Java_com_example_tannhauser_1music_1player_bridge_NativeAudioBridge_nativeGetChannels(
        JNIEnv* env, jobject /* this */) {
    return AudioEngine::getInstance().getPlaybackInfo().format.channels;
}

JNIEXPORT jint JNICALL
Java_com_example_tannhauser_1music_1player_bridge_NativeAudioBridge_nativeGetBitDepth(
        JNIEnv* env, jobject /* this */) {
    return AudioEngine::getInstance().getPlaybackInfo().format.bitDepth;
}

JNIEXPORT jlong JNICALL
Java_com_example_tannhauser_1music_1player_bridge_NativeAudioBridge_nativeGetDuration(
        JNIEnv* env, jobject /* this */) {
    return AudioEngine::getInstance().getPlaybackInfo().totalDurationMs;
}

JNIEXPORT jlong JNICALL
Java_com_example_tannhauser_1music_1player_bridge_NativeAudioBridge_nativeGetPosition(
        JNIEnv* env, jobject /* this */) {
    return AudioEngine::getInstance().getPlaybackInfo().currentPositionMs;
}

JNIEXPORT jboolean JNICALL
Java_com_example_tannhauser_1music_1player_bridge_NativeAudioBridge_nativeSetPeqEnabled(
        JNIEnv* /* env */, jobject /* this */, jboolean enabled) {
    LOGI("JNI: nativeSetPeqEnabled - enabled=%d", enabled ? 1 : 0);
    AudioEngine::getInstance().setPeqEnabled(enabled == JNI_TRUE);
    return JNI_TRUE;
}

JNIEXPORT jboolean JNICALL
Java_com_example_tannhauser_1music_1player_bridge_NativeAudioBridge_nativeSetPeqPreamp(
        JNIEnv* /* env */, jobject /* this */, jdouble preampDb) {
    LOGI("JNI: nativeSetPeqPreamp - preampDb=%.2f", (double)preampDb);
    AudioEngine::getInstance().setPeqPreamp(static_cast<double>(preampDb));
    return JNI_TRUE;
}

JNIEXPORT jboolean JNICALL
Java_com_example_tannhauser_1music_1player_bridge_NativeAudioBridge_nativeUpdatePeqBand(
        JNIEnv* /* env */, jobject /* this */, jint index, jint type, jdouble fc, jdouble gainDb, jdouble q, jboolean enabled) {
    LOGI("JNI: nativeUpdatePeqBand - idx=%d type=%d fc=%.1f gain=%.1f q=%.2f en=%d",
         index, type, (double)fc, (double)gainDb, (double)q, enabled ? 1 : 0);
    AudioEngine::getInstance().updatePeqBand(
        static_cast<int>(index),
        static_cast<int>(type),
        static_cast<double>(fc),
        static_cast<double>(gainDb),
        static_cast<double>(q),
        enabled == JNI_TRUE
    );
    return JNI_TRUE;
}

JNIEXPORT jboolean JNICALL
Java_com_example_tannhauser_1music_1player_bridge_NativeAudioBridge_nativeResetPeqStates(
        JNIEnv* /* env */, jobject /* this */) {
    LOGI("JNI: nativeResetPeqStates");
    AudioEngine::getInstance().resetPeqStates();
    return JNI_TRUE;
}

} // extern "C"
