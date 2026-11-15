#include <jni.h>
#include <string>
#include <android/log.h>
#include "../engine/audio_engine.h"

#define LOG_TAG "Tannhauser_JniBridge"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

using namespace tannhauser;

extern "C" {

JNIEXPORT jboolean JNICALL
Java_com_example_tannhauser_1music_1player_bridge_NativeAudioBridge_nativeSetUsbFileDescriptor(
        JNIEnv* env, jobject /* this */, jint fd) {
    LOGI("JNI: nativeSetUsbFileDescriptor called with FD=%d", fd);
    return AudioEngine::getInstance().setUsbFileDescriptor(fd) ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT jboolean JNICALL
Java_com_example_tannhauser_1music_1player_bridge_NativeAudioBridge_nativeLoadFile(
        JNIEnv* env, jobject /* this */, jstring filePath) {
    if (!filePath) return JNI_FALSE;
    const char* nativePath = env->GetStringUTFChars(filePath, nullptr);
    std::string pathStr(nativePath);
    env->ReleaseStringUTFChars(filePath, nativePath);

    LOGI("JNI: nativeLoadFile called with path: %s", pathStr.c_str());
    return AudioEngine::getInstance().loadFile(pathStr) ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT jboolean JNICALL
Java_com_example_tannhauser_1music_1player_bridge_NativeAudioBridge_nativePlay(
        JNIEnv* env, jobject /* this */) {
    return AudioEngine::getInstance().play() ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT jboolean JNICALL
Java_com_example_tannhauser_1music_1player_bridge_NativeAudioBridge_nativePause(
        JNIEnv* env, jobject /* this */) {
    return AudioEngine::getInstance().pause() ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT jboolean JNICALL
Java_com_example_tannhauser_1music_1player_bridge_NativeAudioBridge_nativeResume(
        JNIEnv* env, jobject /* this */) {
    return AudioEngine::getInstance().resume() ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT jboolean JNICALL
Java_com_example_tannhauser_1music_1player_bridge_NativeAudioBridge_nativeStop(
        JNIEnv* env, jobject /* this */) {
    return AudioEngine::getInstance().stop() ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT jboolean JNICALL
Java_com_example_tannhauser_1music_1player_bridge_NativeAudioBridge_nativeSeek(
        JNIEnv* env, jobject /* this */, jlong positionMs) {
    return AudioEngine::getInstance().seek(positionMs) ? JNI_TRUE : JNI_FALSE;
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

} // extern "C"
